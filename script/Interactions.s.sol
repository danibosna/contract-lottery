// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Script, console } from "forge-std/Script.sol";
import { Raffle } from "src/Raffle.sol";
import { HelperConfig, CodeConstants } from "script/HelperConfig.s.sol";
import { VRFCoordinatorV2_5Mock } from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import { LinkToken } from "test/mocks/LinkToken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script {

  function createSubscriptionUsingConfig() public returns (uint256, address) {
    HelperConfig helperConfig = new HelperConfig();
    address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
    (uint256 subId, ) = createSubscription(vrfCoordinator);
    return (subId, vrfCoordinator);
  }

  function createSubscription(address vrfCoordinator) public returns (uint256, address) {
    console.log("Creating subscrition on chain Id: ", block.chainid);

    vm.startBroadcast();
    uint256 subId = VRFCoordinatorV2_5Mock(vrfCoordinator).createSubscription();
    vm.stopBroadcast();

    console.log("Your subscription Id is: ", subId);
    console.log("Please update the subscription Id in your HelperConfig.s.sol");
    return (subId, vrfCoordinator);
  }

  function run() external returns(uint256, address) {
    return createSubscriptionUsingConfig();
  }
}

contract FundSubscription is Script, CodeConstants {
  uint256 public constant FUND_AMOUNT = 3 ether; // 3 LINK

  function fundSubscriptionUsingConfig() public {
    HelperConfig helperConfig = new HelperConfig();
    address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
    uint256 subscriptionId = helperConfig.getConfig().subscriptionId;
    address linkToken = helperConfig.getConfig().link;
    fundSubscription(vrfCoordinator, subscriptionId, linkToken);
  }

  function fundSubscription(address vrfCoordinator, uint256 subscriptionId, address linkToken) public {
    console.log("Funding subscription: ", subscriptionId);
    console.log("Using vrfCoordinator: ", vrfCoordinator);
    console.log("On chain Id: ", block.chainid);

    if (block.chainid == ANVIL_LOCAL_CHAIN_ID) {
      vm.startBroadcast();
        VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(subscriptionId, FUND_AMOUNT);
      vm.stopBroadcast();
    } else {
      vm.startBroadcast();
        LinkToken(linkToken).transferAndCall(vrfCoordinator, FUND_AMOUNT, abi.encode(subscriptionId));
      vm.stopBroadcast();
    }
  }

  function run() external {
    fundSubscriptionUsingConfig();
  }
}

contract AddConsumer is Script {

  function addConsumerUsingConfig(address contractToAddToVrf) public {
    HelperConfig helperConfig = new HelperConfig();
    uint256 subscriptionId = helperConfig.getConfig().subscriptionId;
    address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
    addConsumer(contractToAddToVrf, vrfCoordinator, subscriptionId);
  }

  function addConsumer(address contractToAddToVrf, address vrfCoordinator, uint256 subscriptionId) public {
    console.log("Adding consumer contract: ", contractToAddToVrf);
    console.log("To vrfCoordinator: ", vrfCoordinator);
    console.log("On chain Id: ", block.chainid);

    vm.startBroadcast();
    VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(subscriptionId, contractToAddToVrf);
    vm.stopBroadcast();
  }

  function run() external {
    address mostRecentlyDeployedContract = DevOpsTools.get_most_recent_deployment("Raffle", block.chainid);
    addConsumerUsingConfig(mostRecentlyDeployedContract);
  }
}
