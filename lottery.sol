// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

contract Lottery is ReentrancyGuard, Ownable, VRFConsumerBaseV2 {
    VRFCoordinatorV2Interface COORDINATOR;
    bytes32 keyHash;
    uint64 subscriptionId;
    uint32 callbackGasLimit = 100000;
    uint16 requestConfirmations = 3;
    uint32 numWords = 1; // Number of random words requested

    uint256 public entryFee;
    address[] public participants;
    bool public lotteryActive;
    uint256 public lotteryEndTime;

    uint256 public randomResult; // Store the random number from Chainlink

    event LotteryEntry(address indexed participant);
    event WinnerSelected(address indexed winner, uint256 amount);
    event LotteryStarted();
    event LotteryStopped();
    event RandomNumberRequested(uint256 requestId);

    constructor(
        uint256 _entryFee,
        address _vrfCoordinator,
        bytes32 _keyHash,
        uint64 _subscriptionId
    ) VRFConsumerBaseV2(_vrfCoordinator) Ownable(msg.sender) {
        require(_entryFee > 0, "Entry fee must be greater than 0");
        entryFee = _entryFee;
        lotteryActive = false;

        COORDINATOR = VRFCoordinatorV2Interface(_vrfCoordinator);
        keyHash = _keyHash;
        subscriptionId = _subscriptionId;
    }

    function enterLottery() public payable {
        require(lotteryActive, "Lottery is not active");
        require(block.timestamp < lotteryEndTime, "Lottery has ended");
        require(msg.value == entryFee, "Incorrect entry fee");
        participants.push(msg.sender);
        emit LotteryEntry(msg.sender);
    }

    function startLottery(uint256 _duration) external onlyOwner {
        require(!lotteryActive, "Lottery already active");
        lotteryActive = true;
        lotteryEndTime = block.timestamp + _duration; 
        emit LotteryStarted();
    }

    function stopLottery() external onlyOwner {
        require(lotteryActive, "Lottery not active");
        lotteryActive = false;
        emit LotteryStopped();
    }

    function selectWinner() external onlyOwner {
        require(lotteryActive, "Lottery is not active");
        require(participants.length > 0, "No participants in the lottery");
        require(randomResult != 0, "Waiting for random number");

        uint256 index = randomResult % participants.length;
        address winner = participants[index];

        emit WinnerSelected(winner, address(this).balance);
        (bool success, ) = winner.call{value: address(this).balance}("");
        require(success, "Transfer failed");

        randomResult = 0; // Reset
        lotteryActive = false;
        delete participants;
    }

    // Function to request a random number from Chainlink VRF
    function requestRandomNumber() internal {
        uint256 requestId = COORDINATOR.requestRandomWords(
            keyHash,
            subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            numWords
        );
        emit RandomNumberRequested(requestId);
    }

  function fulfillRandomWords(
      uint256 /* requestId */, 
      uint256[] memory randomWords 
  ) internal override {
      randomResult = randomWords[0];
  }

    receive() external payable {
        revert("Please use the enterLottery function to participate.");
    }
}
