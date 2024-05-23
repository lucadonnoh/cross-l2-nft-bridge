// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

interface IVault {
    function deposit(uint256 tokenId, address unlocker) external;
    function nft() external view returns (address);
    function vaults(uint256) external view returns (address owner, address unlocker);
    function withdraw(uint256 tokenId) external;
}
