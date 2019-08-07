var Test = require('../config/testConfig.js');
const truffleAssert = require('truffle-assertions');
const BigNumber = require('bignumber.js');

contract('Oracles', async (accounts) => {

  const TEST_ORACLES_COUNT = 20;
  let config;
  // Watch contract events
  const STATUS_CODE_UNKNOWN = 0;
  const STATUS_CODE_ON_TIME = 10;
  const STATUS_CODE_LATE_AIRLINE = 20;
  const STATUS_CODE_LATE_WEATHER = 30;
  const STATUS_CODE_LATE_TECHNICAL = 40;
  const STATUS_CODE_LATE_OTHER = 50;
  
  before('setup contract', async () => {
    config = await Test.Config(accounts);

    
  });


  it('can register oracles', async () => {
    
    // ARRANGE
    let fee = await config.flightSuretyApp.REGISTRATION_FEE.call();

    // ACT
    for(let a=1; a<TEST_ORACLES_COUNT; a++) {      
      await config.flightSuretyApp.registerOracle({ from: accounts[a], value: fee });
      let result = await config.flightSuretyApp.getMyIndexes.call({from: accounts[a]});
      console.log(`Oracle Registered: ${result[0]}, ${result[1]}, ${result[2]}`);
    }
  });

  it('can request flight status', async () => {
    
    // ARRANGE
    let flight = web3.utils.utf8ToHex("Mike101");
    let timestamp = 1564765898826;

    // Submit a request for oracles to get status information for a flight
    let tx = await config.flightSuretyApp.fetchFlightStatus(config.firstAirline, flight, timestamp);
    truffleAssert.eventEmitted(tx, 'OracleRequest', (event) => {
      return expect(web3.utils.hexToUtf8(event.flight)).to.equal("Mike101") &&
              expect(event.airline).to.deep.equal(config.firstAirline) &&
              expect(new BigNumber(event.timestamp).toNumber()).to.deep.equal(timestamp);
    });
    // ACT

    // Since the Index assigned to each test account is opaque by design
    // loop through all the accounts and for each account, all its Indexes (indices?)
    // and submit a response. The contract will reject a submission if it was
    // not requested so while sub-optimal, it's a good test of that feature
    let ctr = 1;
    for(let a=1; a<TEST_ORACLES_COUNT; a++) {

      // Get oracle information
      let oracleIndexes = await config.flightSuretyApp.getMyIndexes.call({ from: accounts[a]});
      for(let idx=0;idx<3;idx++) {

        try {
          // TODO: fix this
          // Submit a response...it will only be accepted if there is an Index match
          let tx = await config.flightSuretyApp.submitOracleResponse(oracleIndexes[idx], config.firstAirline, flight, timestamp, STATUS_CODE_ON_TIME, { from: accounts[a] });
          truffleAssert.eventEmitted(tx, 'OracleReport', (event) => {
            console.log(event);
          });
        }
        catch(e) {
          // Enable this when debugging
           console.log('\nError', idx, oracleIndexes[idx].toNumber(), flight, timestamp, ctr, e);
           ctr++;
        }

      }
    }


  });


 
});
