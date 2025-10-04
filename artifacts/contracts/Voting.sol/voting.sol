// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Voting {
    struct Candidate {
        string name;
        uint256 voteCount;
        bool finalized;
    }

    Candidate[] public candidates;
    address public owner;

    mapping(address => bool) public voters;
    mapping(address => bool) public validators;
    address[] public validatorList;

    mapping(uint256 => address[]) public voteConfirmations;
    mapping(address => uint256) public stakes;
    uint256 public CAP = 10 ether;

    uint256 public votingStart;
    uint256 public votingEnd;

    constructor(string[] memory _candidateNames, uint256 _durationInMinutes) {
        owner = msg.sender;
        votingStart = block.timestamp;
        votingEnd = block.timestamp + (_durationInMinutes * 1 minutes);

        for (uint256 i = 0; i < _candidateNames.length; i++) {
            candidates.push(Candidate({
                name: _candidateNames[i],
                voteCount: 0,
                finalized: false
            }));
        }
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    modifier onlyValidator() {
        require(validators[msg.sender], "Only validator");
        _;
    }

    modifier votingActive() {
        require(block.timestamp >= votingStart && block.timestamp < votingEnd, "Voting not active");
        _;
    }

    // Candidate Management
    function addCandidate(string memory _name) public onlyOwner {
        candidates.push(Candidate({
            name: _name,
            voteCount: 0,
            finalized: false
        }));
    }

    // Validator Management
    function addValidator(address _validator) public onlyOwner {
        require(!validators[_validator], "Already validator");
        validators[_validator] = true;
        validatorList.push(_validator);
    }

    function stake() public payable onlyValidator {
        stakes[msg.sender] += msg.value;
    }

    // Voting
    function vote(uint256 _candidateIndex) public votingActive {
        require(!voters[msg.sender], "Already voted");
        require(_candidateIndex < candidates.length, "Invalid candidate");

        uint256 weight = 1;
        if (validators[msg.sender]) {
            weight = stakes[msg.sender] > CAP ? CAP : stakes[msg.sender];
        }

        candidates[_candidateIndex].voteCount += weight;
        voters[msg.sender] = true;
    }

    // PBFT-style vote confirmation
    function confirmVote(uint256 _candidateIndex) public onlyValidator {
        require(_candidateIndex < candidates.length, "Invalid candidate");
        require(!candidates[_candidateIndex].finalized, "Already finalized");

        // prevent double confirmation
        for (uint i = 0; i < voteConfirmations[_candidateIndex].length; i++) {
            require(voteConfirmations[_candidateIndex][i] != msg.sender, "Already confirmed");
        }

        voteConfirmations[_candidateIndex].push(msg.sender);

        if(voteConfirmations[_candidateIndex].length * 3 >= validatorList.length * 2) {
            candidates[_candidateIndex].finalized = true;
        }
    }

    // Views
    function getAllVotesOfCandidates() public view returns (Candidate[] memory) {
        return candidates;
    }

    function getVotingStatus() public view returns (bool) {
        return block.timestamp >= votingStart && block.timestamp < votingEnd;
    }

    function getRemainingTime() public view returns (uint256) {
        if (block.timestamp < votingStart) return votingStart - block.timestamp;
        if (block.timestamp >= votingEnd) return 0;
        return votingEnd - block.timestamp;
    }

    function getVotingWeight(address _validator) public view returns (uint256) {
        require(validators[_validator], "Not a validator");
        return stakes[_validator] > CAP ? CAP : stakes[_validator];
    }

    function getConfirmations(uint256 _candidateIndex) public view returns (uint256) {
        return voteConfirmations[_candidateIndex].length;
    }
}
