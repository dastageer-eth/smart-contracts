// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./Utils/Errors.sol";

contract DanToken is ERC20, Errors {
    uint256 public tokenPrice;
    address public vaultAddress;
    address public GovernerAddress;

    constructor(
        address _governerAddress,
        address _vaultAddress,
        uint256 _price
    ) ERC20("DanToken", "DT") {
        _mint(address(this), 5000 * 10 ** decimals());
        tokenPrice = _price;
        vaultAddress = _vaultAddress;
        GovernerAddress = _governerAddress;
    }

    function updatePrice(uint256 _price) external {
        if (msg.sender != GovernerAddress) revert NotAuthorised(401);
        tokenPrice = _price;
    }

    function getToken(uint256 amount) external payable {
        if (msg.value != amount * tokenPrice) revert TotalAmountNotSend(402);
        IERC20(address(this)).transfer(msg.sender, amount * 10 ** decimals());
        (bool success, ) = payable(vaultAddress).call{value: msg.value}("");
        if (!success) {
            revert PaymentFailed(403);
        }
    }
}
