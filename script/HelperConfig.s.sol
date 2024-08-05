// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Script } from "forge-std/Script.sol";
import { VRFCoordinatorV2_5Mock } from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

abstract contract CodeConstants {
  /* VRF Mock Values */
  uint96 public MOCK_BASE_FEE = 0.25 ether;
  uint96 public MOCK_GAS_PRICE_LINK = 1e9;
  // LINK / ETH price
  int256 public MOCK_WEI_PER_UINT_LINK = 4e15;

  uint256 public constant ETH_SEPOLIA_CHAIN_ID = 11155111;
  uint256 public constant ANVIL_LOCAL_CHAIN_ID = 31337;
}

contract HelperConfig is Script, CodeConstants {

  error HelperConfig__InvalidChainId();

  struct NetworkConfig {
    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint256 subscriptionId;
    uint32 callbackGasLimit;
  }

  NetworkConfig public localNetworkConfig;
  mapping(uint256 chainId => NetworkConfig) public networkConfigs;

  constructor() {
    networkConfigs[ETH_SEPOLIA_CHAIN_ID] = getSepoliaEthConfig();
  }

  function getConfig() public returns(NetworkConfig memory) {
    return getConfigByChainId(block.chainid);
  }

  function getConfigByChainId(uint256 chainId) public returns(NetworkConfig memory) {
    if (networkConfigs[chainId].vrfCoordinator != address(0)) {
      return networkConfigs[chainId];
    } else if (chainId == ANVIL_LOCAL_CHAIN_ID) {
      return getOrCreateAnvilEthConfig();
    } else {
      revert HelperConfig__InvalidChainId();
    }
  }

  function getSepoliaEthConfig() public pure returns(NetworkConfig memory) {
    return NetworkConfig({
      entranceFee: 0.01 ether,
      interval: 30,
      vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
      gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
      subscriptionId: 0,
      callbackGasLimit: 500000
    });
  }
  
  function getOrCreateAnvilEthConfig() public returns(NetworkConfig memory) {
    // check to see if we set an active network configs
    if (localNetworkConfig.vrfCoordinator != address(0)) {
      return localNetworkConfig;
    }

    // Deploy mocks and such
    vm.startBroadcast();
    VRFCoordinatorV2_5Mock vrfCoordinatorMock = new VRFCoordinatorV2_5Mock(MOCK_BASE_FEE, MOCK_GAS_PRICE_LINK, MOCK_WEI_PER_UINT_LINK);
    vm.stopBroadcast();

    localNetworkConfig = NetworkConfig({
      entranceFee: 0.01 ether,
      interval: 30,
      vrfCoordinator: address(vrfCoordinatorMock),
      // gaslane doesn't matter
      gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
      subscriptionId: 0, // might have to fix this
      callbackGasLimit: 500000
    });

    return localNetworkConfig;
  }
}
