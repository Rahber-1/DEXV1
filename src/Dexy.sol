//SPDX-LICENSE-IDENTIFIER:MIT
pragma solidity ^0.8.20;

import {DexyPool} from "./DexyPool.sol";

/*
*@title:Dexy Contract
*@author:Rahbar Ahmed
*@Info:This contract is responsible for creating token pairs.
*another contract which is DexyPool is where liquidity could be removed/added/swapped
*Thus this contract Dexy just creates and updates mapping of pairs
* anyone could create pair and add liquidity on DexyPool
*in return liquidity provider gets liquidity token which represents their corresponding share in the pool
* each token pair has it's own pool
* Pool works on the constant product formula ie x * y=constant which means at any given time the ratio of reserves of any two assets
* must be constant   
*/

contract Dexy {
    //errors
    error Dexy__AddressZeroNotAllowed();
    error Dexy__BothTokensAreSame();
    error Dexy__PoolAlreadyExists();

    //events
    event PairCreated(address indexed tokenA, address indexed tokenB, address indexed pool);

    //All pairs created must be pushed to allPairs
    address[] public allPairs;

    //mapping tokens to DexyPool contract
    mapping(address tokenA => mapping(address tokenB => DexyPool)) public pools;

    function createPair(address tokenA, address tokenB, string memory nameTokenA, string memory nameTokenB)
        external
        returns (address)
    {
        if (tokenA == address(0) || tokenB == address(0)) {
            revert Dexy__AddressZeroNotAllowed();
        }
        if (tokenA == tokenB) {
            revert Dexy__BothTokensAreSame();
        }
        if (address(pools[tokenA][tokenB]) != address(0)) {
            revert Dexy__PoolAlreadyExists();
        }
        //we want to make pair creation order agnostic meaning pair (tokenA,tokenB) is same as (tokenB,tokenA)
        //this is important for UX consistency
        //addresses in solidity are 20 bytes long so they compared numerically
        (address token0, address token1) = _sortedTokens(tokenA, tokenB);

        string memory name0 = tokenA < tokenB ? nameTokenA : nameTokenB;
        string memory name1 = tokenA < tokenB ? nameTokenA : nameTokenB;

        //now sorting names based on sorted tokens
        string memory tokenName = string(abi.encodePacked("liquidity", "-", name0, name1));
        string memory tokenSymbol = string(abi.encodePacked("LP", "-", name0, name1));
        //update pools through mapping
        DexyPool dexyPool = new DexyPool(token0, token1, tokenName, tokenSymbol);
        pools[token0][token1] = dexyPool;
        pools[token1][token0] = dexyPool;

        allPairs.push(address(dexyPool));
        emit PairCreated(tokenA, tokenB, address(dexyPool));

        return address(dexyPool);
    }

    function _sortedTokens(address tokenA, address tokenB) internal pure returns (address, address) {
        return tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
    }

    function getPoolAddress(address tokenA, address tokenB) external view returns (address) {
        return address(pools[tokenA][tokenB]);
    }

    function getPairByIndex(uint256 index) external view returns (address) {
        return allPairs[index];
    }
}

//Deployer: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
//Deployed to: 0x5FbDB2315678afecb367f032d93F642f64180aa3
