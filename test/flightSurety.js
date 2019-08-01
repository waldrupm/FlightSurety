
var Test = require('../config/testConfig.js');
var BigNumber = require('bignumber.js');

contract('Flight Surety Tests', async (accounts) => {

  var config;
  before('setup contract', async () => {
    config = await Test.Config(accounts);
    await config.flightSuretyData.authorizeCaller(config.flightSuretyApp.address);
  });

  /****************************************************************************************/
  /* Operations and Settings                                                              */
  /****************************************************************************************/

  it(`(multiparty) has correct initial isOperational() value`, async function () {

    // Get operating status
    let status = await config.flightSuretyData.isOperational.call();
    assert.equal(status, true, "Incorrect initial operating status value");

  });

  it(`(multiparty) can block access to setOperatingStatus() for non-Contract Owner account`, async function () {

      // Ensure that access is denied for non-Contract Owner account
      let accessDenied = false;
      try 
      {
          await config.flightSuretyData.setOperatingStatus(false, { from: config.testAddresses[2] });
      }
      catch(e) {
          accessDenied = true;
      }
      assert.equal(accessDenied, true, "Access not restricted to Contract Owner");
            
  });

  it(`(multiparty) can allow access to setOperatingStatus() for Contract Owner account`, async function () {

      // Ensure that access is allowed for Contract Owner account
      let accessDenied = false;
      try 
      {
          await config.flightSuretyData.setOperatingStatus(false);
      }
      catch(e) {
          accessDenied = true;
      }
      assert.equal(accessDenied, false, "Access not restricted to Contract Owner");
      
  });

  it(`(multiparty) can block access to functions using requireIsOperational when operating status is false`, async function () {

      await config.flightSuretyData.setOperatingStatus(false);

      let reverted = false;
      try 
      {
          await config.flightSuretyApp.registerAirline(accounts[2]);
      }
      catch(e) {
          reverted = true;
      }
      assert.equal(reverted, true, "Access not blocked for requireIsOperational");      

      // Set it back for other tests to work
      await config.flightSuretyData.setOperatingStatus(true);

  });

  it('(airline) cannot register an Airline using registerAirline() if it is not funded', async () => {
    
    // ARRANGE
    let newAirline = accounts[2];

    // ACT
    try {
        await config.flightSuretyApp.registerAirline(newAirline, {from: config.firstAirline});
    }
    catch(e) {
        //console.log(e);
    }
    let result = await config.flightSuretyData.isAirline.call(newAirline); 

    // ASSERT
    assert.equal(result, false, "Airline should not be able to register another airline if it hasn't provided funding");

  });

  it('(airline) can send funding and have it reflected in fund balance', async () => {
      let ten_eth = web3.utils.toWei("10", "ether");
    try {
        await config.flightSuretyApp.fundRegisteredAirline({from: config.firstAirline, value: ten_eth});
    } catch(e) {
        console.log(e);
    }
    let result = await config.flightSuretyData.isFundedAirline(config.firstAirline);

    assert.equal(result, true, "Airline is not showing as funded after sending 10 ether");
  });

  it('(airline) can participate in contract after funding itself', async () => {
    let reverted = false;

    try {
        await config.flightSuretyApp.registerAirline(accounts[3], {from: config.firstAirline});
    } catch(e) {
        reverted = true;
    }

    let newAirlineRegistered = await config.flightSuretyData.isAirline(accounts[3])

    assert.equal(newAirlineRegistered, true, "Airline meeting requirements cannot register new airlines");
    assert.equal(reverted, false, "Funded airline that should be able to, cannot participate in contract actions");
  });

  it('Single (airline) can only add others by itself prior to 4 airlines registered', async () => {

  });

  it('Fifth and further (airline) registration required 50% of multiparty consensus', async () => {

  });


});
