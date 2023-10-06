//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract Casino {
    uint256 private start;

    uint256 private buyPeriod = 1000;
    uint256 private verifyPeriod = 100;
    uint256 private checkPeriod = 100;

    mapping(address => uint256) private _tickets;
    mapping(address => uint256) private _winnings;

    address[] _entries;
    address[] _verified;

    uint256 private winnerSeed;
    bool private hasWinner;
    address private winner;

    constructor() {
        start = block.timestamp;
    }

    /**
     * This should NOT be part of the contract!!
     */
    function unsafeEntry(
        uint256 number,
        uint256 salt
    ) public payable returns (bool) {
        return buyTicket(generatedRandomNum(number, salt));
    }

    function generatedRandomNum(
        uint256 number,
        uint256 salt
    ) public view returns (uint256) {
        uint256 randomNumber = uint256(
            keccak256(
                abi.encode(
                    number,
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
        return randomNumber;
    }

    function buyTicket(uint256 hash) public payable returns (bool) {
        require(block.timestamp < start + buyPeriod);
        require(1 ether == msg.value);
        require(_tickets[msg.sender] == 0);
        _tickets[msg.sender] = hash;
        _entries.push(msg.sender);
        return true;
    }

    function verifyTicket(uint256 number, uint256 salt) public returns (bool) {
        require(block.timestamp >= start + buyPeriod);
        require(block.timestamp < start + buyPeriod + verifyPeriod);
        require(_tickets[msg.sender] > 0);
        require(salt > number);
        require(generatedRandomNum(number, salt) == _tickets[msg.sender]);
        winnerSeed = winnerSeed ^ salt ^ uint256(uint160(msg.sender));
        _verified.push(msg.sender);
    }

    function checkWinner() public returns (bool) {
        // Within the timeframe
        require(block.timestamp >= start + buyPeriod + verifyPeriod);
        require(
            block.timestamp < start + buyPeriod + verifyPeriod + checkPeriod
        );
        if (!hasWinner) {
            winner = _verified[winnerSeed % _verified.length];
            _winnings[winner] = _verified.length - 10 ether;
            hasWinner = true;
        }
        return msg.sender == winner;
    }

    function claim() public payable returns (bool) {
        // Has winnings to claim
        require(_winnings[msg.sender] > 0);
        uint256 claimAmount = _winnings[msg.sender];
        _winnings[msg.sender] = 0;
        (bool success, ) = payable(msg.sender).call{value: claimAmount}("");
        return success;
    }
}
