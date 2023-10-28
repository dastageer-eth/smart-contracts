// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IVault {
    function reSupplyToken(uint256 amount) external returns (bool);

    function updateAmount(
        uint256 proposalId,
        uint256 amount
    ) external returns (bool);

    function getTotalAmount(uint256 proposalId) external view returns (uint256);

    function withdrawFunds(
        uint256 _proposalId,
        address _receipentAddress
    ) external returns (bool);
}
