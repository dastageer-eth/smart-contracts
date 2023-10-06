// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "./Helper/ERC721Metadata.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./Interface/IEscrow.sol";
import "./Interface/IModerator.sol";

contract Moderator is IModerator, ERC721Enumerable, ERC721Metadata, Ownable {
    uint256 public maxSupply = 4000000;

    mapping(uint256 => uint256) public modTotalScore;
    mapping(uint256 => uint256) public modSuccessScore;
    mapping(uint256 => uint8) public modSuccessRate;

    event Mint(uint256 indexed modId);

    event UpdateScore(uint256 indexed modId, bool indexed ifSuccess);

    address payable public escrowAddress;

    constructor() public ERC721Metadata("DastageerModEscrow", "DME") {}

    // set escrow contract address
    function setEscrow(address payable _escrow) public onlyOwner {
        IEscrow EscrowContract = IEscrow(_escrow);
        require(
            EscrowContract.getModAddress() == address(this),
            "Mod: wrong escrow contract address"
        );
        escrowAddress = _escrow;
    }

    // mint a new mod
    function mint() public onlyOwner {
        uint256 tokenId = totalSupply() + (1);
        require(tokenId <= maxSupply, "Mod: supply reach the max limit!");
        _safeMint(_msgSender(), tokenId);
        // set default mod score
        modTotalScore[tokenId] = 1;
        // emit mint event
        emit Mint(tokenId);
    }

    // get mod's total supply
    function getMaxModId() external view returns (uint256) {
        return totalSupply();
    }

    // get mod's owner
    function getModOwner(uint256 modId) external view returns (address) {
        require(modId <= totalSupply(), "Mod: illegal moderator ID!");
        return ownerOf(modId);
    }

    // update mod's score
    function updateModScore(
        uint256 modId,
        bool ifSuccess
    ) external returns (bool) {
        //Only Escrow contract can increase score
        require(
            escrowAddress == msg.sender,
            "Mod: only escrow contract can update mod score"
        );
        //total score add 1
        modTotalScore[modId] = modTotalScore[modId] + 1;
        if (ifSuccess) {
            // success score add 1
            modSuccessScore[modId] = modSuccessScore[modId] + 1;
        } else if (modSuccessScore[modId] > 0) {
            modSuccessScore[modId] = modSuccessScore[modId] - 1;
        } else {
            // nothing changed
        }
        // recount mod success rate
        modSuccessRate[modId] = uint8(
            (modSuccessScore[modId] * 100) / (modTotalScore[modId])
        );
        // emit event
        emit UpdateScore(modId, ifSuccess);
        return true;
    }
}
