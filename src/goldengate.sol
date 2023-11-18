// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract GoldenGate {
    uint256 public intentCounter;
    uint256 public bidCounter;

    event NewIntent(
        uint256 indexed intentUid,
        uint256 amountDeposited,
        uint256 minAmountRecv,
        uint256 chainIdDestination,
        address beneficiaryAddress
    );

    struct Intent {
        uint256 amount;
        uint256 minAmountRecv;
        uint256 chainId;
        address beneficiaryAddress;
        bool executed;
        bool returned;
        address owner;
        address fulfiller;
        uint256 timestamp;
    }

    Intent[] public intents;

    event IntentBid(
        uint256 indexed sourceChainId,
        uint256 indexed sourceIntentUid,
        uint256 indexed bidUid,
        uint256 amountProposed
    );

    struct Bid {
        uint256 sourceChainId;
        uint256 intentUid;
        uint256 bidUid;
        uint256 amountProposed;
        address proposer;
        address destination;            // Address bridged funds will be sent to
        address forwarding;             // Address where source funds will be returned
        bool executed;
        bool returned;
        uint256 timestamp;
    }

    Bid[] public bids;

    mapping (bytes32 => bool) satisfiedIntents;

    constructor() {
        intentCounter = 0;
        bidCounter = 0;
    }

    // Called by a user who wants to bridge. This defines the terms of their intention
    function initiateNativeIntent(uint256 minAmountRecv, uint256 chainIdDestination, address beneficiary) external payable {
        require(msg.value > 0, "Amount deposited must be greater than 0");

        // TODO add when this was created so the initiator can withdraw at some point

        emit NewIntent(
            intentCounter++,
            msg.value,
            minAmountRecv,
            chainIdDestination,
            beneficiary
        );

        Intent memory newIntent = Intent({
            amount: msg.value,
            minAmountRecv: minAmountRecv,
            chainId: chainIdDestination,
            beneficiaryAddress: beneficiary,
            executed: false,
            returned: false,
            owner: msg.sender,
            fulfiller: address(0),
            timestamp: block.timestamp
        });

        intents.push(newIntent);
    }

    // General function to check current status of intent
    function getIntent(uint256 intentUid) public view returns (Intent memory) {
        return intents[intentUid];
    }

    // Called by a user who wants to bridge. This will settle based on the most desirable bid
    function acceptBid(uint256 destinationBid, uint256 intentUid) public {
        Intent storage intent = intents[intentUid];
        require(msg.sender == intent.owner, "Only owner can accept");
        require(!intent.executed, "Intent already executed");
        require(!intent.returned, "Intent already returned");
        
        intent.executed = true;
        // TODO trigger message to destination chain executing

        // destinationBid + intentUid
    }

    // Called by a user who wants to bridge. This will revert the intention and return the funds
    function rejectBids(uint256 intentUid) public {
        Intent storage intent = intents[intentUid];
        require(msg.sender == intent.owner, "Only owner can reject");
        require(!intent.executed, "Intent already executed");
        require(!intent.returned, "Intent already returned");
        require(block.timestamp >= intent.timestamp + 1 hours, "Can't reject yet");
        
        intent.returned = true;
        payable(intent.owner).transfer(intent.amount);
    }

    // Called by searcher to propose and stake collateral for a particular intent
    // Source chain, intent Id and destination taken from intent record
    // forwarding address is whether the source chain should send funds if
    // this bid is accepted
    function proposeNativeSolution(
        uint256 sourceChainId,
        uint256 intentUid,
        address destination,
        address forwarding) external payable {
        require(msg.value > 0, "Amount proposed must be greater than 0");

        emit IntentBid(
            sourceChainId,
            intentUid,
            bidCounter++,
            msg.value
        );

        Bid memory newBid = Bid({
            sourceChainId: sourceChainId,
            intentUid: intentUid,
            bidUid: bidCounter,
            amountProposed: msg.value,
            proposer: msg.sender,
            executed: false,
            returned: false,
            destination: destination,
            forwarding: forwarding,
            timestamp: block.timestamp
        });

        bids.push(newBid);
    }

    // Called by searcher to withdraw a bid if they change their mind or
    // their bid was not the winner of the auction
    function withdrawNativeBid(uint256 bidUid) external {
        Bid memory selectedBid = bids[bidUid];
        require(!selectedBid.executed, "Bid has already been executed!");
        require(!selectedBid.returned, "Bid has already been returned!");
        require(selectedBid.proposer == msg.sender, "Only the proposer can withdraw!");
        // Prevent refunding settlement later
        selectedBid.returned = true;
        payable(selectedBid.proposer).transfer(selectedBid.amountProposed);
    }

    // General function to check current status of intent
    function getBid(uint256 bidUid) public view returns (Bid memory) {
        return bids[bidUid];
    }

    // Called by x-chain sg to execute withdrawal
    function settleNativeIntent(uint256 sourceChainId, uint256 intentUid, uint256 bidId) public {
        bytes32 key = generateKey(sourceChainId, intentUid);
        // Prevent double settling of intent
        require(satisfiedIntents[key] == false, "Intent already settled");

        Bid memory selectedBid = bids[bidId];
        require(!selectedBid.executed, "Bid has already been executed!");
        require(!selectedBid.returned, "Bid has already been returned!");
        // Prevent refunding settlement later
        selectedBid.executed = true;
        // Prevent multiple settlements
        satisfiedIntents[key] = true;

        payable(selectedBid.destination).transfer(selectedBid.amountProposed);

        // TODO : send message to source chain with forwarding address
    }

    function generateKey(uint256 sourceChainId, uint256 intentUid) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(sourceChainId, intentUid));
    }
}
