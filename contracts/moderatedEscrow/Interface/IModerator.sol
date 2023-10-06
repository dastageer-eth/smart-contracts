// SPDX-License-Identifier: UNLICENSED 
pragma solidity ^0.8.13;

interface IModerator {
    function getModOwner(uint256 modId) external view returns (address);

    function getMaxModId() external view returns (uint256);

    function updateModScore(
        uint256 modId,
        bool ifSuccess
    ) external returns (bool);
}
