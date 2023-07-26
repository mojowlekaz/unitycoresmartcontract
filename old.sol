// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./PriceContract.sol";

contract LendingPoolToken is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function mint(address account, uint256 amount) external {
        _mint(account, amount);
    }

    function burn(address account, uint256 amount) external {
        _burn(account, amount);
    }
}

contract UnityCoreLendingProtocol is ReentrancyGuard {
    constructor(
        address _lendingToken,
        address _usdtAddress,
        address _usdcAddress,
        address _priceContractaddress,
        address _ucoreaddress
    ) {
        usdtToken = IERC20(_usdtAddress);
        usdcToken = IERC20(_usdcAddress);
        ucoreToken = IERC20(_ucoreaddress);
        lendingToken = LendingPoolToken(_lendingToken);
        priceContract = PriceContract(_priceContractaddress);
        owner = msg.sender;
    }

    error InsufficientEthers();
    error InsufficientIceToken();
    error InsufficientAmount();

    struct UserBalance {

        //Borrow Blance
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

mapping(address => UserCollateralInfo) userCollateralInfo;

    enum CollateralType {
        None,
        CORE,
        USDT,
        USDC
    }

    IERC20 public usdtToken;
    IERC20 public usdcToken;
    IERC20 public ucoreToken;
    uint256 public min_usdt_deposit = 1000000;
    uint256 public min_usdc_deposit = 1000000;
    uint256 public minCoredeposit = 1000000;
    address[] public depositors;
    address[] public borrowers;
    using SafeMath for uint256;
    uint256 public TotalCoreDeposited;
    uint256 public TotalUSDTdeposited;
    uint256 public TotalUSDCdeposited;
    //Borrow
    uint256 public TotalCoreBorrowed;
    uint256 public TotalUSDTBorrowed;
    uint256 public TotalUSDCBorrowed;
    mapping(address => UserBalance) public userBalances;
    mapping(address => uint256) public depositFromTs;
    mapping(address => bool) isBorrower;
    LendingPoolToken public immutable lendingToken;
    PriceContract public immutable priceContract;
    uint256 public usdtPrice = 1000000;
    uint256 public usdcPrice = 1000000;
    uint256 public core_price = 2e18;
    uint256 public liquidationThreshold = 8750; // Liquidation threshold as a basis points
    address public owner;
    uint256 borrowingLimitPercentage = 80;
    uint256 public rewardRate; // Reward rate in percentage (e.g., 1000 for 10%)

    event Deposited(address indexed user, uint256 indexed amount);
    event CoreWithdrawn(address indexed user, uint256 indexed amount);
    event USDTWithdrawn(address indexed user, uint256 indexed amount);
    event USDCWithdrawn(address indexed user, uint256 indexed amount);
    event usdtDeposited(address indexed user, uint256 indexed amount);
    event USDTBorrowed(address indexed user, uint256 indexed amount);
    event USDCBorrowed(address indexed user, uint256 indexed amount);
    event coreBorrowed(address indexed user, uint256 indexed amount);
    event usdcDeposited(address indexed user, uint256 indexed amount);
    event CollateralActivated(address indexed user, string indexed collateral);
    event Withdrewdeposit(address indexed user, uint256 indexed amount);
    event WithdrewUSDT(address indexed user, uint256 indexed amount);
    event WithdrewUSDC(address indexed user, uint256 indexed amount);
    event CorerewardCLiamed(address indexed user, uint256 indexed amount);
    event UsdtrewardCLiamed(address indexed user, uint256 indexed amount);
    event UsdcrewardCLiamed(address indexed user, uint256 indexed amount);
    event Received(address indexed sender, uint256 amount);
    event CollateralDeactivated(address indexed user, string collateralType);

    modifier onlyOwner() {
        require(msg.sender == owner, "You are not the owner");
        _;
    }

    function ChangeCorePrice(uint256 _newprice) public onlyOwner {
        core_price = _newprice;
    }

    function ChangeUSDTPrice(uint256 _newprice) public onlyOwner {
        usdtPrice = _newprice;
    }

    function depositCore() external payable nonReentrant {
        if (msg.value < minCoredeposit) {
            revert InsufficientEthers();
        }
        if (userBalances[msg.sender].COREdepositFrozen == true) {
            revert(
                "you need to withdraw before adding more to your collateral"
            );
            TotalCoreDeposited += msg.value;
            userCollateralInfo[msg.sender].coreBalance += msg.value;
            if (lendingToken.balanceOf(msg.sender) > 0) {
                lendingToken.mint(msg.sender, 0);
            } else {
                lendingToken.mint(msg.sender, msg.value.mul(10));
            }
            userCollateralInfo[msg.sender].depositFromTSofCORE = block.timestamp;
            for (uint256 i = 0; i < depositors.length; i++) {
                if (depositors[i] != msg.sender) {
                    depositors.push(payable(msg.sender));
                }
            }

            emit Deposited(msg.sender, msg.value);
        }
    }

    function depositUSDC(uint256 amount) external payable nonReentrant {
        bool approvalSuccess = usdcToken.approve(address(this), amount);
        if (!approvalSuccess) {
            revert("Approval failed");
        }

        bool transferSuccess = usdcToken.transferFrom(
            msg.sender,
            address(this),
            amount
        );
        if (!transferSuccess) {
            revert("USDC transfer failed");
        }

        if (amount < min_usdc_deposit) {
            revert("Minimum USDC deposit is 1");
        }

        TotalUSDCdeposited += amount;
        userCollateralInfo[msg.sender].usdcBalance += amount;

        if (lendingToken.balanceOf(msg.sender) > 0) {
            lendingToken.mint(msg.sender, 0);
        } else {
            lendingToken.mint(msg.sender, amount.mul(10));
        }

        userCollateralInfo[msg.sender].depositFromTSofUSDC = block.timestamp;

        if (userBalances[msg.sender].USDCdepositFrozen == true) {
            revert(
                "you need to withdraw before adding more to your collateral"
            );

            // Check if msg.sender is already in the depositors array
            bool alreadyInArray = false;
            for (uint256 i = 0; i < depositors.length; i++) {
                if (depositors[i] == msg.sender) {
                    alreadyInArray = true;
                    break;
                }
            }

            // If msg.sender is not in the depositors array, push it
            if (!alreadyInArray) {
                depositors.push(payable(msg.sender));
            }

            emit usdcDeposited(msg.sender, amount);
        }
    }

    function depositUSDT(uint256 amount) external payable nonReentrant {
        bool approvalSuccess = usdtToken.approve(address(this), amount);
        if (!approvalSuccess) {
            revert("Approval failed");
        }

        bool transferSuccess = usdtToken.transferFrom(
            msg.sender,
            address(this),
            amount
        );
        if (!transferSuccess) {
            revert("USDT transfer failed");
        }

        if (amount < min_usdt_deposit) {
            revert("Minimum USDT deposit is 1");
        }
        if (userBalances[msg.sender].USDTdepositFrozen == true) {
            revert(
                "you need to withdraw before adding more to your collateral"
            );
        }

        TotalUSDTdeposited += amount;
        userCollateralInfo[msg.sender].usdtBalance += amount;

        if (lendingToken.balanceOf(msg.sender) > 0) {
            lendingToken.mint(msg.sender, 0);
        } else {
            lendingToken.mint(msg.sender, amount.mul(10));
        }

        userCollateralInfo[msg.sender].depositFromTSofUSDT = block.timestamp;

        // Check if msg.sender is already in the depositors array
        bool alreadyInArray = false;
        for (uint256 i = 0; i < depositors.length; i++) {
            if (depositors[i] == msg.sender) {
                alreadyInArray = true;
                break;
            }
        }

        // If msg.sender is not in the depositors array, push it
        if (!alreadyInArray) {
            depositors.push(payable(msg.sender));
        }

        emit usdtDeposited(msg.sender, amount);
    }

    // Function to activate collateral
    function activateCollateral(uint8 collateral) external {
        CollateralType selected = CollateralType(collateral);

        if (selected == CollateralType.None) {
            revert("Invalid collateral type");
        }
        if (
            selected == CollateralType.USDT &&
            userCollateralInfo[msg.sender].usdtBalance < min_usdt_deposit
        ) {
            revert("Insufficient USDT balance");
        }
        if (
            selected == CollateralType.USDC &&
            userCollateralInfo[msg.sender].usdcBalance < min_usdc_deposit
        ) {
            revert("Insufficient USDC balance");
        }
        if (
            selected == CollateralType.CORE &&
            userCollateralInfo[msg.sender].coreBalance < minCoredeposit
        ) {
            revert("Insufficient CORE balance");
        }

        userBalances[msg.sender].selectedCollateral = selected;
        userBalances[msg.sender].isCollateralActive = true; // Set the collateral as active

        emit CollateralActivated(msg.sender, collateralTypeToString(selected));
    }

    function deactivateCollateral() external {
        // Check if the user's collateral is active
        require(
            userBalances[msg.sender].isCollateralActive,
            "Collateral is not active"
        );

        CollateralType selectedCollateral = userBalances[msg.sender]
            .selectedCollateral;
        require(
            selectedCollateral != CollateralType.None,
            "No collateral selected"
        );
        require(
            userBalances[msg.sender].coreborrowBalance == 0 &&
                userBalances[msg.sender].usdtborrowBalance == 0 &&
                userBalances[msg.sender].usdcborrowBalance == 0,
            "Cannot deactivate collateral with active loans"
        );

        // Check if there are any outstanding borrowings for the selected collateral
        uint256 borrowedAmount = 0;
        if (selectedCollateral == CollateralType.CORE) {
            borrowedAmount = userBalances[msg.sender].coreborrowBalance;
        } else if (selectedCollateral == CollateralType.USDT) {
            borrowedAmount = userBalances[msg.sender].usdtborrowBalance;
        } else if (selectedCollateral == CollateralType.USDC) {
            borrowedAmount = userBalances[msg.sender].usdcborrowBalance;
        }

        require(
            borrowedAmount == 0,
            "Cannot deactivate collateral with outstanding borrowings"
        );

        // Perform any additional checks specific to the selected collateral (e.g., minimum balance requirements)
        if (selectedCollateral == CollateralType.CORE) {
            require(
                userCollateralInfo[msg.sender].coreBalance >= minCoredeposit,
                "Insufficient CORE balance"
            );
        } else if (selectedCollateral == CollateralType.USDT) {
            require(
                userCollateralInfo[msg.sender].usdtBalance >= min_usdt_deposit,
                "Insufficient USDT balance"
            );
        } else if (selectedCollateral == CollateralType.USDC) {
            require(
                userCollateralInfo[msg.sender].usdcBalance >= min_usdc_deposit,
                "Insufficient USDC balance"
            );
        }

        userBalances[msg.sender].selectedCollateral = CollateralType.None;
        // Deactivate the collateral by setting the flag to false
        userBalances[msg.sender].isCollateralActive = false;

        emit CollateralDeactivated(
            msg.sender,
            collateralTypeToString(userBalances[msg.sender].selectedCollateral)
        );
    }

    function collateralTypeToString(
        CollateralType collateral
    ) internal pure returns (string memory) {
        if (collateral == CollateralType.None) {
            return "None";
        } else if (collateral == CollateralType.CORE) {
            return "CORE";
        } else if (collateral == CollateralType.USDT) {
            return "USDT";
        } else if (collateral == CollateralType.USDC) {
            return "USDC";
        }
        return "";
    }

    function getSelectedCollateral() public view returns (string memory) {
        return
            collateralTypeToString(userBalances[msg.sender].selectedCollateral);
    }

function calculatePrice(uint256 amount) internal view returns (uint256, uint256, uint256, uint256, uint256, uint256) {
    uint256 usdtBalancePriceOfUser = (userCollateralInfo[msg.sender].usdtBalance / 1e6) * usdtPrice;
    uint256 usdcBalancePriceOfUser = (userCollateralInfo[msg.sender].usdcBalance / 1e6) * usdcPrice;
    uint256 coreBalancePriceOfUser = (userCollateralInfo[msg.sender].coreBalance / 1e18) * core_price;
    uint256 priceOfCoreUserWantToBorrow = amount * (core_price / 1e18);
    uint256 priceOfUsdcUserWantToBorrow = amount * (usdcPrice / 1e6);
    uint256 priceOfUsdtUserWantToBorrow = amount * (usdtPrice / 1e6);

    return (
        usdtBalancePriceOfUser,
        priceOfUsdcUserWantToBorrow,
        priceOfUsdtUserWantToBorrow,
        coreBalancePriceOfUser,
        usdcBalancePriceOfUser,
        priceOfCoreUserWantToBorrow
    );
}


    function borrowCoreBasedOnCollateral(
        uint256 amount
    ) external payable nonReentrant {
        if (
            userBalances[msg.sender].selectedCollateral == CollateralType.None
        ) {
            revert("A collateral is needed");
        }
        if (
            keccak256(bytes(getSelectedCollateral())) ==
            keccak256(bytes("USDT"))
        ) {
            if (userCollateralInfo[msg.sender].usdtBalance < min_usdt_deposit) {
                revert("Insufficient USDT balance");
            }
            amount = msg.value;
            (
                uint256 usdtBalancePriceOfUser,
                uint256 priceOfusdcUserwantToBorrow,
                uint256 priceOfusdtUserwantToBorrow,
                uint256 coreBalancePriceOfUser,
                uint256 usdcBalancePriceOfUser,
                uint256 PriceOfCoreUserwantToBorrow
            ) = calculatePrice(amount);

            uint256 borrowingLimit = userCollateralInfo[msg.sender]
                .usdtBalance
                .mul(usdtPrice)
                .div(1e6)
                .mul(borrowingLimitPercentage)
                .div(100);

            uint256 coreBorrowBalance = userBalances[msg.sender]
                .coreborrowBalance
                .mul(core_price)
                .div(1e18);
            if (
                !(usdtBalancePriceOfUser >= PriceOfCoreUserwantToBorrow) ||
                !(coreBorrowBalance.add(amount.mul(core_price).div(1e18)) <=
                    usdtBalancePriceOfUser) ||
                !(coreBorrowBalance.add(amount.mul(core_price).div(1e18)) <
                    borrowingLimit)
            ) {
                revert("Invalid borrowing conditions");
            }
            //  uint256 amountToBorrow = amount.mul(80).div(100);
            require(
                address(this).balance > amount,
                "Not enough ETH in the contract"
            );
            (bool success, ) = payable(msg.sender).call{value: amount}("");
            if (!success) {
                revert("Transfer failed");
            }
            userBalances[msg.sender].coreborrowBalance += amount;
            TotalCoreBorrowed += amount;
            bool alreadyInArray = false;
            for (uint256 i = 0; i < borrowers.length; i++) {
                if (borrowers[i] == msg.sender) {
                    alreadyInArray = true;
                    break;
                }
            }

            // If msg.sender is not in the borrowers array, push it
            if (!alreadyInArray) {
                borrowers.push(payable(msg.sender));
            }
            isBorrower[msg.sender] = true;
            userBalances[msg.sender].COREdepositFrozen = true;
            emit coreBorrowed(msg.sender, amount);
        } else if (
            keccak256(bytes(getSelectedCollateral())) ==
            keccak256(bytes("USDC"))
        ) {
            if (userCollateralInfo[msg.sender].usdcBalance < min_usdc_deposit) {
                revert("Insufficient USDC balance");
            }

            (
                uint256 usdcBalancePriceOfUser,
                uint256 priceOfusdcUserwantToBorrow,
                uint256 priceOfusdtUserwantToBorrow,
                uint256 coreBalancePriceOfUser,
                uint256 usdtBalancePriceOfUser,
                uint256 PriceOfCoreUserwantToBorrow
            ) = calculatePrice(amount);

            uint256 USDCPrice = usdcPrice.div(1e6);
            uint256 Price = core_price.div(1e18);

            uint256 depositPrice = userCollateralInfo[msg.sender].usdcBalance.mul(
                USDCPrice
            );

            // uint256 borrowingLimit = depositPrice.mul(borrowingLimitPercentage).div(100);
            uint256 borrowingLimit = userCollateralInfo[msg.sender]
                .usdcBalance
                .mul(usdcPrice)
                .div(1e6)
                .mul(borrowingLimitPercentage)
                .div(100);

            // Calculate the borrowing price in USDC
            uint256 borrowPrice = amount.mul(Price);

            // Calculate the total borrowed amount in USDC
            // uint256 coreBorrowBalancePrice = userBalances[msg.sender].coreborrowBalance.mul(usdcPrice).div(1e6);
            uint256 coreBorrowBalancePrice = userBalances[msg.sender]
                .coreborrowBalance
                .mul(core_price)
                .div(1e18);

            // Check if the borrow conditions are met
            // Check if the borrowing conditions are met
            require(borrowPrice <= borrowingLimit, "Exceeded borrowing limit");
            require(
                coreBorrowBalancePrice.add(borrowPrice) < borrowingLimit,
                "you can not borrow more thsn the deposit limit"
            );
            require(
                coreBorrowBalancePrice.add(borrowPrice) <= depositPrice,
                "Deposit value is insufficient for borrowing"
            );
            require(
                depositPrice > borrowPrice,
                "Borrowed amount should be less than the core deposit value"
            );
            require(
                address(this).balance > amount,
                "Not enough ETH in the contract"
            );

            (bool success, ) = payable(msg.sender).call{value: amount}("");
            if (!success) {
                revert("Transfer failed");
            }
            userBalances[msg.sender].coreborrowBalance += amount;
            TotalCoreBorrowed += amount;

            // Check if msg.sender is already in the borrowers array
            bool alreadyInArray = false;
            for (uint256 i = 0; i < borrowers.length; i++) {
                if (borrowers[i] == msg.sender) {
                    alreadyInArray = true;
                    break;
                }
            }

            // If msg.sender is not in the borrowers array, push it
            if (!alreadyInArray) {
                borrowers.push(payable(msg.sender));
            }
            isBorrower[msg.sender] = true;
            userBalances[msg.sender].COREdepositFrozen = true;
            emit coreBorrowed(msg.sender, amount);
        } else if (
            keccak256(bytes(getSelectedCollateral())) ==
            keccak256(bytes("CORE"))
        ) {
            if (userCollateralInfo[msg.sender].coreBalance < minCoredeposit) {
                revert("Insufficient CORE balance");
            }

            uint256 depositPrice = userCollateralInfo[msg.sender]
                .coreBalance
                .mul(core_price)
                .div(1e18);
            uint256 borrowingLimit = depositPrice
                .mul(borrowingLimitPercentage)
                .div(100);
            uint256 borrowPrice = amount.mul(core_price).div(1e18);
            uint256 coreBorrowBalancePrice = userBalances[msg.sender]
                .coreborrowBalance
                .mul(core_price)
                .div(1e18);

            if (
                borrowPrice > borrowingLimit ||
                coreBorrowBalancePrice.add(borrowPrice) > depositPrice ||
                coreBorrowBalancePrice.add(borrowPrice) > borrowingLimit ||
                depositPrice <= borrowPrice
            ) {
                revert("invalid borrow");
            }
            uint256 amountToBorrow = amount.mul(80).div(100);
            require(
                address(this).balance > amount,
                "Not enough ETH in the contract"
            );
            (bool success, ) = payable(msg.sender).call{value: amount}("");
            if (!success) {
                revert("Transfer failed");
            }
            userBalances[msg.sender].coreborrowBalance += amount;
            // Check if msg.sender is already in the borrowers array
            bool alreadyInArray = false;
            for (uint256 i = 0; i < borrowers.length; i++) {
                if (borrowers[i] == msg.sender) {
                    alreadyInArray = true;
                    break;
                }

                // If msg.sender is not in the borrowers array, push it
                if (!alreadyInArray) {
                    borrowers.push(payable(msg.sender));
                }
                isBorrower[msg.sender] = true;
                userBalances[msg.sender].COREdepositFrozen = true;
                TotalCoreBorrowed += amount;
                emit coreBorrowed(msg.sender, amount);
            }
        }
    }

    //Borrow USDT
    function borrowUSDTbasedonCollateral(
        uint256 amount
    ) external payable nonReentrant {
        if (
            userBalances[msg.sender].selectedCollateral == CollateralType.None
        ) {
            revert("A collateral is needed");
        }
        if (
            keccak256(bytes(getSelectedCollateral())) ==
            keccak256(bytes("USDT"))
        ) {
            if (userCollateralInfo[msg.sender].usdtBalance < min_usdt_deposit) {
                revert("Insufficient USDT balance");
            }

            (
                uint256 usdtBalancePriceOfUser,
                uint256 priceOfusdcUserwantToBorrow,
                uint256 priceOfusdtUserwantToBorrow,
                uint256 coreBalancePriceOfUser,
                uint256 usdcBalancePriceOfUser,
                uint256 PriceOfCoreUserwantToBorrow
            ) = calculatePrice(amount);
            // Calculate the borrowing limit based on the deposit price
            // Calculate the borrowing limit based on the user's borrowed balance
            uint256 borrowingLimit = userCollateralInfo[msg.sender]
                .usdtBalance
                .mul(usdtPrice)
                .div(1e6)
                .mul(borrowingLimitPercentage)
                .div(100);
            // Calculate the borrowing amount in terms of price
            uint256 borrowingAmount = amount.mul(usdtPrice).div(1e6);

            // uint256 balanceofBorrowedUSDTindollar = userBalances[msg.sender].usdtborrowBalance.mul(usdtPrice.div(1e6));
            uint256 usdtBorrowBalance = userBalances[msg.sender]
                .usdtborrowBalance
                .mul(usdtPrice)
                .div(1e6);
            if (
                !(usdtBalancePriceOfUser >= priceOfusdtUserwantToBorrow) ||
                !(usdtBorrowBalance.add(amount.mul(usdtPrice).div(1e6)) <=
                    usdtBalancePriceOfUser) ||
                !(usdtBorrowBalance.add(amount.mul(usdtPrice).div(1e6)) <
                    borrowingLimit)
            ) {
                revert("Invalid borrowing conditions");
            }

            // Borrowing conditions met, proceed with the borrow operation
            uint256 amountToBorrow = amount.mul(80).div(100);
            require(
                usdtToken.transfer(msg.sender, amount),
                "USDT transfer failed"
            );
            require(
                usdtToken.balanceOf(address(this)) >= amount,
                "Contract has insufficient USDCT balance"
            );
            userBalances[msg.sender].usdtborrowBalance += amount;
            TotalUSDTBorrowed += amount;
            // Check if msg.sender is already in the borrowers array
            bool alreadyInArray = false;
            for (uint256 i = 0; i < borrowers.length; i++) {
                if (borrowers[i] == msg.sender) {
                    alreadyInArray = true;
                    break;
                }
            }
            // If msg.sender is not in the borrowers array, push it
            if (!alreadyInArray) {
                borrowers.push(payable(msg.sender));
            }
            isBorrower[msg.sender] = true;
            userBalances[msg.sender].USDTdepositFrozen = true;
            emit USDTBorrowed(msg.sender, amount);
        } else if (
            keccak256(bytes(getSelectedCollateral())) ==
            keccak256(bytes("USDC"))
        ) {
            if (userCollateralInfo[msg.sender].usdcBalance < min_usdc_deposit) {
                revert("Insufficient USDC balance");
            }

            (
                uint256 usdcBalancePriceOfUser,
                uint256 priceOfusdcUserwantToBorrow,
                uint256 priceOfusdtUserwantToBorrow,
                uint256 coreBalancePriceOfUser,
                uint256 usdtBalancePriceOfUser,
                uint256 PriceOfCoreUserwantToBorrow
            ) = calculatePrice(amount);

            uint256 USDCPrice = usdcPrice.div(1e6);
            uint256 USDTPrice = usdtPrice.div(1e6);

            uint256 depositPrice = userCollateralInfo[msg.sender].usdcBalance.mul(
                USDCPrice
            );

            // uint256 borrowingLimit = depositPrice.mul(borrowingLimitPercentage).div(100);
            uint256 borrowingLimit = userCollateralInfo[msg.sender]
                .usdcBalance
                .mul(usdcPrice)
                .div(1e6)
                .mul(borrowingLimitPercentage)
                .div(100);

            // Calculate the borrowing price in USDC
            uint256 borrowPrice = amount.mul(USDTPrice);

            // Calculate the total borrowed amount in USDC
            // uint256 coreBorrowBalancePrice = userBalances[msg.sender].coreborrowBalance.mul(usdcPrice).div(1e6);
            uint256 usdtBorrowBalancePrice = userBalances[msg.sender]
                .usdtborrowBalance
                .mul(USDTPrice);

            // Check if the borrow conditions are met
            // Check if the borrowing conditions are met
            require(borrowPrice <= borrowingLimit, "Exceeded borrowing limit");
            require(
                usdtBorrowBalancePrice.add(borrowPrice) < borrowingLimit,
                "you can not borrow more than the deposit limit"
            );
            require(
                usdtBorrowBalancePrice.add(borrowPrice) <= depositPrice,
                "Deposit value is insufficient for borrowing"
            );
            require(
                depositPrice > borrowPrice,
                "Borrowed amount should be less than the core deposit value"
            );
            require(
                usdtToken.balanceOf(address(this)) >= amount,
                "Contract has insufficient USDCT balance"
            );

            // Proceed with the borrow operation
            require(
                usdtToken.transfer(msg.sender, amount),
                "USDT transfer failed"
            );
            userBalances[msg.sender].usdtborrowBalance += amount;
            TotalUSDTBorrowed += amount;

            // Check if msg.sender is already in the borrowers array
            bool alreadyInArray = false;
            for (uint256 i = 0; i < borrowers.length; i++) {
                if (borrowers[i] == msg.sender) {
                    alreadyInArray = true;
                    break;
                }
            }

            // If msg.sender is not in the borrowers array, push it
            if (!alreadyInArray) {
                borrowers.push(payable(msg.sender));
            }

            isBorrower[msg.sender] = true;
            userBalances[msg.sender].USDTdepositFrozen = true;
            emit USDTBorrowed(msg.sender, amount);
        } else if (
            keccak256(bytes(getSelectedCollateral())) ==
            keccak256(bytes("CORE"))
        ) {
            if (userCollateralInfo[msg.sender].coreBalance < minCoredeposit) {
                revert("Insufficient CORE balance");
            }

            (
                uint256 usdcBalancePriceOfUser,
                uint256 priceOfusdcUserwantToBorrow,
                uint256 priceOfusdtUserwantToBorrow,
                uint256 coreBalancePriceOfUser,
                uint256 usdtBalancePriceOfUser,
                uint256 PriceOfCoreUserwantToBorrow
            ) = calculatePrice(amount);
            // Calculate the borrowing limit based on the user's core balance price
            uint256 depositPrice = userCollateralInfo[msg.sender]
                .coreBalance
                .mul(core_price)
                .div(1e18)
                .div(1e12);
            uint256 borrowingLimit = depositPrice
                .mul(borrowingLimitPercentage)
                .div(100);

            // Calculate the borrowing price in USDT
            uint256 borrowPrice = amount.mul(usdtPrice).div(1e6);

            // Calculate the total borrowed amount in USDT
            uint256 usdtBorrowBalancePrice = userBalances[msg.sender]
                .usdtborrowBalance
                .mul(usdtPrice)
                .div(1e6);

            // Check if the borrow conditions are met
            // Check if the borrowing conditions are met
            require(borrowPrice <= borrowingLimit, "Exceeded borrowing limit");
            require(
                usdtBorrowBalancePrice.add(borrowPrice) < borrowingLimit,
                "you can not borrow more thsn the deposit limit"
            );
            require(
                usdtBorrowBalancePrice.add(borrowPrice) <= depositPrice,
                "Deposit value is insufficient for borrowing"
            );
            require(
                depositPrice > borrowPrice,
                "Borrowed amount should be less than the core deposit value"
            );

            uint256 amountToBorrow = amount.mul(80).div(100);
            require(
                usdtToken.balanceOf(address(this)) >= amount,
                "Contract has insufficient USDT balance"
            );

            require(
                usdtToken.transfer(msg.sender, amount),
                "USDT transfer failed"
            );
            userBalances[msg.sender].usdtborrowBalance += amount;
            TotalUSDTBorrowed += amount;
            // Check if msg.sender is already in the borrowers array
            bool alreadyInArray = false;
            for (uint256 i = 0; i < borrowers.length; i++) {
                if (borrowers[i] == msg.sender) {
                    alreadyInArray = true;
                    break;
                }

                // If msg.sender is not in the borrowers array, push it
                if (!alreadyInArray) {
                    borrowers.push(payable(msg.sender));
                }
                userBalances[msg.sender].USDTdepositFrozen = true;
                emit USDTBorrowed(msg.sender, amount);
            }
        }
    }

    //Borrow USDC
    function borrowUSDCbasedonCollateral(
        uint256 amount
    ) external payable nonReentrant {
        if (
            userBalances[msg.sender].selectedCollateral == CollateralType.None
        ) {
            revert("A collateral is needed");
        }
        if (
            keccak256(bytes(getSelectedCollateral())) ==
            keccak256(bytes("USDT"))
        ) {
            if (userCollateralInfo[msg.sender].usdtBalance < min_usdt_deposit) {
                revert("Insufficient USDT balance");
            }

            (
                uint256 usdtBalancePriceOfUser,
                uint256 priceOfusdcUserwantToBorrow,
                uint256 priceOfusdtUserwantToBorrow,
                uint256 coreBalancePriceOfUser,
                uint256 usdcBalancePriceOfUser,
                uint256 PriceOfCoreUserwantToBorrow
            ) = calculatePrice(amount);
            // Calculate the borrowing limit based on the user's borrowed balance
            uint256 borrowingLimit = userCollateralInfo[msg.sender]
                .usdtBalance
                .mul(usdtPrice)
                .div(1e6)
                .mul(borrowingLimitPercentage)
                .div(100);
            // Calculate the borrowing amount in terms of price
            uint256 borrowingAmount = amount.mul(usdtPrice).div(1e6);

            // uint256 balanceofBorrowedUSDTindollar = userBalances[msg.sender].usdtborrowBalance.mul(usdtPrice.div(1e6));
            uint256 usdcBorrowBalance = userBalances[msg.sender]
                .usdcborrowBalance
                .mul(usdcPrice)
                .div(1e6);
            if (
                !(usdtBalancePriceOfUser >= priceOfusdcUserwantToBorrow) ||
                !(usdcBorrowBalance.add(amount.mul(usdcPrice).div(1e6)) <=
                    usdtBalancePriceOfUser) ||
                !(usdcBorrowBalance.add(amount.mul(usdcPrice).div(1e6)) <
                    borrowingLimit)
            ) {
                revert("Invalid borrowing conditions");
            }

            uint256 amountToBorrow = amount.mul(80).div(100);
            require(
                usdcToken.transfer(msg.sender, amountToBorrow),
                "USDC transfer failed"
            );
            userBalances[msg.sender].usdcborrowBalance += amount;
            TotalUSDCBorrowed += amount;
            // Check if msg.sender is already in the borrowers array
            bool alreadyInArray = false;
            for (uint256 i = 0; i < borrowers.length; i++) {
                if (borrowers[i] == msg.sender) {
                    alreadyInArray = true;
                    break;
                }
            }

            // If msg.sender is not in the borrowers array, push it
            if (!alreadyInArray) {
                borrowers.push(payable(msg.sender));
            }
            isBorrower[msg.sender] = true;
            userBalances[msg.sender].USDCdepositFrozen = true;
            emit USDCBorrowed(msg.sender, amount);
        } else if (
            keccak256(bytes(getSelectedCollateral())) ==
            keccak256(bytes("USDC"))
        ) {
            if (userCollateralInfo[msg.sender].usdcBalance < min_usdc_deposit) {
                revert("Insufficient USDC balance");
            }

            (
                uint256 usdcBalancePriceOfUser,
                uint256 priceOfusdcUserwantToBorrow,
                uint256 priceOfusdtUserwantToBorrow,
                uint256 coreBalancePriceOfUser,
                uint256 usdtBalancePriceOfUser,
                uint256 PriceOfCoreUserwantToBorrow
            ) = calculatePrice(amount);

            uint256 USDCPrice = usdcPrice.div(1e6);
            //    uint256 Price = core_price.div(1e18);

            uint256 depositPrice = userCollateralInfo[msg.sender].usdcBalance.mul(
                USDCPrice
            );

            // uint256 borrowingLimit = depositPrice.mul(borrowingLimitPercentage).div(100);
            uint256 borrowingLimit = userCollateralInfo[msg.sender]
                .usdcBalance
                .mul(usdcPrice)
                .div(1e6)
                .mul(borrowingLimitPercentage)
                .div(100);

            // Calculate the borrowing price in USDC
            uint256 borrowPrice = amount.mul(USDCPrice);

            // Calculate the total borrowed amount in USDC
            // uint256 coreBorrowBalancePrice = userBalances[msg.sender].coreborrowBalance.mul(usdcPrice).div(1e6);
            uint256 usdcBorrowBalancePrice = userBalances[msg.sender]
                .usdcborrowBalance
                .mul(USDCPrice);

            // Check if the borrow conditions are met
            // Check if the borrowing conditions are met
            require(borrowPrice <= borrowingLimit, "Exceeded borrowing limit");
            require(
                usdcBorrowBalancePrice.add(borrowPrice) < borrowingLimit,
                "you can not borrow more thsn the deposit limit"
            );
            require(
                usdcBorrowBalancePrice.add(borrowPrice) <= depositPrice,
                "Deposit value is insufficient for borrowing"
            );
            require(
                depositPrice > borrowPrice,
                "Borrowed amount should be less than the core deposit value"
            );
            require(
                usdcToken.balanceOf(address(this)) >= amount,
                "Contract has insufficient USDC balance"
            );

            require(
                usdcToken.transfer(msg.sender, amount),
                "USDC transfer failed"
            );
            userBalances[msg.sender].usdcborrowBalance += amount;
            TotalUSDCBorrowed += amount;
            // Check if msg.sender is already in the borrowers array
            bool alreadyInArray = false;
            for (uint256 i = 0; i < borrowers.length; i++) {
                if (borrowers[i] == msg.sender) {
                    alreadyInArray = true;
                    break;
                }
            }

            // If msg.sender is not in the borrowers array, push it
            if (!alreadyInArray) {
                borrowers.push(payable(msg.sender));
            }
            isBorrower[msg.sender] = true;
            userBalances[msg.sender].USDCdepositFrozen = true;
            emit USDCBorrowed(msg.sender, amount);
        } else if (
            keccak256(bytes(getSelectedCollateral())) ==
            keccak256(bytes("CORE"))
        ) {
            if (userCollateralInfo[msg.sender].coreBalance < minCoredeposit) {
                revert("Insufficient CORE balance");
            }

            (
                uint256 usdcBalancePriceOfUser,
                uint256 priceOfusdcUserwantToBorrow,
                uint256 priceOfusdtUserwantToBorrow,
                uint256 coreBalancePriceOfUser,
                uint256 usdtBalancePriceOfUser,
                uint256 PriceOfCoreUserwantToBorrow
            ) = calculatePrice(amount);
            // Calculate the borrowing limit based on the user's core balance price
            uint256 depositPrice = userCollateralInfo[msg.sender]
                .coreBalance
                .mul(core_price)
                .div(1e18)
                .div(1e12);
            uint256 borrowingLimit = depositPrice
                .mul(borrowingLimitPercentage)
                .div(100);

            // Calculate the borrowing price in USDC
            uint256 borrowPrice = amount.mul(usdcPrice).div(1e6);

            // Calculate the total borrowed amount in USDC
            uint256 usdcBorrowBalancePrice = userBalances[msg.sender]
                .usdcborrowBalance
                .mul(usdcPrice)
                .div(1e6);

            // Check if the borrow conditions are met
            // Check if the borrowing conditions are met
            require(borrowPrice <= borrowingLimit, "Exceeded borrowing limit");
            require(
                usdcBorrowBalancePrice.add(borrowPrice) < borrowingLimit,
                "you can not borrow more thsn the deposit limit"
            );
            require(
                usdcBorrowBalancePrice.add(borrowPrice) <= depositPrice,
                "Deposit value is insufficient for borrowing"
            );
            require(
                depositPrice > borrowPrice,
                "Borrowed amount should be less than the core deposit value"
            );

            uint256 amountToBorrow = amount.mul(80).div(100);
            require(
                usdcToken.balanceOf(address(this)) >= amount,
                "Contract has insufficient USDC balance"
            );
            require(
                usdcToken.transfer(msg.sender, amount),
                "USDC transfer failed"
            );
            userBalances[msg.sender].usdcborrowBalance += amount;
            TotalUSDCBorrowed += amount;
            // Check if msg.sender is already in the borrowers array
            bool alreadyInArray = false;
            for (uint256 i = 0; i < borrowers.length; i++) {
                if (borrowers[i] == msg.sender) {
                    alreadyInArray = true;
                    break;
                }
            }

            // If msg.sender is not in the borrowers array, push it
            if (!alreadyInArray) {
                borrowers.push(payable(msg.sender));
            }
            isBorrower[msg.sender] = true;
            userBalances[msg.sender].USDCdepositFrozen = true;
            emit USDCBorrowed(msg.sender, amount);
        }
    }

    function isLiquidated(address user) external view returns (bool) {
        // uint256 collateralValue = calculateCollateralValue();
        // uint256 borrowedAmount;

        // Calculate the LTV ratio
        (
            uint256 ltvRatio,
            uint256 borrowedAmount,
            uint256 collateralValue
        ) = calculateLTVRatio(user);
        // Check if the LTV ratio exceeds the liquidation threshold
        if (ltvRatio > liquidationThreshold) {
            return true; // User is liquidated
        }

        return false; // User is not liquidated
    }

    function calculateLTVRatio(
        address user
    ) internal view returns (uint256, uint256, uint256) {
        // Get the user's selected collateral from the userBalances mapping
        CollateralType selectedCollateral = userBalances[user]
            .selectedCollateral;
        require(
            selectedCollateral != CollateralType(0),
            "Collateral not selected"
        );

        // Determine the borrowed amount and collateral value based on the selected collateral
        uint256 borrowedAmount;
        uint256 collateralValue;

        if (selectedCollateral == CollateralType.CORE) {
            borrowedAmount = userBalances[user].coreborrowBalance;
            collateralValue =
                (userCollateralInfo[user].coreBalance * core_price) /
                1e18;
        } else if (selectedCollateral == CollateralType.USDT) {
            borrowedAmount = userBalances[user].usdtborrowBalance;
            collateralValue =
                (userCollateralInfo[user].usdtBalance * usdtPrice) /
                1e6;
        } else if (selectedCollateral == CollateralType.USDC) {
            borrowedAmount = userBalances[user].usdcborrowBalance;
            collateralValue =
                (userCollateralInfo[user].usdcBalance * usdcPrice) /
                1e6;
        } else {
            revert("Invalid collateral type");
        }

        // Calculate the LTV ratio in basis points (multiply by 10000 to convert to basis points)
        uint256 ltvRatio = (borrowedAmount * 10000) / collateralValue;

        return (ltvRatio, borrowedAmount, collateralValue);
    }

    function monitorLiquidationStatus() external {
        for (uint256 i = 0; i < depositors.length; i++) {
            address user = depositors[i];
            // Check if the user is also a borrower
            if (isBorrower[user]) {
                // Perform liquidation status check for the user
                uint256 collateralValue = calculateCollateralValue();
                uint256 borrowedAmount;

                if (
                    userBalances[msg.sender].selectedCollateral ==
                    CollateralType.CORE
                ) {
                    borrowedAmount = userBalances[user].coreborrowBalance;
                } else if (
                    userBalances[msg.sender].selectedCollateral ==
                    CollateralType.USDT
                ) {
                    borrowedAmount = userBalances[user].usdtborrowBalance;
                } else if (
                    userBalances[msg.sender].selectedCollateral ==
                    CollateralType.USDC
                ) {
                    borrowedAmount = userBalances[user].usdcborrowBalance;
                } else {
                    revert("Invalid collateral type");
                }

                // Calculate the LTV ratio
                uint256 ltvRatio = borrowedAmount.mul(10000).div(
                    collateralValue
                );

                // Check if the LTV ratio exceeds the liquidation threshold
                if (ltvRatio >= liquidationThreshold) {
                    uint256 feeDecimal = 45e16; // 4.5% fee in decimal form (0.045)

                    // Calculate the fee amount based on collateral value
                    uint256 feeAmount = collateralValue.mul(feeDecimal).div(
                        1e19
                    );

                    // Deduct the fee from the collateral value
                    uint256 remainingCollateral = collateralValue.sub(
                        feeAmount
                    );

                    // Freeze the deposit balance
                    userBalances[user].isDepositFrozen = true;

                    if (remainingCollateral > 0) {
                        // Update the remaining collateral balance in the user's state
                        // Adjust the code based on the collateral type (USDT, USDC, CORE)
                        if (
                            userBalances[msg.sender].selectedCollateral ==
                            CollateralType.USDT
                        ) {
                            userCollateralInfo[user].usdtBalance = remainingCollateral
                                .div(usdtPrice);
                        } else if (
                            userBalances[msg.sender].selectedCollateral ==
                            CollateralType.USDC
                        ) {
                            userCollateralInfo[user].usdcBalance = remainingCollateral
                                .div(usdcPrice);
                        } else if (
                            userBalances[msg.sender].selectedCollateral ==
                            CollateralType.CORE
                        ) {
                            userCollateralInfo[user].coreBalance = remainingCollateral
                                .div(core_price);
                        } else {
                            revert("Invalid collateral type");
                        }
                    }

                    // Emit an event or perform necessary actions
                    // ...
                }
            }
        }
    }

    function calculateCollateralValue() public view returns (uint256) {
        uint256 collateralValue;

        if (
            userBalances[msg.sender].selectedCollateral == CollateralType.USDT
        ) {
            uint256 usdtBalance = userCollateralInfo[msg.sender].usdtBalance;
            collateralValue = usdtBalance.mul(usdtPrice).div(1e6);
        } else if (
            userBalances[msg.sender].selectedCollateral == CollateralType.CORE
        ) {
            uint256 coreBalance = userCollateralInfo[msg.sender].coreBalance;
            collateralValue = coreBalance.mul(core_price).div(1e18);
        } else if (
            userBalances[msg.sender].selectedCollateral == CollateralType.USDC
        ) {
            uint256 usdcBalance = userCollateralInfo[msg.sender].usdcBalance;
            collateralValue = usdcBalance.mul(usdcPrice).div(1e6);
        } else {
            revert("Invalid collateral type");
        }

        return collateralValue;
    }

    function withdrawCore(uint256 amount) external payable nonReentrant {
        // Check if user has the minimum required amount of CORE
        if (userCollateralInfo[msg.sender].coreBalance < minCoredeposit) {
            revert("Insufficient CORE balance");
        }

        // Check if the amount to withdraw exceeds the available balance
        if (amount > userCollateralInfo[msg.sender].coreBalance) {
            revert("Exceeded amount in the balance");
        }

        require(
            address(this).balance > amount,
            "Not enough ETH in the contract"
        );

        if (userBalances[msg.sender].COREdepositFrozen == true) {
            revert("you already used this asset as your collateral");
        }

        if (
            userBalances[msg.sender].coreborrowBalance > 0
        ) // Check if the user has any outstanding debt (borrowed amounts)
        {
            revert("Please repay your debt before withdrawing");
        }

        // Check if the user's deposit is frozen (liquidated)
        if (userBalances[msg.sender].isDepositFrozen) {
            // Calculate the fee amount (4.5% of the core balance)
            uint256 feeAmount = userCollateralInfo[msg.sender]
                .coreBalance
                .mul(45)
                .div(1000);

            // Calculate the remaining balance after deducting the fee
            uint256 remainingBalance = userCollateralInfo[msg.sender].coreBalance.sub(
                feeAmount
            );

            // Set the balance to zero
            userCollateralInfo[msg.sender].coreBalance = 0;

            // Transfer the remaining balance to the user's address
            (bool success1, ) = payable(msg.sender).call{
                value: remainingBalance
            }("");
            if (!success1) {
                revert("Transfer failed");
            }

            // Emit an event or perform necessary actions
            emit CoreWithdrawn(msg.sender, remainingBalance);

            // Exit the function after the withdrawal is completed
            return;
        }
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        if (!success) {
            revert("Transfer failed");
        }

        userCollateralInfo[msg.sender].coreBalance -= amount;
        lendingToken.burn(msg.sender, amount);

        emit Withdrewdeposit(msg.sender, amount);
    }

    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    function withdrawUSDT(uint256 amount) external payable nonReentrant {
        // Check if user has the minimum required amount of USDT
        if (userCollateralInfo[msg.sender].usdtBalance < min_usdt_deposit) {
            revert("Insufficient USDT balance");
        }

        // Check if the amount to withdraw exceeds the available balance
        if (amount > userCollateralInfo[msg.sender].usdtBalance) {
            revert("Exceeded amount in the balance");
        }
        require(
            usdtToken.balanceOf(address(this)) >= amount,
            "Contract has insufficient USDT balance"
        );

        if (userBalances[msg.sender].USDTdepositFrozen == true) {
            revert("you already used this asset as your collateral");
        }

        if (
            userBalances[msg.sender].usdtborrowBalance > 0
        ) // Check if the user has any outstanding debt (borrowed amounts)
        {
            revert("Please repay your debt before withdrawing");
        }

        // Check if the user's deposit is frozen (liquidated)
        if (userBalances[msg.sender].isDepositFrozen) {
            // Calculate the fee amount (4.5% of the core balance)
            uint256 feeAmount = userCollateralInfo[msg.sender]
                .usdtBalance
                .mul(45)
                .div(1000);

            // Calculate the remaining balance after deducting the fee
            uint256 remainingBalance = userCollateralInfo[msg.sender].usdtBalance.sub(
                feeAmount
            );

            // Set the balance to zero
            userCollateralInfo[msg.sender].usdtBalance = 0;

            // Transfer the remaining balance to the user's address
            (bool success2, ) = payable(msg.sender).call{
                value: remainingBalance
            }("");
            if (!success2) {
                revert("Transfer failed");
            }

            // Emit an event or perform necessary actions
            emit USDTWithdrawn(msg.sender, remainingBalance);

            // Exit the function after the withdrawal is completed
            return;
        }
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        if (!success) {
            revert("Transfer failed");
        }

        userCollateralInfo[msg.sender].usdtBalance -= amount;
        lendingToken.burn(msg.sender, amount);

        emit WithdrewUSDT(msg.sender, amount);
    }

    function withdrawUSDC(uint256 amount) external payable nonReentrant {
        // Check if user has the minimum required amount of USDT
        if (userCollateralInfo[msg.sender].usdtBalance < min_usdc_deposit) {
            revert("Insufficient USDC balance");
        }

        // Check if the amount to withdraw exceeds the available balance
        if (amount > userCollateralInfo[msg.sender].usdcBalance) {
            revert("Exceeded amount in the balance");
        }
        require(
            usdcToken.balanceOf(address(this)) >= amount,
            "Contract has insufficient USDC balance"
        );

        if (userBalances[msg.sender].USDCdepositFrozen == true) {
            revert("you already used this asset as your collateral");
        }

        if (
            userBalances[msg.sender].usdcborrowBalance > 0
        ) // Check if the user has any outstanding debt (borrowed amounts)
        {
            revert("Please repay your debt before withdrawing");
        }

        // Check if the user's deposit is frozen (liquidated)
        if (userBalances[msg.sender].isDepositFrozen) {
            // Calculate the fee amount (4.5% of the core balance)
            uint256 feeAmount = userCollateralInfo[msg.sender]
                .usdcBalance
                .mul(45)
                .div(1000);

            // Calculate the remaining balance after deducting the fee
            uint256 remainingBalance = userCollateralInfo[msg.sender].usdcBalance.sub(
                feeAmount
            );

            // Set the balance to zero
            userCollateralInfo[msg.sender].usdcBalance = 0;

            // Transfer the remaining balance to the user's address
            (bool success, ) = payable(msg.sender).call{
                value: remainingBalance
            }("");
            if (!success) {
                revert("Transfer failed");
            }

            // Emit an event or perform necessary actions
            emit USDCWithdrawn(msg.sender, remainingBalance);

            // Exit the function after the withdrawal is completed
            return;
        }
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        if (!success) {
            revert("Transfer failed");
        }

        userCollateralInfo[msg.sender].usdcBalance -= amount;
        lendingToken.burn(msg.sender, amount);

        emit WithdrewUSDC(msg.sender, amount);
    }

    function withdraw(uint256 amount) external onlyOwner {
        require(
            amount <= address(this).balance,
            "Insufficient contract balance"
        );
        payable(owner).transfer(amount);
        // emit Withdrawn(owner, amount);
    }

    function setRewardRate(uint256 _rewardRate) external onlyOwner {
        rewardRate = _rewardRate;
    }

    function calculateRewardBasedOnCORE() public view returns (uint256) {
        uint256 depositTimestamp = userCollateralInfo[msg.sender].depositFromTSofCORE;
        uint256 currentTimestamp = block.timestamp;
        uint256 timeDifference = currentTimestamp - depositTimestamp;

        // Calculate the reward based on daily APY
        uint256 reward = (userCollateralInfo[msg.sender].coreBalance *
            rewardRate *
            timeDifference *
            1e10) / (31540000 * 1e18);

        uint256 rewardToClaim = reward.div(1e8);

        return rewardToClaim;
    }

    function calculateRewardBasedOnUSDT() public view returns (uint256) {
        uint256 depositTimestamp = userCollateralInfo[msg.sender].depositFromTSofUSDT;
        uint256 currentTimestamp = block.timestamp;
        uint256 timeDifference = currentTimestamp - depositTimestamp;

        // Calculate the reward based on daily APY
        uint256 reward = (userCollateralInfo[msg.sender].usdtBalance *
            rewardRate *
            timeDifference) / (31540000 * 1e6);

        uint256 rewardToClaim = reward.div(1e8);

        return rewardToClaim;
    }

    function calculateRewardBasedOnUSDC() public view returns (uint256) {
        uint256 depositTimestamp = userCollateralInfo[msg.sender].depositFromTSofUSDC;
        uint256 currentTimestamp = block.timestamp;
        uint256 timeDifference = currentTimestamp - depositTimestamp;

        // Calculate the reward based on daily APY
        uint256 reward = (userCollateralInfo[msg.sender].usdcBalance *
            rewardRate *
            timeDifference) / (31540000 * 1e6);

        uint256 rewardToClaim = reward.div(1e8);

        return rewardToClaim;
    }

    function ClaimCoreReward() external payable nonReentrant {
        uint256 coreReward = calculateRewardBasedOnCORE();
        require(coreReward > 0, "No rewards to claim");
        require(
            !userBalances[msg.sender].userHasClaimedRewards,
            "Rewards already claimed"
        );
        require(
            userCollateralInfo[msg.sender].coreBalance > 0,
            "No CORE deposit found"
        );
        // Update the reward balance
        userBalances[msg.sender].rewardBalancesCORE += coreReward;

        // Transfer the reward tokens to the user
        require(
            ucoreToken.transfer(msg.sender, coreReward),
            "Reward transfer failed"
        );

        userCollateralInfo[msg.sender].depositFromTSofCORE = 0;
        // Mark that the user has claimed rewards
        userBalances[msg.sender].userHasClaimedRewards = true;
        emit CorerewardCLiamed(msg.sender, coreReward);
    }

    function ClaimUSDTReward() external payable nonReentrant {
        uint256 usdtReward = calculateRewardBasedOnUSDT();
        require(usdtReward > 0, "No rewards to claim");
        require(
            !userBalances[msg.sender].userHasClaimedRewards,
            "Rewards already claimed"
        );
        require(
            userCollateralInfo[msg.sender].usdtBalance > 0,
            "No   USDT deposit found"
        );
        // Update the reward balance
        userBalances[msg.sender].rewardBalancesUSDT += usdtReward;

        // Transfer the reward tokens to the user
        require(
            ucoreToken.transfer(msg.sender, usdtReward),
            "Reward transfer failed"
        );

        userCollateralInfo[msg.sender].depositFromTSofUSDT = 0;
        // Mark that the user has claimed rewards
        userBalances[msg.sender].userHasClaimedRewards = true;
        emit UsdtrewardCLiamed(msg.sender, usdtReward);
    }

    function ClaimUSDCReward() external payable nonReentrant {
        uint256 usdcReward = calculateRewardBasedOnUSDC();
        require(usdcReward > 0, "No rewards to claim");
        require(
            !userBalances[msg.sender].userHasClaimedRewards,
            "Rewards already claimed"
        );
        require(
            userCollateralInfo[msg.sender].usdcBalance > 0,
            "No USDC deposit found"
        );
        // Update the reward balance
        userBalances[msg.sender].rewardBalancesUSDC += usdcReward;

        // Transfer the reward tokens to the user
        require(
            ucoreToken.transfer(msg.sender, usdcReward),
            "Reward transfer failed"
        );

        userCollateralInfo[msg.sender].depositFromTSofUSDC = 0;
        // Mark that the user has claimed rewards
        userBalances[msg.sender].userHasClaimedRewards = true;
        emit UsdcrewardCLiamed(msg.sender, usdcReward);
    }


    
// Assuming core_price, usdtPrice, and usdcPrice are the prices of CORE, USDT, and USDC tokens in USD, respectively.
function calculateBorrowLimitPercentage(address user, CollateralType collateral) internal view returns (uint256) {
    uint256 borrowedAmountUSD = calculateBorrowedAmountInPrice(user, collateral);
   

    // Calculate the borrow limit percentage for the selected collateral
    uint256 borrowLimitPercentage;
    if (borrowedAmountUSD > 0) {
        borrowLimitPercentage = (borrowedAmountUSD * 100);
    } else {
        borrowLimitPercentage = 0;
    }

    return borrowLimitPercentage;
}

function calculateBorrowedAmountInPrice(address user, CollateralType collateral) internal view returns (uint256) {
    // Get the borrowed amount for the selected collateral in USD
    uint256 borrowedAmountUSD;

    if (collateral == CollateralType.CORE) {
        borrowedAmountUSD = userBalances[user].coreborrowBalance * core_price / 1e18;
    } else if (collateral == CollateralType.USDT) {
        borrowedAmountUSD = userBalances[user].usdtborrowBalance * usdtPrice / 1e6;
    } else if (collateral == CollateralType.USDC) {
        borrowedAmountUSD = userBalances[user].usdcborrowBalance * usdcPrice / 1e6;
    } else {
        revert("Invalid collateral type");
    }

    return borrowedAmountUSD;
}


}

