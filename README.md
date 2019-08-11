# FlightSurety

FlightSurety project completed for Udacity's Blockchain Developer Nanodegree.

## Install

This repository contains Smart Contract code in Solidity (using Truffle), tests (also using Truffle (Mocha / Chai / Truffle-assertions for events)), dApp (using HTML, CSS, Bulma CSS Framework, JS, a bit of JQuery) and server app.

To install, download or clone the repo, then:

`npm install`
`truffle compile`

## Develop Client

To run truffle tests:

`truffle test ./test/flightSurety.js`
`truffle test ./test/oracles.js`

To use the dapp:

`truffle migrate`
`npm run dapp`

To view dapp:

`http://localhost:8000`

## Develop Server (You will need at least 40 Ganache or local ETH accounts in order to setup the project properly. It currently makes use of 20 Oracles, using accounts 19-39 for that purpose.)

`npm run server`
`truffle test ./test/oracles.js`

## Deploy

To build dapp for prod:
`npm run dapp:prod`

Deploy the contents of the ./dapp folder

## Important notes
If there is a metamask RPC payload error about Nonces, metamask accounts need to be reset. This can be done in the Metamask extension by clicking on the account icon > Settings (at bottom) > Advanced > "Reset Account". This deletes account history local and fixes the nonce issue.

The Bulma CSS framework CDN was used in this project. You will not get the full visual experience without being online during testing.

## Airlines
- Airlines can register other airlines (or vote for them if more than 4 airlines already exist) by entering the Airline's address in the address box and clicking "Register".
- Airlines can fund themselves through the Dapp by clicking the "Fund Airline" button and sending the transaction

## Passengers
- Passengers can buy flight insurance up to 1 ETH in value by selecting a flight, entering a value in the ETH field, and clicking purchase insurance.
- Passengers can check the status of their flight and insurance claim by selecting the flight and clicking "Check Status", if the Oracles return the cause as "Late Airline" (they will for testing purposes), the insuree will be credited 1.5x the amount purchased.
- Passengers can request withdrawl of their funds by clicking the Withdraw Funds button. Their funds will arrive shortly.

## Administrators
- Administrators can set the contract operational status by selecting the status they want from the dropdown and clicking Set Status. 
- The new status will be reflected by an event, app lockdown (with the exception of views like getting the flight list), and the status banner at the top of the page. 