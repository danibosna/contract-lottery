// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {Raffle} from "src/Raffle.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";

contract RaffleTest is Test {
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

    function testRaffle_DontAllowPlayersToEnterWhileStateIsCalculating() public {
        // Arrange.
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
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

    function testRaffle_CheckUpkeepReturnsFalseIfRaffleIsntOpen() public {
        // Arrange.
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
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

    function testRaffle_CheckUpkeepReturnsTrueWhenParametersAreGood() public {
        // Arrange.
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        //Act.
        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        //Assert.
        assert(upkeepNeeded);
    }
    /*//////////////////////////////////////////////////////////////
                             PERFORM UPKEEP
    //////////////////////////////////////////////////////////////*/

    function testRaffle_PerformUpkeepCanOnlyRunIfCheckUpkeppIsTrue() public {
      //Arrange
      vm.prank(PLAYER);
      raffle.enterRaffle{value: entranceFee}();
      vm.warp(block.timestamp + interval + 1);
      vm.roll(block.number + 1);
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
}
