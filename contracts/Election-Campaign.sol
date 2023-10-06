// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.9;
contract Election {
    address public admin;
    uint public campaingn_counter;
    uint public winnerGetvotes;

    constructor () {
        admin = msg.sender;
    }

    struct Campaingn {
        uint totalVotes;
        uint startTime;
        uint endTime;
        address winner;
        mapping (address => bool) isVoted;
        mapping (address => bool) isAppliedForParticipation;
        mapping (address => bool) isWhitelistedForParticipation;
        mapping (address => uint) participantVotes;
    }

    mapping (address => bool) isAppliedForVoting;
    mapping (address => bool) isWhitelistedForVoting;
    mapping (uint => Campaingn) campaigns;

    modifier isAdmin {
        require (msg.sender == admin,"Caller Is Not Owner");
        _;
    }

    modifier isChecked(address _participant){
        require(isWhitelistedForVoting[msg.sender]==true,"voter is not whitelisted for voting.");
        require(campaigns[campaingn_counter].isWhitelistedForParticipation[_participant]==true,"participant is not whitelisted for participation.");
        require(campaigns[campaingn_counter].isVoted[msg.sender]==false,"you have been already voted.");
        _;
    }

    modifier checkTime(){
        require(block.timestamp > campaigns[campaingn_counter].startTime && block.timestamp<campaigns[campaingn_counter].endTime,"Either campaign is not started yet or Campaign time is over");
        _;
    }

    function startCampaign(uint endTime_) external isAdmin returns(bool) {
        campaingn_counter += 1;
        campaigns[campaingn_counter].startTime = block.timestamp;
        campaigns[campaingn_counter].endTime = campaigns[campaingn_counter].startTime + endTime_;
        return true;
    }

    function applyForParticipation(address _participant) public checkTime{
        require(campaigns[campaingn_counter].isAppliedForParticipation[_participant]==false,"you have been already applied.");
        campaigns[campaingn_counter].isAppliedForParticipation[_participant]=true;
    }

    function whitelistedForParticipation(address _participant) public checkTime isAdmin{
        require(campaigns[campaingn_counter].isAppliedForParticipation[_participant]==true,"participant has not applied for participation.");
        require(campaigns[campaingn_counter].isWhitelistedForParticipation[_participant]==false,"Participant has been already whitelisted.");
        campaigns[campaingn_counter].isWhitelistedForParticipation[_participant]=true;
    }

    function applyForVoting(address _voter) public checkTime{
        require(isAppliedForVoting[_voter]==false,"you have been already applied.");
        isAppliedForVoting[_voter]=true;
    }

    function whiteListedForVoting(address _voter) public checkTime isAdmin{
        require(isAppliedForVoting[_voter]==true,"voter has not applied for voting.");
        require(isWhitelistedForVoting[_voter]==false,"voter has been already whitelisted.");
        isWhitelistedForVoting[_voter]=true;
    }

    function giveVote(address _participant) public checkTime isChecked(_participant){
        uint temp;
        campaigns[campaingn_counter].participantVotes[_participant]+=1;
        campaigns[campaingn_counter].isVoted[msg.sender]=true;
        campaigns[campaingn_counter].totalVotes++;
        temp=campaigns[campaingn_counter].participantVotes[_participant];
        if(temp>winnerGetvotes){
            campaigns[campaingn_counter].winner=_participant;
            winnerGetvotes=temp;
        }
    }

    function declareWinner() public view returns(address winner) {
        return (campaigns[campaingn_counter].winner);
    }

    function campaingnData(uint campaingnNo) public view returns(uint totalVotes,uint startTime,uint endTime,address Winner){
        return (
            campaigns[campaingnNo].totalVotes,
            campaigns[campaingnNo].startTime,
            campaigns[campaingnNo].endTime,
            campaigns[campaingnNo].winner
        );
    }

    function campaignsVerificationData(uint campaingnNo,address _person) public view 
    returns(bool AppliedForVoting,bool WhitelistedForVoting,bool AppliedForParticipation,bool WhitelistedForParticipation,bool Voted){
        return (
            isAppliedForVoting[_person],
            isWhitelistedForVoting[_person],
            campaigns[campaingnNo].isAppliedForParticipation[_person],
            campaigns[campaingnNo].isWhitelistedForParticipation[_person],
            campaigns[campaingnNo].isVoted[_person]
        );
    }
}