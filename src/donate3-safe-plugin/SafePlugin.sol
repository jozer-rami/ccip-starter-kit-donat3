// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.18;
import {ISafe} from "@safe-global/safe-core-protocol/contracts/interfaces/Accounts.sol";
import {ISafeProtocolManager} from "@safe-global/safe-core-protocol/contracts/interfaces/Manager.sol";
import {SafeTransaction, SafeProtocolAction} from "@safe-global/safe-core-protocol/contracts/DataTypes.sol";
import {BasePluginWithEventMetadata, PluginMetadata} from "./Base.sol";
// CCIP deps

import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";
import {IERC20} from "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.0/token/ERC20/IERC20.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {Withdraw} from "../utils/Withdraw.sol";
/**
 * @title OwnerManager
 * @dev This interface is defined for use in WhitelistPlugin contract.
 */
interface OwnerManager {
    function isOwner(address owner) external view returns (bool);
}

/**
 * @title WhitelistPlugin maintains a mapping that stores information about accounts that are
 *        permitted to execute non-root transactions through a Safe account.
 * @notice This plugin does not need Safe owner(s) confirmation(s) to execute Safe txs once enabled
 *         through a Safe{Core} Protocol Manager.
 */
contract WhitelistPlugin is BasePluginWithEventMetadata(
            PluginMetadata({name: "Whitelist Plugin", version: "1.0.0", requiresRootAccess: false, iconUrl: "", appUrl: ""})
        ) {
    enum PayFeesIn {
        Native,
        LINK
    }

    error CallerIsNotOwner(address safe, address caller);

    address immutable i_router;
    address immutable i_link;
    uint16 immutable i_maxTokensLength;
    
    event MessageSent(bytes32 messageId);

    constructor(address router, address link) {
        i_router = router;
        i_link = link;
        i_maxTokensLength = 5;
        LinkTokenInterface(i_link).approve(i_router, type(uint256).max);
    }

    receive() external payable {}

    /**
     * @notice Executes a Safe transaction if the caller is whitelisted for the given Safe account.
     * @param manager Address of the Safe{Core} Protocol Manager.
     * @param safe Safe account
     * @param safetx SafeTransaction to be executed
     */
    function executeFromPlugin(
        ISafeProtocolManager manager,
        ISafe safe,
        SafeTransaction calldata safetx
    ) external returns (bytes[] memory data) {
        address safeAddress = address(safe);
        // Only Safe owners are allowed to execute transactions
        if (!(OwnerManager(safeAddress).isOwner(msg.sender))) {
            revert CallerIsNotOwner(safeAddress, msg.sender);
        }

        // SafeProtocolAction[] memory actions = safetx.actions;
        // uint256 length = actions.length;
        // for (uint256 i = 0; i < length; i++) {
        //     if (!whitelistedAddresses[safeAddress][actions[i].to]) revert AddressNotWhiteListed(actions[i].to);
        // }
        // // Test: Any tx that updates whitelist of this contract should be blocked
        // (data) = manager.executeTransaction(safe, safetx);

        // TODO call send message CCIP
    }

    function getSupportedTokens(
        uint64 chainSelector
    ) external view returns (address[] memory tokens) {
        tokens = IRouterClient(i_router).getSupportedTokens(chainSelector);
    }

    function send(
        uint64 destinationChainSelector,
        address receiver,
        Client.EVMTokenAmount[] memory tokensToSendDetails,
        PayFeesIn payFeesIn
    ) external {
        uint256 length = tokensToSendDetails.length;
        require(
            length <= i_maxTokensLength,
            "Maximum 5 different tokens can be sent per CCIP Message"
        );

        for (uint256 i = 0; i < length; ) {
            IERC20(tokensToSendDetails[i].token).transferFrom(
                msg.sender,
                address(this),
                tokensToSendDetails[i].amount
            );
            IERC20(tokensToSendDetails[i].token).approve(
                i_router,
                tokensToSendDetails[i].amount
            );

            unchecked {
                ++i;
            }
        }

        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(receiver),
            data: "",
            tokenAmounts: tokensToSendDetails,
            extraArgs: "",
            feeToken: payFeesIn == PayFeesIn.LINK ? i_link : address(0)
        });

        uint256 fee = IRouterClient(i_router).getFee(
            destinationChainSelector,
            message
        );

        bytes32 messageId;

        if (payFeesIn == PayFeesIn.LINK) {
            // LinkTokenInterface(i_link).approve(i_router, fee);
            messageId = IRouterClient(i_router).ccipSend(
                destinationChainSelector,
                message
            );
        } else {
            messageId = IRouterClient(i_router).ccipSend{value: fee}(
                destinationChainSelector,
                message
            );
        }

        emit MessageSent(messageId);
    }

}
