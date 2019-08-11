pragma solidity ^0.4.25;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner;                                      // Account used to deploy contract
    bool private operational = true;                                    // Blocks all state changes throughout the contract if false

    // Minimum funds for airline
    uint256 constant minAirlineFunding = 10 ether;
    // Track contract balance
    uint256 private contractFundBalance = 0 ether;

    // Used to check external authorized callers
    mapping(address => uint8) private authorizedCallers;

    // Airline Data and structures
    struct Airline {
        uint256 funds;
        bool isRegistered;
    }

    mapping(address => address[]) airlineVotes;


    address[] private registeredAirlines;
    mapping(address => Airline) airlines;

    // Flights Data and Structures
    struct Flight {
        bytes32 flight;
        bool isRegistered;
        uint8 statusCode;
        uint256 updatedTimestamp;
        address airline;
    }
    mapping(bytes32 => Flight) private flights;
    bytes32[] private flightKeys;

    // Insurance Data and Structures
    struct Insurance {
        address customer;
        uint256 funds;
        bool isPaid;
    }
    // Flightkeys to insurances
    mapping(bytes32 => bytes32[]) private flightInsurances;
    // Insuree to balances
    mapping(address => uint256) private insureeBalances;
    // Unique insurance keys for recall
    mapping(bytes32 => Insurance) private idToInsurance;
    // Track insurance keys
    bytes32[] private insuranceKeys;


    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/


    /**
    * @dev Constructor
    *      The deploying account becomes contractOwner
    */
    constructor
                                (
                                    address _firstAirline
                                ) 
                                public 
    {
        contractOwner = msg.sender;
        firstAirline(_firstAirline);
    }

    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    // Modifiers help avoid duplication of code. They are typically used to validate something
    // before a function is allowed to be executed.

    /**
    * @dev Modifier that requires the "operational" boolean variable to be "true"
    *      This is used on all state changing functions to pause the contract in 
    *      the event there is an issue that needs to be fixed
    */
    modifier requireIsOperational() 
    {
        require(operational, "Contract is currently not operational");
        _;  // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
    * @dev Modifier that requires the "ContractOwner" account to be the function caller
    */
    modifier requireContractOwner()
    {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    modifier requireAuthorizedCaller()
    {
        require(authorizedCallers[msg.sender] == 1, "You are definitely not authorized for that.");
        _;
    }

    modifier requireOwnerOrAuthorized()
    {
        require(msg.sender == contractOwner || authorizedCallers[msg.sender] == 1, "You are must be owner or authorized to do that");
        _;
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    // @dev Authorize / deauthorize  a caller to use contract
    // @return null
    function authorizeCaller( address _authorizedAddress ) external requireContractOwner {
        authorizedCallers[_authorizedAddress] = 1;
    }

    function deauthorizeCaller( address _deauthorizedAddress ) external requireContractOwner {
        authorizedCallers[_deauthorizedAddress] = 0;
    }

    /**
    * @dev Get operating status of contract
    *
    * @return A bool that is the current operating status
    */      
    function isOperational() 
                            public 
                            view 
                            returns(bool) 
    {
        return operational;
    }


    /**
    * @dev Sets contract operations on/off
    *
    * When operational mode is disabled, all write transactions except for this one will fail
    */    
    function setOperatingStatus
                            (
                                bool mode
                            ) 
                            external
                            requireOwnerOrAuthorized 
    {
        require(mode != operational, "Status is already that");
        operational = mode;
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

    /* Airline Function1ality */

    function firstAirline( address _airlineAddress ) internal requireIsOperational {
        airlines[_airlineAddress] = Airline({funds: 0, isRegistered: true});
        registeredAirlines.push(_airlineAddress);
    }

   /**
    * @dev Add an airline to the registration queue
    *      Can only be called from FlightSuretyApp contract
    *
    */   
    function registerAirline
                            (
                                address _airlineAddress
                            )
                            external
                            requireIsOperational
                            requireAuthorizedCaller
    {
        airlines[_airlineAddress] = Airline({funds: 0, isRegistered: true});
        registeredAirlines.push(_airlineAddress);
    }

    function isAirline( address _airlineAddress ) external view returns (bool) {
        return airlines[_airlineAddress].isRegistered;
    }

    function isFundedAirline ( address _airlineAddress ) public view requireIsOperational returns (bool) {
        return airlines[_airlineAddress].funds >= minAirlineFunding;
    }

    function numRegisteredAirlines() public view requireIsOperational returns (uint256) {
        return registeredAirlines.length;
    }

    function addAirlineVote(address _voter, address _airline) external requireIsOperational requireAuthorizedCaller {
        airlineVotes[_airline].push(_voter);
    }

    function getAirlineVotes(address _airline) public view requireIsOperational returns (address[]) {
        return airlineVotes[_airline];
    }

    function clearAirlineVotes(address _airline) external  requireIsOperational requireAuthorizedCaller {
        delete airlineVotes[_airline];
    }

    function fundAirline(address _airline, uint256 _funds) external payable requireAuthorizedCaller requireIsOperational {
        airlines[_airline].funds = airlines[_airline].funds.add(_funds);
        contractFundBalance = contractFundBalance.add(_funds);
    }


    /* FLIGHTS FUNCTIONALITY */
    function registerFlight (address _airline, uint256 _time, bytes32 _flight) public requireAuthorizedCaller requireIsOperational {
        bytes32 flightKey = getUniqueKey(_airline, _flight, _time);
        flightKeys.push(flightKey);
        flights[flightKey] = Flight({
                                    flight: _flight,
                                    isRegistered: true,
                                    statusCode: 0,
                                    updatedTimestamp: _time,
                                    airline: _airline
                                    });
    }

    function checkFlightExists (bytes32 _flightNumber) public view requireIsOperational returns (bool) {
        for(uint16 f = 0; f < flightKeys.length; f++) {
            if(flights[flightKeys[f]].flight == _flightNumber) {
                return true;
            }
        }
        return false;
    }

    function getFlightkeyByFlight (bytes32 _flightNumber) internal view requireIsOperational returns (bytes32) {
        for(uint16 f = 0; f < flightKeys.length; f++) {
            if(flights[flightKeys[f]].flight == _flightNumber) {
                return flightKeys[f];
            }
        }
        return bytes32(0);
    }

    function getFlightInformation (bytes32 _flightNumber)
                    public view
                    requireIsOperational
                    requireAuthorizedCaller
                    returns (address, bytes32, uint256, uint8, bytes32) {

        bytes32 flightKey = getFlightkeyByFlight(_flightNumber);
        Flight storage flight = flights[flightKey];
        return (flight.airline, flight.flight, flight.updatedTimestamp, flight.statusCode, flightKey);
    }

    function getAllFlights () public view returns (bytes32[] memory) {
        bytes32[] memory flightList = new bytes32[](flightKeys.length);

        for (uint f = 0; f < flightKeys.length; f++) {
            flightList[f] = flights[flightKeys[f]].flight;
        }
        return flightList;
    }

   /**
    * @dev Buy insurance for a flight
    *
    */   
    function buyFlightInsurance (bytes32 _flight, address _insuree) external payable requireIsOperational requireAuthorizedCaller {
        Insurance memory newInsurance = Insurance({customer: _insuree, funds: msg.value, isPaid: false});
        bytes32 flightKey = getFlightkeyByFlight(_flight);
        bytes32 insuranceKey = getUniqueKey(_insuree, _flight, 0);
        flightInsurances[flightKey].push(insuranceKey);
        idToInsurance[insuranceKey] = newInsurance;
        insuranceKeys.push(insuranceKey);
        airlines[flights[flightKey].airline].funds.add(msg.value);
    }

    function getFlightInsuranceDetails (address _insuree, bytes32 _flight)
                    external view
                    requireIsOperational
                    returns (address, uint256, bool, bytes32) {

        bytes32 insuranceKey = getUniqueKey(_insuree, _flight, 0);
        Insurance storage insurance = idToInsurance[insuranceKey];
        return (insurance.customer, insurance.funds, insurance.isPaid, insuranceKey);
    }

    function updateFlightStatus (uint8 _statusCode, bytes32 _flight) public requireIsOperational requireAuthorizedCaller {
        bytes32 flightKey = getFlightkeyByFlight(_flight);
        flights[flightKey].statusCode = _statusCode;
    }

    /**
     *  @dev Credits payouts to insurees
    */
    function creditInsurees (bytes32 _flight) public requireIsOperational requireAuthorizedCaller {
        bytes32 flightKey = getFlightkeyByFlight(_flight);
        address flightAirline = flights[flightKey].airline;
        for(uint8 p=0; p < flightInsurances[flightKey].length; p++) {
            Insurance storage insurance = idToInsurance[flightInsurances[flightKey][p]];
            if (insurance.isPaid == false) {
                uint256 credit = insurance.funds.mul(3).div(2);
                insurance.isPaid == true;
                insureeBalances[insurance.customer] = insureeBalances[insurance.customer].add(credit);
                airlines[flightAirline].funds.sub(credit);
            }
        }
    }

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
    */
    function payInsuree (address _insuree) external requireIsOperational requireAuthorizedCaller returns (bool){
        require(insureeBalances[_insuree] > 0, "This Insuree has no credit to withdraw.");
        uint256 amount = insureeBalances[_insuree];
        insureeBalances[_insuree] = 0;
        address(_insuree).transfer(amount);
        return true;
    }

    function getInsureeBalance (address _insuree) external view requireIsOperational requireAuthorizedCaller returns (uint256) {
        return insureeBalances[_insuree];
    }


    function getUniqueKey
                        (
                            address _address,
                            bytes32 _flight,
                            uint256 _timestamp
                        )
                        pure
                        internal
                        returns(bytes32) 
    {
        return keccak256(abi.encodePacked(_address, _flight, _timestamp));
    }

    function fund
                            (   
                            )
                            public
                            payable
    {
        contractFundBalance.add(msg.value);
    }

    /**
    * @dev Fallback function for funding smart contract.
    *
    */
    function() 
                            external 
                            payable 
    {
        fund();
    }


}

