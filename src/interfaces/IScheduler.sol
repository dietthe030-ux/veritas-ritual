// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IScheduler {
    function schedule(
        bytes calldata callData,
        uint256 gasLimit,
        uint32 startBlock,
        uint32 numCalls,
        uint32 frequency,
        uint32 ttl,
        uint256 maxFeePerGas,
        uint256 maxPriorityFeePerGas,
        uint256 value,
        address payer
    ) external returns (uint256);
}
