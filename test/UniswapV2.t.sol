// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {IUniswapV2Router02} from "../src/v2-periphery/interfaces/IUniswapV2Router02.sol";
import {IUniswapV2Factory} from "../src/v2-core/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Pair} from "../src/v2-core/interfaces/IUniswapV2Pair.sol";
import {WETH9} from "../src/mocks/WETH9.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";

contract UniswapV2Test is Test {
    
    IUniswapV2Factory public factory;
    IUniswapV2Router02 public router;
    WETH9 public weth;
    MockERC20 public tokenA;
    MockERC20 public tokenB;
    
    address public user = makeAddr("user");

    function setUp() public {
        
        weth = new WETH9();
        
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
        
        tokenA = new MockERC20("Token A", "TKNA", 18);
        tokenB = new MockERC20("Token B", "TKNB", 18);
        
        tokenA.mint(user, 1000 ether);
        tokenB.mint(user, 1000 ether);
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
        assertTrue(pair == router.pairFor(address(tokenA), address(tokenB)));
    }
    
    function test_PairCreationCodeHash() public view {
        // Extract Pair creation code embedded in Factory bytecode
        // Factory bytecode structure: ... PUSH2 0x3c31 DUP1 PUSH2 0x0d4b ...
        // Pair creation code starts at offset 0x0d4b, length 0x3c31 (15409 bytes)
        bytes memory factoryBytecode = vm.getCode("out/UniswapV2Factory.sol/UniswapV2Factory.json");
        
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

        // console.log("predicted address", uniV2Router02.getPair())   
        
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
