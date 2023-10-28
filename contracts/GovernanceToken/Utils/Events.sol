//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract Events {
    event NewProposal(
        uint256 indexed proposalId,
        address indexed proposer,
        string description
    );

    event ProposalExecuted(
        uint256 indexed proposalId,
        address indexed proposer,
        address indexed recipient,
        uint256 amount
    );

    event VoteCasted(
        address indexed casterAddress,
        uint256 indexed proposalId,
        uint256 time
    );

    event TokenResuppiled(uint256 amount);

    event PriceUpdated(uint256 price);
}
