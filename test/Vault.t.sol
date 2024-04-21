// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {NFT} from "src/L2/NFT.sol";
import {NftVault} from "src/L2/Vault.sol";
import {IHub} from "./../src/L1/IHub.sol";

contract VaultTest is Test {
    NFT public nft;
    NftVault public vaults;

    function setUp() public {
        nft = new NFT(100);
        vaults = new NftVault(address(nft), IHub(address(0))); //TODO: add real hub
    }

    function test_flow() public {
        address bob = makeAddr("bob");
        address eve = makeAddr("eve");
        nft.mint(bob, "uri");
        vm.startPrank(bob);
        nft.approve(address(vaults), 0);
        vaults.deposit(0, eve);
        vm.stopPrank();
        assertEq(nft.ownerOf(0), address(vaults));

        (address owner, address unlocker,) = vaults.vaults(0);
        assertEq(owner, bob);
        assertEq(unlocker, eve);

        vm.prank(eve);
        vaults.withdraw(0);
        assertEq(nft.ownerOf(0), bob);
    }

    function test_depositNotOwner() public {
        address bob = makeAddr("bob");
        address eve = makeAddr("eve");
        nft.mint(bob, "uri");
        vm.startPrank(bob);
        nft.approve(address(vaults), 0);
        vm.stopPrank();
        vm.expectRevert("NOT_OWNER");
        vaults.deposit(0, eve);
    }

    function test_depositAlreadyDeposited() public {
        address bob = makeAddr("bob");
        address eve = makeAddr("eve");
        nft.mint(bob, "uri");
        vm.startPrank(bob);
        nft.approve(address(vaults), 0);
        vaults.deposit(0, eve);
        vm.stopPrank();
        vm.expectRevert("VAULT_EXISTS");
        vaults.deposit(0, eve);
    }

    function test_notUnlockerCannotWithdraw() public {
        address bob = makeAddr("bob");
        address eve = makeAddr("eve");
        nft.mint(bob, "uri");
        vm.startPrank(bob);
        nft.approve(address(vaults), 0);
        vaults.deposit(0, eve);
        vm.stopPrank();
        vm.prank(bob);
        vm.expectRevert("NOT_UNLOCKER");
        vaults.withdraw(0);
    }
}
