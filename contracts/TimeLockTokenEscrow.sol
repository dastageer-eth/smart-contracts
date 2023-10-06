// SPDX-License-Identifier: UNLICENSED 
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract TimeLockTokenEscrow is ReentrancyGuard {
    event Lockup(
        address indexed _creator,
        address indexed _beneficiary,
        uint256 indexed _amount,
        uint256 _lockedUntil
    );

    event LockupReverted(
        address indexed _creator,
        address indexed _beneficiary,
        uint256 indexed _amount
    );

    event Withdrawal(address indexed _beneficiary, address indexed _caller);

    struct TimeLock {
        address creator;
        uint256 amount;
        uint256 lockedUntil;
    }

    IERC20 public token;

    mapping(address => TimeLock) public beneficiaryToTimeLock;

    constructor(IERC20 _token) public {
        token = _token;
    }

    function lock(
        address _beneficiary,
        uint256 _amount,
        uint256 _lockedUntil
    ) external nonReentrant {
        require(
            _beneficiary != address(0),
            "You cannot lock up tokens for the zero address"
        );
        require(_amount > 0, "Lock up amount of zero tokens is invalid");
        require(
            beneficiaryToTimeLock[_beneficiary].amount == 0,
            "Tokens have already been locked up for the given address"
        );
        require(
            token.allowance(msg.sender, address(this)) >= _amount,
            "The contract does not have enough of an allowance to escrow"
        );

        beneficiaryToTimeLock[_beneficiary] = TimeLock({
            creator: msg.sender,
            amount: _amount,
            lockedUntil: _lockedUntil
        });

        bool transferSuccess = token.transferFrom(
            msg.sender,
            address(this),
            _amount
        );
        require(transferSuccess, "Failed to escrow tokens into the contract");

        emit Lockup(msg.sender, _beneficiary, _amount, _lockedUntil);
    }

    function revertLock(address _beneficiary) external nonReentrant {
        TimeLock storage lockup = beneficiaryToTimeLock[_beneficiary];
        require(
            lockup.creator == msg.sender,
            "Cannot revert a lock unless you are the creator"
        );
        require(
            lockup.amount > 0,
            "There are no tokens left to revert lock up for this address"
        );

        uint256 transferAmount = lockup.amount;
        lockup.amount = 0;

        bool transferSuccess = token.transfer(lockup.creator, transferAmount);
        require(transferSuccess, "Failed to send tokens back to lock creator");

        emit LockupReverted(msg.sender, _beneficiary, transferAmount);
    }

    function withdrawal(address _beneficiary) external nonReentrant {
        TimeLock storage lockup = beneficiaryToTimeLock[_beneficiary];
        require(
            lockup.amount > 0,
            "There are no tokens locked up for this address"
        );
        require(now >= lockup.lockedUntil, "Tokens are still locked up");

        uint256 transferAmount = lockup.amount;
        lockup.amount = 0;

        bool transferSuccess = token.transfer(_beneficiary, transferAmount);
        require(transferSuccess, "Failed to send tokens to the beneficiary");

        emit Withdrawal(_beneficiary, msg.sender);
    }
}
