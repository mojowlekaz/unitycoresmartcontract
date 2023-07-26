// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./PriceContract.sol";
import "./UnityCoreLendingProtocol.sol";
import "./IUnityCoreLendingProtocol.sol";
import "./UnityCoreLendingProtocolProxy.sol";

contract ActivateCollateral {
    IUnityCoreLendingProtocol public unityCoreLendingProtocol;
    UnityCoreLendingProtocolProxy private unityCoreLendingProtocolProxy;
    UnityCoreLendingProtocolProxy public proxyContract;

    constructor(address _proxyContractAddress) {
        proxyContract = UnityCoreLendingProtocolProxy(_proxyContractAddress);
        selectedCollateralMapping[0] = IUnityCoreLendingProtocol
            .CollateralType
            .None;
        selectedCollateralMapping[1] = IUnityCoreLendingProtocol
            .CollateralType
            .CORE;
        selectedCollateralMapping[2] = IUnityCoreLendingProtocol
            .CollateralType
            .USDT;
        selectedCollateralMapping[3] = IUnityCoreLendingProtocol
            .CollateralType
            .USDC;
    }

    mapping(uint8 => IUnityCoreLendingProtocol.CollateralType)
        private selectedCollateralMapping;

    enum CollateralType {
        None,
        CORE,
        USDT,
        USDC
    }

    address[] public depositors;

    event CorerewardCLiamed(address indexed user, uint256 indexed amount);
    event UsdtrewardCLiamed(address indexed user, uint256 indexed amount);
    event UsdcrewardCLiamed(address indexed user, uint256 indexed amount);
    event Received(address indexed sender, uint256 amount);
    event CollateralDeactivated(address indexed user, string collateralType);

    function collateralTypeToString(
        UnityCoreLendingProtocol.CollateralType collateral
    ) internal pure returns (string memory) {
        if (collateral == UnityCoreLendingProtocol.CollateralType.None) {
            return "None";
        } else if (collateral == UnityCoreLendingProtocol.CollateralType.CORE) {
            return "CORE";
        } else if (collateral == UnityCoreLendingProtocol.CollateralType.USDT) {
            return "USDT";
        } else if (collateral == UnityCoreLendingProtocol.CollateralType.USDC) {
            return "USDC";
        }
        return "";
    }

    function someFunction() external {
        IUnityCoreLendingProtocol.CollateralType selected = IUnityCoreLendingProtocol
                .CollateralType
                .CORE;
        IUnityCoreLendingProtocol.UserBalance
            memory userBalance = unityCoreLendingProtocol.getUserBalance(
                msg.sender
            );
        userBalance.selectedCollateral = IUnityCoreLendingProtocol
            .CollateralType(selected);
        unityCoreLendingProtocol.setUserBalance(msg.sender, userBalance);
    }

    function activateCollateral(uint8 collateral) external {
        IUnityCoreLendingProtocol.CollateralType selected = IUnityCoreLendingProtocol
                .CollateralType(collateral);
        UnityCoreLendingProtocolProxy proxyContract = unityCoreLendingProtocolProxy;
        uint256 min_usdt_deposit = proxyContract.getMinUSDTDeposit();
        uint256 min_usdc_deposit = proxyContract.getMinUSDCDeposit();

        if (selected == IUnityCoreLendingProtocol.CollateralType.None) {
            revert("Invalid collateral type");
        }

        if (
            selected == IUnityCoreLendingProtocol.CollateralType.USDT &&
            proxyContract.getUserCollateralInfo(msg.sender).usdtBalance <
            min_usdt_deposit
        ) {
            revert("Insufficient USDT balance");
        }

        if (
            selected == IUnityCoreLendingProtocol.CollateralType.USDC &&
            proxyContract.getUserCollateralInfo(msg.sender).usdcBalance <
            min_usdc_deposit
        ) {
            revert("Insufficient USDC balance");
        }

        if (
            selected == IUnityCoreLendingProtocol.CollateralType.CORE &&
            proxyContract.getUserCollateralInfo(msg.sender).coreBalance <
            proxyContract.getMinCoreDeposit()
        ) {
            revert("Insufficient CORE balance");
        }

        // Update the user's selected collateral and activate the collateral in the proxy contract
        IUnityCoreLendingProtocol.UserBalance memory userBalance = proxyContract
            .getUserBalance(msg.sender);
        userBalance.selectedCollateral = selected;
        userBalance.isCollateralActive = true;
        proxyContract.setUserBalance(msg.sender, userBalance);

        // emit CollateralActivated(msg.sender, collateralTypeToString(selected));
    }

    function deactivateCollateral() external {
        require(
            unityCoreLendingProtocolProxy
                .getUserBalance(msg.sender)
                .isCollateralActive,
            "Collateral is not active"
        );

        IUnityCoreLendingProtocol.UserBalance
            memory userBalance = unityCoreLendingProtocolProxy.getUserBalance(
                msg.sender
            );
        IUnityCoreLendingProtocol.CollateralType selectedCollateral = userBalance
                .selectedCollateral;
        require(
            selectedCollateral != IUnityCoreLendingProtocol.CollateralType.None,
            "No collateral selected"
        );
        require(
            userBalance.coreborrowBalance == 0 &&
                userBalance.usdtborrowBalance == 0 &&
                userBalance.usdcborrowBalance == 0,
            "Cannot deactivate collateral with active loans"
        );
        // Check if there are any outstanding borrowings for the selected collateral
        uint256 borrowedAmount = 0;
        if (
            selectedCollateral == IUnityCoreLendingProtocol.CollateralType.CORE
        ) {
            borrowedAmount = userBalance.coreborrowBalance;
        } else if (
            selectedCollateral == IUnityCoreLendingProtocol.CollateralType.USDT
        ) {
            borrowedAmount = userBalance.usdtborrowBalance;
        } else if (
            selectedCollateral == IUnityCoreLendingProtocol.CollateralType.USDC
        ) {
            borrowedAmount = userBalance.usdcborrowBalance;
        }

        require(
            borrowedAmount == 0,
            "Cannot deactivate collateral with outstanding borrowings"
        );

        // Perform any additional checks specific to the selected collateral (e.g., minimum balance requirements)
        if (
            selectedCollateral == IUnityCoreLendingProtocol.CollateralType.CORE
        ) {
            require(
                unityCoreLendingProtocol
                    .userCollateralInfo(msg.sender)
                    .coreBalance >=
                    unityCoreLendingProtocol.getMinCoreDeposit(),
                "Insufficient CORE balance"
            );
        } else if (
            selectedCollateral == IUnityCoreLendingProtocol.CollateralType.USDT
        ) {
            require(
                unityCoreLendingProtocol
                    .userCollateralInfo(msg.sender)
                    .usdtBalance >=
                    unityCoreLendingProtocol.getMinUSDTDeposit(),
                "Insufficient USDT balance"
            );
        } else if (
            selectedCollateral == IUnityCoreLendingProtocol.CollateralType.USDC
        ) {
            require(
                unityCoreLendingProtocol
                    .userCollateralInfo(msg.sender)
                    .usdcBalance >=
                    unityCoreLendingProtocol.getMinUSDCDeposit(),
                "Insufficient USDC balance"
            );
        }

        unityCoreLendingProtocolProxy.setUserBalance(msg.sender, userBalance);

        emit CollateralDeactivated(
            msg.sender,
            unityCoreLendingProtocolProxy.collateralTypeToString(
                userBalance.selectedCollateral
            )
        );
    }

    function toUnityCollateralType(
        IUnityCoreLendingProtocol.CollateralType collateralType
    ) internal pure returns (UnityCoreLendingProtocol.CollateralType) {
        if (collateralType == IUnityCoreLendingProtocol.CollateralType.USDT) {
            return UnityCoreLendingProtocol.CollateralType.USDT;
        } else if (
            collateralType == IUnityCoreLendingProtocol.CollateralType.USDC
        ) {
            return UnityCoreLendingProtocol.CollateralType.USDC;
        } else if (
            collateralType == IUnityCoreLendingProtocol.CollateralType.CORE
        ) {
            return UnityCoreLendingProtocol.CollateralType.CORE;
        } else {
            revert("Invalid collateral type");
        }
    }

    function calculateLTVRatioAndUpdate(address user) external {
        // Accessing UserBalance and UserCollateralInfo from UnityCoreLendingProtocol contract
        IUnityCoreLendingProtocol.UserBalance
            memory userBalance = unityCoreLendingProtocol.userBalances(user);
        IUnityCoreLendingProtocol.UserCollateralInfo
            memory userCollateralInfo = unityCoreLendingProtocol
                .userCollateralInfo(user);

        // Use the data in userBalance and userCollateralInfo to calculate LTV ratio and update accordingly

        // Example: Calculate LTV ratio
        uint256 ltvRatio = (userBalance.coreborrowBalance +
            userBalance.usdtborrowBalance +
            userBalance.usdcborrowBalance) /
            (userCollateralInfo.coreBalance +
                userCollateralInfo.usdtBalance +
                userCollateralInfo.usdcBalance);

        // Update user data based on LTV ratio, collateral values, etc.
        // ...

        // Set the updated UserBalance and UserCollateralInfo data back in the UnityCoreLendingProtocol contract
        unityCoreLendingProtocol.setUserBalance(user, userBalance);
        unityCoreLendingProtocol.setUserCollateralInfo(
            user,
            userCollateralInfo
        );
    }

    function setUnityCoreLendingProtocol(
        address _unityCoreLendingProtocolAddress
    ) external {
        unityCoreLendingProtocol = IUnityCoreLendingProtocol(
            _unityCoreLendingProtocolAddress
        );
        unityCoreLendingProtocolProxy = UnityCoreLendingProtocolProxy(
            _unityCoreLendingProtocolAddress
        );
    }
}
