// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Script.sol";
import "./Helper.sol";
import {WhitelistPlugin} from "../src/donate3-safe-plugin/WhitelistPlugin.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";

contract DeployWhitelistPlugin is Script, Helper {

    function run(SupportedNetworks source) external {
        uint256 senderPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(senderPrivateKey);

        (address router, address linkToken, , ) = getConfigFromNetwork(source);

        WhitelistPlugin plugin = new WhitelistPlugin();

        console.log(
            "Basic Token Sender deployed on ",
            networks[source],
            "with address: ",
            address(plugin)
        );

        vm.stopBroadcast();
    }
}

