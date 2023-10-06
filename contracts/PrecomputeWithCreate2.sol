// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/utils/Counters.sol";

contract FactoryAssembly {
    using Counters for Counters.Counter;

    Counters.Counter private _nonce;

    event Deployed(address addr, uint salt);
    event Salt(uint256 salt);

    function getBytecode(
        address owner_,
        uint randomValue_
    ) public pure returns (bytes memory) {
        bytes memory bytecode = type(TestContract).creationCode;

        return abi.encodePacked(bytecode, abi.encode(owner_, randomValue_));
    }

    function generateSalt() public returns (uint256 randomNumber) {
        uint256 salt = _nonce.current();
        randomNumber = uint256(
            keccak256(
                abi.encode(
                    msg.sender,
                    tx.gasprice,
                    block.number,
                    block.timestamp,
                    block.difficulty,
                    blockhash(block.number - 1),
                    address(this),
                    salt
                )
            )
        );
        _nonce.increment();
        emit Salt(randomNumber);
    }

    function getAddress(
        bytes memory bytecode_,
        uint256 salt_
    ) public view returns (address) {
        bytes32 hash = keccak256(
            abi.encodePacked(
                bytes1(0xff),
                address(this),
                salt_,
                keccak256(bytecode_)
            )
        );
        return address(uint160(uint(hash)));
    }

    function deploy(bytes memory bytecode, uint _salt) public payable {
        address addr;
        assembly {
            addr := create2(
                callvalue(),
                add(bytecode, 0x20),
                mload(bytecode),
                _salt
            )

            if iszero(extcodesize(addr)) {
                revert(0, 0)
            }
        }
        emit Deployed(addr, _salt);
    }
}

contract TestContract {
    address public owner;
    uint public randomValue;

    constructor(address owner_, uint randomValue_) payable {
        owner = owner_;
        randomValue = randomValue_;
    }

    function getBalance() public view returns (uint) {
        return address(this).balance;
    }
}
