const {loadFixture} = require("@nomicfoundation/hardhat-network-helpers");

const {ethers} = require("hardhat");
const {expect} = require("chai");

const amountA = 25;
const amountB = 40;
const amountC = 35;
const factor = 10 ** 6;

describe("Voting dao tests", function () {

    async function deploy() {
        const [A, B, C] = await ethers.getSigners();

        const VotingToken = await ethers.getContractFactory("Fantik");
        const votingToken = await VotingToken.deploy();

        const Dao = await ethers.getContractFactory("VotingDao");
        const votingDao = await Dao.deploy(votingToken.address);

        console.log("\tVotingDao was deployed to:", votingDao.address);

        await votingToken.connect(A).transfer(A.address, amountA * factor);
        await votingToken.connect(A).transfer(B.address, amountB * factor);
        await votingToken.connect(A).transfer(C.address, amountC * factor);
        await votingToken.connect(A).delegate(A.address);
        await votingToken.connect(B).delegate(B.address);
        await votingToken.connect(C).delegate(C.address);

        console.log("\tTransfering: ", amountA ," were transfered to A by address:", A.address);
        console.log("\tTransfering: ", amountB ," were transfered to B by address:", B.address);
        console.log("\tTransfering: ", amountC ," were transfered to C by address:", C.address);

        return {
            A,
            B,
            C,
            votingToken,
            votingDao
        };
    }

    describe("Deployment", function () {
        it("Should deploy the voting dao contract", async function () {
            const {votingDao} = await loadFixture(deploy);

            expect(votingDao.address).to.properAddress;
        });

        it("Should set the address of voting contract", async function () {
            const {votingDao, votingToken} = await loadFixture(deploy);

            expect(await votingDao.getVotingToken()).to.equal(votingToken.address);
        });

        it("Should be right total supply", async function () {
            const {votingToken} = await loadFixture(deploy);

            const sumAmount = amountA + amountB + amountC;
            expect(await votingToken.totalSupply()).to.equal(sumAmount * factor);
        });
    });

    describe("Proposals", function () {
        it("Should create a proposal", async function () {
            const {votingDao, A} = await loadFixture(deploy);

            const hash = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("First proposal"));

            await votingDao.connect(A).createProposal(hash);
            console.log("\tProposals: request to createProposal sent by A with hash:", hash);
            
            const tx = await votingDao.connect(A).createProposal(hash);
            const receipt = await tx.wait();

            const [event] = receipt.events.filter((e) => e.event === "ProposalCreated");
            expect(await event != null);
        });
    });
});