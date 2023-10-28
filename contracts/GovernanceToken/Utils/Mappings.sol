// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./Structs.sol";

contract Mappings is Structs {
    mapping(uint256 => bool) public activeProposals;
    mapping(uint256 => mapping(address => bool)) public voted;
    mapping(uint256 => Proposal) public proposedProposals;
}
