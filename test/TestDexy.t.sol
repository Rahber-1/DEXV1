//SPDX-LICENSE-IDENTIFIER:MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import "forge-std/Vm.sol";

import {Dexy} from "../src/Dexy.sol";
import {DexyLiquidityToken} from "../src/DexyLiquidityToken.sol";
import {DexyPool} from "../src/DexyPool.sol";
import {MockERC20} from "./MockERC20.sol";
import {IDexyPool} from "./IDexyPool.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract TestDexy is Test {
    Dexy dexy;
    DexyLiquidityToken dexyLiquidityToken;
    DexyPool dexyPool;
    MockERC20 usdc;
    MockERC20 weth;
    address DEPLOYER = makeAddr("deployer");
    address USER = makeAddr("user");
    address USER2 = makeAddr("user2");
    uint256 constant INITIAL_AMOUNT = 1000e18;
    uint256 constant ADD_LIQUIDITY_TOKENA = 1e18;
    uint256 constant ADD_LIQUIDITY_TOKENB = 2e18;
    uint256 constant ADD_LIQUIDITY = 1e18;

    event PairCreated(address indexed tokenA, address indexed tokenB, address indexed pool);
    event LiquidityAdded(address indexed user, uint256 amount);
    event LiquidityTokenRedeemed(address indexed user, uint256 amountTokenA, uint256 amountTokenB);
    event SwapCompleted(address indexed user, uint256 amount);

    function setUp() public {
        usdc = new MockERC20("USDC", "usdc");
        weth = new MockERC20("WETH", "weth");
        usdc.mint(USER, INITIAL_AMOUNT);
        usdc.mint(USER2, INITIAL_AMOUNT);

        weth.mint(USER, INITIAL_AMOUNT);
        weth.mint(USER2, INITIAL_AMOUNT);

        vm.startBroadcast(DEPLOYER);
        dexy = new Dexy();
        vm.stopBroadcast();
    }

    function testGetPoolAddress() public {
        address tokenA = address(weth);
        address tokenB = address(usdc);

        address expectedPool = dexy.createPair(tokenA, tokenB, "weth", "usdc");

        address actualPool = dexy.getPoolAddress(tokenA, tokenB);

        assertEq(expectedPool, actualPool);
    }

    function testGetPairByIndex() public {
        address tokenA = address(weth);
        address tokenB = address(usdc);

        dexy.createPair(tokenA, tokenB, "weth", "usdc");

        address expectedPairsAtIndexZero = dexy.allPairs(0);
        address actualPairsAtIndexZero = dexy.getPairByIndex(0);

        assertEq(expectedPairsAtIndexZero, actualPairsAtIndexZero);
    }

    function testDexyCanCreateTokenPairs() public {
        vm.startPrank(USER);

        vm.recordLogs();

        address pool = dexy.createPair(address(weth), address(usdc), "weth", "usdc");

        Vm.Log[] memory entries = vm.getRecordedLogs();

        vm.stopPrank();

        bool found = false;

        //get hash of the event sign
        bytes32 eventSignature = keccak256("PairCreated(address,address,address)");
        for (uint256 i = 0; i < entries.length; i++) {
           
            if (entries[i].topics[0] == eventSignature) {
               
                assertEq(address(uint160(uint256(entries[i].topics[1]))), address(weth));
                
                assertEq(address(uint160(uint256(entries[i].topics[2]))), address(usdc));
                
                assertEq(address(uint160(uint256(entries[i].topics[3]))), address(pool));

                
                found = true;
                break; // no need to keep looping
            }
        }
    }

    function testCanAddLiquidity() public {
        //fetch balance of user and pool before adding liq
        uint256 balanceUserBeforeWeth = weth.balanceOf(USER);
        uint256 balanceUserBeforeUsdc = usdc.balanceOf(USER);
        console.log("balance before: ", balanceUserBeforeWeth);

        vm.prank(USER);
        address pool = dexy.createPair(address(weth), address(usdc), "weth", "usdc");
        uint256 balanceOfPoolBeforeWeth = weth.balanceOf(pool);
        uint256 balanceOfPoolBeforeUsdc = usdc.balanceOf(pool);

        //approve pool
        vm.prank(USER);
        weth.approve(pool, ADD_LIQUIDITY);

        vm.prank(USER);
        usdc.approve(pool, ADD_LIQUIDITY);

        //add liquidity to pool
        vm.prank(USER);
        IDexyPool(pool).addLiquidity(ADD_LIQUIDITY, ADD_LIQUIDITY);

        //check balance after adding liq
        // uint256 balanceUserAfterWeth = weth.balanceOf(USER);
        // uint256 balanceUserAfterUsdc = usdc.balanceOf(USER);

        // uint256 balanceOfPoolAfterWeth = weth.balanceOf(pool);
        // uint256 balanceOfPoolAfterUsdc = usdc.balanceOf(pool);

        assertEq(balanceUserBeforeWeth - ADD_LIQUIDITY, weth.balanceOf(USER));
        assertEq(balanceOfPoolBeforeWeth + ADD_LIQUIDITY, weth.balanceOf(pool));
        assertEq(balanceUserBeforeUsdc - ADD_LIQUIDITY, usdc.balanceOf(USER));
        assertEq(balanceOfPoolBeforeUsdc + ADD_LIQUIDITY, usdc.balanceOf(pool));
    }

    function testMintsCorrectAmountOfLiquidityTokens() public {
        vm.prank(USER);
        address pool = dexy.createPair(address(weth), address(usdc), "weth", "usdc");

        vm.prank(USER);
        weth.approve(address(pool), ADD_LIQUIDITY_TOKENA);
        vm.prank(USER);
        usdc.approve(address(pool), ADD_LIQUIDITY_TOKENB);
        vm.prank(USER2);
        weth.approve(address(pool), ADD_LIQUIDITY_TOKENA);
        vm.prank(USER2);
        usdc.approve(address(pool), ADD_LIQUIDITY_TOKENB);
        IDexyPool poolContract = IDexyPool(pool);
        address lpTokenAddress = poolContract.getLiquidityToken();
        dexyLiquidityToken = DexyLiquidityToken(lpTokenAddress);
        uint256 totalLiquidityTokens = dexyLiquidityToken.totalSupply();

        uint256 expectedAmoutOfLiquidityTokens;

        if (totalLiquidityTokens == 0) {
            uint256 tokenProduct = ADD_LIQUIDITY_TOKENA * ADD_LIQUIDITY_TOKENB;
            expectedAmoutOfLiquidityTokens = Math.sqrt(tokenProduct);
        } else {
            expectedAmoutOfLiquidityTokens = Math.min(
                ((ADD_LIQUIDITY_TOKENB * totalLiquidityTokens) / ADD_LIQUIDITY_TOKENA),
                ((ADD_LIQUIDITY_TOKENA * totalLiquidityTokens) / ADD_LIQUIDITY_TOKENB)
            );
        }
        vm.prank(USER);
        IDexyPool(pool).addLiquidity(ADD_LIQUIDITY_TOKENA, ADD_LIQUIDITY_TOKENB);
        assertEq(expectedAmoutOfLiquidityTokens, dexyLiquidityToken.balanceOf(USER));
        uint256 totalLiquidityTokensUser2 = dexyLiquidityToken.totalSupply();

        vm.prank(USER2);
        IDexyPool(pool).addLiquidity(ADD_LIQUIDITY_TOKENA, ADD_LIQUIDITY_TOKENB);
        uint256 expectedAmoutOfLiquidityTokensUser2;

        if (totalLiquidityTokensUser2 == 0) {
            uint256 tokenProduct = ADD_LIQUIDITY_TOKENA * ADD_LIQUIDITY_TOKENB;
            expectedAmoutOfLiquidityTokensUser2 = Math.sqrt(tokenProduct);
        } else {
            expectedAmoutOfLiquidityTokensUser2 = Math.min(
                ((ADD_LIQUIDITY_TOKENB * totalLiquidityTokensUser2) / ADD_LIQUIDITY_TOKENA),
                ((ADD_LIQUIDITY_TOKENA * totalLiquidityTokensUser2) / ADD_LIQUIDITY_TOKENB)
            );
        }
        console.log("expectedAmoutOfLiquidityTokensUser2: ", expectedAmoutOfLiquidityTokensUser2);

        assertEq(expectedAmoutOfLiquidityTokensUser2, dexyLiquidityToken.balanceOf(USER2));
    }

    function testCanAddLiquidityEvenEmit() public {
        vm.prank(USER);
        address pool = dexy.createPair(address(weth), address(usdc), "weth", "usdc");

        //approve pool
        vm.prank(USER);
        weth.approve(pool, ADD_LIQUIDITY);

        vm.prank(USER);
        usdc.approve(pool, ADD_LIQUIDITY);

        vm.expectEmit(true, false, false, false);
        emit LiquidityAdded(USER, uint256(0));

        //add liquidity to pool
        vm.prank(USER);
        IDexyPool(pool).addLiquidity(ADD_LIQUIDITY, ADD_LIQUIDITY);
    }

    function testCanRedeemLiquidityTokensForAssets() public {
        vm.prank(USER);
        address pool = dexy.createPair(address(weth), address(usdc), "weth", "usdc");

        // Approve tokens for adding liquidity
        vm.startPrank(USER);
        weth.approve(pool, ADD_LIQUIDITY_TOKENA);
        usdc.approve(pool, ADD_LIQUIDITY_TOKENB);

        IDexyPool poolContract = IDexyPool(pool);
        address lpTokenAddress = poolContract.getLiquidityToken();
        dexyLiquidityToken = DexyLiquidityToken(lpTokenAddress);

        // Add liquidity
        poolContract.addLiquidity(ADD_LIQUIDITY_TOKENA, ADD_LIQUIDITY_TOKENB);
        vm.stopPrank();

        // Fetch amount to redeem
        uint256 amountToRedeem = dexyLiquidityToken.balanceOf(USER);
        uint256 totalLiquidityTokens = dexyLiquidityToken.totalSupply();
        console.log("User LP token balance:", amountToRedeem);
        console.log("Total LP supply:", totalLiquidityTokens);

        uint256 reserveWeth = weth.balanceOf(address(pool));
        uint256 reserveUsdc = usdc.balanceOf(address(pool));

        uint256 expectedAmountWeth = (amountToRedeem * reserveWeth) / totalLiquidityTokens;
        uint256 expectedAmountUsdc = (amountToRedeem * reserveUsdc) / totalLiquidityTokens;

        console.log("Expected WETH:", expectedAmountWeth);
        console.log("Expected USDC:", expectedAmountUsdc);

        // Record balances before redeeming
        uint256 wethBefore = weth.balanceOf(USER);
        uint256 usdcBefore = usdc.balanceOf(USER);

        // Redeem liquidity tokens
        vm.prank(USER);
        poolContract.redeemLiquidityToken(amountToRedeem);

        // Check received amounts
        uint256 wethAfter = weth.balanceOf(USER);
        uint256 usdcAfter = usdc.balanceOf(USER);

        uint256 actualWethReceived = wethAfter - wethBefore;
        uint256 actualUsdcReceived = usdcAfter - usdcBefore;

        console.log("Actual WETH received:", actualWethReceived);
        console.log("Actual USDC received:", actualUsdcReceived);

        // Assert they match expected values
        assertApproxEqAbs(actualWethReceived, expectedAmountWeth, 1e12); // allow small tolerance
        assertApproxEqAbs(actualUsdcReceived, expectedAmountUsdc, 1e6); // depending on decimals
    }

    function testRedeemLiquidityEventEmits() public {
        vm.prank(USER);
        address pool = dexy.createPair(address(weth), address(usdc), "weth", "usdc");

        // Approve tokens for adding liquidity
        vm.startPrank(USER);
        weth.approve(pool, ADD_LIQUIDITY_TOKENA);
        usdc.approve(pool, ADD_LIQUIDITY_TOKENB);

        IDexyPool poolContract = IDexyPool(pool);
        address lpTokenAddress = poolContract.getLiquidityToken();
        dexyLiquidityToken = DexyLiquidityToken(lpTokenAddress);

        // Add liquidity
        poolContract.addLiquidity(ADD_LIQUIDITY_TOKENA, ADD_LIQUIDITY_TOKENB);
        vm.stopPrank();

        // Fetch amount to redeem
        uint256 amountToRedeem = dexyLiquidityToken.balanceOf(USER);
        vm.expectEmit(true, false, false, false);
        emit LiquidityTokenRedeemed(USER, uint256(0), uint256(0));
        vm.prank(USER);
        poolContract.redeemLiquidityToken(amountToRedeem);
    }

    function testCanSwapTokensWithEventEmit() public {
        uint256 amountIn = ADD_LIQUIDITY_TOKENA;
        uint256 amountOut = ADD_LIQUIDITY_TOKENB;
        vm.prank(USER);
        address pool = dexy.createPair(address(weth), address(usdc), "weth", "usdc");

        // Approve tokens for adding liquidity
        vm.startPrank(USER);
        weth.approve(pool, ADD_LIQUIDITY_TOKENA + ADD_LIQUIDITY_TOKENA);
        usdc.approve(pool, ADD_LIQUIDITY_TOKENB + ADD_LIQUIDITY_TOKENB);

        IDexyPool poolContract = IDexyPool(pool);

        // Add liquidity
        poolContract.addLiquidity(
            ADD_LIQUIDITY_TOKENA + ADD_LIQUIDITY_TOKENA, ADD_LIQUIDITY_TOKENB + ADD_LIQUIDITY_TOKENB
        );
        vm.stopPrank();
        uint256 wethReserve=weth.balanceOf(pool);
        uint256 usdcReserve=usdc.balanceOf(pool);
        console.log("wethReserve: ",wethReserve);
        console.log("usdcReserve: ",usdcReserve);
        uint256 expectedAmountOut = (amountIn * (ADD_LIQUIDITY_TOKENB + ADD_LIQUIDITY_TOKENB))
            / ((ADD_LIQUIDITY_TOKENA + ADD_LIQUIDITY_TOKENA) + amountIn);

        console.log("expectedAmountOut: ",expectedAmountOut);

        
        
        uint256 wethBeforeSwapUser2=weth.balanceOf(USER2);
        uint256 usdcBeforeSwapUser2=usdc.balanceOf(USER2);
        uint256 wethBalancePoolBeforeSwap=weth.balanceOf(pool);
        uint256 usdcBalancePoolBeforeSwap=usdc.balanceOf(pool);
        vm.startPrank(USER2);
        weth.approve(address(pool), amountIn);
        
        poolContract.swapTokens(address(weth), address(usdc), amountIn, amountOut);

        vm.stopPrank();
        uint256 wethAfterSwapUser2=weth.balanceOf(USER2);
        uint256 usdcAfterSwapUser2=usdc.balanceOf(USER2);
        uint256 wethBalancePoolAfterSwap=weth.balanceOf(pool);
        uint256 usdcBalancePoolAfterSwap=usdc.balanceOf(pool);

        //102000000000000000000=102.0 ether
        //101333333333333333333=101.333.. ether
        //diff is 666666666666666667=0.67 ether
        
        assertApproxEqAbs(wethBeforeSwapUser2-amountIn,wethAfterSwapUser2,0.67 ether);
        assertApproxEqAbs(usdcBeforeSwapUser2 +amountOut,usdcAfterSwapUser2,0.67 ether);
        assertApproxEqAbs(wethBalancePoolBeforeSwap+amountIn,wethBalancePoolAfterSwap,0.67 ether);
        assertApproxEqAbs(usdcBalancePoolBeforeSwap -amountOut,usdcBalancePoolAfterSwap,0.67 ether);


      

    }
    function testOnlyPoolCanMintLiquidityTokens() public{
        vm.prank(USER);
        address pool = dexy.createPair(address(weth), address(usdc), "weth", "usdc");

        // Approve tokens for adding liquidity
        vm.startPrank(USER);
        weth.approve(pool, ADD_LIQUIDITY_TOKENA);
        usdc.approve(pool, ADD_LIQUIDITY_TOKENB);
        vm.stopPrank();

        IDexyPool poolContract = IDexyPool(pool);
        address lpTokenAddress = poolContract.getLiquidityToken();
        dexyLiquidityToken = DexyLiquidityToken(lpTokenAddress);
        vm.prank(pool);
        dexyLiquidityToken.mint(USER,INITIAL_AMOUNT);
        
        
        vm.prank(USER);
        vm.expectRevert();
        dexyLiquidityToken.mint(USER,INITIAL_AMOUNT);
    }
    function testUpdatesReserveCorrectly() public {
        vm.prank(USER);
        address pool = dexy.createPair(address(weth), address(usdc), "weth", "usdc");
        

        // Approve tokens for adding liquidity
        vm.startPrank(USER);
        weth.approve(pool, ADD_LIQUIDITY_TOKENA);
        usdc.approve(pool, ADD_LIQUIDITY_TOKENB);
        vm.stopPrank();

        DexyPool poolContract = DexyPool(pool);
        vm.prank(USER);
        poolContract.addLiquidity(ADD_LIQUIDITY_TOKENA, ADD_LIQUIDITY_TOKENB);
        console.log("weth pool balance: ",weth.balanceOf(pool));
        console.log("usdc pool balance: ",usdc.balanceOf(pool));
        uint256 expectedReserveProduct=ADD_LIQUIDITY_TOKENA * ADD_LIQUIDITY_TOKENB;

        uint256 actualReserveProduct=poolContract.constantK();

        assertEq(expectedReserveProduct,actualReserveProduct);

    }
}
