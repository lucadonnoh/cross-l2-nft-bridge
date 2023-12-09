// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {NFT} from "src/NFT.sol";

contract NftTest is Test {
    NFT public nft;
    uint256 maxSupply;

    function setUp() public {
        maxSupply = 100;
        nft = new NFT(maxSupply);
    }

    function testFuzz_mint(uint256 amount) public {
        for (uint256 i = 0; i < amount; i++) {
            if (nft.totalSupply() >= maxSupply) {
                vm.expectRevert("MAX_SUPPLY");
                nft.mint(address(this));
                return;
            }
            nft.mint(address(this));
        }
        assertEq(nft.totalSupply(), amount);
        assertEq(nft.balanceOf(address(this)), amount);
    }

    function test_mint100() public {
        for (uint256 i = 0; i < 100; i++) {
            nft.mint(address(this));
        }
        assertEq(nft.totalSupply(), 100);
        assertEq(nft.balanceOf(address(this)), 100);
    }

    function test_mint101() public {
        for (uint256 i = 0; i < 100; i++) {
            nft.mint(address(this));
        }
        vm.expectRevert("MAX_SUPPLY");
        nft.mint(address(this));
    }

    function test_mintNotOwner() public {
        address notOwner = makeAddr("notOwner");
        vm.prank(notOwner);
        bytes4 selector = bytes4(keccak256("OwnableUnauthorizedAccount(address)"));
        vm.expectRevert(abi.encodeWithSelector(selector, notOwner));
        nft.mint(address(this));
    }
}
