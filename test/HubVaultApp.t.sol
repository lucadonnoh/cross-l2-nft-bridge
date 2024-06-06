// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {NFT} from "./../src/L2/NFT.sol";
import {NftVault} from "./../src/L2/Vault.sol";
import {Hub, ICrossDomainMessenger} from "./../src/L1/Hub.sol";
import {IL2CrossDomainMessenger} from "./../src/L2/IL2CrossDomainMessenger.sol";
import {IVault} from "./../src/L2/IVault.sol";
import {App} from "./../src/L2/App.sol";

contract HubVaultAppTest is Test {
    NFT public nft;
    NftVault public vaults;
    Hub public hub;
    App public app;
    ICrossDomainMessenger constant MOCK_VAULT_L1_MESSENGER = ICrossDomainMessenger(address(0xABC));
    ICrossDomainMessenger constant MOCK_APP_L1_MESSENGER = ICrossDomainMessenger(address(0xDEF));
    IL2CrossDomainMessenger constant MOCK_VAULT_L2_MESSENGER =
        IL2CrossDomainMessenger(address(0x4200000000000000000000000000000000000007));
    IL2CrossDomainMessenger constant MOCK_APP_L2_MESSENGER =
        IL2CrossDomainMessenger(address(0x4200000000000000000000000000000000000007));

    struct Vault {
        address owner;
        address unlocker;
        bool relayedToL1;
    }

    function setUp() public {
        nft = new NFT(100); // L2
        vaults = new NftVault(address(nft)); // L2
        hub = new Hub(IVault(address(vaults)), MOCK_VAULT_L1_MESSENGER, MOCK_APP_L1_MESSENGER); // L1
        vaults.setHubAddress(address(hub)); // L2
        app = new App(MOCK_APP_L2_MESSENGER); // L2
        app.setHubAddress(address(hub)); // L2
        hub.setAppAddress(address(app)); // L1
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
        vaults.deposit(0);
        (uint256 tokenId, bool isRelayedToL1, bool isLocked) = vaults.vaults(bob);
        assertEq(tokenId, 0);
        assertEq(isRelayedToL1, false);
        assertEq(isLocked, true);

        vm.mockCall(
            address(MOCK_VAULT_L2_MESSENGER),
            abi.encodeWithSelector(MOCK_VAULT_L2_MESSENGER.sendMessage.selector),
            bytes("")
        );
        vaults.initiateBridgeLock(1_000_000);
        (tokenId, isRelayedToL1, isLocked) = vaults.vaults(bob);
        vm.stopPrank();
        assertEq(tokenId, 0);
        assertEq(isRelayedToL1, true);
        assertEq(isLocked, true);
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
        vaults.deposit(0);
        vm.mockCall(
            address(MOCK_VAULT_L2_MESSENGER),
            abi.encodeWithSelector(MOCK_VAULT_L2_MESSENGER.sendMessage.selector),
            bytes("")
        );
        vaults.initiateBridgeLock(1_000_000);
        vm.expectRevert("ALREADY_RELAYED");
        vaults.initiateBridgeLock(1_000_000);
        vm.stopPrank();
    }

    function test_finalizeBridgeUnlock() public {
        address bob = makeAddr("bob");
        nft.mint(bob, "uri");
        vm.startPrank(bob);
        nft.approve(address(vaults), 0);
        vaults.deposit(0);
        vm.stopPrank();

        vm.mockCall(
            address(MOCK_VAULT_L2_MESSENGER),
            abi.encodeWithSelector(MOCK_VAULT_L2_MESSENGER.xDomainMessageSender.selector),
            abi.encode(address(hub))
        );

        vm.prank(address(MOCK_VAULT_L2_MESSENGER));
        vaults.finalizeBridgeUnlock(bob);

        (uint256 tokenId, bool isRelayedToL1, bool isLocked) = vaults.vaults(bob);
        assertEq(tokenId, 0);
        assertEq(isRelayedToL1, false);
        assertEq(isLocked, false);
        assertEq(nft.ownerOf(0), bob);
    }

    function test_finalizeBridgeUnlockNotLocked() public {
        address bob = makeAddr("bob");
        nft.mint(bob, "uri");
        vm.expectRevert("NOT_LOCKED");
        vaults.finalizeBridgeUnlock(bob);
    }

    function test_finalizeBridgeUnlockCallerNotMessenger() public {
        address bob = makeAddr("bob");
        nft.mint(bob, "uri");
        vm.startPrank(bob);
        nft.approve(address(vaults), 0);
        vaults.deposit(0);
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
        vaults.deposit(0);
        vm.stopPrank();
        vm.mockCall(
            address(MOCK_VAULT_L2_MESSENGER),
            abi.encodeWithSelector(MOCK_VAULT_L2_MESSENGER.xDomainMessageSender.selector),
            abi.encode(makeAddr("eve"))
        );
        vm.prank(address(MOCK_VAULT_L2_MESSENGER));
        vm.expectRevert("ONLY_L1_HUB");
        vaults.finalizeBridgeUnlock(bob);
    }

    function test_finalizeBridgedLock() public {
        address bob = makeAddr("bob");
        assertEq(hub.isLocked(bob), false);

        vm.mockCall(
            address(MOCK_VAULT_L1_MESSENGER),
            abi.encodeWithSelector(MOCK_VAULT_L1_MESSENGER.xDomainMessageSender.selector),
            abi.encode(address(vaults))
        );

        vm.prank(address(MOCK_VAULT_L1_MESSENGER));
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
            address(MOCK_VAULT_L1_MESSENGER),
            abi.encodeWithSelector(MOCK_VAULT_L1_MESSENGER.xDomainMessageSender.selector),
            abi.encode(makeAddr("eve"))
        );

        vm.expectRevert("INVALID_SENDER");
        vm.prank(address(MOCK_VAULT_L1_MESSENGER));
        hub.finalizeBridgeLock(bob);
    }

    function test_initiateBridgeUnlock() public {
        address bob = makeAddr("bob");
        nft.mint(bob, "uri");
        vm.mockCall(
            address(MOCK_VAULT_L1_MESSENGER),
            abi.encodeWithSelector(MOCK_VAULT_L1_MESSENGER.xDomainMessageSender.selector),
            abi.encode(address(vaults))
        );
        vm.prank(address(MOCK_VAULT_L1_MESSENGER));
        hub.finalizeBridgeLock(bob);

        vm.mockCall(
            address(MOCK_VAULT_L1_MESSENGER),
            abi.encodeWithSelector(MOCK_VAULT_L1_MESSENGER.sendMessage.selector),
            bytes("")
        );
        vm.mockCall(
            address(MOCK_APP_L1_MESSENGER),
            abi.encodeWithSelector(MOCK_APP_L1_MESSENGER.xDomainMessageSender.selector),
            abi.encode(address(app))
        );
        vm.prank(address(MOCK_APP_L1_MESSENGER));
        hub.initiateBridgeUnlock(bob, 1_000_000);
    }

    function test_initiateBridgeUnlockNotUnlocker() public {
        address bob = makeAddr("bob");
        nft.mint(bob, "uri");
        vm.mockCall(
            address(MOCK_VAULT_L1_MESSENGER),
            abi.encodeWithSelector(MOCK_VAULT_L1_MESSENGER.xDomainMessageSender.selector),
            abi.encode(address(vaults))
        );
        vm.prank(address(MOCK_VAULT_L1_MESSENGER));
        hub.finalizeBridgeLock(bob);

        vm.expectRevert("ONLY_UNLOCKER");
        vm.prank(makeAddr("eve"));
        hub.initiateBridgeUnlock(bob, 1_000_000);
    }

    function test_initiateBridgeUnlockNotLocked() public {
        address bob = makeAddr("bob");
        vm.mockCall(
            address(MOCK_APP_L1_MESSENGER),
            abi.encodeWithSelector(MOCK_APP_L1_MESSENGER.xDomainMessageSender.selector),
            abi.encode(address(app))
        );
        vm.expectRevert("NOT_LOCKED");
        vm.prank(address(MOCK_APP_L1_MESSENGER));
        hub.initiateBridgeUnlock(bob, 1_000_000);
    }

    function test_fullFlow() public {
        // 1. mint nft
        // 2. lock in vault
        // 3. initiate send bridge lock to hub
        // 4. finalize bridge lock
        // 5. initiate action on hub
        // 6. finalize action on app
        // 7. initiate bridge unlock on hub
        // 8. finalize bridge unlock on vault
        // 9. check that original owner has nft
        vm.pauseGasMetering();
        address bob = makeAddr("bob");
        nft.mint(bob, "uri"); // step 1 done
        vm.startPrank(bob);
        nft.approve(address(vaults), 0);
        vaults.deposit(0); // step 2 done
        assertNotEq(nft.ownerOf(0), bob);
        vm.mockCall(
            address(MOCK_VAULT_L2_MESSENGER),
            abi.encodeWithSelector(MOCK_VAULT_L2_MESSENGER.sendMessage.selector),
            bytes("")
        );
        vaults.initiateBridgeLock(1_000_000); // step 3 done
        vm.resumeGasMetering();
        vm.stopPrank();
        vm.mockCall(
            address(MOCK_VAULT_L1_MESSENGER),
            abi.encodeWithSelector(MOCK_VAULT_L1_MESSENGER.xDomainMessageSender.selector),
            abi.encode(address(vaults))
        );
        vm.prank(address(MOCK_VAULT_L1_MESSENGER));
        hub.finalizeBridgeLock(bob); // step 4 done
        vm.prank(bob);
        vm.mockCall(
            address(MOCK_APP_L1_MESSENGER),
            abi.encodeWithSelector(MOCK_APP_L1_MESSENGER.sendMessage.selector),
            bytes("")
        );
        hub.initiateAction(abi.encodeWithSelector(app.gatedHello.selector, bob), 1_000_000); // step 5 done
        vm.mockCall(
            address(MOCK_APP_L2_MESSENGER),
            abi.encodeWithSelector(MOCK_APP_L2_MESSENGER.sendMessage.selector),
            bytes("")
        );
        vm.mockCall(
            address(MOCK_APP_L2_MESSENGER),
            abi.encodeWithSelector(MOCK_APP_L2_MESSENGER.xDomainMessageSender.selector),
            abi.encode(address(hub))
        );
        vm.prank(address(MOCK_APP_L2_MESSENGER));
        vm.pauseGasMetering();
        app.gatedHello(bob); // step 6 done
        vm.mockCall(
            address(MOCK_APP_L1_MESSENGER),
            abi.encodeWithSelector(MOCK_APP_L1_MESSENGER.xDomainMessageSender.selector),
            abi.encode(address(app))
        );
        vm.mockCall(
            address(MOCK_VAULT_L1_MESSENGER),
            abi.encodeWithSelector(MOCK_VAULT_L1_MESSENGER.sendMessage.selector),
            bytes("")
        );
        vm.prank(address(MOCK_APP_L1_MESSENGER));
        vm.resumeGasMetering();
        hub.initiateBridgeUnlock(bob, 1_000_000); // step 7 done
        vm.mockCall(
            address(MOCK_VAULT_L2_MESSENGER),
            abi.encodeWithSelector(MOCK_VAULT_L2_MESSENGER.xDomainMessageSender.selector),
            abi.encode(address(hub))
        );
        vm.prank(address(MOCK_VAULT_L2_MESSENGER));
        vm.pauseGasMetering();
        vaults.finalizeBridgeUnlock(bob); // step 8 done
        assertEq(nft.ownerOf(0), bob); // step 9 done
        vm.resumeGasMetering();
    }

    function test_initiateBridgeUnlockXSenderIsNotApp() public {
        address bob = makeAddr("bob");
        nft.mint(bob, "uri");
        vm.mockCall(
            address(MOCK_VAULT_L1_MESSENGER),
            abi.encodeWithSelector(MOCK_VAULT_L1_MESSENGER.xDomainMessageSender.selector),
            abi.encode(address(vaults))
        );
        vm.prank(address(MOCK_VAULT_L1_MESSENGER));
        hub.finalizeBridgeLock(bob);

        vm.mockCall(
            address(MOCK_APP_L1_MESSENGER),
            abi.encodeWithSelector(MOCK_APP_L1_MESSENGER.xDomainMessageSender.selector),
            abi.encode(makeAddr("eve"))
        );
        vm.expectRevert("INVALID_SENDER");
        vm.prank(address(MOCK_APP_L1_MESSENGER));
        hub.initiateBridgeUnlock(bob, 1_000_000);
    }
}
