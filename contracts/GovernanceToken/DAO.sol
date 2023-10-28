//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./Utils/Mappings.sol";
import "./Utils/Errors.sol";
import "./Utils/Events.sol";
import "./Interfaces/IVault.sol";
import "./Interfaces/IERC20.sol";

contract DAO is Mappings, Errors, Events {
    uint256 public constant MIN_PROPOSAL_THRESHOLD = 0.1 ether;
    uint256 public MIN_VOTING_THRESHOLD;

    uint256 public proposalCounter;
    address public vaultAddress;
    address public governanceTokenAddress;

    constructor(address vaultAdd, address gTokenAdd, uint256 MinThreshold) {
        vaultAddress = vaultAdd;
        governanceTokenAddress = gTokenAdd;
        MIN_VOTING_THRESHOLD =
            MinThreshold *
            10 ** IERC20(gTokenAdd).decimals();
    }

    function createProposal(
        string memory _description,
        uint256 _amounttoRaise,
        address payable _recipient
    ) external payable {
        if (msg.value != MIN_PROPOSAL_THRESHOLD) revert PaymentFailed(403);

        Proposal memory newProposal = Proposal({
            id: proposalCounter += 1,
            proposer: msg.sender,
            description: _description,
            amount: _amounttoRaise,
            recipient: _recipient,
            startTime: block.timestamp,
            endTime: block.timestamp + 7 days,
            yesVotes: 0,
            noVotes: 0,
            executed: false
        });

        proposedProposals[newProposal.id] = newProposal;
        activeProposals[newProposal.id] = true;
        (bool success, ) = payable(vaultAddress).call{value: msg.value}("");
        if (!success) {
            revert PaymentFailed(403);
        }
        emit NewProposal(newProposal.id, msg.sender, _description);
    }

    function vote(uint256 _proposalId, bool _support) external {
        if (
            IERC20(governanceTokenAddress).balanceOf(msg.sender) <=
            MIN_VOTING_THRESHOLD
        ) revert InsufficentBalance(428);

        if (!activeProposals[_proposalId]) revert InactivePraposal(412);

        if (block.timestamp <= proposedProposals[_proposalId].startTime)
            revert HasNotStarted(403);

        if (block.timestamp >= proposedProposals[_proposalId].endTime)
            revert HasEnded(403);

        if (voted[_proposalId][msg.sender]) revert AlreadyVoted(429);

        if (_support) {
            proposedProposals[_proposalId].yesVotes += 1;
        } else {
            proposedProposals[_proposalId].noVotes += 1;
        }

        voted[_proposalId][msg.sender] = true;

        IVault(vaultAddress).updateAmount(
            _proposalId,
            (1 * 10 ** IERC20(governanceTokenAddress).decimals()) *
                IERC20(governanceTokenAddress).tokenPrice()
        );

        IERC20(governanceTokenAddress).transferFrom(
            msg.sender,
            vaultAddress,
            1 * 10 ** IERC20(governanceTokenAddress).decimals()
        );

        emit VoteCasted(msg.sender, _proposalId, block.timestamp);
    }

    function executeProposal(uint256 _proposalId) external {
        if (proposedProposals[_proposalId].proposer == msg.sender)
            revert NotProposer(403);

        if (proposedProposals[_proposalId].executed)
            revert AlreadyExecuted(503);

        if (block.timestamp < proposedProposals[_proposalId].endTime)
            revert StillRunning(425);

        if (
            proposedProposals[_proposalId].yesVotes <
            proposedProposals[_proposalId].noVotes
        ) revert FailedProposal(424);

        proposedProposals[_proposalId].executed = true;
        activeProposals[_proposalId] = false;

        bool success = IVault(vaultAddress).withdrawFunds(
            _proposalId,
            proposedProposals[_proposalId].recipient
        );
        if (!success) {
            revert PaymentFailed(403);
        }

        emit ProposalExecuted(
            _proposalId,
            proposedProposals[_proposalId].proposer,
            proposedProposals[_proposalId].recipient,
            proposedProposals[_proposalId].amount
        );
    }
}
