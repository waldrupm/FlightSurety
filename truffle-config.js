// var HDWalletProvider = require("truffle-hdwallet-provider");
// var mnemonic = "candy maple cake sugar pudding cream honey rich smooth crumble sweet treat";

module.exports = {
  networks: {
    development: {
      host: "127.0.0.1",
      port: 7545,
      network_id: "*" // Match any network id
    },
    develop: {
      accounts: 40,
      defaultEtherBalance: 500,
      blockTime: 0
    }
  },
  compilers: {
    solc: {
      version: "^0.4.24"
    }
  }
};