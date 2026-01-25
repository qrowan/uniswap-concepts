// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Counter} from "../src/Counter.sol";
import {IUniswapV2Router02} from "../src/v2-periphery/interfaces/IUniswapV2Router02.sol";
import {IUniswapV2Factory} from "../src/v2-core/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Pair} from "../src/v2-core/interfaces/IUniswapV2Pair.sol";
import {WETH9} from "../src/mocks/WETH9.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";

contract CounterTest is Test {
    Counter public counter;
    
    IUniswapV2Factory public factory;
    IUniswapV2Router02 public router;
    WETH9 public weth;
    MockERC20 public tokenA;
    MockERC20 public tokenB;
    
    address public user = makeAddr("user");

    function setUp() public {
        counter = new Counter();
        counter.setNumber(0);
        
        weth = new WETH9();
        
        bytes memory factoryBytecode = abi.encodePacked(
            vm.getCode("out/v2-core/UniswapV2Factory.sol/UniswapV2Factory.json"),
            abi.encode(address(this))
        );
        address factoryAddr;
        assembly {
            factoryAddr := create(0, add(factoryBytecode, 0x20), mload(factoryBytecode))
        }
        require(factoryAddr != address(0), "Factory deploy failed");
        factory = IUniswapV2Factory(factoryAddr);
        
        bytes memory routerBytecode = abi.encodePacked(
            vm.getCode("out/v2-periphery/UniswapV2Router02.sol/UniswapV2Router02.json"),
            abi.encode(address(factory), address(weth))
        );
        address routerAddr;
        assembly {
            routerAddr := create(0, add(routerBytecode, 0x20), mload(routerBytecode))
        }
        require(routerAddr != address(0), "Router deploy failed");
        router = IUniswapV2Router02(routerAddr);
        
        tokenA = new MockERC20("Token A", "TKNA", 18);
        tokenB = new MockERC20("Token B", "TKNB", 18);
        
        tokenA.mint(user, 1000 ether);
        tokenB.mint(user, 1000 ether);
    }

    function test_Increment() public {
        counter.increment();
        assertEq(counter.number(), 1);
    }

    function testFuzz_SetNumber(uint256 x) public {
        counter.setNumber(x);
        assertEq(counter.number(), x);
    }
    
    function test_FactoryDeployed() public view {
        assertEq(factory.feeToSetter(), address(this));
    }
    
    function test_RouterDeployed() public view {
        assertEq(router.factory(), address(factory));
        assertEq(router.WETH(), address(weth));
    }
    
    function test_CreatePairManually() public {
        address pair = factory.createPair(address(tokenA), address(tokenB));
        console.log("Pair created at:", pair);
        assertFalse(pair == address(0));
    }
    
    function test_PairCreationCodeHash() public view {
        // Factory bytecode에 임베드된 Pair creation code를 추출
        // Factory bytecode 구조: ... PUSH2 0x3c31 DUP1 PUSH2 0x0d4b ...
        // Pair creation code는 offset 0x0d4b에서 시작, 길이 0x3c31 (15409 bytes)
        bytes memory factoryBytecode = vm.getCode("out/v2-core/UniswapV2Factory.sol/UniswapV2Factory.json");
        
        // Extract Pair creation code from Factory bytecode
        uint256 offset = 0x0d4b;
        uint256 length = 0x3c31;
        
        bytes memory pairCreationCode = new bytes(length);
        for (uint256 i = 0; i < length; i++) {
            pairCreationCode[i] = factoryBytecode[offset + i];
        }
        
        bytes32 initCodeHash = keccak256(pairCreationCode);
        console.log("Pair init code hash:");
        console.logBytes32(initCodeHash);
    }
    
    function test_AddLiquidity() public {
        uint256 amountA = 100 ether;
        uint256 amountB = 100 ether;
        
        vm.startPrank(user);
        
        tokenA.approve(address(router), type(uint256).max);
        tokenB.approve(address(router), type(uint256).max);
        
        (uint256 addedA, uint256 addedB, uint256 liquidity) = router.addLiquidity(
            address(tokenA),
            address(tokenB),
            amountA,
            amountB,
            0,
            0,
            user,
            block.timestamp + 1
        );
        
        vm.stopPrank();
        
        assertGt(addedA, 0);
        assertGt(addedB, 0);
        assertGt(liquidity, 0);
        
        address pair = factory.getPair(address(tokenA), address(tokenB));
        assertGt(IUniswapV2Pair(pair).balanceOf(user), 0);
    }
    
    function test_SwapExactTokensForTokens() public {
        uint256 liquidityA = 100 ether;
        uint256 liquidityB = 100 ether;
        
        vm.startPrank(user);
        
        tokenA.approve(address(router), type(uint256).max);
        tokenB.approve(address(router), type(uint256).max);
        
        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            liquidityA,
            liquidityB,
            0,
            0,
            user,
            block.timestamp + 1
        );
        
        uint256 swapAmount = 10 ether;
        
        uint256 balanceBBefore = tokenB.balanceOf(user);
        
        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);
        
        router.swapExactTokensForTokens(
            swapAmount,
            0,
            path,
            user,
            block.timestamp + 1
        );
        
        vm.stopPrank();
        
        uint256 balanceBAfter = tokenB.balanceOf(user);
        assertGt(balanceBAfter, balanceBBefore);
        
        console.log("Swapped %s tokenA for %s tokenB", swapAmount, balanceBAfter - balanceBBefore);
    }
}
