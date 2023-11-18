# Problem description

We have intents based execution for swapping and limit-like orders. For better or worse this exists and has advantages for users.

What we haven't seen yet is the same approach applied to bridging - bridges often involve complex trust assumptions or use of multiple parties with variable finality. What if we changed that to make an Intents based Bridging protocol?

# Idea

Protocol where users can express bridging intent

i.e. "I have 10 ETH on Polygon and I want it to be transferred to Base and get at least 9.98 ETH back within 30 seconds"

Stretch goal - prehooks for executing based on some event - could this be connected to Uma?

This would be broadcast to a solver pool off chain which can decide on how to fulfil the bridging.

# Design (high level)

Each supported chain has a contract that accepts a deposit of ETH along with bridging params. This raises a Log which is then broadcast to a pool of solvers.

psuedo:

[on source chain]
function initiate_intent(min_amount_recv, chain_id_destination) payable {}
-> raises NewIntent(intent_uid, amount_deposited, min_amount_recv, chain_id_destination, beneficiary_address);

This opens a window of bidding where solvers offer to fulfil the intent specifying the uid of the source chain intent minimum the user will receive (in a Dutch auction?).

psuedo:

[on destination chain]
function propose_solution(source_chain_id, intent_uid, amount_proposed) {}  (Can be EIP712 for gas efficiency)
* Requires amount to be sent as proof of fulfilment
-> raises IntentBid(source_chain_id, source_intent_uid, bid_uid, amount_proposed);

The winner then supplies the collateral on the destination chain.

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