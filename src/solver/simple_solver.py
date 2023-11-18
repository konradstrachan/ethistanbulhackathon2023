from web3 import Web3, HTTPProvider
from web3.middleware import geth_poa_middleware

chain_contract_abi = [{"inputs":[{"internalType":"address","name":"mailbox","type":"address"},{"internalType":"address","name":"operator","type":"address"}],"stateMutability":"nonpayable","type":"constructor"},{"anonymous":False,"inputs":[{"indexed":True,"internalType":"uint256","name":"intentUid","type":"uint256"},{"indexed":False,"internalType":"uint256","name":"amountDeposited","type":"uint256"},{"indexed":False,"internalType":"uint256","name":"minAmountRecv","type":"uint256"},{"indexed":False,"internalType":"uint256","name":"chainIdDestination","type":"uint256"},{"indexed":False,"internalType":"address","name":"beneficiaryAddress","type":"address"}],"name":"NewIntent","type":"event"},{"anonymous":False,"inputs":[{"indexed":True,"internalType":"uint256","name":"sourceChainId","type":"uint256"},{"indexed":True,"internalType":"uint256","name":"sourceIntentUid","type":"uint256"},{"indexed":True,"internalType":"uint256","name":"bidUid","type":"uint256"},{"indexed":False,"internalType":"uint256","name":"amountProposed","type":"uint256"}],"name":"NewIntentBid","type":"event"},{"inputs":[{"internalType":"uint256","name":"destinationBid","type":"uint256"},{"internalType":"uint256","name":"intentUid","type":"uint256"}],"name":"acceptBid","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"uint32","name":"domainId","type":"uint32"},{"internalType":"address","name":"handler","type":"address"}],"name":"addChainMapping","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"uint256","name":"sourceChainId","type":"uint256"},{"internalType":"uint256","name":"intentUid","type":"uint256"}],"name":"generateKey","outputs":[{"internalType":"bytes32","name":"","type":"bytes32"}],"stateMutability":"pure","type":"function"},{"inputs":[{"internalType":"uint256","name":"bidUid","type":"uint256"}],"name":"getBid","outputs":[{"components":[{"internalType":"uint256","name":"sourceChainId","type":"uint256"},{"internalType":"uint256","name":"intentUid","type":"uint256"},{"internalType":"uint256","name":"amountProposed","type":"uint256"},{"internalType":"address","name":"proposer","type":"address"},{"internalType":"address","name":"destination","type":"address"},{"internalType":"address","name":"forwarding","type":"address"},{"internalType":"bool","name":"executed","type":"bool"},{"internalType":"bool","name":"returned","type":"bool"},{"internalType":"uint256","name":"timestamp","type":"uint256"}],"internalType":"struct GoldenGate.Bid","name":"","type":"tuple"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"uint256","name":"intentUid","type":"uint256"}],"name":"getIntent","outputs":[{"components":[{"internalType":"uint256","name":"amount","type":"uint256"},{"internalType":"uint256","name":"minAmountRecv","type":"uint256"},{"internalType":"uint32","name":"chainId","type":"uint32"},{"internalType":"address","name":"beneficiaryAddress","type":"address"},{"internalType":"bool","name":"executed","type":"bool"},{"internalType":"bool","name":"returned","type":"bool"},{"internalType":"address","name":"owner","type":"address"},{"internalType":"address","name":"fulfiller","type":"address"},{"internalType":"uint256","name":"timestamp","type":"uint256"}],"internalType":"struct GoldenGate.Intent","name":"","type":"tuple"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"uint32","name":"origin","type":"uint32"},{"internalType":"bytes32","name":"sender","type":"bytes32"},{"internalType":"bytes","name":"message","type":"bytes"}],"name":"handleMessage","outputs":[],"stateMutability":"payable","type":"function"},{"inputs":[{"internalType":"uint256","name":"minAmountRecv","type":"uint256"},{"internalType":"uint32","name":"chainIdDestination","type":"uint32"},{"internalType":"address","name":"beneficiary","type":"address"}],"name":"initiateNativeIntent","outputs":[],"stateMutability":"payable","type":"function"},{"inputs":[{"internalType":"uint256","name":"sourceChainId","type":"uint256"},{"internalType":"uint256","name":"intentUid","type":"uint256"},{"internalType":"address","name":"destination","type":"address"},{"internalType":"address","name":"forwarding","type":"address"}],"name":"proposeNativeSolution","outputs":[],"stateMutability":"payable","type":"function"},{"inputs":[{"internalType":"uint256","name":"intentUid","type":"uint256"},{"internalType":"address","name":"destination","type":"address"}],"name":"realseFundsToSettler","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"uint256","name":"intentUid","type":"uint256"}],"name":"rejectBids","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"uint256","name":"sourceChainId","type":"uint256"},{"internalType":"uint256","name":"intentUid","type":"uint256"},{"internalType":"uint256","name":"bidId","type":"uint256"}],"name":"settleNativeIntent","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"uint256","name":"bidUid","type":"uint256"}],"name":"withdrawNativeBid","outputs":[],"stateMutability":"nonpayable","type":"function"}]
rpc_url_sepolia = "XXX"
rpc_url_scroll = "https://alpha-rpc.scroll.io/l2"

contract_address_sepolia = Web3.to_checksum_address("0xFfe8e2f2aA5BB81E13EDc3b5c51be045d97f1A1A")
contract_address_scroll = Web3.to_checksum_address("0xFfe8e2f2aA5BB81E13EDc3b5c51be045d97f1A1A")

sepolia_testnet_chainid = 11155111
scroll_testnet_chainid = 534353

wallet_sepolia_user_pub = "0x347D03041d4Dbb2b61144275E28FDc31ACb89722"
wallet_sepolia_user_prv = "XXX"

wallet_scroll_solver_pub = wallet_sepolia_user_pub
wallet_scroll_solver_prv = wallet_sepolia_user_prv

def handle_event(event):
    print(f"🌟 Event detected: {event['event']} - {event['args']}")
    print("")
    return event['args']
        
def submit_intent_to_bridge():
    print("😁 USER: Submitting new bridging intent")
    print("INTENT: Will send 0.001 ETH, expects at least 0.0009 ETH back at destination chain")
    w3 = Web3(HTTPProvider(rpc_url_sepolia))

    contract = w3.eth.contract(address=contract_address_sepolia, abi=chain_contract_abi)

    account_address = wallet_sepolia_user_pub

    # Nonce is used to prevent replay attacks
    nonce = w3.eth.get_transaction_count(account_address)

    # Prepare the transaction data
    # Send 0.001 ETH, expect 0.0009 back
    transaction_data = contract.functions.initiateNativeIntent(
        minAmountRecv=900000000000000,     # 0.0009 ETH
        chainIdDestination=sepolia_testnet_chainid,
        beneficiary=account_address,
    ).build_transaction({
        'from': account_address,
        'gas': 200000,
        'gasPrice': w3.to_wei('10', 'gwei'),
        'nonce': nonce,
        'value': 1000000000000000
    })

    # Sign the transaction
    signed_transaction = w3.eth.account.sign_transaction(transaction_data, wallet_scroll_solver_prv)

    # Send the transaction
    transaction_hash = w3.eth.send_raw_transaction(signed_transaction.rawTransaction)

    print(f"✅ Transaction sent. Transaction Hash: {transaction_hash.hex()}")
    print("RFQ auction now running for intent")
    print("")

def watch_for_new_intent():
    print("🤖 SOLVER: Watching for new intent event..")
    contract_address = contract_address_sepolia

    w3 = Web3(HTTPProvider(rpc_url_sepolia))

    contract = w3.eth.contract(address=contract_address, abi=chain_contract_abi)

    filter_from_block = "latest"
    
    event_name = "NewIntent"
    event_filter = contract.events[event_name].create_filter(fromBlock=filter_from_block)

    while True:
        for event in event_filter.get_new_entries():
            return handle_event(event)

def submit_candidate_bid(args):
    print("🤖 SOLVER: Submitting candidate bid for intent..")
    print("PROPOSAL: Supply 0.0009 ETH on destination chain for 0.0001 ETH on source")
    print("PROPOSAL: Fee will be 0.0001 ETH to the solver")
    
    w3 = Web3(HTTPProvider(rpc_url_sepolia))

    contract = w3.eth.contract(address=contract_address_sepolia, abi=chain_contract_abi)

    account_address = wallet_sepolia_user_pub

    # Nonce is used to prevent replay attacks
    nonce = w3.eth.get_transaction_count(account_address)

    # Prepare the transaction data
    transaction_data = contract.functions.proposeNativeSolution(
        sourceChainId=sepolia_testnet_chainid,
        intentUid=args['intentUid'],
        destination=args['beneficiaryAddress'],
        forwarding=wallet_sepolia_user_pub
    ).build_transaction({
        'from': account_address,
        'gas': 2000000,
        'gasPrice': w3.to_wei('10', 'gwei'),
        'nonce': nonce,
        'value': 900000000000000     # 0.0009 ETH
    })

    # Sign the transaction
    signed_transaction = w3.eth.account.sign_transaction(transaction_data, wallet_scroll_solver_prv)

    # Send the transaction
    transaction_hash = w3.eth.send_raw_transaction(signed_transaction.rawTransaction)

    print(f"✅ Transaction sent. Transaction Hash: {transaction_hash.hex()}")
    print("")

def watch_for_new_bid():
    print("😁 USER: Watching for new bid event..")
    contract_address = contract_address_sepolia

    w3 = Web3(HTTPProvider(rpc_url_sepolia))

    contract = w3.eth.contract(address=contract_address, abi=chain_contract_abi)

    filter_from_block = "latest"
    
    event_name = "NewIntentBid"
    event_filter = contract.events[event_name].create_filter(fromBlock=filter_from_block)

    while True:
        for event in event_filter.get_new_entries():
            return handle_event(event)
        
def submit_bid_acceptance(args):
    print("😁 USER: Happy to accept terms of bid, they fulfil the intent definition")
    print("USER: Submitting intent bid acceptance..")
    w3 = Web3(HTTPProvider(rpc_url_sepolia))

    contract = w3.eth.contract(address=contract_address_sepolia, abi=chain_contract_abi)

    account_address = wallet_sepolia_user_pub

    # Nonce is used to prevent replay attacks
    nonce = w3.eth.get_transaction_count(account_address)

    # Prepare the transaction data
    transaction_data = contract.functions.acceptBid(
        destinationBid=args['bidUid'],
        intentUid=args['sourceIntentUid'],
    ).build_transaction({
        'from': account_address,
        'gas': 200000,
        'gasPrice': w3.to_wei('10', 'gwei'),
        'nonce': nonce,
    })

    # Sign the transaction
    signed_transaction = w3.eth.account.sign_transaction(transaction_data, wallet_scroll_solver_prv)

    # Send the transaction
    transaction_hash = w3.eth.send_raw_transaction(signed_transaction.rawTransaction)

    print(f"✅ Transaction sent. Transaction Hash: {transaction_hash.hex()}")
    print("")

def main():
    print("")
    print("Test of GoldenGate bridging intents execution")
    print("----------------------------------------------")
    print("😁 User will submit an intent to bridge which will be picked up by a solver and filled")
    print("🤖 Bot will attempt to bid to fill this intent and provide the bridging service")
    print("")
    submit_intent_to_bridge()
    args = watch_for_new_intent()
    submit_candidate_bid(args)
    args = watch_for_new_bid()
    submit_bid_acceptance(args)

    print("Bridging operation completed")


if __name__ == "__main__":
    main()