//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract Errors {
    error AllOwnerNotSupport(uint256);
    error NotEnoughtToken(uint256);
    error TotalAmountNotSend(uint256);
    error NotAuthorised(uint256);
    error PaymentFailed(uint256);
    error ExternalCallFailed(uint256);
    error ActivePraposal(uint256);
    error InsufficentBalance(uint256);
    error InactivePraposal(uint256);
    error HasNotStarted(uint256);
    error HasEnded(uint256);
    error AlreadyVoted(uint256);
    error AlreadyExecuted(uint256);
    error StillRunning(uint256);
    error FailedProposal(uint256);
    error NotProposer(uint256);
}
