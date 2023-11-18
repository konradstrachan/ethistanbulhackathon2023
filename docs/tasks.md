Smart contract

[x] Build deposit method to store funds and raise log for intent params
[x] Build mechanism for submitting (and locking funds) for bids and raise log for bid parameters
[x] Implement message passing between contracts on source and destination side so that user can accept a bid_id and will be triggered on the destination contract
[x] When receiving a message the contract stores the chain_id + intent_uid so others that submitted can withdraw their bids
[x] When receiving a message the contract forwards the funds to satisfy the intent with the bid params
[x] After satisfying the bid a message is sent back to the source chain indicating it has been fulfilled and preventing the source funds being withdrawn (having the intent cancelled)
[x] After satisfying the bid, the message of confirmation forwards the funds to the forwarding address specified by the bidder
[x] Implement mechanism for intents to be cancelled if they are not fulfilled in a certain time

Seeker reference implementation

[x] Watch for a record, take parameters from record
[x] Supply bid that satifies intent
[x] ..?