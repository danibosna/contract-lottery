// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {Raffle} from "src/Raffle.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {HelperConfig, CodeConstants} from "script/HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract RaffleTest is Test, CodeConstants {
    Raffle public raffle;
    HelperConfig public helperConfig;

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint256 subscriptionId;
    uint32 callbackGasLimit;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_PLAYER_BALANCE = 10 ether;

    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);

    modifier raffleEntered() {
      vm.prank(PLAYER);
      raffle.enterRaffle{value: entranceFee}();
      vm.warp(block.timestamp + interval + 1);
      vm.roll(block.number + 1);
      _;
    }

    modifier skipFork() {
      if (block.chainid != ANVIL_LOCAL_CHAIN_ID) {
        return;
      }
      _;
    }

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.deployContract();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        entranceFee = config.entranceFee;
        interval = config.interval;
        vrfCoordinator = config.vrfCoordinator;
        gasLane = config.gasLane;
        subscriptionId = config.subscriptionId;
        callbackGasLimit = config.callbackGasLimit;

        vm.deal(PLAYER, STARTING_PLAYER_BALANCE);
    }

    function testRaffle_InitializesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    /*//////////////////////////////////////////////////////////////
                              ENTER RAFFLE
    //////////////////////////////////////////////////////////////*/

    function testRaffle_RevertWhenYouDontPayEnough() public {
        // Arrange
        vm.prank(PLAYER);
        // Act / Assert
        vm.expectRevert(Raffle.Raffle__NotEnoughEthSent.selector);
        raffle.enterRaffle();
    }

    function testRaffle_RecordsPlayerWhenTheyEnter() public {
        // Arrange
        vm.prank(PLAYER);
        // Act
        raffle.enterRaffle{value: entranceFee}();
        // Assert
        address playerRecorded = raffle.getPlayerByIndex(0);
        assert(playerRecorded == PLAYER);
    }

    function testRaffle_EmitEventWhenPlayerEnter() public {
        // Arrange
        vm.prank(PLAYER);
        // Act.
        vm.expectEmit(true, false, false, false, address(raffle));
        emit RaffleEntered(PLAYER);
        // assert
        raffle.enterRaffle{value: entranceFee}();
    }

    function testRaffle_DontAllowPlayersToEnterWhileStateIsCalculating() public raffleEntered {
        // Arrange.
        raffle.performUpkeep("");
        // Act./ Assert
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    /*//////////////////////////////////////////////////////////////
                              CHECK UPKEEP
    //////////////////////////////////////////////////////////////*/

    function testRaffle_CheckUpkeepReturnsFalseIfHasNoBalance() public {
        //Arrange
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        //Act.
        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        //Assert.
        assert(!upkeepNeeded);
    }

    function testRaffle_CheckUpkeepReturnsFalseIfRaffleIsntOpen() public raffleEntered {
        // Arrange.
        raffle.performUpkeep("");
        //Act.
        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        //Assert.
        assert(!upkeepNeeded);
    }

    function testRaffle_CheckUpkeepReturnsFalseIfEnoughTimeHasPassed() public {
        //Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        //Act.
        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        //Assert.
        assertFalse(upkeepNeeded);
    }

    function testRaffle_CheckUpkeepReturnsTrueWhenParametersAreGood() public raffleEntered {

        //Act.
        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        //Assert.
        assert(upkeepNeeded);
    }
    /*//////////////////////////////////////////////////////////////
                             PERFORM UPKEEP
    //////////////////////////////////////////////////////////////*/

    function testRaffle_PerformUpkeepCanOnlyRunIfCheckUpkeppIsTrue() public raffleEntered {
      //Act / Assert
      raffle.checkUpkeep("");
    }

    function testRaffle_PerformUpkeepRevertIsCheckUpkeepIsFalse() public {
      //Arrange
      uint256 currentBalance = 0;
      uint256 numPlayers = 0;
      Raffle.RaffleState rState = raffle.getRaffleState();
      //Act / Assert.
      vm.expectRevert(
        abi.encodeWithSelector(Raffle.Raffle__UpKeepNeededNotPassed.selector, currentBalance, numPlayers, rState)
      );
      raffle.performUpkeep("");
    }

    function testPerformUpkeep_UpdatesRaffleStateAndEmitsRequestId() public raffleEntered {
      //Act.
      vm.recordLogs();
      raffle.performUpkeep("");
      Vm.Log[] memory entries = vm.getRecordedLogs();
      bytes32 requestId = entries[1].topics[1];
      //Assert.
      Raffle.RaffleState raffleState = raffle.getRaffleState();
      assert(uint256(requestId) > 0);
      assert(uint256(raffleState) == 1);
    }
    /*//////////////////////////////////////////////////////////////
                          FULFILL RANDOMWORDS
    //////////////////////////////////////////////////////////////*/
    function testFulfillRandomWords_CanOnlyBeCallebAfterPerformUpkeep(uint256 randomRequestId) public raffleEntered skipFork {
      //Arrange / Act. / assert
      vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
      VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(randomRequestId, address(raffle));
    }

    function testFulfillRandomWords_PicksAWinnerResetsAndSendMoney() public raffleEntered skipFork {
      //Arrange
      uint256 additionalEntrants = 3;
      uint256 startingIndex = 1;
      address expectedWinner = address(1);

      for (uint256 index = startingIndex; index < startingIndex + additionalEntrants; index++) {
        address newPlayer = address(uint160(index));
        hoax(newPlayer, 1 ether);
        raffle.enterRaffle{value: entranceFee}();
      }

      uint256 startingTimeStamp = raffle.getLastTimeStamp();
      uint256 startingWinnerBalance = expectedWinner.balance;

      //Act.
      vm.recordLogs();
      raffle.performUpkeep("");
      Vm.Log[] memory entries = vm.getRecordedLogs();
      bytes32 requestId = entries[1].topics[1];
      VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId), address(raffle));

      //Assert.
      address recentWinner = raffle.getRecentWinner();
      Raffle.RaffleState raffleState = raffle.getRaffleState();
      uint256 endingTimeStamp = raffle.getLastTimeStamp();
      uint256 winnerBalance = recentWinner.balance;
      uint256 prize = entranceFee * (additionalEntrants + startingIndex);

      assert(recentWinner == expectedWinner);
      assert(uint256(raffleState) == 0);
      assert(winnerBalance == startingWinnerBalance + prize);
      assert(endingTimeStamp > startingTimeStamp);
    }
}
