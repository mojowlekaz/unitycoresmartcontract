// RewardsContract.sol

pragma solidity ^0.8.0;

// Interface for the main contract (UcorelendingProtocol)
interface IUcorelendingProtocol {
    function lastClaimTimestamp(address user) external view returns (uint256);

    function ucoreClaimableBalance(
        address user
    ) external view returns (uint256);
}

contract RewardsContract {
    // Declare the interface for the main contract
    IUcorelendingProtocol public coreLendingProtocol;
    address public owner;
    mapping(address => uint256) public ucoreClaimableBalance;

    constructor(address coreLendingProtocolAddress) {
        coreLendingProtocol = IUcorelendingProtocol(coreLendingProtocolAddress);
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "You are not the owner");
        _;
    }

    function calculateClaimableUCORE(
        address user
    ) public view returns (uint256) {
        uint256 timeDifference = block.timestamp -
            coreLendingProtocol.lastClaimTimestamp(user);
        uint256 ucoreAmountToTransfer = coreLendingProtocol
            .ucoreClaimableBalance(user) + (2 * timeDifference) / 8;
        return ucoreAmountToTransfer;
    }

    function setUCOREClaimableBalance(
        address user,
        uint256 amount
    ) external onlyOwner {
        ucoreClaimableBalance[user] = amount;
    }

    function updateUCOREClaimableBalance(
        address user,
        uint256 newBalance
    ) external onlyOwner {
        ucoreClaimableBalance[user] = newBalance;
    }

    function setCoreLendingProtocolAddress(
        address newAddress
    ) external onlyOwner {
        coreLendingProtocol = IUcorelendingProtocol(newAddress);
    }
}
