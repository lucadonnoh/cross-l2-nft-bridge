// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "./../L1/IHub.sol";
import "./../libraries/Predeploys.sol";
import "./IL2CrossDomainMessenger.sol";

contract NftVault {
    ERC721 public immutable NFT;
    IHub public L1Hub;
    address immutable OWNER;
    address[] public toBatchBridge;

    struct Vault {
        uint256 tokenId;
        address unlocker;
        bool relayedToL1;
    }

    mapping(address => Vault) public vaults;

    constructor(address _nft) {
        NFT = ERC721(_nft);
        OWNER = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == OWNER, "ONLY_OWNER");
        _;
    }

    function setHubAddress(address hubAddress) external onlyOwner {
        require(address(L1Hub) == address(0), "ALREADY_SET");
        L1Hub = IHub(hubAddress);
    }

    function deposit(uint256 _tokenId, address _unlocker) public {
        require(vaults[msg.sender].unlocker == address(0), "VAULT_EXISTS");
        require(NFT.ownerOf(_tokenId) == msg.sender, "NOT_OWNER");
        require(_unlocker != address(0), "INVALID_UNLOCKER");
        vaults[msg.sender] = Vault(_tokenId, _unlocker, false);
        NFT.transferFrom(msg.sender, address(this), _tokenId);
    }

    function depositAndEnqueue(uint256 _tokenId, address _unlocker) external {
        deposit(_tokenId, _unlocker);
        toBatchBridge.push(msg.sender);
    }

    function withdraw(address _owner) external {
        Vault memory vault = vaults[_owner];
        require(vault.unlocker == msg.sender, "NOT_UNLOCKER");
        require(!vault.relayedToL1, "RELAYED_TO_L1");
        uint256 _tokenId = vault.tokenId;
        delete vaults[_owner];
        NFT.transferFrom(address(this), _owner, _tokenId);
    }

    function isLocked(address _owner) public view returns (bool) {
        return vaults[_owner].unlocker != address(0);
    }

    function initiateBridgeLock(uint32 _minGasLimit) public {
        require(isLocked(msg.sender), "NOT_LOCKED");
        require(!vaults[msg.sender].relayedToL1, "ALREADY_RELAYED");
        require(vaults[msg.sender].unlocker == address(L1Hub), "HUB_NOT_UNLOCKER");
        vaults[msg.sender].relayedToL1 = true;
        IL2CrossDomainMessenger(Predeploys.L2_CROSS_DOMAIN_MESSENGER).sendMessage({
            _target: address(L1Hub),
            _message: abi.encodeWithSelector(L1Hub.finalizeBridgeLock.selector, msg.sender),
            _minGasLimit: _minGasLimit
        });
    }

    function finalizeBridgeUnlock(address _owner) external {
        require(isLocked(_owner), "NOT_LOCKED");
        Vault memory vault = vaults[_owner];
        require(vault.unlocker == address(L1Hub), "NOT_UNLOCKER");
        require(msg.sender == Predeploys.L2_CROSS_DOMAIN_MESSENGER, "ONLY_MESSENGER");
        require(
            IL2CrossDomainMessenger(Predeploys.L2_CROSS_DOMAIN_MESSENGER).xDomainMessageSender() == address(L1Hub),
            "ONLY_L1_HUB"
        );
        uint256 _tokenId = vault.tokenId;
        delete vaults[_owner];
        NFT.transferFrom(address(this), _owner, _tokenId);
    }
}
