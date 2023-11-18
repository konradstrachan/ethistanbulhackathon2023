# GoldenGate (bridge)

# Introduction

## Problem description

We have intents based execution for swapping and limit-like orders. For better or worse this exists and has advantages for users.

What we haven't seen yet is the same approach applied to bridging - bridges often involve complex trust assumptions or use of multiple parties with variable finality. What if we changed that to make an Intents based Bridging protocol?

# Design (high level)

Each supported chain has a contract that accepts a deposit of ETH along with bridging params. This raises a Log which is then broadcast to a pool of solvers.

[on source chain]
function initiate_intent(min_amount_recv, chain_id_destination) payable {}
-> raises NewIntent(intent_uid, amount_deposited, min_amount_recv, chain_id_destination, beneficiary_address);

This opens a window of bidding where solvers offer to fulfil the intent specifying the uid of the source chain intent and minimum the user will receive if they select the bid of the solver. They do this by calling a function on the destination chain with the solving parameters along with staking funds which will be sent to the user if they accept.

[on destination chain]
function propose_solution(source_chain_id, intent_uid, amount_proposed) {}  (Can be EIP712 for gas efficiency)
* Requires amount to be sent as proof of fulfilment
-> raises IntentBid(source_chain_id, source_intent_uid, bid_uid, amount_proposed);

The smart contract sends the funds from the winning solver on the destination chain to the user and has the user's funds tranferred on the source chain. Messages between the two chain contracts are handled permissionlessly using Hyperlane.

The user who initated the intent proposal specifies which bid they accept.

psuedo:

function settle_intent(intent_uid, destination_chain_id, bid_uid) {}
* Prevents funds on source being withdrawn
* Sends a message to the destination chain to have funds sent to beneficiary
* Smart contract at destination receives message and forwards the funds.

For other bridging proposers that were not picked, they can withdraw their bid either:
1. if the source_chain_id + intent_uid has been marked as claimed (done when another is claimed)
or
2. after 24 hours

If there are no bids, the intents proposer can withdraw their intent and funds after 30 minutes

# Components

* Smart contract
* Solver tool

# Technology used

* EVM / Solidity
* Hyperlane

# Supported chains

* Sepolia
* Chiliz
* Scroll
* Mantle
* CELO
* Base
* Neon EVM