// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {NFT} from "./../src/L2/NFT.sol";
import {NftVault} from "./../src/L2/Vault.sol";
import {Hub} from "./../src/L1/Hub.sol";
import {IVault} from "./../src/L2/IVault.sol";
import {ICrossDomainMessenger} from "./../src/L1/Hub.sol";

contract VaultTest is Test {
    NFT public nft;
    NftVault public vaults;
    Hub public hub;
    ICrossDomainMessenger public mockL1Messenger = ICrossDomainMessenger(makeAddr("L1CrossDomainMessenger"));
    ICrossDomainMessenger public mockL2Messenger =
        ICrossDomainMessenger(address(0x4200000000000000000000000000000000000007));

    struct Vault {
        address owner;
        address unlocker;
        bool relayedToL1;
    }

    function setUp() public {
        nft = new NFT(100);
        vaults = new NftVault(address(nft));
        hub = new Hub(IVault(address(vaults)), ICrossDomainMessenger(mockL1Messenger), msg.sender);
        vaults.setHubAddress(address(hub));
    }

    function testInitiateBridgeLock() public {
        address bob = makeAddr("bob");
        nft.mint(bob, "uri");
        vm.startPrank(bob);
        nft.approve(address(vaults), 0);
        vaults.deposit(0, address(hub));
        (address owner, address unlocker, bool isRelayedToL1) = vaults.vaults(0);
        assertEq(owner, bob);
        assertEq(unlocker, address(hub));
        assertEq(isRelayedToL1, false);

        vm.mockCall(address(mockL2Messenger), abi.encodeWithSelector(mockL2Messenger.sendMessage.selector), bytes(""));
        vaults.initiateBridgeLock(0, 1_000_000);
        (owner, unlocker, isRelayedToL1) = vaults.vaults(0);
        vm.stopPrank();
        assertEq(owner, bob);
        assertEq(unlocker, address(hub));
        assertEq(isRelayedToL1, true);
    }
}
