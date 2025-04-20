//SPDX-LICENSE-IDENTIFIER:MIT
pragma solidity ^0.8.20;

import {DexyLiquidityToken} from "./DexyLiquidityToken.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract DexyPool {
    //errors
    error DexyPool__AmountIsZero();
    error DexyPool__TransferOfTokenToPoolFailed();
    error DexyPool__ZeroAddressNotAllowed();
    error DexyPool__TransferOfTokenToUserFailed();

    //events
    event LiquidityAdded(address indexed user, uint256 amount);
    event LiquidityTokenRedeemed(address indexed user, uint256 amountTokenA, uint256 amountTokenB);
    event SwapCompleted(address indexed user, uint256 amount);
    //state variables

    address public tokenA;
    address public tokenB;

    uint256 reserveTokenA;
    uint256 reserveTokenB;

    uint256 public constantK;
    DexyLiquidityToken dexyLiquidityToken;

    //In this design there is separate liquidity token for each pair
    //so we must account which liquidity token belongs to which pair
    //mapping(address tokenA=>mapping(address tokenB=>dexyLiquidityToken)) public lpTokens;

    constructor(address _tokenA, address _tokenB, string memory _tokenName, string memory _tokenSymbol) {
        tokenA = _tokenA;
        tokenB = _tokenB;
        dexyLiquidityToken = new DexyLiquidityToken(_tokenName, _tokenSymbol, address(this));
    }

    function addLiquidity(uint256 amountTokenA, uint256 amountTokenB) external {
        //checks on amount of tokens being deposited
        if (amountTokenA == 0 || amountTokenB == 0) {
            revert DexyPool__AmountIsZero();
        }
        //calculate amount of liquidity tokens to mint
        uint256 totalLiquidityTokens = dexyLiquidityToken.totalSupply();
        uint256 liquidityToMint;
        if (totalLiquidityTokens == 0) {
            uint256 productOfTokens = amountTokenA * amountTokenB;

            liquidityToMint = Math.sqrt(productOfTokens);
        } else {
            liquidityToMint = Math.min(
                ((amountTokenB * totalLiquidityTokens) / amountTokenA),
                ((amountTokenA * totalLiquidityTokens) / amountTokenB)
            );
        }

        //add tokenA and TokennB to the pool(address(this))
        //@notice:Some older ERC20 tokens do not return a boolean — they just silently succeed or revert.
        //But newer and OpenZeppelin-compliant tokens do return bool.

        bool success = IERC20(tokenA).transferFrom(msg.sender, address(this), amountTokenA)
            && IERC20(tokenB).transferFrom(msg.sender, address(this), amountTokenB);
        if (!success) {
            revert DexyPool__TransferOfTokenToPoolFailed();
        }

        //updates corresponding reserves
        reserveTokenA += amountTokenA;
        reserveTokenB += amountTokenB;

        //minting liquidity tokens to liquidity provider(msg.sender)
        dexyLiquidityToken.mint(msg.sender, liquidityToMint);

        emit LiquidityAdded(msg.sender, liquidityToMint);

        //update constant product formula
        _updateConstantProductFormula(reserveTokenA, reserveTokenB);
    }
    //let's say user has 10% of LP tokens this entitles him to get 10% of tokenA(reserveA at the time)
    //and tokenB(reserveB at the time) of redeeming LP tokens

    function redeemLiquidityToken(uint256 amountToRedeem) external {
        //zero check
        if (amountToRedeem == 0) {
            revert DexyPool__AmountIsZero();
        }

        //checking if user has the amountToRedeem
        require(dexyLiquidityToken.balanceOf(msg.sender) >= amountToRedeem, "User does not have enough balance");

        uint256 totalLiquidityTokens = dexyLiquidityToken.totalSupply();
        //amount of tokenA to redeem
        uint256 reserveA = IERC20(tokenA).balanceOf(address(this));
        uint256 amountTokenA = (amountToRedeem * reserveA) / totalLiquidityTokens;

        //amount of tokenB to redeem
        uint256 reserveB = IERC20(tokenB).balanceOf(address(this));
        uint256 amountTokenB = (amountToRedeem * reserveB) / totalLiquidityTokens;

        //burn the liquidity token
        dexyLiquidityToken.burn(msg.sender, amountToRedeem);

        //update token reserves
        reserveTokenA -= amountTokenA;
        reserveTokenB -= amountTokenB;

        _updateConstantProductFormula(reserveTokenA, reserveTokenB);

        //transfer tokenA and tokenB to the user
        bool success =
            IERC20(tokenA).transfer(msg.sender, amountTokenA) && IERC20(tokenB).transfer(msg.sender, amountTokenB);
        if (!success) {
            revert DexyPool__TransferOfTokenToUserFailed();
        }

        emit LiquidityTokenRedeemed(msg.sender, amountTokenA, amountTokenB);
    }
    //this function swaps two tokens
    //maintains the constant product

    function swapTokens(address fromToken, address toToken, uint256 amountIn, uint256 amountOut) external {
        if (fromToken == address(0) || toToken == address(0)) {
            revert DexyPool__ZeroAddressNotAllowed();
        }
        if (amountIn == 0 || amountOut == 0) {
            revert DexyPool__AmountIsZero();
        }
        require(
            (fromToken == tokenA && toToken == tokenB) || (fromToken == tokenB && toToken == tokenA),
            "tokens are not eligible to swap"
        );
        IERC20 fromTokenContract = IERC20(fromToken);
        IERC20 toTokenContract = IERC20(toToken);

        require(
            fromTokenContract.balanceOf(msg.sender) >= amountIn,
            "User does not have enough balance of token being swapped"
        );
        require(
            toTokenContract.balanceOf(address(this)) >= amountOut,
            "pool does not have enough balance of toToken to swap"
        );

        //we need to select the from and to reserves based on from and to tokens
        uint256 expectedAmountOut;
        uint256 fromReserve = fromToken == tokenA ? reserveTokenA : reserveTokenB;
        uint256 toReserve = toToken == tokenA ? reserveTokenA : reserveTokenB;

        expectedAmountOut = (amountIn * toReserve) / (fromReserve + amountIn);

        //transfer tokens
        fromTokenContract.transferFrom(msg.sender, address(this), amountIn);
        toTokenContract.transfer(msg.sender, expectedAmountOut);

        //update reserves
        if (fromToken == tokenA && toToken == tokenB) {
            reserveTokenA += amountIn;
            reserveTokenB -= expectedAmountOut;
        } else {
            reserveTokenA -= expectedAmountOut;
            reserveTokenB += amountIn;
        }

        _updateConstantProductFormula(reserveTokenA, reserveTokenB);

        //swap event should be emiited
        emit SwapCompleted(msg.sender, expectedAmountOut);
    }

    // function _sortedTokens(address _tokenA, address _tokenB) internal view returns (address, address) {
    //     return _tokenA < _tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
    // }
    //@check:this function could revert because of mul of two uint256 numbers

    function _updateConstantProductFormula(uint256 _reserveA, uint256 _reserveB) internal {
        constantK = _reserveA * _reserveB;
    }

    function getLiquidityToken() external view returns (address) {
        return address(dexyLiquidityToken);
    }

    function getConstantProductFormula(uint256 _reserveA, uint256 _reserveB) external {
        _updateConstantProductFormula(_reserveA, _reserveB);
    }
}
