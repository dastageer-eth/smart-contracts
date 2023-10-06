// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./Structs.sol";

contract Mappings is Structs{
    mapping(uint256 => address) public appOwner;
    mapping(uint256 => uint256) public appIntervalDispute;
    mapping(uint256 => uint256) public appIntervalClaim;
    mapping(uint256 => uint256) public appIntervalRefuse;
    mapping(uint256 => string) public appURI;
    mapping(uint256 => string) public appName;
    mapping(uint256 => uint8) public appModCommission;
    mapping(uint256 => uint8) public appOwnerCommission;
    mapping(uint256 => uint8) public orderModAResolution;
    mapping(uint256 => uint8) public orderModBResolution;
    mapping(uint256 => Order) public orderBook;
    mapping(uint256 => Dispute) public disputeBook;
    mapping(address => mapping(address => uint256)) public userBalance;
}
