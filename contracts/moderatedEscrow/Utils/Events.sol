// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract Events {
    event Withdraw(
        address indexed user,
        uint256 indexed amount,
        address indexed coinContract
    );

    event NewApp(uint256 indexed appId);

    event PayOrder(
        uint256 indexed orderId,
        uint256 indexed appOrderId,
        address indexed coinAddress,
        uint256 amount,
        address buyer,
        address seller,
        uint256 appId,
        uint256 modAId
    );

    event ConfirmDone(uint256 indexed appId, uint256 indexed orderId);

    event AskRefund(
        uint256 indexed appId,
        uint256 indexed orderId,
        uint256 indexed refund
    );

    event CancelRefund(uint256 indexed appId, uint256 indexed orderId);

    event RefuseRefund(uint256 indexed appId, uint256 indexed orderId);

    event Escalate(uint256 indexed appId, uint256 indexed orderId);

    event Resolve(
        address indexed user,
        bool indexed isAgree,
        uint256 indexed orderId,
        uint256 appId,
        uint8 modType 
    );

    event ResolvedFinally(
        uint256 indexed appId,
        uint256 indexed orderId,
        uint8 indexed refundType 
    );

    event Claim(
        address indexed user,
        uint256 indexed appId,
        uint256 indexed orderId
    );

    event UserBalanceChanged(
        address indexed user,
        bool indexed isIn,
        uint256 indexed amount,
        address coinAddress,
        uint256 appId,
        uint256 orderId
    );
}
