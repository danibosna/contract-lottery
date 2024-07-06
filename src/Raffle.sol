// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import { VRFConsumerBaseV2Plus } from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import { VRFV2PlusClient } from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";


/**
* @title A sample Raffle Contract
* @author DaniBosna
* @notice This contract is for creating a sample raffle
* @dev Implements Chainlink VRFv2
*/
contract Raffle is VRFConsumerBaseV2Plus {
  /*Errors*/
  error Raffle__NotEnoughEthSent();



  
  uint16 private constant REQUEST_CONFIRMATIONS = 3;
  uint32 private constant NUM_WORDS = 1;
  uint256 private immutable i_entranceFee;
  uint256 private immutable i_interval;
  bytes32 private immutable i_keyHash;
  uint256 private immutable i_subscriptionId;
  uint32 private immutable i_callbackGasLimit;
  address payable[] private s_players;
  uint256 private s_lastTimeStamp;

  /*Events*/
  event RaffleEntered(address indexed player);


  constructor(uint256 entranceFee, uint256 interval, address vrfCoordinator, bytes32 gasLane, uint256 subscriptionId, uint32 callbackGasLimit) VRFConsumerBaseV2Plus(vrfCoordinator) {
    i_entranceFee = entranceFee;
    i_interval = interval;
    s_lastTimeStamp = block.timestamp;
    i_keyHash = gasLane;
    i_subscriptionId = subscriptionId;
    i_callbackGasLimit = callbackGasLimit;
  }

  function enterRaffle() external payable {
    // require(msg.value >= i_entranceFee, "NotEnoughEthSent");
    if (msg.value < i_entranceFee) {
      revert Raffle__NotEnoughEthSent();
    }
    s_players.push(payable(msg.sender));
    emit RaffleEntered(msg.sender);
  }

  // 1. Get a random Number
  // 2. Use random number to pick a player
  // 3. Be automatically called
  function pickWinner() external {
    if ((block.timestamp - s_lastTimeStamp) < i_interval ) {
      revert();
    }
    //Get Random Number VRF2.5
    // 1. Request RNG
    // 2. Get RNG
    VRFV2PlusClient.RandomWordsRequest request = VRFV2PlusClient.RandomWordsRequest({
                keyHash: s_keyHash,
                subId: s_subscriptionId,
                requestConfirmations: requestConfirmations,
                callbackGasLimit: callbackGasLimit,
                numWords: numWords,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            });
    //uint256 requestId = s_vrfCoordinator.requestRandomWords(
    //  request
    //);
  }

  function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal override {}

  /** Getter Funtion */

  function getEntraceFee() external view returns(uint256) {
    return i_entranceFee;
  }

}
