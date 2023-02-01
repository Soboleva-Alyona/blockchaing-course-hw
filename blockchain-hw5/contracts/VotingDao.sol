// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract VotingDao {

    /*
     *  Events
     */
    event ProposalCreated(bytes32 _hash);   
    event ProposalRejected(bytes32 _hash);
    event ProposalAccepted(bytes32 _hash);

    /*
     *  Constants
     */
    uint256 private constant TTL = 3 days;
    uint256 private constant MAX_PROPOSALS_CNT = 3;

    /*
     *  Storage
     */
    bytes32[MAX_PROPOSALS_CNT] private proposals;
    mapping(bytes32 => Proposal) proposalsIndexes;
    mapping(bytes32 => mapping(address => Votes)) hashToVotes;

    ERC20Votes private token;

    enum VoteSide {
        AGAINTS, 
        FOR 
    }

    struct Votes {
        uint256 agreed;
        uint256 against;
    }

    enum ProposalStatus {
        CREATED,
        ACCEPTED,
        REJECTED,
        DISCARDED
    }

    struct Proposal {
        ProposalStatus status;
        uint256 timeToExpire;
        Votes votesInfo;
        uint256 createrBlock;
    }

    constructor(address votes) {
        token = ERC20Votes(votes);
    }

    /*
     *  Modifiers
     */

    modifier proposalNotExpired(Proposal storage p) {
        require(
            p.status != ProposalStatus.DISCARDED, 
            "Proposal expired"
            );
        _;
    }

    modifier amountIsPositive(uint256 amount) {
        require(
            amount > 0, 
            "Vote amount can't be zero or less"
            );
        _;
    }

    modifier proposalNotExists(bytes32 hash) {
        require(
            proposalsIndexes[hash].timeToExpire == 0 , 
            Strings.toString(proposalsIndexes[hash].timeToExpire)
            );
        _;
    }

    /*
    * Creates proposal with given hash
    * Requirements:
    *   proposal with such hash should not be presented in queue
    */
    function createProposal(bytes32 pHash) external proposalNotExists(pHash)
    {
        uint256 ind = MAX_PROPOSALS_CNT + 1;
        uint256 cntObsolute = 0;
        uint256 mostObsoluteInd = 0;
        uint256 mostOldTime = 0;
        for (uint256 i = 0; i < MAX_PROPOSALS_CNT; i++) {
            bytes32 cur = proposals[i];
            Proposal storage p = proposalsIndexes[cur];
            if (p.status == ProposalStatus.DISCARDED || p.status == ProposalStatus.ACCEPTED || p.status == ProposalStatus.REJECTED) {
                ind = i;
            }
            if (p.timeToExpire <= block.timestamp) {
                cntObsolute++;
                if (p.timeToExpire < mostOldTime) {
                    mostOldTime = p.timeToExpire;
                    mostObsoluteInd = i;
                }
            }
        }
        if (cntObsolute == MAX_PROPOSALS_CNT) {
            bytes32 cur = proposals[mostObsoluteInd];
            proposalsIndexes[cur].status = ProposalStatus.DISCARDED;
            ind = mostObsoluteInd;
        }

        require(ind < MAX_PROPOSALS_CNT, "Proposals queue is full");

        proposalsIndexes[pHash] = Proposal({
            status: ProposalStatus.CREATED,
            timeToExpire: block.timestamp + TTL,
            votesInfo: Votes({
                agreed: 0,
                against: 0
                }),
            createrBlock: block.number
        }
        );
        proposals[ind] = pHash;
        emit ProposalCreated(pHash);        
    }

    function vote(bytes32 _hash, uint256 amount, bool agreed) external 
        proposalNotExpired(proposalsIndexes[_hash])
        amountIsPositive(amount) 
    {
        require(proposalsIndexes[_hash].timeToExpire != 0, "Proposal is not presented");

        Proposal storage p = proposalsIndexes[_hash];
        require(token.getVotes(msg.sender) >= amount, "Not enough balance on sender account"); 
        if (block.timestamp >= p.timeToExpire) {
            p.status = ProposalStatus.DISCARDED;
        }
    
        Votes storage votes = hashToVotes[_hash][msg.sender];
        if (agreed) {
            votes.agreed += amount;
            p.votesInfo.agreed += amount;
        } else {
            votes.against += amount;
            p.votesInfo.against += amount;
        }

        uint256 totalSupply = token.getPastTotalSupply(p.createrBlock);
        
        if (p.votesInfo.agreed > totalSupply / 2) {
            p.status = ProposalStatus.ACCEPTED;
            emit ProposalAccepted(_hash);
        } else if (p.votesInfo.against > totalSupply / 2) {
            p.status = ProposalStatus.REJECTED;
            emit ProposalRejected(_hash);
        } 
    }

    /*
    * View functions
    */
    function getVotingToken() public view returns (ERC20) {
        return token;
    }

}