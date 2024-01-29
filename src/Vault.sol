// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract NftVault {
    ERC721 public immutable nft;

    struct Vault {
        address owner;
        address unlocker;
    }

    mapping(uint256 => Vault) public vaults;

    constructor(address nftAddress) {
        nft = ERC721(nftAddress);
    }

    function deposit(uint256 tokenId, address unlocker) external {
        require(vaults[tokenId].owner == address(0), "VAULT_EXISTS");
        require(nft.ownerOf(tokenId) == msg.sender, "NOT_OWNER");
        vaults[tokenId] = Vault(msg.sender, unlocker);
        nft.transferFrom(msg.sender, address(this), tokenId);
    }

    function withdraw(uint256 tokenId) external {
        Vault memory vault = vaults[tokenId];
        require(vault.unlocker == msg.sender, "NOT_UNLOCKER");
        delete vaults[tokenId];
        nft.transferFrom(address(this), vault.owner, tokenId);
    }
}
