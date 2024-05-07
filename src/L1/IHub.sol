// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

interface IHub {
    function finalizeBridgeLock(uint256 tokenId) external;
    function isLocked(uint256) external view returns (bool);
}
