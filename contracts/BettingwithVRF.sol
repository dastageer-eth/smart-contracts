// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

contract Lottery is VRFConsumerBaseV2 {
    VRFCoordinatorV2Interface COORDINATOR;

    address internal owner;
    address payable[] public players;
    uint64 s_subscriptionId;
    uint32 callbackGasLimit = 100000;
    uint16 requestConfirmations = 3;
    uint32 numWords = 1;
    uint256[] internal s_randomWords;

    address vrfCoordinator = 0x6168499c0cFfCaCD319c818142124B7A15E857ab;
    bytes32 keyHash =
        0xd89b2bf150e3b9e13446986e571fb9cab24b13cea0a43ea20a6049a85cc807cc;

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    constructor(uint64 subscriptionId) VRFConsumerBaseV2(vrfCoordinator) {
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        owner = msg.sender;
        s_subscriptionId = subscriptionId;
    }

    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function enter() public payable {
        // address of player entering lottery
        players.push(payable(msg.sender));
    }

    function getRandomNumber() internal returns (uint256) {
        uint256 s_requestId = COORDINATOR.requestRandomWords(
            keyHash,
            s_subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            numWords
        );
        return s_requestId;
    }

    function fulfillRandomWords(
        uint256,
        uint256[] memory randomWords
    ) internal override {
        s_randomWords = randomWords;
    }

    function pickWinner() external onlyOwner {
        uint256 index = getRandomNumber() % players.length;
        players[index].transfer(address(this).balance);

        // reset the state of the contract
        players = new address payable[](0);
    }
}
