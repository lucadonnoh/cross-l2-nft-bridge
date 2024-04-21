// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "src/L1/IHub.sol";
import "src/libraries/Predeploys.sol";
import "./IL2CrossDomainMessenger.sol";

contract NftVault {
    ERC721 public immutable NFT;
    IHub public L1Hub;
    address immutable OWNER;

    struct Vault {
        address owner;
        address unlocker;
        bool relayedToL1;
    }

    mapping(uint256 => Vault) public vaults;

    constructor(address _nft, IHub _hub) {
        NFT = ERC721(_nft);
        L1Hub = _hub;
        OWNER = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == OWNER, "ONLY_OWNER");
        _;
    }

    function setHubAddress(address hubAddress) external onlyOwner {
        L1Hub = IHub(hubAddress);
    }

    function deposit(uint256 _tokenId, address _unlocker) external {
        require(vaults[_tokenId].owner == address(0), "VAULT_EXISTS");
        require(NFT.ownerOf(_tokenId) == msg.sender, "NOT_OWNER");
        vaults[_tokenId] = Vault(msg.sender, _unlocker, false);
        NFT.transferFrom(msg.sender, address(this), _tokenId);
    }

    function withdraw(uint256 _tokenId) external {
        Vault memory vault = vaults[_tokenId];
        require(vault.unlocker == msg.sender, "NOT_UNLOCKER");
        delete vaults[_tokenId];
        NFT.transferFrom(address(this), vault.owner, _tokenId);
    }

    function isLocked(uint256 _tokenId) public view returns (bool) {
        return vaults[_tokenId].unlocker != address(0);
    }

    function initiateBridgeLock(uint256 _tokenId, uint32 _minGasLimit) public {
        require(isLocked(_tokenId), "NOT_LOCKED");
        require(!vaults[_tokenId].relayedToL1, "ALREADY_RELAYED");
        require(NFT.ownerOf(_tokenId) == address(this), "NOT_OWNER");
        vaults[_tokenId].relayedToL1 = true;
        IL2CrossDomainMessenger(Predeploys.L2_CROSS_DOMAIN_MESSENGER).sendMessage({
            _target: address(L1Hub),
            _message: abi.encodeWithSelector(L1Hub.finalizeBridgedLock.selector, _tokenId),
            _minGasLimit: _minGasLimit
        });
    }

    function finalizeBridgeUnlock(uint256 _tokenId) external {
        Vault memory vault = vaults[_tokenId];
        require(msg.sender == Predeploys.L2_CROSS_DOMAIN_MESSENGER, "ONLY_MESSENGER");
        require(
            IL2CrossDomainMessenger(Predeploys.L2_CROSS_DOMAIN_MESSENGER).xDomainMessageSender() == address(L1Hub),
            "ONLY_L1_HUB"
        );
        require(vault.unlocker == address(L1Hub), "NOT_UNLOCKER");
        delete vaults[_tokenId];
        NFT.transferFrom(address(this), vault.owner, _tokenId);
    }
}
