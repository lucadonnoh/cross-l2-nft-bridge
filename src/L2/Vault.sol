// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "./../L1/IHub.sol";
import "./../libraries/Predeploys.sol";
import "./IL2CrossDomainMessenger.sol";

library AddressAliasHelper {
    uint160 constant offset = uint160(0x1111000000000000000000000000000000001111);

    /// @notice Utility function that converts the address in the L1 that submitted a tx to
    /// the inbox to the msg.sender viewed in the L2
    /// @param l1Address the address in the L1 that triggered the tx to L2
    /// @return l2Address L2 address as viewed in msg.sender
    function applyL1ToL2Alias(address l1Address) internal pure returns (address l2Address) {
        unchecked {
            l2Address = address(uint160(l1Address) + offset);
        }
    }

    /// @notice Utility function that converts the msg.sender viewed in the L2 to the
    /// address in the L1 that submitted a tx to the inbox
    /// @param l2Address L2 address as viewed in msg.sender
    /// @return l1Address the address in the L1 that triggered the tx to L2
    function undoL1ToL2Alias(address l2Address) internal pure returns (address l1Address) {
        unchecked {
            l1Address = address(uint160(l2Address) - offset);
        }
    }
}

contract NftVault {
    ERC721 public immutable NFT;
    IHub public L1Hub;
    address immutable OWNER;
    address[] public toBatchBridge;

    struct Vault {
        uint256 tokenId;
        bool relayedToL1;
        bool isLocked;
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

    function deposit(uint256 _tokenId) public {
        require(vaults[msg.sender].isLocked == false, "VAULT_EXISTS");
        require(NFT.ownerOf(_tokenId) == msg.sender, "NOT_OWNER");
        vaults[msg.sender] = Vault(_tokenId, false, true);
        NFT.transferFrom(msg.sender, address(this), _tokenId);
    }

    function depositAndEnqueue(uint256 _tokenId) external {
        deposit(_tokenId);
        toBatchBridge.push(msg.sender);
    }

    function isLocked(address _owner) public view returns (bool) {
        return vaults[_owner].isLocked;
    }

    function initiateBridgeLock(uint32 _minGasLimit) public {
        require(isLocked(msg.sender), "NOT_LOCKED");
        require(!vaults[msg.sender].relayedToL1, "ALREADY_RELAYED");
        vaults[msg.sender].relayedToL1 = true;
        IL2CrossDomainMessenger(Predeploys.L2_CROSS_DOMAIN_MESSENGER).sendMessage({
            _target: address(L1Hub),
            _message: abi.encodeWithSelector(L1Hub.finalizeBridgeLock.selector, msg.sender),
            _minGasLimit: _minGasLimit
        });
    }

    function initiateBatchBridgeLock(uint32 _minGasLimit) external {
        bytes32 hashedAddresses = keccak256(abi.encode(toBatchBridge));
        IL2CrossDomainMessenger(Predeploys.L2_CROSS_DOMAIN_MESSENGER).sendMessage({
            _target: address(L1Hub),
            _message: abi.encodeWithSelector(L1Hub.finalizeBatchBridgeLock.selector, hashedAddresses),
            _minGasLimit: _minGasLimit
        });
    }

    function finalizeBridgeUnlock(address _owner) external {
        require(isLocked(_owner), "NOT_LOCKED");
        Vault memory vault = vaults[_owner];
        require(msg.sender == address(Predeploys.L2_CROSS_DOMAIN_MESSENGER), "ONLY_MESSENGER");
        require(
            IL2CrossDomainMessenger(Predeploys.L2_CROSS_DOMAIN_MESSENGER).xDomainMessageSender()
                == AddressAliasHelper.applyL1ToL2Alias(address(L1Hub)),
            "ONLY_L1_HUB"
        );
        uint256 _tokenId = vault.tokenId;
        delete vaults[_owner];
        NFT.transferFrom(address(this), _owner, _tokenId);
    }

    function finalizeBatchBridgeUnlock() external {
        require(msg.sender == address(Predeploys.L2_CROSS_DOMAIN_MESSENGER), "ONLY_MESSENGER");
        require(
            IL2CrossDomainMessenger(Predeploys.L2_CROSS_DOMAIN_MESSENGER).xDomainMessageSender()
                == AddressAliasHelper.applyL1ToL2Alias(address(L1Hub)),
            "ONLY_L1_HUB"
        );
        for (uint256 i = 0; i < toBatchBridge.length; i++) {
            address _owner = toBatchBridge[i];
            require(isLocked(_owner), "NOT_LOCKED");
            Vault memory vault = vaults[_owner];
            uint256 _tokenId = vault.tokenId;
            delete vaults[_owner];
            NFT.transferFrom(address(this), _owner, _tokenId);
        }
        delete toBatchBridge;
    }
}
