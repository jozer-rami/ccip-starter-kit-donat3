// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Script.sol";
import {SafeProtocolManager} from "@safe-global/safe-core-protocol/contracts/SafeProtocolManager.sol";
import {SafeProtocolRegistry} from "@safe-global/safe-core-protocol/contracts/SafeProtocolRegistry.sol";


contract DeploySafeProtocol is Script {
    function run() external {

        uint256 ownerPrivateKey = vm.envUint("PRIVATE_KEY");
        address owner = vm.envAddress("OWNER");

        vm.startBroadcast(ownerPrivateKey);

        SafeProtocolRegistry registry = new SafeProtocolRegistry(owner);

        SafeProtocolManager manager = new SafeProtocolManager(owner, address(registry));

        console.log(
            "SafeProtocolManager deployed with address: ",
            address(manager),
            "SafeProtocolRegsitry deployed with address: ",
            address(registry)
        );
    }
}
