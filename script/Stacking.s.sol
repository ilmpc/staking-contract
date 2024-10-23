// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Stacking} from "../src/Stacking.sol";

contract CounterScript is Script {
    Stacking public stacking;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        // stacking = new Stacking({
        //     _stackingToken: "",
        //     _rewardToken: "",
        //     _rewardRate: 1
        // });

        vm.stopBroadcast();
    }
}
