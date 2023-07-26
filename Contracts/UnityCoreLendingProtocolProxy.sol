// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

// Import the correct interface
import "./IUnityCoreLendingProtocol.sol";

contract UnityCoreLendingProtocolProxy {
    IUnityCoreLendingProtocol public lendingProtocolContract;
    mapping(address => IUnityCoreLendingProtocol.UserBalance)
        private userBalances;
    address public owner;

    constructor(address _lendingProtocolContract) {
        lendingProtocolContract = IUnityCoreLendingProtocol(
            _lendingProtocolContract
        );
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }

    // Function to set the user balance
    function setUserBalance(
        address user,
        IUnityCoreLendingProtocol.UserBalance memory userBalance
    ) external {
        userBalances[user] = userBalance;
    }

    // Getter function for userBalances
    function getUserBalance(
        address user
    ) external view returns (IUnityCoreLendingProtocol.UserBalance memory) {
        return userBalances[user];
    }

    // Getter function for userCollateralInfo
    function getUserCollateralInfo(
        address user
    )
        external
        view
        returns (IUnityCoreLendingProtocol.UserCollateralInfo memory)
    {
        return lendingProtocolContract.userCollateralInfo(user);
    }

    function getMinUSDTDeposit() external view returns (uint256) {
        return lendingProtocolContract.getMinUSDTDeposit();
    }

    function getMinUSDCDeposit() external view returns (uint256) {
        return lendingProtocolContract.getMinUSDCDeposit();
    }

    function getMinCoreDeposit() external view returns (uint256) {
        return lendingProtocolContract.getMinCoreDeposit();
    }

    function getDepositors() external view returns (address[] memory) {
        return lendingProtocolContract.getDepositors();
    }

    function updateLendingProtocolContract(
        address newContractAddress
    ) external onlyOwner {
        lendingProtocolContract = IUnityCoreLendingProtocol(newContractAddress);
    }

    function calculateCollateralValue() public view returns (uint256) {
        uint256 collateralValue;
        uint256 usdtPrice;
        uint256 corePrice;
        uint256 usdcPrice;

        // Fetch the prices from the oracle
        (usdtPrice, corePrice, usdcPrice) = lendingProtocolContract.getPrices();

        if (
            userBalances[msg.sender].selectedCollateral ==
            IUnityCoreLendingProtocol.CollateralType.USDT
        ) {
            uint256 usdtBalance = lendingProtocolContract
                .userCollateralInfo(msg.sender)
                .usdtBalance;
            collateralValue = (usdtBalance * usdtPrice) / 1e6; // Use the * operator for multiplication
        } else if (
            userBalances[msg.sender].selectedCollateral ==
            IUnityCoreLendingProtocol.CollateralType.CORE
        ) {
            uint256 coreBalance = lendingProtocolContract
                .userCollateralInfo(msg.sender)
                .coreBalance;
            collateralValue = (coreBalance * corePrice) / 1e18; // Use the * operator for multiplication
        } else if (
            userBalances[msg.sender].selectedCollateral ==
            IUnityCoreLendingProtocol.CollateralType.USDC
        ) {
            uint256 usdcBalance = lendingProtocolContract
                .userCollateralInfo(msg.sender)
                .usdcBalance;
            collateralValue = (usdcBalance * usdcPrice) / 1e6; // Use the * operator for multiplication
        } else {
            revert("Invalid collateral type");
        }

        return collateralValue;
    }

    function collateralTypeToString(
        IUnityCoreLendingProtocol.CollateralType collateralType
    ) external pure returns (string memory) {
        if (collateralType == IUnityCoreLendingProtocol.CollateralType.None) {
            return "None";
        } else if (
            collateralType == IUnityCoreLendingProtocol.CollateralType.CORE
        ) {
            return "CORE";
        } else if (
            collateralType == IUnityCoreLendingProtocol.CollateralType.USDT
        ) {
            return "USDT";
        } else if (
            collateralType == IUnityCoreLendingProtocol.CollateralType.USDC
        ) {
            return "USDC";
        } else {
            // Handle unknown collateral types here, if needed
            revert("Unknown collateral type");
        }
    }

    // ... (other functions and contract logic) ...
}
