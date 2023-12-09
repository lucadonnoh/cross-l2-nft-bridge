// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {NFT} from "src/NFT.sol";

contract CounterTest is Test {
    NFT public nft;

    function setUp() public {
        nft = new NFT();
    }

    function testMint() public {
        nft.mint(address(this));
        assertEq(nft.balanceOf(address(this)), 1);
    }
}
