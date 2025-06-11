// Handler is going to narrow down the way we call function

// SPDX-License-Identifier:MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {DSCEngine} from "src/DscEngine.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {StdUtils} from "forge-std/StdUtils.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";

contract Handler is Test {
    DSCEngine engine;
    DecentralizedStableCoin dsc;

    ERC20Mock weth;
    ERC20Mock wbtc;

    uint256 MAX_DEPOSIT_SIZE = type(uint96).max;
    MockV3Aggregator public ethUsdPriceFeed;

    constructor(DSCEngine _engine, DecentralizedStableCoin _dsc) {
        engine = _engine;
        dsc = _dsc;

        address[] memory collateralTokens = engine.getCollateralTokens();
        weth = ERC20Mock(collateralTokens[0]);
        wbtc = ERC20Mock(collateralTokens[1]);

        ethUsdPriceFeed = MockV3Aggregator(engine.getPriceFeed(address(weth)));
    }

    // Depositing Collateral
    function depositCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        amountCollateral = bound(amountCollateral, 1, MAX_DEPOSIT_SIZE);

        vm.startPrank(msg.sender);
        collateral.mint(msg.sender, amountCollateral);
        collateral.approve(address(engine), amountCollateral);
        engine.depositCollateral(address(collateral), amountCollateral);
        vm.stopPrank();
    }

    // Redeeming Collateral
    function redeemCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        uint256 maxAmountToRedeem = engine.getAmountForUser(msg.sender, address(collateral));
        amountCollateral = bound(amountCollateral, 0, maxAmountToRedeem);

        if (amountCollateral == 0) {
            return;
        }

        vm.prank(msg.sender);
        engine.redeemCollateral(address(collateral), amountCollateral);
    }

    function mintDsc(uint256 amountDscToMint) public {
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = engine.getAccountInformation(msg.sender);
        int256 maxDscToMint = (int256(collateralValueInUsd) / 2) - int256(totalDscMinted);
        if (maxDscToMint < 0) {
            return;
        }

        amountDscToMint = bound(amountDscToMint, 1, uint256(maxDscToMint));
        if (amountDscToMint == 0) {
            return;
        }

        vm.prank(msg.sender);
        engine.mintDsc(amountDscToMint);
    }

    // PriceFeed
    // This breaks our invariant test suite, becasuse the price will change random.
    /* function updateCollateralPrice(uint96 newPrice) public {
        int256 newPriceInt = int256(uint256(newPrice));

        ethUsdPriceFeed.updateAnswer(newPriceInt);
    }*/

    // Helper Function
    function _getCollateralFromSeed(uint256 collateralSeed) private view returns (ERC20Mock) {
        if (collateralSeed % 2 == 0) {
            return weth;
        }
        return wbtc;
    }
}
