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