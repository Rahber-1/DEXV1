//SPDX-LICENSE-IDENTIFIER:MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {Dexy} from "../src/Dexy.sol";

contract DeployDexy is Script {
    Dexy dexy;

    function run() public returns (address) {
        vm.startBroadcast();
        dexy = new Dexy();
        vm.stopBroadCast();
        return address(dexy);
    }
}
