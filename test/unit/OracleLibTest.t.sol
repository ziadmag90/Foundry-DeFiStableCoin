// SPDX-License-Identifier:MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {OracleLib, AggregatorV3Interface} from "../../src/Libraries/OracleLib.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";

contract OracleLibTest is Test {
    using OracleLib for AggregatorV3Interface;

    MockV3Aggregator public priceFeed;

    uint8 public constant DECIMALS = 8;
    int256 public constant ETH_USD_PRICE = 2000e8;

    function setUp() public {
        priceFeed = new MockV3Aggregator(DECIMALS, ETH_USD_PRICE);
    }

    function testPriceWithinTimeout() public view {
        uint256 expectedPrice = 2000e8;
        uint256 actualPrice = AggregatorV3Interface(address(priceFeed)).getPrice();

        console.log("expectedPrice = ", expectedPrice);
        console.log("actualPrice = ", actualPrice);

        assertEq(actualPrice, expectedPrice);
    }

    function testPriceStaleReverts() public {
        // update block.timestamp to exceeds Timeout
        vm.warp(block.timestamp + 50 hours);

        vm.expectRevert(OracleLib.OracleLib__StalePrice.selector);
        AggregatorV3Interface(address(priceFeed)).stalePriceChecks();
    }

    function testGetTimeout() public pure {
        uint256 expectedTimeout = 3 hours;
        uint256 actualTimeout = OracleLib.getTimeout();

        assertEq(actualTimeout, expectedTimeout);
    }
}
