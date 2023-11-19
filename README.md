# GoldenGate (bridge)

# Introduction

## Problem description

We have intents based execution for swapping and limit-like orders. For better or worse this exists and has advantages for users around UX and reducing the impact of MEV.

What we haven't seen yet is the same approach applied to bridging - bridges often involve complex trust assumptions or use of multiple parties with variable finality. What if we changed that to make an Intents based Bridging protocol?

Suddenly users can specify their finality needs and solvers can source liquidity using their own risk models and inventory to fulfil orders at no risk to the user.

## What is GoldenGate

GG is a bridge (get it?) protocol tailored to 

i.e. "I have 10 ETH on Polygon and I want it to be transferred to Base and get at least 9.98 ETH back within 30 seconds"

Stretch goal - prehooks for executing based on some event - could this be connected to Uma?

This would be broadcast to a solver pool off chain which can decide on how to fulfil the bridging.

# Design

## Overview

GG is a protocol that facilitates competition between solvers who bid to fulfil the bridging requirements of a user.

A user can specify using an Intents based approach how they'd like to bridge their funds :

e.g. A user might signal they want to send 0.1 ETH from Scroll to Polygon zkEVM where it will be credited within 10 blocks to a specific address. They expect to receive at least 0.095 ETH at the destination chain.

Once this intent is expressed, solvers can compete to optimise collateral to facilitate this. Solvers indicate their bids to fulfil the intent with the user picking the most desirable (presumably on price) after an RFQ window of approx 30 seconds.

## Economics

Bridging currently always requires a direct smart contract interaction which a user has to pay gas for. Whilst gas sponsored bridging may already exist, the majority of users expect to pay to bridge their funds from chain to chain. 

This fee is simply the difference between the amount the user receives at the destination vs the amount they spent at the source. Solvers are free to propose any fee they wish provided they fulfil the minimum amount the user specifies in their intention. This incentivises solvers to provide their collateral as a service.

## Demo

https://github.com/konradstrachan/ethistanbulhackathon2023/assets/21056525/29c1fe78-bacf-4296-8690-942ce96790c3

## High level flow

![image](https://github.com/konradstrachan/ethistanbulhackathon2023/assets/21056525/acee29d6-b0a8-4bc7-9556-3634003d8b66)

Each supported chain has a contract that accepts a deposit of ETH along with parameterised requirements. Conceptually any composable token with a cross chain representation can be used, but for the hackathon only chain native tokens are supported.

When a user signals an intent this is done through an call to initiateNativeIntent on the smart contract. 

This raises a Log NewIntent that solvers monitor for and  opens an RFQ window where solvers offer to fulfil the intent specifying the id of the source chain intent and minimum the user will receive if they select the bid of the solver (along with any other relevant constraints the user may have expressed).

Solvers offer bridging outcomes by calling the proposeNativeSolution funciton on the destination chain with the solving parameters along with staking funds which will be sent to the user if they accept.

When a bids is received, it results in a Log NewIntentBid which the user can monitor for. In the future, it would be desirable to use a Dutch auction like system to make bidding more competitive along with automatically resolving the auction at the end of the RFQ period with the best outcome being awarded fulfilment, however these are future work considerations.

Once a winning bid has been selected, the smart contract sends the funds from the winning solver on the destination chain to the user and has the user's funds tranferred on the source chain. Messages between the two chain contracts are handled permissionlessly using Hyperlane.

Currently the user who initated the intent proposal specifies which bid they accept by calling settleNativeIntent.

For other bridging proposers that were not picked, they can withdraw their bid either:
1. if the source_chain_id + intent_uid has been marked as claimed (done when another is claimed)
or
2. after 30 minutes if no bid has been accepted by the intent originator

If there are no bids, the intents proposer can withdraw their intent and funds after 30 minutes

# Components

* Smart contract
* Solver

# Technology used

* Smart contracts were written in Solidity and deployed on numerous chains to allow for bridging
* Message passing between chains is achieved trustlessly using Hyperlane
* Solver reference was implemented in Python

# Supported chains

* Sepolia - https://sepolia.etherscan.io/address/0x246c7802c82598bff1521eea314cf3beabc33197
* Chiliz - Deployed but issues with blockexplorer?
* Scroll - https://sepolia.scrollscan.com/address/0xbca10b3abf218ab63d967c4282343b3e0308a15b
* Arbitrum - https://goerli.arbiscan.io/address/0x4dc36fcc192c042fc49fe934d86e8942d79c4e93#code
* Mantle - https://explorer.testnet.mantle.xyz/address/0xF07b86d5DCd3165A23438bc37a8964128a94c7f0
* CELO - https://explorer.celo.org/alfajores/address/0x4DC36FCc192c042fC49Fe934D86E8942D79c4e93 (issue verifying contract?)
* Neon EVM - https://devnet.neonscan.org/address/0x35461b3ba63aa1764b46778570d8e369ea3cff86

# Future work

* Support EIP7512 and make intents expression more dynamic
* Adding custom logic hooks for pre and post bridging
* Better fee mechanism to handle Hyperlane cost of message exchange
* Shielding the bidding process to make the solvers more competive (and honest?)