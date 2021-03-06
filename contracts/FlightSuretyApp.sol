pragma solidity ^0.4.25;

// It's important to avoid vulnerabilities due to numeric overflow bugs
// OpenZeppelin's SafeMath library, when used correctly, protects agains such bugs
// More info: https://www.nccgroup.trust/us/about-us/newsroom-and-events/blog/2018/november/smart-contract-insecurity-bad-arithmetic/

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./FlightSuretyData.sol";

/************************************************** */
/* FlightSurety Smart Contract                      */
/************************************************** */
contract FlightSuretyApp {
    using SafeMath for uint256; // Allow SafeMath functions to be called for all uint256 types (similar to "prototype" in Javascript)

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    FlightSuretyData flightSuretyData;

    // Flight status codees
    uint8 private constant STATUS_CODE_UNKNOWN = 0;
    uint8 private constant STATUS_CODE_ON_TIME = 10;
    uint8 private constant STATUS_CODE_LATE_AIRLINE = 20;
    uint8 private constant STATUS_CODE_LATE_WEATHER = 30;
    uint8 private constant STATUS_CODE_LATE_TECHNICAL = 40;
    uint8 private constant STATUS_CODE_LATE_OTHER = 50;

    uint256 private constant CONSENSUS_NUM = 4;

    address private contractOwner;          // Account used to deploy contract


    /**************************************************************************
    EVENTS
    ***************************************************************************/
    event OperationalStatusChange(bool newStatus);

    event AirlineVotedFor(address votedFor, address airlineVoted);
    event AirlineRegistered(address airline);
    event AirlineFunded(address airline);

    event FlightRegistered(bytes32 flight);

    event FlightInsurancePurchased(bytes32 flight, address insuree);
    // Event fired each time an oracle submits a response
    event FlightStatusInfo(address airline, bytes32 flight, uint256 timestamp, uint8 status);

    event OracleReport(address airline, bytes32 flight, uint256 timestamp, uint8 status);

    event FlightStatusFinalized(bytes32 flight, uint8 statusCode);
    // Event fired when flight status request is submitted
    // Oracles track this and if they have a matching index
    // they fetch data and submit a response
    event OracleRequest(uint8 index, address airline, bytes32 flight, uint256 timestamp);
    event OracleRegistered(address oracle);

    event InsureePaid(address insuree);

    //debugging
    // event InVoting(uint256 votesNumber);

 
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
         // Modify to call data contract's status
        require(flightSuretyData.isOperational(), "Contract is currently not operational");  
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

    modifier requireAirlineRegAndFunded()
    {
        require(flightSuretyData.isAirline(msg.sender), "You must be a registered Airline to do this");
        require(flightSuretyData.isFundedAirline(msg.sender), "Your Airline must be funded to do this");
        _;
    }

    modifier requireAirline()
    {
        require(flightSuretyData.isAirline(msg.sender), "You are not an airline");
        _;
    }

    modifier requireNewFlight(bytes32 flightNumber) {
        bool flightExists = flightSuretyData.checkFlightExists(flightNumber);
        require(flightExists == false, "Flight already exists.");
        _;
    }

    modifier requireFlightExists(bytes32 flightNumber) {
        bool flightExists = flightSuretyData.checkFlightExists(flightNumber);
        require(flightExists == true, "Flight does not exist.");
        _;
    }
    
    modifier requireHasInsureeBalance(address _insuree) {
        uint256 balance = flightSuretyData.getInsureeBalance(_insuree);
        require(balance > 0, "You don't have a balance to withrdraw presently");
        _;
    }

    modifier isMaxOneEther() {
        require(msg.value <= 1 ether, "You may only insure for up to 1 Ether");
        _;
    }

    /********************************************************************************************/
    /*                                       CONSTRUCTOR                                        */
    /********************************************************************************************/

    /**
    * @dev Contract constructor
    *
    */
    constructor
                                (
                                    address _dataContractAddress
                                ) 
                                public 
    {
        contractOwner = msg.sender;
        flightSuretyData = FlightSuretyData(_dataContractAddress);
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    function isOperational() 
                            public 
                            view 
                            returns(bool) 
    {
        return flightSuretyData.isOperational(); // Modify to call data contract's status
    }

    function setOperationalStatus(bool _mode) external requireContractOwner {
        require(_mode != isOperational(), "Mode is already that");
        flightSuretyData.setOperatingStatus(_mode);
        emit OperationalStatusChange(_mode);
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

  
   /**
    * @dev Add an airline to the registration queue
    *
    */   
    function registerAirline
                            (   
                                address _newAirline
                            )
                            public
                            requireIsOperational
                            requireAirlineRegAndFunded
    {
        require(!flightSuretyData.isAirline(_newAirline), "Airline has already been registered");
        
        uint256 numRegisteredAirlines = flightSuretyData.numRegisteredAirlines();
        // Use consensus
        if (numRegisteredAirlines >= CONSENSUS_NUM) {
            
            // Check if sender has already voted for airline
            address[] memory votes = flightSuretyData.getAirlineVotes(_newAirline);
            bool alreadyVoted = false;
            for (uint v = 0; v < votes.length; v++) {
                if (votes[v] == msg.sender) {
                    alreadyVoted = true;
                    break;
                }
            }
            require(!alreadyVoted, "You have already voted for that airline.");

            // if not add a vote for it
            flightSuretyData.addAirlineVote(msg.sender, _newAirline);
            votes = flightSuretyData.getAirlineVotes(_newAirline);
            // check for approval conditions
            if (votes.length > numRegisteredAirlines.div(2)) {
                flightSuretyData.clearAirlineVotes(_newAirline);
                flightSuretyData.registerAirline(_newAirline);
                emit AirlineRegistered(_newAirline);
            } else {
                emit AirlineVotedFor(_newAirline, msg.sender);
            }
            
        } else {
            flightSuretyData.registerAirline(_newAirline);
            emit AirlineRegistered(_newAirline);
        }

    }

    // Fund an airline
    function fundRegisteredAirline () public payable requireIsOperational requireAirline {
        flightSuretyData.fundAirline.value(msg.value)(msg.sender, msg.value);
        emit AirlineFunded(msg.sender);
    }


   /**
    * @dev Register a future flight for insuring.
    *
    */  
    // Frontend should pass _flight as web3.fromUtf8(_flight)
    function registerFlight ( address _airline, uint256 _time, bytes32 _flight) public requireIsOperational requireAirlineRegAndFunded /*requireNewFlight(_flight)*/ {
        
        flightSuretyData.registerFlight(_airline, _time, _flight);
        emit FlightRegistered(_flight);
    }

    function buyFlightInsurance ( bytes32 _flight ) public payable isMaxOneEther requireIsOperational requireFlightExists( _flight ) {
        flightSuretyData.buyFlightInsurance.value(msg.value)(_flight, msg.sender);
        emit FlightInsurancePurchased(_flight, msg.sender);
    }
    
   /**
    * @dev Called after oracle has updated flight status
    *
    */  
    function processFlightStatus
                                (
                                    bytes32 flight,
                                    uint8 statusCode,
                                    bytes32 _oracleResponseKey
                                )
                                private requireIsOperational
    {
        if (statusCode == STATUS_CODE_LATE_AIRLINE) {
            flightSuretyData.creditInsurees(flight);
        }
            flightSuretyData.updateFlightStatus(statusCode, flight);
            oracleResponses[_oracleResponseKey].isOpen = false;
            emit FlightStatusFinalized(flight, statusCode);
    }


    // Generate a request for oracles to fetch flight information
    function fetchFlightStatus
                        (
                            bytes32 _flight
                        )
                        external
    {
        uint8 index = getRandomIndex(msg.sender);
        address airline;
        bytes32 flight;
        uint256 timestamp;
        (airline, flight, timestamp,,) = flightSuretyData.getFlightInformation(_flight);
        // Generate a unique key for storing the request
        bytes32 key = keccak256(abi.encodePacked(index, airline, _flight, timestamp));
        oracleResponses[key] = ResponseInfo({
                                                requester: msg.sender,
                                                isOpen: true
                                            });

        emit OracleRequest(index, airline, _flight, timestamp);
    }

    function getAllFlights () external view returns (bytes32[])
    {
        return flightSuretyData.getAllFlights();
    }

    function withdrawInsureeCredit() external requireHasInsureeBalance(msg.sender) {
        flightSuretyData.payInsuree(msg.sender);
        emit InsureePaid(msg.sender);
    }


// region ORACLE MANAGEMENT

    // Incremented to add pseudo-randomness at various points
    uint8 private nonce = 0;    

    // Fee to be paid when registering oracle
    uint256 public constant REGISTRATION_FEE = 1 ether;

    // Number of oracles that must respond for valid status
    uint256 private constant MIN_RESPONSES = 3;


    struct Oracle {
        bool isRegistered;
        uint8[3] indexes;        
    }

    // Track all registered oracles
    mapping(address => Oracle) private oracles;

    // Model for responses from oracles
    struct ResponseInfo {
        address requester;                              // Account that requested status
        bool isOpen;                                    // If open, oracle responses are accepted
        mapping(uint8 => address[]) responses;          // Mapping key is the status code reported
                                                        // This lets us group responses and identify
                                                        // the response that majority of the oracles
    }

    // Track all oracle responses
    // Key = hash(index, flight, timestamp)
    mapping(bytes32 => ResponseInfo) private oracleResponses;

    

    // Register an oracle with the contract
    function registerOracle
                            (
                            )
                            external
                            payable
    {
        // Require registration fee
        require(msg.value >= REGISTRATION_FEE, "Registration fee is required");

        uint8[3] memory indexes = generateIndexes(msg.sender);

        oracles[msg.sender] = Oracle({
                                        isRegistered: true,
                                        indexes: indexes
                                    });
        emit OracleRegistered(msg.sender);
    }

    function getMyIndexes
                            (
                            )
                            view
                            external
                            returns(uint8[3])
    {
        require(oracles[msg.sender].isRegistered, "Not registered as an oracle");

        return oracles[msg.sender].indexes;
    }




    // Called by oracle when a response is available to an outstanding request
    // For the response to be accepted, there must be a pending request that is open
    // and matches one of the three Indexes randomly assigned to the oracle at the
    // time of registration (i.e. uninvited oracles are not welcome)
    function submitOracleResponse
                        (
                            uint8 index,
                            address airline,
                            bytes32 flight,
                            uint256 timestamp,
                            uint8 statusCode
                        )
                        external
    {
        require((oracles[msg.sender].indexes[0] == index) || (oracles[msg.sender].indexes[1] == index) || (oracles[msg.sender].indexes[2] == index), "Index does not match oracle request");


        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp));
        require(oracleResponses[key].isOpen, "Flight or timestamp do not match oracle request");

        oracleResponses[key].responses[statusCode].push(msg.sender);

        // Information isn't considered verified until at least MIN_RESPONSES
        // oracles respond with the *** same *** information
        emit OracleReport(airline, flight, timestamp, statusCode);
        if (oracleResponses[key].responses[statusCode].length >= MIN_RESPONSES) {

            emit FlightStatusInfo(airline, flight, timestamp, statusCode);

            // Handle flight status as appropriate
            processFlightStatus(flight, statusCode, key);
        }
    }


    function getFlightKey
                        (
                            address airline,
                            bytes32 flight,
                            uint256 timestamp
                        )
                        pure
                        internal
                        returns(bytes32) 
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    // Returns array of three non-duplicating integers from 0-9
    function generateIndexes
                            (                       
                                address account         
                            )
                            internal
                            returns(uint8[3])
    {
        uint8[3] memory indexes;
        indexes[0] = getRandomIndex(account);
        
        indexes[1] = indexes[0];
        while(indexes[1] == indexes[0]) {
            indexes[1] = getRandomIndex(account);
        }

        indexes[2] = indexes[1];
        while((indexes[2] == indexes[0]) || (indexes[2] == indexes[1])) {
            indexes[2] = getRandomIndex(account);
        }

        return indexes;
    }

    // Returns array of three non-duplicating integers from 0-9
    function getRandomIndex
                            (
                                address account
                            )
                            internal
                            returns (uint8)
    {
        uint8 maxValue = 10;

        // Pseudo random number...the incrementing nonce adds variation
        uint8 random = uint8(uint256(keccak256(abi.encodePacked(blockhash(block.number - nonce++), account))) % maxValue);

        if (nonce > 250) {
            nonce = 0;  // Can only fetch blockhashes for last 256 blocks so we adapt
        }

        return random;
    }

// endregion

}   