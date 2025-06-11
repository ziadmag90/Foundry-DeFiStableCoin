// SPDX-License-Identifier:MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";

contract DSCTest is Test {
    DecentralizedStableCoin public dsc;

    uint256 private constant DSC_MINTED = 100 ether;
    uint256 private constant AMOUNT_TO_BURN = 40 ether;

    address public owner = address(this);
    address public Anonymous = address(1);

    function setUp() public {
        dsc = new DecentralizedStableCoin();
    }

    // Constructor Tests
    function testConstructorSetsCorrectNameAndSymbol() public view {
        string memory expectedName = "DecentralizedStableCoin";
        string memory actualName = dsc.name();

        string memory expectedSymbol = "DSC";
        string memory actualSymbol = dsc.symbol();

        assert(keccak256(abi.encodePacked(expectedName)) == keccak256(abi.encodePacked(actualName)));
        assert(keccak256(abi.encodePacked(expectedSymbol)) == keccak256(abi.encodePacked(actualSymbol)));
    }

    function testConstructorSetsOwner() public view {
        assertEq(dsc.owner(), owner);
    }

    // Minting Functionality Test
    function testMintRevertsIfNotOwner() public {
        // Use the raw error selector instead of contract-based access
        bytes4 errorSelector = bytes4(keccak256("OwnableUnauthorizedAccount(address)"));

        vm.prank(Anonymous);
        vm.expectRevert(abi.encodeWithSelector(errorSelector, Anonymous));
        dsc.mint(Anonymous, DSC_MINTED);
    }

    function testMintRevertsIfZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(DecentralizedStableCoin.DecentralizedStableCoin__NotZeroAddress.selector);
        dsc.mint(address(0), DSC_MINTED);
    }

    function testMintRevertsIfZeroAmoun() public {
        vm.prank(owner);
        vm.expectRevert(DecentralizedStableCoin.DecentralizedStableCoin__MustBeMoreThanZero.selector);
        dsc.mint(Anonymous, 0);
    }

    function testMintIncreasesBalance() public {
        vm.prank(owner);
        dsc.mint(Anonymous, DSC_MINTED);

        uint256 expectedBalance = DSC_MINTED;
        uint256 actualBalance = dsc.balanceOf(Anonymous);

        assertEq(actualBalance, expectedBalance);
    }

    // Burning Functionality Test
    function testBurnRevertsIfNotOwner() public {
        bytes4 errorSelector = bytes4(keccak256("OwnableUnauthorizedAccount(address)"));

        vm.prank(Anonymous);
        vm.expectRevert(abi.encodeWithSelector(errorSelector, Anonymous));
        dsc.burn(AMOUNT_TO_BURN);
    }

    function testBurnRevertsIfZeroAmount() public {
        vm.prank(owner);
        vm.expectRevert(DecentralizedStableCoin.DecentralizedStableCoin__MustBeMoreThanZero.selector);
        dsc.burn(0);
    }

    function testBurnRevertsIfInsufficientBalance() public {
        vm.startPrank(owner);
        vm.expectRevert(DecentralizedStableCoin.DecentralizedStableCoin__BurnAmountExceedsBalance.selector);
        dsc.burn(AMOUNT_TO_BURN);
    }

    function testBurnDecreasesBalance() public {
        vm.startPrank(owner);
        dsc.mint(owner, DSC_MINTED);
        dsc.burn(AMOUNT_TO_BURN);

        uint256 expectedBalance = DSC_MINTED - AMOUNT_TO_BURN;
        uint256 actualBalance = dsc.balanceOf(owner);

        assertEq(actualBalance, expectedBalance);
    }
}
