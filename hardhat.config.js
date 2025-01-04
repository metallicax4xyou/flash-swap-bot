require("hardhat-deploy");
require("@nomiclabs/hardhat-ethers");
require("@nomiclabs/hardhat-etherscan");

// Load environment variables from .env file. Suppress warnings if dotenv is missing.
require("dotenv").config({ silent: true });

module.exports = {
  solidity: {
      compilers: [
            {
                    version: "0.8.19", // Use a Solidity version compatible with Uniswap V3
                          },
                                {
                                        version: "0.7.6", // Uniswap V3 Periphery uses 0.7.6
                                              }
                                                  ],
                                                    },
                                                      networks: {
                                                          hardhat: {
                                                                forking: {
                                                                        url: "https://eth-mainnet.g.alchemy.com/v2/WcDsq7m0lStFkxdphGwFAgtJeGbrGVpd", // YOUR ALCHEMY URL!
                                                                              }
                                                                                  }
                                                                                    },
                                                                                      paths: {
                                                                                          sources: "./contracts",     // Where your .sol contracts are
                                                                                              tests: "./test",             // Where your tests are
                                                                                                  cache: "./cache",           // Cache directory (for compilation artifacts)
                                                                                                      artifacts: "./artifacts",   // Where to put compiled output
                                                                                                        }
                                                                                                        };