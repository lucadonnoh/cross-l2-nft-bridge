// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./../L1/IHub.sol";
import "./IL2CrossDomainMessenger.sol";

contract App {
    IHub public L1Hub;
    IL2CrossDomainMessenger immutable L2_MESSENGER;
    address constant ALIASED_L1_MESSENGER = 0xac910c1E8B61aA9D141bCD317dde7849F7A054f6; // Aliased Mode Sepolia L1CrossDomainMessenger

    mapping(address => bool) public hasHelloed;
    bytes32 public hashedAddresses;

    constructor(IL2CrossDomainMessenger _messenger) {
        L2_MESSENGER = _messenger;
    }

    function setHubAddress(address _l1Hub) external {
        require(address(L1Hub) == address(0), "ALREADY_SET");
        L1Hub = IHub(_l1Hub);
    }

    function gatedHello(address _owner) public {
        require(msg.sender == address(L2_MESSENGER), "ONLY_MESSENGER");
        require(L2_MESSENGER.xDomainMessageSender() == address(L1Hub), "INVALID_SENDER");
        _hello(_owner);
        L2_MESSENGER.sendMessage({
            _target: address(L1Hub),
            _message: abi.encodeWithSignature("initiateBridgeUnlock(address,uint32)", _owner, 1_000_000),
            _minGasLimit: 5_000_000
        });
    }

    function saveBatch(bytes32 _hashedAddresses) public {
        require(msg.sender == address(L2_MESSENGER), "ONLY_MESSENGER");
        require(L2_MESSENGER.xDomainMessageSender() == address(L1Hub), "INVALID_SENDER");
        hashedAddresses = _hashedAddresses;
    }

    function batchGatedHello(address[] memory _owners) public {
        require(hashedAddresses != 0x0, "NO_HASH");
        bytes32 _hashedAddresses = keccak256(abi.encode(_owners));
        require(hashedAddresses == _hashedAddresses, "INVALID_HASH");
        for (uint256 i = 0; i < _owners.length; i++) {
            _hello(_owners[i]);
        }
        L2_MESSENGER.sendMessage({
            _target: address(L1Hub),
            _message: abi.encodeWithSignature("initiateBatchBridgeUnlock(bytes32,uint32)", _hashedAddresses, 1_000_000),
            _minGasLimit: 5_000_000
        });
        hashedAddresses = 0x0;
    }

    function _hello(address _owner) public {
        hasHelloed[_owner] = true;
    }
}
