import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
import FlightSuretyData from '../../build/contracts/FlightSuretyData.json';
import Config from './config.json';
import Web3 from 'web3';
import express from 'express';


let config = Config['localhost'];
let web3 = new Web3(new Web3.providers.WebsocketProvider(config.url.replace('http', 'ws')));
web3.eth.defaultAccount = web3.eth.accounts[0];
let flightSuretyApp = new web3.eth.Contract(FlightSuretyApp.abi, config.appAddress);
let flightSuretyData = new web3.eth.Contract(FlightSuretyData.abi, config.dataAddress);

// State maintenance
let truffleAccounts = [];
const possibleStatus = [0, 10, 20, 30, 40, 50];
let oracleMap = new Map();


// SETUP
const setupOracles = async () => {
  //Get truffle accounts
  truffleAccounts = await getTruffleAccounts();
  //Register Oracles the last 20 of them

  //Setup an airline and fund it

  //Register a flight or two

  //Initiate a call for flight status for testing
};

const getTruffleAccounts = async () => {
  return new Promise( (resolve, reject) => {
    web3.eth.getAccounts((e, res) => {
      if (e) {
        reject(error);
      } else {
        console.log(res);
        resolve(res);
      }
    });
  });
};

// Initiate Setup
setupOracles();

flightSuretyApp.events.OracleRequest({
    fromBlock: 0
  }, function (error, event) {
    if (error) console.log(error)
    console.log(event);
});

const app = express();
app.get('/api', (req, res) => {
    res.send({
      message: 'An API for use with your Dapp!'
    })
});

export default app;


