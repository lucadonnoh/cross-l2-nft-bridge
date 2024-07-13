// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

interface IHub {
    function finalizeBridgeLock(address) external;
    function isLocked(address) external view returns (bool);
    function finalizeBatchBridgeLock(bytes32) external;
}
