// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {NFT} from "src/NFT.sol";

contract CounterTest is Test {
    NFT public nft;

    function setUp() public {
        uint256 maxSupply = 100;
        nft = new NFT(maxSupply);
    }

    function testMint() public {
        nft.mint(address(this));
        assertEq(nft.balanceOf(address(this)), 1);
    }

    function testMint100() public {
        for (uint256 i = 0; i < 100; i++) {
            nft.mint(address(this));
        }
        assertEq(nft.balanceOf(address(this)), 100);
    }

    function testMint101() public {
        for (uint256 i = 0; i < 100; i++) {
            nft.mint(address(this));
        }
        assertEq(nft.balanceOf(address(this)), 100);
        vm.expectRevert("MAX_SUPPLY");
        nft.mint(address(this));
    }
}
