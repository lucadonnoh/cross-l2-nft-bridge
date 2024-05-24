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

    mapping(uint256 => bool) public isLocked;
    mapping(uint256 => bool) public isActioned;

    constructor(IVault _remoteVault, ICrossDomainMessenger _messenger, address _unlocker) {
        REMOTE_VAULT = _remoteVault;
        MESSENGER = _messenger;
        UNLOCKER = _unlocker;
    }

    function finalizeBridgeLock(uint256 tokenId) public {
        require(msg.sender == address(MESSENGER), "ONLY_MESSENGER");
        require(MESSENGER.xDomainMessageSender() == address(REMOTE_VAULT), "INVALID_SENDER");
        isLocked[tokenId] = true;
        // call to other-L2 application
    }

    function initiateBridgeUnlock(uint256 tokenId, uint32 _minGasLimit) public {
        require(msg.sender == UNLOCKER, "ONLY_UNLOCKER"); // the UNLOCKER should be the other-L2 application
        require(isLocked[tokenId], "NOT_LOCKED");
        ICrossDomainMessenger(MESSENGER).sendMessage({
            _target: address(REMOTE_VAULT),
            _message: abi.encodeWithSignature("finalizeBridgeUnlock(uint256)", tokenId),
            _minGasLimit: _minGasLimit
        });
        isLocked[tokenId] = false;
    }

    function initiateAction(uint256 _tokenId, address _target, bytes calldata _data, uint32 _minGasLimit) public {
        require(!isActioned[_tokenId], "ALREADY_ACTIONED");
        require(msg.sender == address(MESSENGER), "ONLY_MESSENGER");
        ICrossDomainMessenger(MESSENGER).sendMessage({_target: _target, _message: _data, _minGasLimit: _minGasLimit});
        isActioned[_tokenId] = true;
    }
}
