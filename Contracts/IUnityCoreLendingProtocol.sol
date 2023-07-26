// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

interface IUnityCoreLendingProtocol {
    struct UserCollateralInfo {
        uint256 depositFromTSofCORE;
        uint256 depositFromTSofUSDT;
        uint256 depositFromTSofUSDC;
        uint256 coreBalance;
        uint256 usdtBalance;
        uint256 usdcBalance;
        bool userHasClaimedRewards;
        // Add other collateral-related fields as needed
    }

    enum CollateralType {
        None,
        CORE,
        USDT,
        USDC
    }

    struct UserBalance {
        uint256 coreborrowBalance;
        uint256 usdtborrowBalance;
        uint256 usdcborrowBalance;
        bool isDepositFrozen;
        bool COREdepositFrozen;
        bool USDTdepositFrozen;
        bool USDCdepositFrozen;
        bool userHasClaimedRewards;
        uint256 rewardBalancesCORE;
        uint256 rewardBalancesUSDT;
        uint256 rewardBalancesUSDC;
        CollateralType selectedCollateral;
        bool isCollateralActive;
    }

    function userBalances(
        address user
    ) external view returns (UserBalance memory);

    function userCollateralInfo(
        address user
    ) external view returns (UserCollateralInfo memory);

    function getMinUSDTDeposit() external view returns (uint256);

    function getMinUSDCDeposit() external view returns (uint256);

    function getReward() external view returns (uint256);

    function getMinCoreDeposit() external view returns (uint256);

    function getDepositors() external view returns (address[] memory);

    function getPrices()
        external
        view
        returns (uint256 usdtPrice, uint256 corePrice, uint256 usdcPrice);

    function getUserBalance(
        address user
    ) external view returns (UserBalance memory);

    function setUserBalance(
        address user,
        IUnityCoreLendingProtocol.UserBalance calldata userBalance
    ) external;

    function collateralTypeToString(
        CollateralType collateralType
    ) external pure returns (string memory);

    function setUserCollateralInfo(
        address user,
        UserCollateralInfo memory collateralInfo
    ) external;

    function getUserCollateralInfo(
        address user
    ) external view returns (UserCollateralInfo memory);

    function setActivateCollateralAddress(
        address _activateCollateralAddress
    ) external;

    function calculateClaimableUCORE(
        address user
    ) external view returns (uint256);
    // Add other functions and events as needed
}
