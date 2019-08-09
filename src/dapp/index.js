import Config from './config.json';
import Web3 from 'web3';

let App = {
    web3Provider: null,
    contracts: {},
    emptyAddress: "0x0000000000000000000000000000000000000000",
    metamaskAccountID: "0x0000000000000000000000000000000000000000",
    airlineRegistrationAddress: "0x0000000000000000000000000000000000000000",
    currentFlights: [],
    config: Config.localhost,
    web3: null,
  
    init: async function () {
        App.readForm();
        /// Setup access to blockchain
        return await App.initWeb3();
    },
  
    readForm: function () {
        App.airlineRegistrationAddress = $("#airlineRegistrationAddress").val();
        App.purchaseInsuranceFlight = $("#purchaseInsuranceFlight option:selected").text();
        App.purchaseInsuranceValue = $("#purchaseInsuranceValue").val();
        App.checkFlightStatusFlightName = $("#checkFlightStatusFlightName option:selected").text();
        App.operationalStatus_Status = $("#operationalStatus_Status option:selected").text();
        App.authorizeContractAddress = $("#authorizeContractAddress").val();
  
        // console log all values
        console.log(
            App.airlineRegistrationAddress,
            App.purchaseInsuranceFlight,
            App.purchaseInsuranceValue,
            App.checkFlightStatusFlightName,
            App.operationalStatus_Status,
            App.authorizeContractAddress
        );
    },
  
    initWeb3: async function () {
        /// Find or Inject Web3 Provider
        /// Modern dapp browsers...
        if (window.ethereum) {
            App.web3Provider = window.ethereum;
            try {
                // Request account access
                await window.ethereum.enable();
            } catch (error) {
                // User denied account access...
                console.error("User denied account access")
            }
        }
        // Legacy dapp browsers...
        else if (window.web3) {
            App.web3Provider = window.web3.currentProvider;
        }
        // If no injected web3 instance is detected, fall back to Ganache
        else {
            App.web3Provider = new Web3.providers.HttpProvider('http://localhost:7545');
        }
  
        App.getMetaskAccountID();
  
        return App.initAirlineApp();
    },
  
    getMetaskAccountID: function () {
        App.web3 = new Web3(App.web3Provider);
  
        // Retrieving accounts
        App.web3.eth.getAccounts(function(err, res) {
            if (err) {
                console.log('Error:',err);
                return;
            }
            console.log('getMetaskID:',res);
            App.metamaskAccountID = res[0];
  
        })
    },
  
    initAirlineApp: () => {
        /// Source the truffle compiled smart contracts
        let jsonAirlineApp='./FlightSuretyApp.json';
        
        /// JSONfy the smart contracts
        console.log("Trying to get App json");
        $.getJSON(jsonAirlineApp, function(data) {
            console.log('data',data);
            console.log("Should have given data");
            var AirlineAppArtifact = data;
            App.contracts.AirlineApp = new App.web3.eth.Contract(AirlineAppArtifact.abi, App.config.appAddress);
            
            App.fetchCurrentFlights();
  
        });
        return App.bindEvents();
    },
  
    bindEvents: function() {
        $(document).on('click', App.handleButtonClick);
    },

    fetchCurrentFlights: async function() {
        let flights = await App.contracts.AirlineApp.methods.getAllFlights().call();
            let flightNames = [];
            flights.forEach( flight => {
                console.log(flight);
                flightNames.push(App.web3.utils.hexToUtf8(flight));
            });
            flightNames.forEach( name => {
                $("#purchaseInsuranceFlight").append(`<option value="${name}">${name}</option>`);
                $("#checkFlightStatusFlightName").append(`<option value="${name}">${name}</option>`);
            }); 
    },
  
    handleButtonClick: async function(event) {
        event.preventDefault();
  
        App.getMetaskAccountID();
        App.readForm();
  
        var processId = parseInt($(event.target).data('id'));
        console.log('processId',processId);
  
        switch(processId) {
            case 1:
                return await App.registerAirline(event);
                break;
            case 2:
                return await App.fundAirline(event);
                break;
            case 3:
                return await App.buyFlightInsurance(event);
                break;
            case 4:
                return await App.checkFlightStatus(event);
                break;
            case 5:
                return await App.requestWithdraw(event);
                break;
            case 6:
                return await App.setOperationalStatus(event);
                break;
            case 7:
                return await App.authorizeCaller(event);
                break;
            }
    },
  };
  
  $(function () {
    $(window).load(function () {
        App.init();
    });
  });