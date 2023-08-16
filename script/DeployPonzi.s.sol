// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "lib/forge-std/src/Script.sol";
import {PonziContract} from "../src/Ponzi.sol";

contract DeployPonzi is Script {
    uint256 public DEFAULT_ANVIL_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    function run() external returns (PonziContract ponzi, address deployerAddress) {
        uint256 deployerKey = getDeployerKey();
        vm.startBroadcast(deployerKey);
        ponzi = new PonziContract();
        deployerAddress = vm.addr(deployerKey);
        vm.stopBroadcast();
    }

    function getDeployerKey() public returns (uint256 deployerKey) {
        deployerKey = vm.envOr("PRIVATE_KEY", DEFAULT_ANVIL_KEY);
    }
}
