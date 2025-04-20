//SPDX-LICENSE-IDENTIFIER:MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {DexyPool} from "./DexyPool.sol";

contract DexyLiquidityToken is ERC20, AccessControl {
    address private DEXY_POOL;

    constructor(string memory tokenName, string memory tokenSymbol, address _dexyPool) ERC20(tokenName, tokenSymbol) {
        DEXY_POOL = _dexyPool;

        _grantRole(DEFAULT_ADMIN_ROLE, DEXY_POOL);
    }

    function mint(address to, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _burn(from, amount);
    }
}
