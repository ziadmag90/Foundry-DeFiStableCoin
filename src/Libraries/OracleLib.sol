//SPDX-License-Identifier:MIT
pragma solidity ^0.8.28;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/**
 * @title OracleLib
 *     @author ziad magdy
 *     @notice This library is used to check the chainlink oracle for stale data.
 */
library OracleLib {
    error OracleLib__StalePrice();

    uint256 private constant TIMEOUT = 3 hours;

    function stalePriceChecks(AggregatorV3Interface priceFeed)
        public
        view
        returns (uint80, int256, uint256, uint256, uint80)
    {
        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) =
            priceFeed.latestRoundData();
        uint256 secondSince = block.timestamp - updatedAt;

        if (secondSince > TIMEOUT) {
            revert OracleLib__StalePrice();
        }

        return (roundId, answer, startedAt, updatedAt, answeredInRound);
    }

    // Getter Function
    function getPrice(AggregatorV3Interface chainlinkFeed) external view returns (uint256) {
        (, int256 price,,,) = stalePriceChecks(chainlinkFeed);
        return uint256(price);
    }

    function getTimeout() external pure returns (uint256) {
        return TIMEOUT;
    }
}
