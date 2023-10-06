// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract Structs{

    struct Order {
        uint256 appId; 
        uint256 amount; 
        address coinAddress; 
        address buyer; 
        address seller; 
        uint256 createdTime; 
        uint256 claimTime; 
        uint8 status; 
        uint256 modAId; 
    }

      struct Dispute {
        uint256 refund; 
        uint256 modBId; 
        uint256 refuseExpired;
    }

}