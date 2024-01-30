// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract NFT is ERC721Enumerable, ERC721URIStorage, AccessControl {
    uint256 public immutable MAX_SUPPLY;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    constructor(uint256 maxSupply) ERC721("NFT", "NFT") {
        MAX_SUPPLY = maxSupply;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
    }

    function addMinter(address account) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(MINTER_ROLE, account);
    }

    function mint(address to, string memory tokenUri) public onlyRole(MINTER_ROLE) {
        uint256 ts = totalSupply();
        require(ts < MAX_SUPPLY, "MAX_SUPPLY");
        _mint(to, ts);
        _setTokenURI(ts, tokenUri);
    }

    function tokenURI(uint256 tokenId) public view override(ERC721URIStorage, ERC721) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function _increaseBalance(address account, uint128 amount) internal virtual override(ERC721, ERC721Enumerable) {
        super._increaseBalance(account, amount);
    }

    function _update(address to, uint256 tokenId, address auth)
        internal
        virtual
        override(ERC721, ERC721Enumerable)
        returns (address)
    {
        return super._update(to, tokenId, auth);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721URIStorage, ERC721Enumerable, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
