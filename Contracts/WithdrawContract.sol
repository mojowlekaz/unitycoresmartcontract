pragma solidity ^0.8.0;
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./UnityCoreLendingProtocol.sol";

// WithdrawContract.sol

contract WithdrawContract {
    UnityCoreLendingProtocol public mainContract;
    address public usdtTokenAddress; // Address of the USDT token contract
    IERC20 public usdtToken;
    IERC20 public usdcToken;
    uint256 public rewardRate;
    LendingPoolToken public immutable lendingToken;
    address public owner;
    IERC20 public ucoreToken;

    modifier onlyOwner() {
        require(msg.sender == owner, "You are not the owner");
        _;
    }

    constructor(
        address payable mainContractAddress,
        address _ucoreaddress,
        address _lendingToken,
        address _usdtTokenAddress,
        address _usdcTokenAddress
    ) {
        mainContract = UnityCoreLendingProtocol(mainContractAddress);
        usdtTokenAddress = _usdtTokenAddress;
        usdtToken = IERC20(_usdtTokenAddress);
        usdcToken = IERC20(_usdcTokenAddress);
        lendingToken = LendingPoolToken(_lendingToken);
        owner = msg.sender;
        ucoreToken = IERC20(_ucoreaddress);
    }

    event Deposited(address indexed user, uint256 indexed amount);
    event USDTDebtRepaid(address indexed user, uint256 indexed amount);
    event USDCDebtRepaid(address indexed user, uint256 indexed amount);
    event COREWithdrawn(address indexed user, uint256 indexed amount);
    event USDTWithdrawn(address indexed user, uint256 indexed amount);
    event USDCWithdrawn(address indexed user, uint256 indexed amount);
    event COREDebtRepaid(address indexed user, uint256 indexed amount);
    event Withdrewdeposit(address indexed user, uint256 indexed amount);
    event WithdrewUSDT(address indexed user, uint256 indexed amount);
    event WithdrewUSDC(address indexed user, uint256 indexed amount);
    event CorerewardCLiamed(address indexed user, uint256 indexed amount);
    event UsdtrewardCLiamed(address indexed user, uint256 indexed amount);
    event UsdcrewardCLiamed(address indexed user, uint256 indexed amount);
    event Received(address indexed sender, uint256 amount);
    event CollateralDeactivated(address indexed user, string collateralType);

    function withdrawCORE(uint256 amount) external payable {
        address user = msg.sender;
        UnityCoreLendingProtocol.UserCollateralInfo
            memory userCollateralInfo = mainContract.getUserCollateralInfo(
                user
            );

        // Check if user has the minimum required amount of CORE
        uint256 minCoredeposit = mainContract.getMinCoreDeposit();
        if (userCollateralInfo.coreBalance < minCoredeposit) {
            revert("Insufficient CORE balance");
        }

        // Check if the amount to withdraw exceeds the available balance
        if (amount > userCollateralInfo.coreBalance) {
            revert("Exceeded amount in the balance");
        }

        // Check if the contract has enough ETH balance for the withdrawal
        uint256 contractETHBalance = address(mainContract).balance;
        if (contractETHBalance < amount) {
            revert("Contract has insufficient ETH balance");
        }

        // Access the userBalances mapping through the main contract instance
        UnityCoreLendingProtocol.UserBalance memory userBalance = mainContract
            .getUserBalance(user);

        if (userBalance.COREdepositFrozen == true) {
            revert("You already used this asset as your collateral");
        }

        if (userBalance.coreborrowBalance > 0) {
            revert("Please repay your debt before withdrawing");
        }

        // Check if the user's deposit is frozen (liquidated)
        if (userBalance.isDepositFrozen) {
            // Calculate the fee amount (4.5% of the core balance)
            uint256 feeAmount = (userCollateralInfo.coreBalance * 45) / 1000;

            // Calculate the remaining balance after deducting the fee
            uint256 remainingBalance = userCollateralInfo.coreBalance -
                feeAmount;

            // Set the balance to zero
            userCollateralInfo.coreBalance = 0;

            // Transfer the remaining balance to the user's address
            (bool success, ) = payable(user).call{value: remainingBalance}("");
            if (!success) {
                revert("Transfer failed");
            }
            userBalance.COREdepositFrozen == false;
            // Emit an event or perform necessary actions
            emit COREWithdrawn(user, remainingBalance);

            // Exit the function after the withdrawal is completed
            return;
        }

        // Transfer ETH to the user
        (bool success, ) = payable(user).call{value: amount}("");
        if (!success) {
            revert("Transfer failed");
        }
        userCollateralInfo.isBorrower = false;
        mainContract.updateUserCOREBalance(
            user,
            userCollateralInfo.coreBalance - amount
        );
        // lendingToken.burn(user, amount);

        // Emit an event or perform other actions
        emit COREWithdrawn(user, amount);
    }

    function withdrawUSDT(uint256 amount) external payable {
        address user = msg.sender;
        UnityCoreLendingProtocol.UserCollateralInfo
            memory userCollateralInfo = mainContract.getUserCollateralInfo(
                user
            );

        // Check if user has the minimum required amount of USDT
        uint256 min_usdt_deposit = mainContract.getMinUSDTDeposit();
        if (userCollateralInfo.usdtBalance < min_usdt_deposit) {
            revert("Insufficient USDT balance");
        }

        // Check if the amount to withdraw exceeds the available balance
        if (amount > userCollateralInfo.usdtBalance) {
            revert("Exceeded amount in the balance");
        }

        // Check if the contract has enough USDT balance for the withdrawal
        uint256 contractUSDTBalance = usdtToken.balanceOf(
            address(mainContract)
        );
        if (contractUSDTBalance < amount) {
            revert("Contract has insufficient USDT balance");
        }

        // Access the userBalances mapping through the main contract instance
        UnityCoreLendingProtocol.UserBalance memory userBalance = mainContract
            .getUserBalance(user);

        if (userBalance.USDTdepositFrozen == true) {
            revert("You already used this asset as your collateral");
        }

        if (userBalance.usdtborrowBalance > 0) {
            revert("Please repay your debt before withdrawing");
        }

        // Check if the user's deposit is frozen (liquidated)
        if (userBalance.isDepositFrozen) {
            // Calculate the fee amount (4.5% of the core balance)
            uint256 feeAmount = (userCollateralInfo.usdtBalance * (45)) /
                (1000);

            // Calculate the remaining balance after deducting the fee
            uint256 remainingBalance = userCollateralInfo.usdtBalance -
                (feeAmount);

            // Set the balance to zero
            userCollateralInfo.usdtBalance = 0;
            mainContract.updateUserUSDTBalance(user, 0);

            // Transfer the remaining balance to the user's address
            (bool success, ) = payable(user).call{value: remainingBalance}("");
            if (!success) {
                revert("Transfer failed");
            }

            userBalance.USDTdepositFrozen == false;

            // Emit an event or perform necessary actions
            emit USDTWithdrawn(user, remainingBalance);
            // lendingToken.burn(user, remainingBalance);
            return;
        }
        // Transfer USDT tokens to the user
        require(usdtToken.transfer(user, amount), "USDT transfer failed");
        mainContract.updateUserUSDTBalance(
            user,
            userCollateralInfo.usdtBalance - amount
        );
        userCollateralInfo.isBorrower = false;
        // Emit an event or perform other actions
        emit USDTWithdrawn(user, amount);
        // lendingToken.burn(user, amount);
    }

    function withdrawUSDC(uint256 amount) external payable {
        address user = msg.sender;
        UnityCoreLendingProtocol.UserCollateralInfo
            memory userCollateralInfo = mainContract.getUserCollateralInfo(
                user
            );

        // Check if user has the minimum required amount of USDC
        uint256 min_usdt_deposit = mainContract.getMinUSDCDeposit();
        if (userCollateralInfo.usdcBalance < min_usdt_deposit) {
            revert("Insufficient USDC balance");
        }

        // Check if the amount to withdraw exceeds the available balance
        if (amount > userCollateralInfo.usdcBalance) {
            revert("Exceeded amount in the balance");
        }

        // Check if the contract has enough USDC balance for the withdrawal
        uint256 contractUSDCBalance = usdcToken.balanceOf(
            address(mainContract)
        );
        if (contractUSDCBalance < amount) {
            revert("Contract has insufficient USDC balance");
        }

        // Access the userBalances mapping through the main contract instance
        UnityCoreLendingProtocol.UserBalance memory userBalance = mainContract
            .getUserBalance(user);

        if (userBalance.USDCdepositFrozen == true) {
            revert("You already used this asset as your collateral");
        }

        if (userBalance.usdcborrowBalance > 0) {
            revert("Please repay your debt before withdrawing");
        }

        // Check if the user's deposit is frozen (liquidated)
        if (userBalance.isDepositFrozen) {
            // Calculate the fee amount (4.5% of the core balance)
            uint256 feeAmount = (userCollateralInfo.usdcBalance * (45)) /
                (1000);

            // Calculate the remaining balance after deducting the fee
            uint256 remainingBalance = userCollateralInfo.usdcBalance -
                (feeAmount);

            // Set the balance to zero
            userCollateralInfo.usdcBalance = 0;

            // Transfer the remaining balance to the user's address
            (bool success, ) = payable(user).call{value: remainingBalance}("");
            if (!success) {
                revert("Transfer failed");
            }

            userBalance.USDCdepositFrozen == false;
            emit USDCWithdrawn(user, remainingBalance);

            // Exit the function after the withdrawal is completed
            return;
        }

        // Transfer USDC tokens to the user
        require(usdcToken.transfer(user, amount), "USDC transfer failed");
        mainContract.updateUserUSDCBalance(
            user,
            userCollateralInfo.usdcBalance - amount
        );
        userCollateralInfo.isBorrower = false;
        emit USDCWithdrawn(user, amount);
        //    lendingToken.burn(user, amount * 10);
    }

    function calculateRewardBasedOnCORE() public view returns (uint256) {
        address user = msg.sender;
        // UnityCoreLendingProtocol.UserBalance memory userBalance = mainContract.getUserBalance(user);
        UnityCoreLendingProtocol.UserCollateralInfo
            memory userCollateralInfo = mainContract.getUserCollateralInfo(
                user
            );

        uint256 SecondStaked = block.timestamp -
            userCollateralInfo.depositFromTSofCORE;
        // Access the balance field from the UserBalance struct
        uint256 userBalanceAmount = userCollateralInfo.coreBalance;

        // Calculate the reward based on the user's balance and seconds staked
        uint256 rewardclaulation = (userBalanceAmount *
            SecondStaked *
            rewardRate) / 3.154e7;
        uint256 reward = (rewardclaulation / 1e18);
        return reward;
    }

    function calculateRewardBasedOnUSDT() public view returns (uint256) {
        address user = msg.sender;
        // UnityCoreLendingProtocol.UserBalance memory userBalance = mainContract.getUserBalance(user);
        UnityCoreLendingProtocol.UserCollateralInfo
            memory userCollateralInfo = mainContract.getUserCollateralInfo(
                user
            );

        uint256 SecondStaked = block.timestamp -
            userCollateralInfo.depositFromTSofUSDT;
        // Access the balance field from the UserBalance struct
        uint256 userBalanceAmount = userCollateralInfo.usdtBalance;

        // Calculate the reward based on the user's balance and seconds staked
        uint256 rewardclaulation = (userBalanceAmount *
            SecondStaked *
            rewardRate) / 3.154e7;
        uint256 reward = (rewardclaulation / 1e6);
        return reward;
    }

    function calculateRewardBasedOnUSDC() public view returns (uint256) {
        address user = msg.sender;
        // UnityCoreLendingProtocol.UserBalance memory userBalance = mainContract.getUserBalance(user);
        UnityCoreLendingProtocol.UserCollateralInfo
            memory userCollateralInfo = mainContract.getUserCollateralInfo(
                user
            );

        uint256 SecondStaked = block.timestamp -
            userCollateralInfo.depositFromTSofUSDC;
        // Access the balance field from the UserBalance struct
        uint256 userBalanceAmount = userCollateralInfo.usdcBalance;

        // Calculate the reward based on the user's balance and seconds staked
        uint256 rewardclaulation = (userBalanceAmount *
            SecondStaked *
            rewardRate) / 3.154e7;
        uint256 reward = (rewardclaulation / 1e6);
        return reward;
    }

    function claimCoreReward() external payable {
        UnityCoreLendingProtocol.UserBalance memory userBalance = mainContract
            .getUserBalance(msg.sender);
        uint256 coreReward = calculateRewardBasedOnCORE();
        require(coreReward > 0, "No rewards to claim");
        require(
            !mainContract.getUserBalance(msg.sender).userHasClaimedRewards,
            "Rewards already claimed"
        );
        require(
            mainContract.getUserCollateralInfo(msg.sender).coreBalance > 0,
            "No CORE deposit found"
        );

        if (userBalance.coreborrowBalance > 0) {
            revert("Please repay your debt before claiming");
        }

        // Update the reward balance in the main contract
        mainContract
            .getUserBalance(msg.sender)
            .rewardBalancesCORE += coreReward;

        // Transfer the reward tokens to the user
        require(
            ucoreToken.transfer(msg.sender, coreReward),
            "Reward transfer failed"
        );

        // Mark that the user has claimed rewards
        mainContract.getUserBalance(msg.sender).userHasClaimedRewards = true;

        // emit CoreRewardClaimed(msg.sender, coreReward);
    }

    function claimUSDTReward() external payable {
        UnityCoreLendingProtocol.UserBalance memory userBalance = mainContract
            .getUserBalance(msg.sender);
        uint256 usdtReward = calculateRewardBasedOnUSDT();
        require(usdtReward > 0, "No rewards to claim");
        require(
            !mainContract.getUserBalance(msg.sender).userHasClaimedRewards,
            "Rewards already claimed"
        );
        require(
            mainContract.getUserCollateralInfo(msg.sender).usdtBalance > 0,
            "No USDT deposit found"
        );

        if (userBalance.usdtborrowBalance > 0) {
            revert("Please repay your debt before claiming");
        }

        // Update the reward balance in the main contract
        mainContract
            .getUserBalance(msg.sender)
            .rewardBalancesUSDT += usdtReward;

        // Transfer the reward tokens to the user
        require(
            ucoreToken.transfer(msg.sender, usdtReward),
            "Reward transfer failed"
        );

        // Mark that the user has claimed rewards
        mainContract.getUserBalance(msg.sender).userHasClaimedRewards = true;

        // emit USDTRewardClaimed(msg.sender, usdtReward);
    }

    function claimUSDCReward() external payable {
        UnityCoreLendingProtocol.UserBalance memory userBalance = mainContract
            .getUserBalance(msg.sender);
        uint256 usdcReward = calculateRewardBasedOnUSDC();
        require(usdcReward > 0, "No rewards to claim");
        require(
            !mainContract.getUserBalance(msg.sender).userHasClaimedRewards,
            "Rewards already claimed"
        );
        require(
            mainContract.getUserCollateralInfo(msg.sender).usdcBalance > 0,
            "No USDC deposit found"
        );
        if (userBalance.usdcborrowBalance > 0) {
            revert("Please repay your debt before claiming");
        }

        // Update the reward balance in the main contract
        mainContract
            .getUserBalance(msg.sender)
            .rewardBalancesUSDC += usdcReward;

        // Transfer the reward tokens to the user
        require(
            ucoreToken.transfer(msg.sender, usdcReward),
            "Reward transfer failed"
        );

        // Mark that the user has claimed rewards
        mainContract.getUserBalance(msg.sender).userHasClaimedRewards = true;

        // emit USDCRewardClaimed(msg.sender, usdcReward);
    }

    function setRewardRate(uint256 _rewardRate) external onlyOwner {
        rewardRate = _rewardRate;
    }

    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) external onlyOwner {
        require(
            amount <= address(this).balance,
            "Insufficient contract balance"
        );
    }

    function RepayCOREDebt(uint256 amount) external payable {
        address user = msg.sender;
        UnityCoreLendingProtocol.UserCollateralInfo
            memory userCollateralInfo = mainContract.getUserCollateralInfo(
                user
            );
        UnityCoreLendingProtocol.UserBalance memory userBalance = mainContract
            .getUserBalance(user);
        require(userCollateralInfo.coreBalance > 0, "You have no deposit");
        require(userBalance.coreborrowBalance > 0, "You have no borrows");
        require(
            amount <= userBalance.coreborrowBalance,
            "You can not repay more than your borrow"
        );

        // Transfer ETH from the user to the contract to repay the debt
        require(msg.value >= amount, "Insufficient ETH sent");

        // Update the user's borrow balance
        mainContract.updateUserCOREBorrowBalance(
            user,
            userBalance.coreborrowBalance - amount
        );
        userBalance.COREdepositFrozen = false;
        userCollateralInfo.isBorrower = false;
        emit COREDebtRepaid(msg.sender, amount);
    }

    function RepayUSDTDebt(uint256 amount) external payable {
        address user = msg.sender;
        UnityCoreLendingProtocol.UserCollateralInfo
            memory userCollateralInfo = mainContract.getUserCollateralInfo(
                user
            );
        UnityCoreLendingProtocol.UserBalance memory userBalance = mainContract
            .getUserBalance(user);
        require(userCollateralInfo.usdtBalance > 0, "You have no deposit");
        require(userBalance.usdtborrowBalance > 0, "You have no borrows");
        require(
            amount <= userBalance.usdtborrowBalance,
            "You can not repay more than your borrow"
        );

        bool transferSuccess = usdtToken.transferFrom(
            msg.sender,
            address(this),
            amount
        );
        if (!transferSuccess) {
            revert("USDT transfer failed");
        }

        // Update the user's borrow balance
        // userBalance.usdtborrowBalance -= amount;
        mainContract.updateUserUSDTBorrowBalance(
            user,
            userBalance.usdtborrowBalance - amount
        );
        userBalance.USDTdepositFrozen = false;
        userCollateralInfo.isBorrower = false;
        emit USDTDebtRepaid(msg.sender, amount);
    }

    function RepayUSDCDebt(uint256 amount) external payable {
        address user = msg.sender;
        UnityCoreLendingProtocol.UserCollateralInfo
            memory userCollateralInfo = mainContract.getUserCollateralInfo(
                user
            );
        UnityCoreLendingProtocol.UserBalance memory userBalance = mainContract
            .getUserBalance(user);
        require(userCollateralInfo.usdcBalance > 0, "You have no deposit");
        require(userBalance.usdcborrowBalance > 0, "You have no borrows");
        require(
            amount <= userBalance.usdcborrowBalance,
            "You can not repay more than your borrow"
        );

        require(
            usdcToken.transferFrom(user, address(this), amount),
            "USDC transfer failed"
        );

        // Update the user's borrow balance
        mainContract.updateUserUSDCBorrowBalance(
            user,
            userBalance.usdcborrowBalance - amount
        );
        userBalance.USDCdepositFrozen = false;
        userCollateralInfo.isBorrower = false;
        emit USDCDebtRepaid(msg.sender, amount);
    }
}
