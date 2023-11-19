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
 * @dev This interface is defined for use in CCIPTokenSenderPlugin contract.
 */
interface OwnerManager {
    function isOwner(address owner) external view returns (bool);
}

/**
 * @title CCIPTokenSenderPlugin 
 * @notice This plugin does not need Safe owner(s) confirmation(s) to execute Safe txs once enabled
 *         through a Safe{Core} Protocol Manager.
 */
contract CCIPTokenSenderPlugin is  BasePluginWithEventMetadata{

    enum PayFeesIn {
        Native,
        LINK
    }

    error CallerIsNotOwner(address safe, address caller);

    address immutable i_router;
    address immutable i_link;
    uint16 immutable i_maxTokensLength;
    
    event MessageSent(bytes32 messageId);

    constructor(address router, address link) BasePluginWithEventMetadata(
            PluginMetadata({name: "CCIPTokenSenderPlugin Plugin", version: "1.0.0", requiresRootAccess: false, iconUrl: "", appUrl: ""})
        ) {
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
     */
    function executeFromPlugin(
        ISafeProtocolManager manager,
        ISafe safe,
        uint64 destinationChainSelector,
        address receiver,
        Client.EVMTokenAmount[] memory tokensToSendDetails
    ) external returns (bytes[] memory data) {
        address safeAddress = address(safe);
        // Only Safe owners are allowed to execute transactions
        if (!(OwnerManager(safeAddress).isOwner(msg.sender))) {
            revert CallerIsNotOwner(safeAddress, msg.sender);
        }

        SafeProtocolAction[] memory actions = createSafeActionsToExecute(destinationChainSelector, receiver, tokensToSendDetails);
        SafeTransaction memory safetx;
        safetx.actions=actions;

        // Test: Any tx that updates whitelist of this contract should be blocked
        (data) = manager.executeTransaction(safe, safetx);

    }

    function getSupportedTokens(
        uint64 chainSelector
    ) external view returns (address[] memory tokens) {
        tokens = IRouterClient(i_router).getSupportedTokens(chainSelector);
    }

    // Encoding Safe Protocol Actions
    // Approve router token spending
    function createSafeActionsToExecute(
        uint64 destinationChainSelector,
        address receiver,
        Client.EVMTokenAmount[] memory tokensToSendDetails
    ) internal returns (SafeProtocolAction[] memory){
        uint256 length = tokensToSendDetails.length;
        require(
            length <= i_maxTokensLength,
            "Maximum 5 different tokens can be sent per CCIP Message"
        );

        // Actions required are all the approvals for the tokens + 1 extra action for CCIP send call
        SafeProtocolAction[] memory safeActions = new SafeProtocolAction[](length+1);

        for (uint256 i = 0; i < length; ) {
            safeActions[i].to = payable(tokensToSendDetails[i].token);
            safeActions[i].value = 0;
            safeActions[i].data = abi.encodeWithSignature("approve(address,uint256)", i_router, tokensToSendDetails[i].amount);

            unchecked {
                ++i;
            }
        }

        // Create CCIP call to send message
        SafeProtocolAction memory ccipAction = createCCIPsendAction(destinationChainSelector, receiver, tokensToSendDetails);
        safeActions[length] = ccipAction;

        return safeActions;
    }

    function createCCIPsendAction(
        uint64 destinationChainSelector,
        address receiver,
        Client.EVMTokenAmount[] memory tokensToSendDetails
    ) internal returns (SafeProtocolAction memory safeAction)  {
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(receiver),
            data: "",
            tokenAmounts: tokensToSendDetails,
            extraArgs: "",
            feeToken: address(0)
        });

        uint256 fee = IRouterClient(i_router).getFee(
            destinationChainSelector,
            message
        );

        bytes32 messageId;

        safeAction.to = payable(i_router);
        safeAction.value = fee;
        safeAction.data = abi.encodeWithSignature("ccipSend(uint64,bytes)",destinationChainSelector,message);

        emit MessageSent(messageId);

        return safeAction;
    }

}
