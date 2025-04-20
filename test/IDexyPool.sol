//SPDX-LICENSE-IDENTIFIER:MIT
pragma solidity ^0.8.20;

interface IDexyPool {
    function addLiquidity(uint256, uint256) external;
    function redeemLiquidityToken(uint256) external;
    function swapTokens(address, address, uint256, uint256) external;
    function getLiquidityToken() external view returns (address);
    function getConstantProductFormula(uint256, uint256) external;
    
}
