// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {NFT} from "./../src/L2/NFT.sol";
import {NftVault} from "./../src/L2/Vault.sol";
import {Hub} from "./../src/L1/Hub.sol";
import {IVault} from "./../src/L2/IVault.sol";
import {ICrossDomainMessenger} from "./../src/L1/Hub.sol";

contract HubVaultTest is Test {
    NFT public nft;
    NftVault public vaults;
    Hub public hub;
    ICrossDomainMessenger constant MOCK_L1_MESSENGER = ICrossDomainMessenger(address(0xABC));
    ICrossDomainMessenger constant MOCK_L2_MESSENGER =
        ICrossDomainMessenger(address(0x4200000000000000000000000000000000000007));

    struct Vault {
        address owner;
        address unlocker;
        bool relayedToL1;
    }

    function setUp() public {
        nft = new NFT(100);
        vaults = new NftVault(address(nft));
        hub = new Hub(IVault(address(vaults)), ICrossDomainMessenger(MOCK_L1_MESSENGER), makeAddr("unlocker"));
        vaults.setHubAddress(address(hub));
    }

    function test_setHubAddressAlreadySet() public {
        vm.expectRevert("ALREADY_SET");
        vaults.setHubAddress(address(hub));
    }

    function test_setHubNotOwner() public {
        vm.expectRevert("ONLY_OWNER");
        vm.prank(makeAddr("eve"));
        vaults.setHubAddress(address(hub));
    }

    function test_initiateBridgeLock() public {
        address bob = makeAddr("bob");
        nft.mint(bob, "uri");
        vm.startPrank(bob);
        nft.approve(address(vaults), 0);
        vaults.deposit(0, address(hub));
        (uint256 tokenId, address unlocker, bool isRelayedToL1) = vaults.vaults(bob);
        assertEq(tokenId, 0);
        assertEq(unlocker, address(hub));
        assertEq(isRelayedToL1, false);

        vm.mockCall(
            address(MOCK_L2_MESSENGER), abi.encodeWithSelector(MOCK_L2_MESSENGER.sendMessage.selector), bytes("")
        );
        vaults.initiateBridgeLock(1_000_000);
        (tokenId, unlocker, isRelayedToL1) = vaults.vaults(bob);
        vm.stopPrank();
        assertEq(tokenId, 0);
        assertEq(unlocker, address(hub));
        assertEq(isRelayedToL1, true);
    }

    function test_initiateBridgeLockWithoutDeposit() public {
        address bob = makeAddr("bob");
        nft.mint(bob, "uri");
        vm.expectRevert("NOT_LOCKED");
        vaults.initiateBridgeLock(1_000_000);
    }

    function test_initiateBridgeLockAlreadyRelayed() public {
        address bob = makeAddr("bob");
        nft.mint(bob, "uri");
        vm.startPrank(bob);
        nft.approve(address(vaults), 0);
        vaults.deposit(0, address(hub));
        vm.mockCall(
            address(MOCK_L2_MESSENGER), abi.encodeWithSelector(MOCK_L2_MESSENGER.sendMessage.selector), bytes("")
        );
        vaults.initiateBridgeLock(1_000_000);
        vm.expectRevert("ALREADY_RELAYED");
        vaults.initiateBridgeLock(1_000_000);
        vm.stopPrank();
    }

    function test_initiateBridgeLockHubNotUnlocker() public {
        address bob = makeAddr("bob");
        nft.mint(bob, "uri");
        vm.startPrank(bob);
        nft.approve(address(vaults), 0);
        vaults.deposit(0, makeAddr("eve"));
        vm.expectRevert("HUB_NOT_UNLOCKER");
        vaults.initiateBridgeLock(1_000_000);
        vm.stopPrank();
    }

    function test_cannotWithdrawIfRelayed() public {
        address bob = makeAddr("bob");
        nft.mint(bob, "uri");
        vm.startPrank(bob);
        nft.approve(address(vaults), 0);
        vaults.deposit(0, address(hub));
        vm.mockCall(
            address(MOCK_L2_MESSENGER),
            abi.encodeWithSelector(MOCK_L2_MESSENGER.xDomainMessageSender.selector),
            abi.encode(address(hub))
        );
        vaults.initiateBridgeLock(1_000_000);
        vm.stopPrank();
        vm.expectRevert("RELAYED_TO_L1");
        vm.prank(address(hub));
        vaults.withdraw(bob);
    }

    function test_finalizeBridgeUnlock() public {
        address bob = makeAddr("bob");
        nft.mint(bob, "uri");
        vm.startPrank(bob);
        nft.approve(address(vaults), 0);
        vaults.deposit(0, address(hub));
        vm.stopPrank();

        vm.mockCall(
            address(MOCK_L2_MESSENGER),
            abi.encodeWithSelector(MOCK_L2_MESSENGER.xDomainMessageSender.selector),
            abi.encode(address(hub))
        );

        vm.prank(address(MOCK_L2_MESSENGER));
        vaults.finalizeBridgeUnlock(bob);

        (uint256 tokenId, address unlocker, bool isRelayedToL1) = vaults.vaults(bob);
        assertEq(tokenId, 0);
        assertEq(unlocker, address(0));
        assertEq(isRelayedToL1, false);
        assertEq(nft.ownerOf(0), bob);
    }

    function test_finalizeBridgeUnlockNotLocked() public {
        address bob = makeAddr("bob");
        nft.mint(bob, "uri");
        vm.expectRevert("NOT_LOCKED");
        vaults.finalizeBridgeUnlock(bob);
    }

    function test_finalizeBridgeUnlockHubNotUnlocker() public {
        address bob = makeAddr("bob");
        nft.mint(bob, "uri");
        vm.startPrank(bob);
        nft.approve(address(vaults), 0);
        vaults.deposit(0, makeAddr("eve"));
        vm.stopPrank();
        vm.expectRevert("NOT_UNLOCKER");
        vaults.finalizeBridgeUnlock(bob);
    }

    function test_finalizeBridgeUnlockCallerNotMessenger() public {
        address bob = makeAddr("bob");
        nft.mint(bob, "uri");
        vm.startPrank(bob);
        nft.approve(address(vaults), 0);
        vaults.deposit(0, address(hub));
        vm.stopPrank();
        vm.prank(makeAddr("eve"));
        vm.expectRevert("ONLY_MESSENGER");
        vaults.finalizeBridgeUnlock(bob);
    }

    function test_finalizeBridgeUnlockXDomainMessageSenderNotHub() public {
        address bob = makeAddr("bob");
        nft.mint(bob, "uri");
        vm.startPrank(bob);
        nft.approve(address(vaults), 0);
        vaults.deposit(0, address(hub));
        vm.stopPrank();
        vm.mockCall(
            address(MOCK_L2_MESSENGER),
            abi.encodeWithSelector(MOCK_L2_MESSENGER.xDomainMessageSender.selector),
            abi.encode(makeAddr("eve"))
        );
        vm.prank(address(MOCK_L2_MESSENGER));
        vm.expectRevert("ONLY_L1_HUB");
        vaults.finalizeBridgeUnlock(bob);
    }

    function test_finalizeBridgedLock() public {
        address bob = makeAddr("bob");
        assertEq(hub.isLocked(bob), false);

        vm.mockCall(
            address(MOCK_L1_MESSENGER),
            abi.encodeWithSelector(MOCK_L1_MESSENGER.xDomainMessageSender.selector),
            abi.encode(address(vaults))
        );

        vm.prank(address(MOCK_L1_MESSENGER));
        hub.finalizeBridgeLock(bob);

        assertEq(hub.isLocked(bob), true);
    }

    function test_finalizeBridgedLockCallerNotMessenger() public {
        address bob = makeAddr("bob");
        vm.expectRevert("ONLY_MESSENGER");
        hub.finalizeBridgeLock(bob);
    }

    function test_finalizeBridgeLockSenderNotVault() public {
        address bob = makeAddr("bob");
        vm.mockCall(
            address(MOCK_L1_MESSENGER),
            abi.encodeWithSelector(MOCK_L1_MESSENGER.xDomainMessageSender.selector),
            abi.encode(makeAddr("eve"))
        );

        vm.expectRevert("INVALID_SENDER");
        vm.prank(address(MOCK_L1_MESSENGER));
        hub.finalizeBridgeLock(bob);
    }

    function test_initiateBridgeUnlock() public {
        address bob = makeAddr("bob");
        nft.mint(bob, "uri");
        vm.mockCall(
            address(MOCK_L1_MESSENGER),
            abi.encodeWithSelector(MOCK_L1_MESSENGER.xDomainMessageSender.selector),
            abi.encode(address(vaults))
        );
        vm.prank(address(MOCK_L1_MESSENGER));
        hub.finalizeBridgeLock(bob);

        vm.mockCall(
            address(MOCK_L1_MESSENGER), abi.encodeWithSelector(MOCK_L1_MESSENGER.sendMessage.selector), bytes("")
        );
        vm.prank(makeAddr("unlocker"));
        hub.initiateBridgeUnlock(bob, 1_000_000);
    }

    function test_initiateBridgeUnlockNotUnlocker() public {
        address bob = makeAddr("bob");
        nft.mint(bob, "uri");
        vm.mockCall(
            address(MOCK_L1_MESSENGER),
            abi.encodeWithSelector(MOCK_L1_MESSENGER.xDomainMessageSender.selector),
            abi.encode(address(vaults))
        );
        vm.prank(address(MOCK_L1_MESSENGER));
        hub.finalizeBridgeLock(bob);

        vm.expectRevert("ONLY_UNLOCKER");
        vm.prank(makeAddr("eve"));
        hub.initiateBridgeUnlock(bob, 1_000_000);
    }

    function test_initiateBridgeUnlockNotLocked() public {
        address bob = makeAddr("bob");
        vm.expectRevert("NOT_LOCKED");
        vm.prank(makeAddr("unlocker"));
        hub.initiateBridgeUnlock(bob, 1_000_000);
    }
}
