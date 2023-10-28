// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./Utils/Errors.sol";

contract Vault is Errors {
    address public GovernanceTokenAddress;
    address public DAOAddress;

    mapping(uint256 => uint256) public amountToPay;

    function setTokenAddress(address _address) external {
        GovernanceTokenAddress = _address;
    }

    function setDAOAddress(address _daoAddress) external {
        DAOAddress = _daoAddress;
    }

    function reSupplyToken(uint256 _amount) external returns (bool) {
        if (msg.sender != GovernanceTokenAddress) revert NotAuthorised(401);
        if (IERC20(GovernanceTokenAddress).balanceOf(address(this)) <= _amount)
            revert NotEnoughtToken(403);
        IERC20(GovernanceTokenAddress).transfer(
            GovernanceTokenAddress,
            _amount
        );
        return true;
    }

    function withdrawFunds(
        uint256 _proposalId,
        address _receipentAddress
    ) external returns (bool) {
        if (msg.sender != DAOAddress) revert NotAuthorised(401);
        (bool success, ) = payable(_receipentAddress).call{
            value: amountToPay[_proposalId]
        }("");
        if (!success) {
            revert PaymentFailed(403);
        }
        return success;
    }

    function updateAmount(
        uint256 _proposalId,
        uint256 _amount
    ) external returns (bool) {
        if (msg.sender != DAOAddress) revert NotAuthorised(401);
        amountToPay[_proposalId] += _amount;
        return true;
    }

    function getTotalAmount(
        uint256 _proposalId
    ) external view returns (uint256) {
        return amountToPay[_proposalId];
    }

    receive() external payable {}
}
