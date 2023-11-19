// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IHyperlaneMailbox {
    function dispatch(
        uint32 destinationDomain,
        bytes32 recipient,
        bytes memory messageBody
    ) external payable returns (uint256);
}

contract GoldenGate {
    uint256 private _intentCounter;
    uint256 private _bidCounter;
    address private _mailbox;

    address private _operatorRelayer;

    mapping (uint32 => address) _chainMapping;

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
        uint32 chainId;
        address beneficiaryAddress;
        bool executed;
        bool returned;
        address owner;
        address fulfiller;
        uint256 timestamp;
    }

    Intent[] private _intents;

    event NewIntentBid(
        uint256 indexed sourceChainId,
        uint256 indexed sourceIntentUid,
        uint256 indexed bidUid,
        uint256 amountProposed
    );

    struct Bid {
        uint256 sourceChainId;
        uint256 intentUid;
        uint256 amountProposed;
        address proposer;
        address destination;            // Address bridged funds will be sent to
        address forwarding;             // Address where source funds will be returned
        bool executed;
        bool returned;
        uint256 timestamp;
    }

    Bid[] private _bids;

    mapping (bytes32 => bool) _satisfiedIntents;

    constructor(address mailbox, address operator) {
        _intentCounter = 0;
        _bidCounter = 0;

        // Trustless message passing via Hyperlane wherever possible
        _mailbox = mailbox;
        // Permissioned operator for testing and unsupported chains
        _operatorRelayer = operator;

        // TODO set up allowed chainIds to domains:
        // https://docs.hyperlane.xyz/docs/reference/domains
        // Blanket allow Sepolia for testing
        _chainMapping[11155111] = address(operator);   
    }

    modifier onlyMailbox() {
        require(msg.sender == _mailbox
                || msg.sender == _operatorRelayer);
        _;
    }

    function addChainMapping(uint32 domainId, address handler) external {
        require(_chainMapping[domainId] == address(0), "Destination chain already registered!");
        _chainMapping[domainId] = handler;
    }

    // Called by a user who wants to bridge. This defines the terms of their intention
    function initiateNativeIntent(uint256 minAmountRecv, uint32 chainIdDestination, address beneficiary) external payable {
        require(msg.value > 0, "Amount deposited must be greater than 0");

        require(_chainMapping[chainIdDestination] != address(0), "Destination chain not supported!");

        // TODO: impose constrains on the operation beyond price
        // TODO: accept calldata as a prehook operation?

        emit NewIntent(
            _intentCounter++,
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

        _intents.push(newIntent);
    }

    // General function to check current status of intent
    function getIntent(uint256 intentUid) public view returns (Intent memory) {
        return _intents[intentUid];
    }

    // Called by a user who wants to bridge. This will settle based on the most desirable bid
    function acceptBid(uint256 destinationBid, uint256 intentUid) public returns (uint256) {
        Intent storage intent = _intents[intentUid];
        require(msg.sender == intent.owner, "Only owner can accept");
        require(!intent.executed, "Intent already executed");
        require(!intent.returned, "Intent already returned");
        // Allow a reasonable RFQ window for solvers to propose
        require(block.timestamp >= intent.timestamp + 30 seconds, "Can't accept yet");
        
        intent.executed = true;
        // TODO executed, but not confirmed / finalised? Perhaps there needs to be a new state?
        
        // trigger message to destination chain executing

        if (block.chainid == intent.chainId) {
            // Sending to the same chain, we can call settleNativeIntent directly
            settleNativeIntent(block.chainid, intentUid, destinationBid);
            return 1337;
        }

        // TODO should we lookup to see what the domain id is for the chain or can we assume
        // it will always be the same?

        address destinationChainHandler = _chainMapping[intent.chainId];
        require(destinationChainHandler != address(0), "Invalid destination?");

        bytes memory encodedData = encodeSettlementForBid(block.chainid, intentUid, destinationBid);

        // TODO bugfix send small amount of native token to pay for sending msg
        uint256 result = IHyperlaneMailbox(_mailbox).dispatch(
                intent.chainId,
                addressToBytes32(destinationChainHandler),
                encodedData
            );
        return result;
    }

    // Called by a user who wants to bridge. This will revert the intention and return the funds
    function rejectBids(uint256 intentUid) public {
        Intent storage intent = _intents[intentUid];
        require(msg.sender == intent.owner, "Only owner can reject");
        require(!intent.executed, "Intent already executed");
        require(!intent.returned, "Intent already returned");
        require(block.timestamp >= intent.timestamp + 30 minutes, "Can't reject yet");
        
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

        emit NewIntentBid(
            sourceChainId,
            intentUid,
            _bidCounter++,
            msg.value
        );

        Bid memory newBid = Bid({
            sourceChainId: sourceChainId,
            intentUid: intentUid,
            amountProposed: msg.value,
            proposer: msg.sender,
            executed: false,
            returned: false,
            destination: destination,
            forwarding: forwarding,
            timestamp: block.timestamp
        });

        _bids.push(newBid);
    }

    // Called by searcher to withdraw a bid if they change their mind or
    // their bid was not the winner of the auction
    function withdrawNativeBid(uint256 bidUid) external {
        Bid memory selectedBid = _bids[bidUid];
        require(!selectedBid.executed, "Bid has already been executed!");
        require(!selectedBid.returned, "Bid has already been returned!");
        require(selectedBid.proposer == msg.sender, "Only the proposer can withdraw!");
        require(block.timestamp >= selectedBid.timestamp + 30 minutes, "Can't withdraw yet!");
        // Prevent refunding settlement later
        selectedBid.returned = true;
        payable(selectedBid.proposer).transfer(selectedBid.amountProposed);
    }

    // General function to check current status of intent
    function getBid(uint256 bidUid) public view returns (Bid memory) {
        return _bids[bidUid];
    }

    // Called by x-chain sg to execute withdrawal
    function settleNativeIntent(uint256 sourceChainId, uint256 intentUid, uint256 bidId) public returns (uint256) {
        bytes32 key = generateKey(sourceChainId, intentUid);
        // Prevent double settling of intent
        require(_satisfiedIntents[key] == false, "Intent already settled");

        Bid memory selectedBid = _bids[bidId];
        require(!selectedBid.executed, "Bid has already been executed!");
        require(!selectedBid.returned, "Bid has already been returned!");
        // Prevent refunding settlement later
        selectedBid.executed = true;
        // Prevent multiple settlements
        _satisfiedIntents[key] = true;

        payable(selectedBid.destination).transfer(selectedBid.amountProposed);

        if (block.chainid == sourceChainId) {
            // Sending to the same chain, we can call realseFundsToSettler directly
            realseFundsToSettler(intentUid, selectedBid.forwarding);
            return 1337;
        }

        // send message to source chain with forwarding address

        address destinationChainHandler = _chainMapping[uint32(sourceChainId)];
        require(destinationChainHandler != address(0), "Invalid destination?");

        bytes memory encodedData = encodeReleaseFunds(intentUid, selectedBid.forwarding);

        // TODO bugfix send small amount of native token to pay for sending msg
        uint256 result = IHyperlaneMailbox(_mailbox).dispatch(
                uint32(sourceChainId),
                addressToBytes32(destinationChainHandler),
                encodedData
            );

        return result;
    }

    // Final stage, triggered by confirmation message coming from destination chain
    // Releases funds from the depositor to the settler that has provided funds on the
    // destination chain
    function realseFundsToSettler(uint256 intentUid, address destination) public {
        Intent storage intent = _intents[intentUid];
        require(intent.executed, "Intent not yet executed");
        require(!intent.returned, "Intent already returned");
        require(intent.fulfiller == address(0), "Funds already sent already returned");
        intent.fulfiller = destination;

        payable(intent.fulfiller).transfer(intent.amount);
    }

    //////////////////////////////////////
    //
    // utility functions
    //

    function generateKey(uint256 sourceChainId, uint256 intentUid) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(sourceChainId, intentUid));
    }

    // alignment preserving cast
    function addressToBytes32(address _addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }

    function bytes32ToAddress(bytes32 _buf) internal pure returns (address) {
        return address(uint160(uint256(_buf)));
    }

    function handleMessage(
        uint32 origin,
        bytes32 sender,
        bytes calldata message
    ) external payable onlyMailbox {
        (
            uint32 messageType,
            uint256 param1,
            uint256 param2,
            uint256 param3
        ) = decodeData(message);

        if (messageType == uint32(1)) {
            // This is a settlement for bid request
            require(origin == uint32(param1), "Chain ID mismatches!");
            settleNativeIntent(param1, param2, param3);

        } else if (messageType == uint32(2)) {
            // This is a confirmation of settlement and releases funds to the settler
            realseFundsToSettler(param1, address(uint160(param2)));
        }
    }

    function encodeSettlementForBid(
        uint256 sourceChainId, uint256 intentUid, uint256 bidId
    ) internal pure returns (bytes memory) {
        return abi.encode(uint32(1), sourceChainId, intentUid, bidId);
    }

    function encodeReleaseFunds(
        uint256 intentUid, address destination
    ) internal pure returns (bytes memory) {
        return abi.encode(uint32(2), intentUid, uint256(uint160(destination)), 0);
    }

    function decodeData(bytes memory encodedData) internal pure
        returns (uint32 messageType, uint256 sourceChainId, uint256 intentUid, uint256 bidId)
    {
        (messageType, sourceChainId, intentUid, bidId) = abi.decode(
            encodedData,
            (uint32, uint256, uint256, uint256));

        return (messageType, sourceChainId, intentUid, bidId);
    }
}
