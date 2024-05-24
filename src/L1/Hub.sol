// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../L2/IVault.sol";

interface ICrossDomainMessenger {
    function xDomainMessageSender() external view returns (address);
    function sendMessage(address _target, bytes calldata _message, uint32 _minGasLimit) external;
}

contract Hub {
    IVault immutable REMOTE_VAULT;
    ICrossDomainMessenger immutable MESSENGER;
    address immutable UNLOCKER;

    mapping(address => bool) public isLocked;
    mapping(address => bool) public isActioned;

    constructor(IVault _remoteVault, ICrossDomainMessenger _messenger, address _unlocker) {
        REMOTE_VAULT = _remoteVault;
        MESSENGER = _messenger;
        UNLOCKER = _unlocker;
    }

    function finalizeBridgeLock(address _owner) public {
        require(msg.sender == address(MESSENGER), "ONLY_MESSENGER");
        require(MESSENGER.xDomainMessageSender() == address(REMOTE_VAULT), "INVALID_SENDER");
        isLocked[_owner] = true;
        // call to other-L2 application
    }

    function initiateBridgeUnlock(address _owner, uint32 _minGasLimit) public {
        require(msg.sender == UNLOCKER, "ONLY_UNLOCKER"); // the UNLOCKER should be the other-L2 application
        require(isLocked[_owner], "NOT_LOCKED");
        ICrossDomainMessenger(MESSENGER).sendMessage({
            _target: address(REMOTE_VAULT),
            _message: abi.encodeWithSignature("finalizeBridgeUnlock(uint256)", _owner),
            _minGasLimit: _minGasLimit
        });
        isLocked[_owner] = false;
    }

    function initiateAction(address _owner, address _target, bytes calldata _data, uint32 _minGasLimit) public {
        require(!isActioned[_owner], "ALREADY_ACTIONED");
        ICrossDomainMessenger(MESSENGER).sendMessage({_target: _target, _message: _data, _minGasLimit: _minGasLimit});
        isActioned[_owner] = true;
    }
}
