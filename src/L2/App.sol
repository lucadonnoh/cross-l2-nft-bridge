// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./../L1/IHub.sol";

contract App {
    IHub public L1Hub;

    mapping(address => bool) public hasHelloed;

    function gatedHello() public {}
}
