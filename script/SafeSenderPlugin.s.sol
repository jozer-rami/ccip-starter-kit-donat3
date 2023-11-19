// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Script.sol";
import "./Helper.sol";
import {CCIPTokenSenderPlugin} from "../src/donate3-safe-plugin/CCIPTokenSenderPlugin.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {ISafe} from "@safe-global/safe-core-protocol/contracts/interfaces/Accounts.sol";
import {ISafeProtocolManager} from "@safe-global/safe-core-protocol/contracts/interfaces/Manager.sol";

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

// command
// forge script ./script/SafeSenderPlugin.s.sol:SafeExecuteApproval -vvv --broadcast --rpc-url ethereumSepolia --sig "run(uint8,address,address,(address,uint256)[])" -- 0 <PLUGIN> <SAFE> "[(0xD21341536c5cF5EB1bcb58f6723cE26e8D8E90e4,100),(0x0b9d5D9136855f6FEc3c0993feE6E9CE8a297846,100)]"

// command test
// forge script ./script/SafeSenderPlugin.s.sol:SafeExecuteApproval 
// -vvv --broadcast --rpc-url ethereumSepolia 
// --sig "run(uint8,address,address,(address,uint256)[])" 
// -- 0 0x28aa614bfA57Ff015950f1d8035E8a4F59610171 0x940f64931dE77dB9A8F01167C7581be5F7dBA178 "[(0xD21341536c5cF5EB1bcb58f6723cE26e8D8E90e4,100),(0x0b9d5D9136855f6FEc3c0993feE6E9CE8a297846,100)]"

contract SafeExecuteCCIP is Script, Helper {
    function run(
        SupportedNetworks destination,
        address receiver,
        address payable pluginAddress,
        address safeAddress,
        Client.EVMTokenAmount[] memory tokensToSendDetails
    ) external {
        uint256 senderPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(senderPrivateKey);

        (, , , uint64 destinationChainId) = getConfigFromNetwork(destination);

        address manager = 0x105f7E9Ed9F318394C9652cB0A2A08489b617C16;
        ISafeProtocolManager safeManager = ISafeProtocolManager(manager);
        ISafe safe = ISafe(safeAddress);

        CCIPTokenSenderPlugin(pluginAddress).executeFromPlugin(
            safeManager,
            safe,
            destinationChainId,
            receiver,
            tokensToSendDetails
        );

        vm.stopBroadcast();
    }
}
