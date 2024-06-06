// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {NFT} from "src/L2/NFT.sol";

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
                nft.mint(address(this), "uri");
                return;
            }
            nft.mint(address(this), "uri");
        }
        assertEq(nft.totalSupply(), amount);
        assertEq(nft.balanceOf(address(this)), amount);
    }

    function test_mint100() public {
        for (uint256 i = 0; i < 100; i++) {
            nft.mint(address(this), "uri");
        }
        assertEq(nft.totalSupply(), 100);
        assertEq(nft.balanceOf(address(this)), 100);
    }

    function test_mint101() public {
        for (uint256 i = 0; i < 100; i++) {
            nft.mint(address(this), "uri");
        }
        vm.expectRevert("MAX_SUPPLY");
        nft.mint(address(this), "uri");
    }

    function testFuzz_mintNotDeployer(address _a) public {
        vm.assume(_a != address(this));
        address notDeployer = _a;
        vm.prank(notDeployer);
        bytes4 selector = bytes4(keccak256("AccessControlUnauthorizedAccount(address,bytes32)"));
        vm.expectRevert(abi.encodeWithSelector(selector, notDeployer, keccak256("MINTER_ROLE")));
        nft.mint(address(this), "uri");
    }

    function test_addMinter() public {
        address newMinter = makeAddr("newMinter");
        nft.addMinter(newMinter);
        vm.prank(newMinter);
        nft.mint(address(this), "uri");
        assertEq(nft.totalSupply(), 1);
        assertEq(nft.balanceOf(address(this)), 1);
    }

    function testFuzz_notDeployerCannotAddMinter(address _a) public {
        vm.assume(_a != address(this));
        address notDeployer = _a;
        vm.prank(notDeployer);
        bytes4 selector = bytes4(keccak256("AccessControlUnauthorizedAccount(address,bytes32)"));
        vm.expectRevert(abi.encodeWithSelector(selector, notDeployer, 0x00));
        nft.addMinter(notDeployer);
    }

    function testFuzz_tokenUri(string memory _uri) public {
        nft.mint(address(this), _uri);
        assertEq(nft.tokenURI(0), _uri);
    }

    function test_supportsInterface() public {
        bytes4 interfaceId = bytes4(keccak256("supportsInterface(bytes4)"));
        assertEq(nft.supportsInterface(interfaceId), true);
    }
}

// Testing private functions

contract NftHarness is NFT {
    constructor() NFT(100) {}

    function exposed_increaseBalance(address account, uint128 amount) public {
        _increaseBalance(account, amount);
    }

    function exposed_update(address to, uint256 tokenId, address auth) public returns (address) {
        return _update(to, tokenId, auth);
    }
}

contract NftHarnessTest is Test {
    NftHarness public nft;

    function setUp() public {
        nft = new NftHarness();
    }

    function test_increaseBalance() public {
        nft.exposed_increaseBalance(address(this), 0);
        assertEq(nft.balanceOf(address(this)), 0);
    }

    function test_update(address _to) public {
        vm.assume(_to != address(0));
        nft.mint(address(this), "uri");
        assertEq(nft.ownerOf(0), address(this));
        nft.exposed_update(_to, 0, address(this));
        assertEq(nft.ownerOf(0), _to);
    }
}
