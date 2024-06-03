// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {NFT} from "src/L2/NFT.sol";
import {NftVault} from "src/L2/Vault.sol";

contract VaultTest is Test {
    NFT public nft;
    NftVault public vaults;

    function setUp() public {
        nft = new NFT(100);
        vaults = new NftVault(address(nft)); //TODO: add real hub
    }

    function test_depositNotOwner() public {
        address bob = makeAddr("bob");
        nft.mint(bob, "uri");
        vm.startPrank(bob);
        nft.approve(address(vaults), 0);
        vm.stopPrank();
        vm.expectRevert("NOT_OWNER");
        vaults.deposit(0);
    }

    function test_depositAlreadyDeposited() public {
        address bob = makeAddr("bob");
        nft.mint(bob, "uri");
        vm.startPrank(bob);
        nft.approve(address(vaults), 0);
        vaults.deposit(0);
        vm.expectRevert("VAULT_EXISTS");
        vaults.deposit(0);
        vm.stopPrank();
    }

    function test_isLocked() public {
        address bob = makeAddr("bob");
        nft.mint(bob, "uri");
        assertEq(vaults.isLocked(bob), false);
        vm.startPrank(bob);
        nft.approve(address(vaults), 0);
        vaults.deposit(0);
        vm.stopPrank();
        assertEq(vaults.isLocked(bob), true);
    }

    function test_isLockedWhenJustTransferred() public {
        address bob = makeAddr("bob");
        nft.mint(bob, "uri");
        assertEq(vaults.isLocked(bob), false);
        vm.prank(bob);
        nft.transferFrom(bob, address(vaults), 0);
        assertEq(vaults.isLocked(bob), false);
    }
}
