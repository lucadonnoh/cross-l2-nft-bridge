// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./../L1/IHub.sol";
import "./IL2CrossDomainMessenger.sol";

contract App {
    IHub public L1Hub;
    IL2CrossDomainMessenger immutable MESSENGER;

    mapping(address => bool) public hasHelloed;

    constructor(IL2CrossDomainMessenger _messenger) {
        MESSENGER = _messenger;
    }

    function setHubAddress(address _l1Hub) external {
        require(address(L1Hub) == address(0), "ALREADY_SET");
        L1Hub = IHub(_l1Hub);
    }

    function gatedHello(address _owner) public {
        require(msg.sender == address(MESSENGER), "ONLY_MESSENGER");
        require(MESSENGER.xDomainMessageSender() == address(L1Hub), "INVALID_SENDER");
        _hello(_owner);
        MESSENGER.sendMessage({
            _target: address(L1Hub),
            _message: abi.encodeWithSignature("initiateBridgeUnlock(address,uint256)", _owner, 5_000_000),
            _minGasLimit: 5_000_000
        });
    }

    function _hello(address _owner) public {
        hasHelloed[_owner] = true;
    }
}
