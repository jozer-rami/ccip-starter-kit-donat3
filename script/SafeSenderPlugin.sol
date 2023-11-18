// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Script.sol";
import "./Helper.sol";
import {CCIPTokenSenderPlugin} from "../src/donate3-safe-plugin/CCIPTokenSenderPlugin.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";

contract DeployCCIPTokenSenderPlugin is Script, Helper {

    function run(SupportedNetworks source) external {
        uint256 senderPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(senderPrivateKey);

        (address router, address linkToken, , ) = getConfigFromNetwork(source);

        CCIPTokenSenderPlugin ccipPlugin = new CCIPTokenSenderPlugin(
            router,
            linkToken
        );

        console.log(
            "Basic Token Sender deployed on ",
            networks[source],
            "with address: ",
            address(ccipPlugin)
        );

        vm.stopBroadcast();
    }
}

// TODO
// contract Add Plugin to hardcoded safe Manager
// Enable module contract call
// Try 

// contract SendBatch is Script, Helper {
//     function run(
//         SupportedNetworks destination,
//         address payable basicTokenSenderAddres,
//         address receiver,
//         Client.EVMTokenAmount[] memory tokensToSendDetails,
//         CCIPTokenSenderPlugin.PayFeesIn payFeesIn
//     ) external {
//         uint256 senderPrivateKey = vm.envUint("PRIVATE_KEY");
//         vm.startBroadcast(senderPrivateKey);

//         (, , , uint64 destinationChainId) = getConfigFromNetwork(destination);

//         CCIPTokenSenderPlugin(basicTokenSenderAddres).send(
//             destinationChainId,
//             receiver,
//             tokensToSendDetails,
//             payFeesIn
//         );

//         vm.stopBroadcast();
//     }
// }
