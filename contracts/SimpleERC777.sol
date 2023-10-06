//SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC777/ERC777.sol";
import "@openzeppelin/contracts/token/ERC777/IERC777.sol";
import "@openzeppelin/contracts/utils/introspection/IERC1820Registry.sol";
import "@openzeppelin/contracts/utils/introspection/ERC1820Implementer.sol";
import "@openzeppelin/contracts/token/ERC777/IERC777Sender.sol";

contract SimpleERC777 is ERC777{
    constructor() ERC777("simpleToken", "ST", new address[](0)){
        _mint(msg.sender, 10000 * 10 ** 18, "", "");
    }
}

contract Simple777Sender is IERC777Sender, ERC1820Implementer {

    bytes32 constant public TOKENS_SENDER_INTERFACE_HASH = keccak256("ERC777TokensSender");

    event DoneStuff(address operator, address from, address to, uint256 amount, bytes userData, bytes operatorData);

    function senderFor(address account) public {
        _registerInterfaceForAddress(TOKENS_SENDER_INTERFACE_HASH, account);
    }

    function tokensToSend(
        address operator,
        address from,
        address to,
        uint256 amount,
        bytes calldata userData,
        bytes calldata operatorData
    ) external override {
        
        emit DoneStuff(operator, from, to, amount, userData, operatorData);
    }
}

contract Simple777Recipient is IERC777Recipient {

    IERC1820Registry private _erc1820 = IERC1820Registry(0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24);
    bytes32 constant private TOKENS_RECIPIENT_INTERFACE_HASH = keccak256("ERC777TokensRecipient");

    IERC777 private _token;

    event DoneStuff(address operator, address from, address to, uint256 amount, bytes userData, bytes operatorData);

    constructor (address token) {
        _token = IERC777(token);
        _erc1820.setInterfaceImplementer(address(this), TOKENS_RECIPIENT_INTERFACE_HASH, address(this));
    }

    function tokensReceived(
        address operator,
        address from,
        address to,
        uint256 amount,
        bytes calldata userData,
        bytes calldata operatorData
    ) external override {
        require(msg.sender == address(_token), "Simple777Recipient: Invalid token");

        emit DoneStuff(operator, from, to, amount, userData, operatorData);
    }
}
