// SPDX-License-Identifier:MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";
import {MockFailedTransferFrom} from "../mocks/MockFailedTransferFrom.sol";
import {MockFailedTransfer} from "../mocks/MockFailedTransfer.sol";

contract DSCEngineTest is Test {
    DecentralizedStableCoin public dsc;
    DSCEngine public engine;
    HelperConfig public config;

    // Test configuration constants
    uint256 public constant AMOUNT_COLLATERAL = 50 ether;
    uint256 public constant AMOUNT_DSCMINTED = 25_000 ether;
    uint256 public constant STARTING_ERC20_BALANCE = 50 ether;
    uint256 public constant LIQUIDATOR_COLLATERAL = 40 ether;
    uint256 public constant LIQUIDATOR_DSC_MINT = 200 ether;

    // Protocol addresses
    address public ethUsdPriceFeed;
    address public btcUsdPriceFeed;
    address public weth;

    // Test user addresses
    address public user = makeAddr("perfect");
    address public liquidator = makeAddr("liquidator");

    function setUp() public {
        DeployDSC deployer = new DeployDSC();
        (dsc, engine, config) = deployer.run();
        (ethUsdPriceFeed, btcUsdPriceFeed, weth,,) = config.activeNetworkConfig();

        ERC20Mock(weth).mint(user, STARTING_ERC20_BALANCE);
    }

    // Constructor Test
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    // Test parameter validation during contract creation
    function testRevertsIfTokenLengthDoesntMatchPriceFeeds() public {
        tokenAddresses.push(weth);
        priceFeedAddresses.push(ethUsdPriceFeed);
        priceFeedAddresses.push(btcUsdPriceFeed);

        vm.expectRevert(DSCEngine.DSCEngine___tokenAddressesAndpriceFeedAddressesMustBeSameLength.selector);
        new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc));
    }

    function testConstructorSetsDscAddressCorrectly() public view {
        assertEq(address(dsc), engine.getAddressForDsc());
    }

    modifier addTokenAndPriceFeed() {
        tokenAddresses.push(weth);
        priceFeedAddresses.push(ethUsdPriceFeed);
        _;
    }

    function testConstructorRevertsIfDscAddressIsZero() public addTokenAndPriceFeed {
        vm.expectRevert(DSCEngine.DSCEngine__InvalidDscAddress.selector);
        new DSCEngine(tokenAddresses, priceFeedAddresses, address(0));
    }

    function testConstructorSetsCollateralTokensCorrectly() public addTokenAndPriceFeed {
        DSCEngine dsce = new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc));

        address expectedToken = tokenAddresses[0];
        address actualToken = dsce.getToken(0);

        assertEq(expectedToken, actualToken);
    }

    function testConstructorSetsPriceFeedsCorrectly() public addTokenAndPriceFeed {
        DSCEngine dsce = new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc));

        address expectedPriceFeed = priceFeedAddresses[0];
        address actualPriceFeed = dsce.getPriceFeed(tokenAddresses[0]);

        assertEq(expectedPriceFeed, actualPriceFeed);
    }

    // Price Test
    function testGetUsdValue() public view {
        uint256 ethAmount = 15e18;
        // 15e18 * 2000/Eth = 30000e18
        uint256 expectedUsd = 30000e18;
        uint256 actualUsd = engine.getUsdValue(weth, ethAmount);
        assertEq(expectedUsd, actualUsd);
    }

    function testGetTokenAmountFromUsd() public view {
        uint256 usdAmount = 100 ether;
        // 100 / 2000 = 0.05
        uint256 expectedWeth = 0.05 ether;
        uint256 actualWeth = engine.getTokenAmountFromUsd(weth, usdAmount);

        assertEq(expectedWeth, actualWeth);
    }

    // depostiCollateral Test
    uint256 public amountToMint = 100 ether;
    uint256 public amountCollateral = 10 ether;

    function testRevertIfCollateralZero() public {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);

        vm.expectRevert(DSCEngine.DSCEngine___NeedsMoreThanZero.selector);
        engine.depositCollateral(weth, 0);
        vm.stopPrank();
    }

    function testRevertsWithUnapprovedCollateral() public {
        ERC20Mock ranToken = new ERC20Mock();
        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSelector(DSCEngine.DSCEngine___NotAllowedToken.selector, address(ranToken)));
        engine.depositCollateral(address(ranToken), AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    modifier depositedCollateral() {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        engine.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
        _;
    }

    function testDepositCollateralUpdatesUserBalance() public depositedCollateral {
        uint256 actualAmount = engine.getAmountForUser(user, weth);
        assertEq(AMOUNT_COLLATERAL, actualAmount);
    }

    function testCanDepositCollateralAndGetAccountInfo() public depositedCollateral {
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = engine.getAccountInformation(user);

        uint256 expectedTotalDscMinted = 0;
        uint256 expectedDepositAmount = engine.getTokenAmountFromUsd(weth, collateralValueInUsd);

        assert(totalDscMinted == expectedTotalDscMinted);
        assert(AMOUNT_COLLATERAL == expectedDepositAmount);
    }

    function testDepositCollateralEmitsEvent() public {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);

        vm.expectEmit(true, true, false, true);
        emit DSCEngine.CollateralDeposited(user, weth, AMOUNT_COLLATERAL);
        engine.depositCollateral(weth, AMOUNT_COLLATERAL);

        vm.stopPrank();
    }

    function testRevertsIfTransferFromFails() public {
        address owner = msg.sender;
        vm.prank(owner);
        MockFailedTransferFrom mockCollateralToken = new MockFailedTransferFrom();
        tokenAddresses = [address(mockCollateralToken)];
        priceFeedAddresses = [ethUsdPriceFeed];

        vm.prank(owner);
        DSCEngine mockDsce = new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc));
        mockCollateralToken.mint(user, amountCollateral);
        vm.startPrank(user);
        ERC20Mock(address(mockCollateralToken)).approve(address(mockDsce), amountCollateral);
        // Act / Assert
        vm.expectRevert(DSCEngine.DSCEngine__TransferFailed.selector);
        mockDsce.depositCollateral(address(mockCollateralToken), amountCollateral);
        vm.stopPrank();
    }

    // mintDsc Test
    function testMintDscRevertsIfAmountZero() public {
        vm.startPrank(user);
        vm.expectRevert(DSCEngine.DSCEngine___NeedsMoreThanZero.selector);
        engine.mintDsc(0);
        vm.stopPrank();
    }

    function testMintDscUpdatesDscMinted() public depositedCollateral {
        vm.prank(user);
        engine.mintDsc(AMOUNT_DSCMINTED);

        uint256 expectedDscMinted = AMOUNT_DSCMINTED;
        uint256 actualDscMinted = engine.getDscMintedForUser(user);

        assertEq(actualDscMinted, expectedDscMinted);
    }

    function testMintDscEmitsEvent() public depositedCollateral {
        vm.startPrank(user);
        vm.expectEmit(true, true, false, true);
        emit DSCEngine.DscMinted(user, AMOUNT_DSCMINTED);
        engine.mintDsc(AMOUNT_DSCMINTED);
        vm.stopPrank();
    }

    function testRevertsIfMintedDscBreaksHealthFactor() public {
        (, int256 price,,,) = MockV3Aggregator(ethUsdPriceFeed).latestRoundData();
        amountToMint =
            (amountCollateral * (uint256(price) * engine.getAdditionalFeedPrecision())) / engine.getPrecision();
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(engine), amountCollateral);

        uint256 expectedHealthFactor =
            engine.calculateHealthFactor(amountToMint, engine.getUsdValue(weth, amountCollateral));
        vm.expectRevert(abi.encodeWithSelector(DSCEngine.DSCEngine__BreaksHealthFactor.selector, expectedHealthFactor));
        engine.depositCollateralAndMintDsc(weth, amountCollateral, amountToMint);
        vm.stopPrank();
    }

    // BurnDsc Test
    modifier depositAndMint() {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        engine.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, AMOUNT_DSCMINTED);
        vm.stopPrank();
        _;
    }

    function testBurnDscRevertsIfAmountZero() public depositAndMint {
        vm.startPrank(user);
        dsc.approve(address(engine), AMOUNT_DSCMINTED);
        vm.expectRevert(DSCEngine.DSCEngine___NeedsMoreThanZero.selector);
        engine.burnDsc(0);
        vm.stopPrank();
    }

    function testBurnDscUpdatesDscMinted() public depositAndMint {
        uint256 amountToBurn = 1 ether;
        vm.startPrank(user);
        dsc.approve(address(engine), amountToBurn);
        engine.burnDsc(amountToBurn);

        uint256 expectedAmountAfterToBurn = AMOUNT_DSCMINTED - amountToBurn;
        uint256 actualAmount = engine.getDscMintedForUser(user);

        assert(actualAmount == expectedAmountAfterToBurn);
    }

    // redeemCollateral Test
    function testRedeemCollateralRevertsIfAmountZero() public depositAndMint {
        vm.prank(user);
        vm.expectRevert(DSCEngine.DSCEngine___NeedsMoreThanZero.selector);
        engine.redeemCollateral(weth, 0);
    }

    function testRedeemCollateralUpdatesUserBalance() public depositAndMint {
        uint256 amountToRedeem = 1 ether;
        uint256 balanceBeforeRedeem = engine.getAmountForUser(user, weth);

        vm.prank(user);
        engine.redeemCollateral(weth, amountToRedeem);

        uint256 expectedBalanceAfteRedeem = balanceBeforeRedeem - amountToRedeem;
        uint256 actualBalance = engine.getAmountForUser(user, weth);

        assertEq(actualBalance, expectedBalanceAfteRedeem);
    }

    function testRedeemCollateralEmitsEvent() public depositAndMint {
        uint256 amountToRedeem = 1 ether;

        vm.expectEmit(true, true, false, true);
        vm.prank(user);
        emit DSCEngine.CollateralRedeemed(user, user, weth, amountToRedeem);
        engine.redeemCollateral(weth, amountToRedeem);
    }

    function testRedeemCollateralTransfersTokensToUser() public depositAndMint {
        uint256 amountToRedeem = 1 ether;
        uint256 startingTokenBalance = ERC20Mock(weth).balanceOf(user);

        vm.prank(user);
        engine.redeemCollateral(weth, amountToRedeem);

        uint256 expectedTokenBalance = startingTokenBalance + amountToRedeem;
        uint256 actualTokenBalance = ERC20Mock(weth).balanceOf(user);

        assertEq(actualTokenBalance, expectedTokenBalance);
    }

    function testRevertsIfTransferFails() public {
        address owner = msg.sender;
        vm.prank(owner);
        MockFailedTransfer mockDsc = new MockFailedTransfer();
        tokenAddresses = [address(mockDsc)];
        priceFeedAddresses = [ethUsdPriceFeed];

        vm.prank(owner);
        DSCEngine mockDsce = new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc));
        mockDsc.mint(user, amountCollateral);

        vm.prank(owner);
        mockDsc.transferOwnership(address(mockDsce));

        // Act
        vm.startPrank(user);
        ERC20Mock(address(mockDsc)).approve(address(mockDsce), amountCollateral);
        mockDsce.depositCollateral(address(mockDsc), amountCollateral);

        vm.expectRevert(DSCEngine.DSCEngine__TransferFailed.selector);
        mockDsce.redeemCollateral(address(mockDsc), amountCollateral);
        vm.stopPrank();
    }

    function testRedeemCollateralRevertsIfHealthFactorBroken() public depositAndMint {
        uint256 amountToRedeem = 30 ether;

        uint256 remainingCollateralValue = engine.getUsdValue(weth, AMOUNT_COLLATERAL - amountToRedeem);
        uint256 expectedHealthFactor = engine.calculateHealthFactor(AMOUNT_DSCMINTED, remainingCollateralValue);

        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSelector(DSCEngine.DSCEngine__BreaksHealthFactor.selector, expectedHealthFactor));
        engine.redeemCollateral(weth, amountToRedeem);
        vm.stopPrank();
    }

    function testRedeemCollateralRevertsIfInsufficientCollateral() public depositAndMint {
        uint256 amountToRedeem = AMOUNT_COLLATERAL + 1;

        vm.startPrank(user);
        vm.expectRevert(DSCEngine.DSCEngine__RedeemAmountExceedsBalance.selector);
        engine.redeemCollateral(weth, amountToRedeem);
        vm.stopPrank();
    }

    // liquidation Tests
    uint256 debtToCover = 10 ether;

    modifier depositAndMintForLiquidator() {
        vm.startPrank(liquidator);
        ERC20Mock(weth).mint(liquidator, LIQUIDATOR_COLLATERAL);
        ERC20Mock(weth).approve(address(engine), LIQUIDATOR_COLLATERAL);
        engine.depositCollateralAndMintDsc(weth, LIQUIDATOR_COLLATERAL, LIQUIDATOR_DSC_MINT);
        dsc.approve(address(engine), debtToCover); // Approve engine to burn DSC
        vm.stopPrank();
        _;
    }

    modifier setEthPriceLow() {
        int256 newEthPrice = 800e8; // $800 per ETH
        MockV3Aggregator(ethUsdPriceFeed).updateAnswer(newEthPrice);
        _;
    }

    function testLiquidateRevertsIfAmountZero() public depositAndMint depositAndMintForLiquidator {
        vm.startPrank(liquidator);
        vm.expectRevert(DSCEngine.DSCEngine___NeedsMoreThanZero.selector);
        engine.liquidate(weth, user, 0);
        vm.stopPrank();
    }

    function testLiquidateRevertsIfUserHealthFactorOk() public depositAndMint depositAndMintForLiquidator {
        vm.startPrank(liquidator);
        vm.expectRevert(DSCEngine.DSCEngine__HealthFactorOk.selector);
        engine.liquidate(weth, user, debtToCover);
    }

    function testLiquidateTransfersCollateralToLiquidator()
        public
        depositAndMint
        depositAndMintForLiquidator
        setEthPriceLow
    {
        uint256 liquidatorWethBefore = ERC20Mock(weth).balanceOf(liquidator);
        (uint256 userDscBefore,) = engine.getAccountInformation(user);
        uint256 startingHealthFactor = engine.calculateHealthFactor(
            userDscBefore, engine.getUsdValue(weth, engine.getAmountForUser(liquidator, weth))
        );

        uint256 expectedCollateral = engine.getTokenAmountFromUsd(weth, debtToCover);
        uint256 bonusCollateral = (expectedCollateral * engine.getLiquidationBonus()) / engine.getLiquidationPrecision();
        uint256 totalCollateral = expectedCollateral + bonusCollateral;

        vm.prank(liquidator);
        engine.liquidate(weth, user, debtToCover);

        console.log(
            "HealthFactor for liquidator: ",
            engine.calculateHealthFactor(
                engine.getDscMintedForUser(liquidator),
                engine.getUsdValue(weth, engine.getAmountForUser(liquidator, weth))
            )
        );

        uint256 liquidatorWethAfter = ERC20Mock(weth).balanceOf(liquidator);
        (uint256 userDscAfter,) = engine.getAccountInformation(user);
        uint256 healthFactorAfter =
            engine.calculateHealthFactor(userDscAfter, engine.getUsdValue(weth, engine.getAmountForUser(user, weth)));

        assertEq(
            liquidatorWethAfter,
            liquidatorWethBefore + totalCollateral,
            "Liquidator didn't receive correct collateral amount"
        );
        assertEq(userDscBefore - userDscAfter, debtToCover, "User's DSC debt not reduced correctly");
        assertGt(healthFactorAfter, startingHealthFactor, "Health factor did not improve");
    }

    function testLiquidateBurnsDsc() public depositAndMint depositAndMintForLiquidator setEthPriceLow {
        uint256 amountDscBeforeLiquidate = engine.getDscMintedForUser(liquidator);

        vm.prank(liquidator);
        engine.liquidate(weth, user, debtToCover);

        uint256 amountDscAfterLiquidate = engine.getDscMintedForUser(liquidator);

        assertEq(amountDscAfterLiquidate, amountDscBeforeLiquidate - debtToCover);
    }

    function testCantLiquidateGoodHealthFactor() public depositAndMint depositAndMintForLiquidator {
        vm.startPrank(liquidator);
        vm.expectRevert(DSCEngine.DSCEngine__HealthFactorOk.selector);
        engine.liquidate(weth, user, debtToCover);
        vm.stopPrank();
    }

    // Account Information Tests
    function testGetAccountInformationReturnsZeroForEmptyAccount() public view {
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = engine.getAccountInformation(user);

        assert(totalDscMinted == 0);
        assert(collateralValueInUsd == 0);
    }

    function testGetAccountCollateralValueCalculatesCorrectly() public depositAndMint {
        // amount collaterl = 50e18
        // 2000/Eth * 50e18 = 100000e18
        uint256 expectedCollateralValueInUsd = 100000e18;
        uint256 actualCallateralValueInUsd = engine.getAccountCollateralValue(user);

        assert(actualCallateralValueInUsd == expectedCollateralValueInUsd);
    }

    // Health Factor Test
    function testHealthFactorReturnsMaxIfNoDscMinted() public view {
        uint256 expectedHealthFactor = type(uint256).max;
        uint256 actualHealthFactor = engine.calculateHealthFactor(0, engine.getUsdValue(weth, AMOUNT_COLLATERAL));

        assert(actualHealthFactor == expectedHealthFactor);
    }

    function testHealthFactorCalculatesCorrectlyWithCollateralAndDsc() public depositAndMint {
        // amountCollateralValueInUsd = 100000e18 ;
        // 2000/Eth * 50e18 = 100000e18

        // expectedHealthFactor -> ( (amountCollateralValueInUsd * 50) / 100 ) / 250000
        // 25000 -> totalDscMinted --- 50 -> liquidationThreshold --- 100 -> liquidationPrecision

        uint256 expectedHealthFactor = 2e18;
        uint256 actualHealthFactor =
            engine.calculateHealthFactor(engine.getDscMintedForUser(user), engine.getUsdValue(weth, AMOUNT_COLLATERAL));

        assert(actualHealthFactor == expectedHealthFactor);
    }

    // View & Pure Function Tests
    function testGetCollateralTokenPriceFeed() public view {
        address priceFeed = engine.getPriceFeed(weth);
        assert(ethUsdPriceFeed == priceFeed);
    }

    function testGetCollateralTokens() public view {
        address token = engine.getToken(0);
        assert(token == weth);
    }

    function testGetLiquidationPercision() public view {
        uint256 liquidationPercision = engine.getLiquidationPrecision();
        assert(liquidationPercision == 100);
    }
}