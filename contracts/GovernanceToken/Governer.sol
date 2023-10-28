//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./Interfaces/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./Helpers/verifySignature.sol";
import "./Utils/Errors.sol";
import "./Interfaces/IVault.sol";
import "./Utils/Events.sol";

/*
    Error Code
    401 := Unauthorized
    403:= Forbidden
*/

contract DAOGoverner is Errors, Events, VerifySiganture, Ownable {
    address public VaultAddress;
    address public GovernanceTokenAddress;
    address[] public governersAddress;

    constructor(
        address[] memory _DAOOwners,
        address _vaultAddress
    ) Ownable(msg.sender) {
        for (uint128 i = 0; i < _DAOOwners.length; i++) {
            governersAddress.push(_DAOOwners[i]);
        }
        VaultAddress = _vaultAddress;
    }

    function _verifyAllSignature(
        string memory message,
        bytes[] memory ownerSignatures
    ) internal view returns (bool) {
        uint256 governerLength = governersAddress.length;
        uint256 supportCounter;

        if (governerLength != ownerSignatures.length)
            revert AllOwnerNotSupport(401);

        for (uint128 i = 0; i < governerLength; i++) {
            bool support = verify(
                governersAddress[i],
                message,
                ownerSignatures[i]
            );
            if (support) {
                supportCounter++;
            }
        }

        if (supportCounter == governerLength) {
            return true;
        }
        return false;
    }

    function updateTokenPrice(
        uint256 updatedPrice,
        string memory message,
        bytes[] memory ownerSignatures
    ) external {
        bool support = _verifyAllSignature(message, ownerSignatures);
        if (support) {
            IERC20(GovernanceTokenAddress).updatePrice(updatedPrice);
        }
        emit PriceUpdated(updatedPrice);
    }

    function increaseSupply(
        uint256 amount,
        string memory message,
        bytes[] memory ownerSignatures
    ) external {
        bool support = _verifyAllSignature(message, ownerSignatures);
        if (support) {
            bool success = IVault(VaultAddress).reSupplyToken(
                amount * 10 ** IERC20(GovernanceTokenAddress).decimals()
            );
            if (!success) {
                revert ExternalCallFailed(500);
            }
        } else {
            revert AllOwnerNotSupport(401);
        }
        emit TokenResuppiled(amount);
    }
}

//["0x5B38Da6a701c568545dCfcB03FcB875f56beddC4","0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2","0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db"]
