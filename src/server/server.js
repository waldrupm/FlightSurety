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
let oraclesMap = new Map();


// SETUP
const setupOracles = async () => {
  //Get truffle accounts
  truffleAccounts = await getTruffleAccounts();
  //Register Oracles to the last 20 of them and assign indexes
  registerAllOracles();
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
        resolve(res);
      }
    });
  });
};

const registerOracle = (oracle) => {
  return new Promise ((resolve, reject) => {
    flightSuretyApp.methods.registerOracle().send({from: oracle, value: web3.utils.toWei("1", "ether"), gas: 220000000000}, (e, res) => {
      if (e) {
        console.log(e);
        reject(e);
      } else {
        resolve(res);
      }
    });
  });
};

const registerAllOracles = async () => {
  for (let a = 20; a < 40; a++) {
    console.log(truffleAccounts[a]);
    await checkGasRequirement(truffleAccounts[a]);
    await registerOracle(truffleAccounts[a]);
    console.log("Oracle registered", a-19);
    let oracleIndexes = await getIndexes(truffleAccounts[a]);
    console.log(oracleIndexes);
    oraclesMap.set(truffleAccounts[a], oracleIndexes);
  }
}

const checkGasRequirement = (oracle) => {
    flightSuretyApp.methods.registerOracle().estimateGas({from: oracle}).then(function(gasAmount) {
      console.log(gasAmount);
    });
}

const getIndexes = (oracle) => {
  return new Promise( (resolve, reject) => {
    flightSuretyApp.methods.getMyIndexes().call({from: oracle}, (e, res) => {
      if (e) {
        reject(e);
      } else {
        resolve(res);
      }
    });
  });
}

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


