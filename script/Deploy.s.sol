// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/L1/Hub.sol";
import "../src/L2/App.sol";
import "../src/L2/Vault.sol";

contract Deploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        NftVault vault = new NftVault(0xc3E1A72Ee9e2Cc7F5dcd332807dceA95bf7C16D4);

        vm.stopBroadcast();
    }
}
