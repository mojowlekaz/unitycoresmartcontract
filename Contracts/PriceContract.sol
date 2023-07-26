// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

interface ISwitchboard {
    // read from aggregator
    function latestResult(address aggregatorAddress) external payable returns (int256 value, uint timestamp);
}

contract PriceContract {
    int256 public latestValue;
    uint256 public latestTimestamp;
    address switchboardAddress;
    address aggregatorAddress;

    constructor(address _switchboard, address _aggregatorAddress) {
        switchboardAddress = _switchboard;
        aggregatorAddress = _aggregatorAddress;
    }

    function latest() external view returns (int256, uint256) {
        return (latestValue, latestTimestamp);
    }

    function getPrice() external returns (uint256) {
        ISwitchboard switchboard = ISwitchboard(switchboardAddress);
        (int256 value, ) = switchboard.latestResult(aggregatorAddress);
        latestValue = value;
        latestTimestamp = block.timestamp;
        return uint256(value);
    }
}



//  function borrowCoreBasedOnCollateral()
//         external
//         payable
//         nonReentrant
//     {
//         if (selectedCollateral[msg.sender] == CollateralType.None) {
//             revert("A collateral is needed");
//         }
//         if (
//             keccak256(bytes(getSelectedCollateral())) ==
//             keccak256(bytes("USDT"))
//         ) {
//             if (userBalances[msg.sender].usdtBalance < min_usdt_deposit) {
//                 revert("Insufficient USDT balance");
//             }
//             require(msg.value > 0, "borrow a reasonable amount");
//             uint256 amountToBorrow = msg.value.mul(80).div(100);
//             require(amountToBorrow <= address(this).balance, "Insufficient contract balance");

//             (
//                 uint256 usdtBalancePriceOfUser,
//                 uint256 priceOfusdcUserwantToBorrow,
//                 uint256 priceOfusdtUserwantToBorrow,
//                 uint256 coreBalancePriceOfUser,
//                 uint256 PriceOfCoreUserwantToBorrow
//             ) = calculatePrice(amountToBorrow);
//             if (usdtBalancePriceOfUser > PriceOfCoreUserwantToBorrow) {
//                 payable(msg.sender).transfer(amountToBorrow);
//                 userBalances[msg.sender].coreborrowBalance += amountToBorrow;
//                 TotalCoreBorrowed += amountToBorrow;
//                                 bool alreadyInArray = false;
//                 for (uint256 i = 0; i < borrowers.length; i++) {
//                     if (borrowers[i] == msg.sender) {
//                         alreadyInArray = true;
//                         break;
//                     }
//                 }

//                 // If msg.sender is not in the borrowers array, push it
//                 if (!alreadyInArray) {
//                     borrowers.push(payable(msg.sender));
//                 }
//                 isBorrower[msg.sender] = true;
//                 emit coreBorrowed(msg.sender, amountToBorrow);
//             }
//         } else if (
//             keccak256(bytes(getSelectedCollateral())) ==
//             keccak256(bytes("USDC"))
//         ) {
//             if (userBalances[msg.sender].usdcBalance < min_usdc_deposit) {
//                 revert("Insufficient USDC balance");
//             }
//             require(msg.value > 0, "borrow a reasonable amount");
//             uint256 amountToBorrow = msg.value.mul(80).div(100);
//             require(amountToBorrow <= address(this).balance, "Insufficient contract balance");

//             (
//                 uint256 usdcBalancePriceOfUser,
//                 uint256 priceOfusdcUserwantToBorrow,
//                 uint256 priceOfusdtUserwantToBorrow,
//                 uint256 coreBalancePriceOfUser,
//                 uint256 PriceOfCoreUserwantToBorrow
//             ) = calculatePrice(amountToBorrow);
//             if (usdcBalancePriceOfUser > PriceOfCoreUserwantToBorrow) {
//                 uint256 amountToBorrow = amountToBorrow.mul(80).div(100);
//                 payable(msg.sender).transfer(amountToBorrow);
//                 userBalances[msg.sender].coreborrowBalance += amountToBorrow;
//                 TotalCoreBorrowed += amountToBorrow;
//                 // Check if msg.sender is already in the borrowers array
//                 bool alreadyInArray = false;
//                 for (uint256 i = 0; i < borrowers.length; i++) {
//                     if (borrowers[i] == msg.sender) {
//                         alreadyInArray = true;
//                         break;
//                     }
//                 }

//                 // If msg.sender is not in the borrowers array, push it
//                 if (!alreadyInArray) {
//                     borrowers.push(payable(msg.sender));
//                 }
//  isBorrower[msg.sender] = true;
//                 emit coreBorrowed(msg.sender, amountToBorrow);
//             }
//         } else if (
//             keccak256(bytes(getSelectedCollateral())) ==
//             keccak256(bytes("CORE"))
//         ) {
//             if (userBalances[msg.sender].coreBalance < minCoredeposit) {
//                 revert("Insufficient CORE balance");
//             }
//             require(msg.value > 0, "borrow a reasonable amount");
//             uint256 amountToBorrow = msg.value.mul(80).div(100);
//             require(amountToBorrow <= address(this).balance, "Insufficient contract balance");
//             (
//                 uint256 usdcBalancePriceOfUser,
//                 uint256 priceOfusdcUserwantToBorrow,
//                 uint256 priceOfusdtUserwantToBorrow,
//                 uint256 coreBalancePriceOfUser,
//                 uint256 PriceOfCoreUserwantToBorrow
//             ) = calculatePrice(amountToBorrow);
//             if (coreBalancePriceOfUser > PriceOfCoreUserwantToBorrow) {
//                 uint256 amountToBorrow = amountToBorrow.mul(80).div(100);
//                 payable(msg.sender).transfer(amountToBorrow);
//                 userBalances[msg.sender].coreborrowBalance += amountToBorrow;
//                 // Check if msg.sender is already in the borrowers array
//                 bool alreadyInArray = false;
//                 for (uint256 i = 0; i < borrowers.length; i++) {
//                     if (borrowers[i] == msg.sender) {
//                         alreadyInArray = true;
//                         break;
//                     }
//                 }

//                 // If msg.sender is not in the borrowers array, push it
//                 if (!alreadyInArray) {
//                     borrowers.push(payable(msg.sender));
//                 }
//  isBorrower[msg.sender] = true;
//                 TotalCoreBorrowed += amountToBorrow;
//                 emit coreBorrowed(msg.sender, amountToBorrow);
//             }
//         }
//     }