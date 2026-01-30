// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {TestUtils} from "./TestUtils.sol";
import {IUniswapV2Router02} from "../src/v2-periphery/interfaces/IUniswapV2Router02.sol";
import {IUniswapV2Factory} from "../src/v2-core/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Pair} from "../src/v2-core/interfaces/IUniswapV2Pair.sol";
import {WETH9} from "../src/mocks/WETH9.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";

/**
 * @title UniswapV2 Scenario Tests
 * @notice Scenario tests to understand UniswapV2 core concepts using ETH-USDC pair
 * 
 * Scenarios:
 * 1. Initial Liquidity Provision - Create new pool (First LP)
 * 2. Add Liquidity to Existing Pool - Add LP to existing pool (Second LP)
 * 3. Swap (Exact Input) - Exchange exact amount of ETH to USDC
 * 4. Swap (Exact Output) - Exchange ETH to get exact amount of USDC
 */
contract UniswapV2ScenariosTest is TestUtils {
    IUniswapV2Factory public factory;
    IUniswapV2Router02 public router;
    WETH9 public weth;
    MockERC20 public usdc;

    // Initial liquidity provider (pool creator)
    address public initialLP = makeAddr("initialLP");
    // Additional liquidity provider
    address public secondLP = makeAddr("secondLP");
    // Swap user
    address public trader = makeAddr("trader");

    // Initial pool ratio: 1 ETH = 2000 USDC (realistic price assumption)
    uint256 constant INITIAL_ETH_LIQUIDITY = 10 ether;
    uint256 constant INITIAL_USDC_LIQUIDITY = 20_000 * 1e6; // USDC has 6 decimals
    
    // Decimals
    uint256 constant ETH_DECIMALS = 18;
    uint256 constant USDC_DECIMALS = 6;
    uint256 constant LP_DECIMALS = 18; // LP token also has 18 decimals

    function setUp() public {
        // Deploy WETH
        weth = new WETH9();
        
        // Deploy USDC Mock (6 decimals)
        usdc = new MockERC20("USD Coin", "USDC", 6);
        
        // Deploy Factory
        bytes memory factoryBytecode = abi.encodePacked(
            vm.getCode("out/UniswapV2Factory.sol/UniswapV2Factory.json"),
            abi.encode(address(this))
        );
        address factoryAddr;
        assembly {
            factoryAddr := create(0, add(factoryBytecode, 0x20), mload(factoryBytecode))
        }
        require(factoryAddr != address(0), "Factory deploy failed");
        factory = IUniswapV2Factory(factoryAddr);
        
        // Deploy Router
        bytes memory routerBytecode = abi.encodePacked(
            vm.getCode("out/UniswapV2Router02.sol/UniswapV2Router02.json"),
            abi.encode(address(factory), address(weth))
        );
        address routerAddr;
        assembly {
            routerAddr := create(0, add(routerBytecode, 0x20), mload(routerBytecode))
        }
        require(routerAddr != address(0), "Router deploy failed");
        router = IUniswapV2Router02(routerAddr);

        // Distribute funds to users
        // Initial LP: 100 ETH + 200,000 USDC
        vm.deal(initialLP, 100 ether);
        usdc.mint(initialLP, 200_000 * 1e6);
        
        // Second LP: 50 ETH + 100,000 USDC  
        vm.deal(secondLP, 50 ether);
        usdc.mint(secondLP, 100_000 * 1e6);
        
        // Trader: 10 ETH (for swaps)
        vm.deal(trader, 10 ether);
    }

    /**
     * @notice Scenario 1: Initial Liquidity Provision (Pool Creation)
     * 
     * Situation: Alice(initialLP) creates a new ETH-USDC pool and provides first liquidity.
     * 
     * Key Concepts:
     * - First LP determines the initial price of the pool (10 ETH : 20,000 USDC = 1:2000 ratio)
     * - LP tokens = sqrt(ETH * USDC) - MINIMUM_LIQUIDITY(1000)
     * - MINIMUM_LIQUIDITY is permanently locked to prevent pool from being fully drained
     */
    function test_Scenario1_InitialLiquidityProvision() public {
        console.log("");
        console.log("============================================================");
        console.log("   SCENARIO 1: Initial Liquidity Provision (Pool Creation)");
        console.log("============================================================");
        console.log("");
        
        // --- Situation description ---
        console.log("[SITUATION]");
        console.log("  Alice wants to create a new ETH-USDC liquidity pool.");
        console.log("  She will set the initial price: 1 ETH = 2,000 USDC");
        console.log("");
        
        // --- Alice's initial balance ---
        console.log("[BEFORE] Alice's Wallet:");
        console.log("  ETH Balance:  ", fromUnit(initialLP.balance, ETH_DECIMALS, 4), "ETH");
        console.log("  USDC Balance: ", fromUnit(usdc.balanceOf(initialLP), USDC_DECIMALS, 2), "USDC");
        console.log("");
        
        // --- Execute action ---
        console.log("[ACTION] Alice adds liquidity to create new pool:");
        console.log("  Depositing: ", fromUnit(INITIAL_ETH_LIQUIDITY, ETH_DECIMALS, 4), "ETH");
        console.log("  Depositing: ", fromUnit(INITIAL_USDC_LIQUIDITY, USDC_DECIMALS, 2), "USDC");
        console.log("");
        
        vm.startPrank(initialLP);
        usdc.approve(address(router), type(uint256).max);
        
        (uint256 amountUSDC, uint256 amountETH, uint256 liquidity) = router.addLiquidityETH{value: INITIAL_ETH_LIQUIDITY}(
            address(usdc),
            INITIAL_USDC_LIQUIDITY,
            0,
            0,
            initialLP,
            block.timestamp + 1
        );
        vm.stopPrank();
        
        // --- Result ---
        address pair = factory.getPair(address(weth), address(usdc));
        
        console.log("[RESULT] Pool Created!");
        console.log("  Pair Address: ", pair);
        console.log("  ETH Added:    ", fromUnit(amountETH, ETH_DECIMALS, 4), "ETH");
        console.log("  USDC Added:   ", fromUnit(amountUSDC, USDC_DECIMALS, 2), "USDC");
        console.log("");
        
        console.log("[RESULT] LP Tokens Minted:");
        uint256 totalSupply = IUniswapV2Pair(pair).totalSupply();
        console.log("  Alice received:      ", fromUnit(liquidity, LP_DECIMALS, 6), "LP");
        console.log("  MINIMUM_LIQUIDITY:   ", fromUnit(1000, LP_DECIMALS, 6), "LP (permanently locked)");
        console.log("  Total LP Supply:     ", fromUnit(totalSupply, LP_DECIMALS, 6), "LP");
        console.log("");
        
        // --- Alice's final balance ---
        console.log("[AFTER] Alice's Wallet:");
        console.log("  ETH Balance:  ", fromUnit(initialLP.balance, ETH_DECIMALS, 4), "ETH");
        console.log("  USDC Balance: ", fromUnit(usdc.balanceOf(initialLP), USDC_DECIMALS, 2), "USDC");
        console.log("  LP Balance:   ", fromUnit(IUniswapV2Pair(pair).balanceOf(initialLP), LP_DECIMALS, 6), "LP");
        console.log("");
        
        // --- Pool state ---
        (uint112 reserveETH, uint112 reserveUSDC) = _getReserves(pair);
        console.log("[POOL STATE]");
        console.log("  ETH Reserve:  ", fromUnit(reserveETH, ETH_DECIMALS, 4), "ETH");
        console.log("  USDC Reserve: ", fromUnit(reserveUSDC, USDC_DECIMALS, 2), "USDC");
        console.log("  Spot Price:   1 ETH = ", fromUnit(uint256(reserveUSDC) * 1e18 / reserveETH, USDC_DECIMALS, 2), "USDC");
        console.log("");
        
        // --- Key concept explanation ---
        console.log("[KEY CONCEPT]");
        console.log("  LP Token Formula: sqrt(ETH * USDC) - MINIMUM_LIQUIDITY");
        console.log("  sqrt(10 * 20000) = sqrt(200000) ~= 447.21");
        console.log("  Alice's LP = 447.21 - 0.000001 (min liquidity) ~= 447.21 LP tokens");
        console.log("");
        
        // Assertions
        assertFalse(pair == address(0));
        assertGt(liquidity, 0);
    }

    /**
     * @notice Scenario 2: Add Liquidity to Existing Pool
     * 
     * Situation: Bob(secondLP) adds liquidity to an existing pool.
     * 
     * Key Concepts:
     * - Must supply according to existing pool ratio (if ratio doesn't match, only partial amount is used)
     * - LP tokens = min(ETH/reserveETH, USDC/reserveUSDC) * totalSupply
     * - LP issued is proportional to contribution ratio
     */
    function test_Scenario2_AddLiquidityToExistingPool() public {
        console.log("");
        console.log("============================================================");
        console.log("   SCENARIO 2: Add Liquidity to Existing Pool");
        console.log("============================================================");
        console.log("");
        
        // Create initial pool (Alice)
        _createInitialPool();
        address pair = factory.getPair(address(weth), address(usdc));
        
        // --- Current situation ---
        console.log("[SITUATION]");
        console.log("  Alice has already created the ETH-USDC pool.");
        console.log("  Bob wants to add liquidity to earn trading fees.");
        console.log("");
        
        // --- Current pool state ---
        (uint112 reserveETH_before, uint112 reserveUSDC_before) = _getReserves(pair);
        uint256 totalSupply_before = IUniswapV2Pair(pair).totalSupply();
        
        console.log("[BEFORE] Pool State:");
        console.log("  ETH Reserve:    ", fromUnit(reserveETH_before, ETH_DECIMALS, 4), "ETH");
        console.log("  USDC Reserve:   ", fromUnit(reserveUSDC_before, USDC_DECIMALS, 2), "USDC");
        console.log("  Total LP Supply:", fromUnit(totalSupply_before, LP_DECIMALS, 6), "LP");
        console.log("  Current Price:  1 ETH = ", fromUnit(uint256(reserveUSDC_before) * 1e18 / reserveETH_before, USDC_DECIMALS, 2), "USDC");
        console.log("");
        
        // --- Bob's initial balance ---
        console.log("[BEFORE] Bob's Wallet:");
        console.log("  ETH Balance:  ", fromUnit(secondLP.balance, ETH_DECIMALS, 4), "ETH");
        console.log("  USDC Balance: ", fromUnit(usdc.balanceOf(secondLP), USDC_DECIMALS, 2), "USDC");
        console.log("  LP Balance:   ", fromUnit(IUniswapV2Pair(pair).balanceOf(secondLP), LP_DECIMALS, 6), "LP");
        console.log("");
        
        // --- Action ---
        uint256 addETH = 5 ether;
        uint256 addUSDC = 10_000 * 1e6;
        
        console.log("[ACTION] Bob adds liquidity:");
        console.log("  Depositing: ", fromUnit(addETH, ETH_DECIMALS, 4), "ETH");
        console.log("  Depositing: ", fromUnit(addUSDC, USDC_DECIMALS, 2), "USDC");
        console.log("  (Ratio matches pool: 1 ETH = 2000 USDC)");
        console.log("");
        
        vm.startPrank(secondLP);
        usdc.approve(address(router), type(uint256).max);
        
        (uint256 amountUSDC, uint256 amountETH, uint256 liquidity) = router.addLiquidityETH{value: addETH}(
            address(usdc),
            addUSDC,
            0,
            0,
            secondLP,
            block.timestamp + 1
        );
        vm.stopPrank();
        
        // --- Result ---
        console.log("[RESULT] Liquidity Added:");
        console.log("  ETH Used:     ", fromUnit(amountETH, ETH_DECIMALS, 4), "ETH");
        console.log("  USDC Used:    ", fromUnit(amountUSDC, USDC_DECIMALS, 2), "USDC");
        console.log("  LP Received:  ", fromUnit(liquidity, LP_DECIMALS, 6), "LP");
        console.log("");
        
        // --- Bob's final balance ---
        console.log("[AFTER] Bob's Wallet:");
        console.log("  ETH Balance:  ", fromUnit(secondLP.balance, ETH_DECIMALS, 4), "ETH");
        console.log("  USDC Balance: ", fromUnit(usdc.balanceOf(secondLP), USDC_DECIMALS, 2), "USDC");
        console.log("  LP Balance:   ", fromUnit(IUniswapV2Pair(pair).balanceOf(secondLP), LP_DECIMALS, 6), "LP");
        console.log("");
        
        // --- Final pool state ---
        (uint112 reserveETH_after, uint112 reserveUSDC_after) = _getReserves(pair);
        uint256 totalSupply_after = IUniswapV2Pair(pair).totalSupply();
        uint256 bobShare = IUniswapV2Pair(pair).balanceOf(secondLP) * 100 / totalSupply_after;
        uint256 aliceShare = IUniswapV2Pair(pair).balanceOf(initialLP) * 100 / totalSupply_after;
        
        console.log("[AFTER] Pool State:");
        console.log("  ETH Reserve:    ", fromUnit(reserveETH_after, ETH_DECIMALS, 4), "ETH");
        console.log("  USDC Reserve:   ", fromUnit(reserveUSDC_after, USDC_DECIMALS, 2), "USDC");
        console.log("  Total LP Supply:", fromUnit(totalSupply_after, LP_DECIMALS, 6), "LP");
        console.log("  Price (unchanged): 1 ETH = ", fromUnit(uint256(reserveUSDC_after) * 1e18 / reserveETH_after, USDC_DECIMALS, 2), "USDC");
        console.log("");
        
        console.log("[OWNERSHIP]");
        console.log("  Alice's Share: ", aliceShare, "%");
        console.log("  Bob's Share:   ", bobShare, "%");
        console.log("");
        
        console.log("[KEY CONCEPT]");
        console.log("  Bob added 50% of Alice's liquidity (5 ETH vs 10 ETH)");
        console.log("  Bob receives 50% of Alice's LP tokens");
        console.log("  Pool ownership: Alice ~67%, Bob ~33%");
        console.log("");
        
        // Assertions
        assertGt(liquidity, 0);
        assertEq(amountETH, addETH);
    }

    /**
     * @notice Scenario 3: Swap - Exact Input
     * 
     * Situation: Charlie(trader) exchanges exactly 0.1 ETH for USDC.
     * 
     * Key Concepts:
     * - swapExactETHForTokens: Input amount is fixed, output amount is determined by AMM
     * - Output calculated using x * y = k formula after 0.3% fee deduction
     * - Price Impact: Larger trades result in worse prices
     */
    function test_Scenario3_SwapExactETHForUSDC() public {
        console.log("");
        console.log("============================================================");
        console.log("   SCENARIO 3: Swap - Exact Input (0.1 ETH -> USDC)");
        console.log("============================================================");
        console.log("");
        
        _createInitialPool();
        address pair = factory.getPair(address(weth), address(usdc));
        
        // --- Current situation ---
        console.log("[SITUATION]");
        console.log("  Charlie wants to exchange ETH for USDC.");
        console.log("  He has exactly 0.1 ETH and wants to know how much USDC he'll get.");
        console.log("  (Exact Input Swap: input is fixed, output varies)");
        console.log("");
        
        // --- Pool state ---
        (uint112 reserveETH_before, uint112 reserveUSDC_before) = _getReserves(pair);
        uint256 spotPrice = uint256(reserveUSDC_before) * 1e18 / reserveETH_before;
        
        console.log("[BEFORE] Pool State:");
        console.log("  ETH Reserve:  ", fromUnit(reserveETH_before, ETH_DECIMALS, 4), "ETH");
        console.log("  USDC Reserve: ", fromUnit(reserveUSDC_before, USDC_DECIMALS, 2), "USDC");
        console.log("  Spot Price:   1 ETH = ", fromUnit(spotPrice, USDC_DECIMALS, 2), "USDC");
        console.log("");
        
        // --- Charlie's initial balance ---
        console.log("[BEFORE] Charlie's Wallet:");
        console.log("  ETH Balance:  ", fromUnit(trader.balance, ETH_DECIMALS, 4), "ETH");
        console.log("  USDC Balance: ", fromUnit(usdc.balanceOf(trader), USDC_DECIMALS, 2), "USDC");
        console.log("");
        
        // --- Calculate expected output ---
        uint256 swapAmountETH = 0.1 ether;
        address[] memory path = new address[](2);
        path[0] = address(weth);
        path[1] = address(usdc);
        
        uint256[] memory expectedAmounts = router.getAmountsOut(swapAmountETH, path);
        uint256 expectedUSDC = expectedAmounts[1];
        uint256 theoreticalUSDC = swapAmountETH * spotPrice / 1e18; // Theoretical price (without fees)
        
        console.log("[PREVIEW] Expected Swap Result:");
        console.log("  Input:                  ", fromUnit(swapAmountETH, ETH_DECIMALS, 4), "ETH");
        console.log("  Theoretical Output:     ", fromUnit(theoreticalUSDC, USDC_DECIMALS, 2), "USDC (at spot price)");
        console.log("  Actual Expected Output: ", fromUnit(expectedUSDC, USDC_DECIMALS, 2), "USDC (after 0.3% fee + slippage)");
        console.log("");
        
        // --- Action ---
        console.log("[ACTION] Charlie swaps 0.1 ETH for USDC...");
        console.log("");
        
        vm.startPrank(trader);
        uint256 ethBefore = trader.balance;
        uint256 usdcBefore = usdc.balanceOf(trader);
        
        router.swapExactETHForTokens{value: swapAmountETH}(
            1,  // amountOutMin
            path,
            trader,
            block.timestamp + 1
        );
        vm.stopPrank();
        
        uint256 ethSpent = ethBefore - trader.balance;
        uint256 usdcReceived = usdc.balanceOf(trader) - usdcBefore;
        
        // --- Result ---
        console.log("[RESULT] Swap Completed:");
        console.log("  ETH Spent:      ", fromUnit(ethSpent, ETH_DECIMALS, 4), "ETH");
        console.log("  USDC Received:  ", fromUnit(usdcReceived, USDC_DECIMALS, 2), "USDC");
        uint256 effectivePrice = usdcReceived * 1e18 / ethSpent;
        console.log("  Effective Rate: 1 ETH = ", fromUnit(effectivePrice, USDC_DECIMALS, 2), "USDC");
        console.log("");
        
        // --- Charlie's final balance ---
        _logWallet("Charlie", trader);
        
        // --- Final pool state and analysis ---
        _logSwapAnalysis(pair, spotPrice, effectivePrice);
        
        // Assertions
        assertEq(ethSpent, swapAmountETH);
        assertGt(usdcReceived, 0);
    }

    /**
     * @notice Scenario 4: Swap - Exact Output
     * 
     * Situation: Charlie(trader) exchanges ETH to get exactly 10 USDC.
     * 
     * Key Concepts:
     * - swapETHForExactTokens: Output amount is fixed, input amount is determined by AMM
     * - Useful when user needs a specific amount of tokens
     * - Excess ETH is automatically refunded
     */
    function test_Scenario4_SwapETHForExactUSDC() public {
        console.log("");
        console.log("============================================================");
        console.log("   SCENARIO 4: Swap - Exact Output (ETH -> 10 USDC)");
        console.log("============================================================");
        console.log("");
        
        _createInitialPool();
        address pair = factory.getPair(address(weth), address(usdc));
        
        // --- Current situation ---
        console.log("[SITUATION]");
        console.log("  Charlie needs exactly 10 USDC to pay for something.");
        console.log("  He wants to know how much ETH he needs to spend.");
        console.log("  (Exact Output Swap: output is fixed, input varies)");
        console.log("");
        
        // --- Pool state ---
        (uint112 reserveETH_before, uint112 reserveUSDC_before) = _getReserves(pair);
        uint256 spotPrice = uint256(reserveUSDC_before) * 1e18 / reserveETH_before;
        
        console.log("[BEFORE] Pool State:");
        console.log("  ETH Reserve:  ", fromUnit(reserveETH_before, ETH_DECIMALS, 4), "ETH");
        console.log("  USDC Reserve: ", fromUnit(reserveUSDC_before, USDC_DECIMALS, 2), "USDC");
        console.log("  Spot Price:   1 ETH = ", fromUnit(spotPrice, USDC_DECIMALS, 2), "USDC");
        console.log("");
        
        // --- Charlie's initial balance ---
        console.log("[BEFORE] Charlie's Wallet:");
        console.log("  ETH Balance:  ", fromUnit(trader.balance, ETH_DECIMALS, 4), "ETH");
        console.log("  USDC Balance: ", fromUnit(usdc.balanceOf(trader), USDC_DECIMALS, 2), "USDC");
        console.log("");
        
        // --- Calculate expected input ---
        uint256 desiredUSDC = 10 * 1e6; // 10 USDC
        address[] memory path = new address[](2);
        path[0] = address(weth);
        path[1] = address(usdc);
        
        uint256[] memory expectedAmounts = router.getAmountsIn(desiredUSDC, path);
        uint256 expectedETH = expectedAmounts[0];
        uint256 theoreticalETH = desiredUSDC * 1e18 / spotPrice; // Theoretical price (without fees)
        
        console.log("[PREVIEW] Expected Swap Result:");
        console.log("  Desired Output:         ", fromUnit(desiredUSDC, USDC_DECIMALS, 2), "USDC");
        console.log("  Theoretical Input:      ", fromUnit(theoreticalETH, ETH_DECIMALS, 6), "ETH (at spot price)");
        console.log("  Actual Expected Input:  ", fromUnit(expectedETH, ETH_DECIMALS, 6), "ETH (with 0.3% fee + slippage)");
        console.log("");
        
        // --- Action ---
        uint256 maxETH = 1 ether;
        console.log("[ACTION] Charlie swaps ETH for exactly 10 USDC...");
        console.log("  (Sending ", fromUnit(maxETH, ETH_DECIMALS, 4), " ETH as max, unused will be refunded)");
        console.log("");
        
        vm.startPrank(trader);
        uint256 ethBefore = trader.balance;
        uint256 usdcBefore = usdc.balanceOf(trader);
        
        router.swapETHForExactTokens{value: maxETH}(
            desiredUSDC,
            path,
            trader,
            block.timestamp + 1
        );
        vm.stopPrank();
        
        uint256 ethSpent = ethBefore - trader.balance;
        uint256 usdcReceived = usdc.balanceOf(trader) - usdcBefore;
        uint256 ethRefunded = maxETH - ethSpent;
        
        // --- Result ---
        console.log("[RESULT] Swap Completed:");
        console.log("  ETH Spent:        ", fromUnit(ethSpent, ETH_DECIMALS, 6), "ETH");
        console.log("  ETH Refunded:     ", fromUnit(ethRefunded, ETH_DECIMALS, 4), "ETH");
        console.log("  USDC Received:    ", fromUnit(usdcReceived, USDC_DECIMALS, 2), "USDC (exactly as requested!)");
        uint256 effectivePrice = usdcReceived * 1e18 / ethSpent;
        console.log("  Effective Rate:   1 ETH = ", fromUnit(effectivePrice, USDC_DECIMALS, 2), "USDC");
        console.log("");
        
        // --- Charlie's final balance ---
        console.log("[AFTER] Charlie's Wallet:");
        console.log("  ETH Balance:  ", fromUnit(trader.balance, ETH_DECIMALS, 4), "ETH");
        console.log("  USDC Balance: ", fromUnit(usdc.balanceOf(trader), USDC_DECIMALS, 2), "USDC");
        console.log("");
        
        // --- Cost analysis ---
        uint256 overhead = ethSpent - theoreticalETH;
        uint256 overheadBps = overhead * 10000 / theoreticalETH;
        
        console.log("[COST ANALYSIS]");
        console.log("  Theoretical Cost:  ", fromUnit(theoreticalETH, ETH_DECIMALS, 6), "ETH");
        console.log("  Actual Cost:       ", fromUnit(ethSpent, ETH_DECIMALS, 6), "ETH");
        console.log("  Overhead (fee+slip):", fromUnit(overhead, ETH_DECIMALS, 6), "ETH");
        console.log("  Overhead %:         %s bps (%s.%s%)", overheadBps, overheadBps / 100, overheadBps % 100);
        console.log("");
        
        console.log("[KEY CONCEPT]");
        console.log("  Exact Output swaps guarantee you get the exact amount you need.");
        console.log("  You send more ETH than needed, excess is automatically refunded.");
        console.log("  Useful when you need a specific amount of tokens (e.g., to pay a bill).");
        console.log("");
        
        // Assertions
        assertEq(usdcReceived, desiredUSDC);
        assertLt(ethSpent, maxETH);
    }

    // ============ Helper Functions ============

    function _createInitialPool() internal {
        vm.startPrank(initialLP);
        usdc.approve(address(router), type(uint256).max);
        
        router.addLiquidityETH{value: INITIAL_ETH_LIQUIDITY}(
            address(usdc),
            INITIAL_USDC_LIQUIDITY,
            0,
            0,
            initialLP,
            block.timestamp + 1
        );
        
        vm.stopPrank();
    }

    function _getReserves(address pair) internal view returns (uint112 reserveETH, uint112 reserveUSDC) {
        (uint112 reserve0, uint112 reserve1,) = IUniswapV2Pair(pair).getReserves();
        address token0 = IUniswapV2Pair(pair).token0();
        
        if (token0 == address(weth)) {
            return (reserve0, reserve1);
        } else {
            return (reserve1, reserve0);
        }
    }
    
    function _logWallet(string memory name, address user) internal view {
        console.log(string.concat("[AFTER] ", name, "'s Wallet:"));
        console.log("  ETH Balance:  ", fromUnit(user.balance, ETH_DECIMALS, 4), "ETH");
        console.log("  USDC Balance: ", fromUnit(usdc.balanceOf(user), USDC_DECIMALS, 2), "USDC");
        console.log("");
    }
    
    function _logSwapAnalysis(address pair, uint256 spotPriceBefore, uint256 effectivePrice) internal view {
        (uint112 rETH, uint112 rUSDC) = _getReserves(pair);
        uint256 newSpotPrice = uint256(rUSDC) * 1e18 / rETH;
        
        console.log("[AFTER] Pool State:");
        console.log("  ETH Reserve:   ", fromUnit(rETH, ETH_DECIMALS, 4), "ETH (increased)");
        console.log("  USDC Reserve:  ", fromUnit(rUSDC, USDC_DECIMALS, 2), "USDC (decreased)");
        console.log("  New Spot Price: 1 ETH = ", fromUnit(newSpotPrice, USDC_DECIMALS, 2), "USDC");
        console.log("");
        
        uint256 priceImpactBps = (spotPriceBefore - effectivePrice) * 10000 / spotPriceBefore;
        uint256 priceMoved = spotPriceBefore - newSpotPrice;
        
        console.log("[ANALYSIS]");
        console.log("  Spot Price Before:     ", fromUnit(spotPriceBefore, USDC_DECIMALS, 2), "USDC");
        console.log("  Effective Price:       ", fromUnit(effectivePrice, USDC_DECIMALS, 2), "USDC");
        console.log("  Spot Price After:      ", fromUnit(newSpotPrice, USDC_DECIMALS, 2), "USDC");
        console.log("  Price Impact:           %s bps (%s.%s%)", priceImpactBps, priceImpactBps / 100, priceImpactBps % 100);
        console.log("  Price Moved:           -", fromUnit(priceMoved, USDC_DECIMALS, 2), "USDC per ETH");
        console.log("");
        
        console.log("[KEY CONCEPT]");
        console.log("  x * y = k (Constant Product Formula)");
        console.log("  After swap: More ETH in pool, Less USDC -> ETH price drops");
        console.log("  0.3% fee is retained in pool (benefits LPs)");
        console.log("");
    }
}
