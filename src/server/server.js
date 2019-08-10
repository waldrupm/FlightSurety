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
let timestamp = 1143243321;
let oraclesMap = new Map();


// SETUP
const setupOracles = async () => {
  try {
    //Get truffle accounts
    truffleAccounts = await getTruffleAccounts();
    // Register Oracles to the last 20 of them and assign indexes
    await registerAllOracles().then(console.log("Oracles Registered"));
    await authorizeAppContract().then(console.log("App contract authorized"));
  
    await fundFirstAirline().then(console.log("Airline Funded"));
    await setupThreeFlights().then(console.log("Flights are set up"));
  } catch (e) {
    console.log(e.message);
  }
};

const getTruffleAccounts = async () => {
  return new Promise( (resolve, reject) => {
    web3.eth.getAccounts((e, res) => {
      if (e) {
        reject(error);
      } else {
        // console.log(res);
        resolve(res);
      }
    });
  });
};

const registerOracle = (oracle) => {
  return new Promise ((resolve, reject) => {
    flightSuretyApp.methods.registerOracle().send({from: oracle, value: web3.utils.toWei("1", "ether"), gas: 3000000}, (e, res) => {
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
    // console.log("__________________________");
    // console.log(truffleAccounts[a]);
    await checkGasRequirement(truffleAccounts[a]);
    await registerOracle(truffleAccounts[a]);
    console.log("Oracle registered", a-19);
    let oracleIndexes = await getIndexes(truffleAccounts[a]);
    // console.log(oracleIndexes);
    oraclesMap.set(truffleAccounts[a], oracleIndexes);
    console.log("__________________________");
  }
};

const checkGasRequirement = (oracle) => {
    flightSuretyApp.methods.registerOracle().estimateGas({from: oracle}).then(function(gasAmount) {
      // console.log(gasAmount);
    });
};

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
};

const submitOracleResponses = async (event) => {
  let matchingOracles = getMatchingOracles(event.returnValues.index);
  console.log(matchingOracles);
  matchingOracles.forEach(async(oracle) => {
    try {
      // console.log(event.returnValues);
      if (await flightSuretyApp.methods.checkOpenOracleRequest(event.returnValues.index,  event.returnValues.airline, event.returnValues.flight, event.returnValues.timestamp).send({from: oracle, gas: 100000})) {
        console.log("Oracle request is still open");
        await submitOracleResponse(event.returnValues.index, event.returnValues.airline, event.returnValues.flight, event.returnValues.timestamp, oracle);
      } else {
        return;
      }
    } catch(e) {
      console.log("Failed Oracle Response:" , e);
    }
  });
};

const submitOracleResponse = async (_index, _airline, _flight, _timestamp, _oracle) => {
  return new Promise ( (resolve, reject) => {
    let statusCode = generateStatusCode();
    flightSuretyApp.methods.submitOracleResponse(_index, _airline, _flight, _timestamp, statusCode).send({from: _oracle, gas: 100000}, 
                                (e, res) => {
                                  if(e) {
                                    console.log("Oracle response send failed", e);
                                    reject(e);
                                  } else {
                                    resolve(res);
                                  }
                                });
  });
};

const generateStatusCode = () => {
  // return 10 * Math.floor(Math.random() * Math.floor(5));
  return 20;
};

const getMatchingOracles = (_index) => {
  let oraclesWithIndex = [];
  for (let [address, indexes] of oraclesMap) {
    console.log(address, indexes);
    indexes.forEach( index => {
      if (index == _index) {
        console.log(address, "Matched index ", _index);
        oraclesWithIndex.push(address);
      }
    });
  }
  return oraclesWithIndex;
};

const setupThreeFlights = async () => {
  await setupFlight("SolidAir155");
  await setupFlight("SolidAir211");
  await setupFlight("SolidAir333");
};

const setupFlight = (flight) => {
  return new Promise ( (resolve, reject) => {
    flightSuretyApp.methods.registerFlight(truffleAccounts[1], timestamp, web3.utils.fromAscii(flight)).send({from: truffleAccounts[1], gas: 5000000, gasPrice: 100000000000}, (e, res) => {
      if (e) {
        console.log(`In flight setup passing: ${truffleAccounts[1]}, ${timestamp}, and ${web3.utils.fromUtf8(flight)} - Error: ${e.message}`);
        reject(e);
      } else {
        console.log("Registered flight: ", flight);
        resolve(res);
      }
    })
  });
};

const fundFirstAirline = () => {
  return new Promise ( (resolve, reject) => {
    flightSuretyApp.methods.fundRegisteredAirline().send({from: truffleAccounts[1], value: web3.utils.toWei("10", "ether"), gas: 100000}, (e, res) => {
      if (e) {
        console.log(e.message);
        reject(e);
      } else {
        resolve(res);
      }
    });
  });
};

const authorizeAppContract = () => {
  return new Promise ( (resolve, reject) => {
    flightSuretyData.methods.authorizeCaller(config.appAddress).send({from: truffleAccounts[0], gas: 100000}, (e, res) => {
      if(e) {
        console.log(e.message);
        reject(e);
      } else {
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
    submitOracleResponses(event);
});

flightSuretyApp.events.OracleRegistered({
  fromBlock: 0
}, function (error, event) {
  if(error) console.log(error);
  console.log(`Oracles registered: ${event.returnValues.oracle}`);
});

flightSuretyApp.events.OracleReport({
  fromBlock: 0
}, function (error, event) {
  if(error) console.log(error);
  console.log(`Oracle responded to request for ${event.returnValues.flight} with: ${event.returnValues.status}`);
});


// TODO: Listen for other events for testing purposes

const app = express();
app.get('/api', (req, res) => {
    res.send({
      message: 'An API for use with your Dapp!'
    })
});

export default app;


