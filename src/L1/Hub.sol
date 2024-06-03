// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../L2/IVault.sol";

interface ICrossDomainMessenger {
    function xDomainMessageSender() external view returns (address);
    function sendMessage(address _target, bytes calldata _message, uint32 _minGasLimit) external;
}

contract Hub {
    IVault immutable REMOTE_VAULT;
    ICrossDomainMessenger immutable VAULT_MESSENGER;
    ICrossDomainMessenger immutable APP_MESSENGER;
    address public app;

    mapping(address => bool) public isLocked;
    mapping(address => bool) public isActioned;

    mapping(bytes32 => bool) public isBatchLocked;
    mapping(bytes32 => bool) public isBatchActioned;

    constructor(IVault _remoteVault, ICrossDomainMessenger _vaultMessenger, ICrossDomainMessenger _appMessenger) {
        REMOTE_VAULT = _remoteVault;
        VAULT_MESSENGER = _vaultMessenger;
        APP_MESSENGER = _appMessenger;
    }

    function setAppAddress(address _app) external {
        require(app == address(0), "ALREADY_SET");
        app = _app;
    }

    function finalizeBridgeLock(address _owner) external {
        require(msg.sender == address(VAULT_MESSENGER), "ONLY_MESSENGER");
        require(VAULT_MESSENGER.xDomainMessageSender() == address(REMOTE_VAULT), "INVALID_SENDER");
        isLocked[_owner] = true;
    }

    function finalizeBatchBridgeLock(bytes32 hashedAddresses) external {
        require(msg.sender == address(VAULT_MESSENGER), "ONLY_MESSENGER");
        require(VAULT_MESSENGER.xDomainMessageSender() == address(REMOTE_VAULT), "INVALID_SENDER");
        isBatchLocked[hashedAddresses] = true;
    }

    function initiateBridgeUnlock(address _owner, uint32 _minGasLimit) external {
        require(msg.sender == address(APP_MESSENGER), "ONLY_UNLOCKER");
        require(APP_MESSENGER.xDomainMessageSender() == app, "INVALID_SENDER");
        require(isLocked[_owner], "NOT_LOCKED");
        VAULT_MESSENGER.sendMessage({
            _target: address(REMOTE_VAULT),
            _message: abi.encodeWithSignature("finalizeBridgeUnlock(uint256)", _owner),
            _minGasLimit: _minGasLimit
        });
        isLocked[_owner] = false;
    }

    function initiateBatchBridgeUnlock(bytes32 _hashedAddresses, uint32 _minGasLimit) external {
        require(msg.sender == address(APP_MESSENGER), "ONLY_UNLOCKER");
        require(APP_MESSENGER.xDomainMessageSender() == app, "INVALID_SENDER");
        require(isBatchLocked[_hashedAddresses], "NOT_LOCKED");
        VAULT_MESSENGER.sendMessage({
            _target: address(REMOTE_VAULT),
            _message: abi.encodeWithSignature("finalizeBatchBridgeUnlock()"),
            _minGasLimit: _minGasLimit
        });
        isBatchLocked[_hashedAddresses] = false;
    }

    function initiateAction(bytes calldata _data, uint32 _minGasLimit) public {
        require(!isActioned[msg.sender], "ALREADY_ACTIONED");
        require(isLocked[msg.sender], "NOT_LOCKED");
        APP_MESSENGER.sendMessage({_target: app, _message: _data, _minGasLimit: _minGasLimit});
        isActioned[msg.sender] = true;
    }

    function initiateBatchAction(bytes32 _hashedAddresses, bytes calldata _data, uint32 _minGasLimit) external {
        require(!isBatchActioned[_hashedAddresses], "ALREADY_ACTIONED");
        require(isBatchLocked[_hashedAddresses], "NOT_LOCKED");
        APP_MESSENGER.sendMessage({_target: app, _message: _data, _minGasLimit: _minGasLimit});
        isBatchActioned[_hashedAddresses] = true;
    }
}
