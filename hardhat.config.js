require("hardhat-deploy");
// require("@nomiclabs/hardhat-ethers"); // Commented out: Older plugin, potentially conflicting with hardhat-toolbox's ethers v6
require("@nomiclabs/hardhat-etherscan"); // Keep for etherscan verification functionality
// Note: @nomicfoundation/hardhat-toolbox (in package.json) should provide the necessary Ethers v6 integration

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
                                                              // If using Alchemy, make sure the URL is correct and active
                                                              // You can set ALCHEMY_URL in a .env file or paste directly here (less secure)
                                                                forking: {
                                                                        url: process.env.ALCHEMY_URL || "https://eth-mainnet.g.alchemy.com/v2/WcDsq7m0lStFkxdphGwFAgtJeGbrGVpd", // Prioritize .env, fallback to placeholder
                                                                              },
                                                                        // Recommended: Increase default timeout for complex interactions or slower networks
                                                                        // timeout: 120000 // e.g., 120 seconds
                                                                        // Recommended: Specify a block number to fork from for consistency
                                                                        // blockNumber: 19000000 // Example block number
                                                                              }
                                                                                  },
                                                                                    paths: {
                                                                                        sources: "./contracts",     // Where your .sol contracts are
                                                                                            tests: "./test",             // Where your tests are (though your test file is in scripts/)
                                                                                            cache: "./cache",           // Cache directory (for compilation artifacts)
                                                                                            artifacts: "./artifacts",   // Where to put compiled output
                                                                                              },
                                                                                      // Optional: Etherscan config for contract verification
                                                                                      // etherscan: {
                                                                                      //   apiKey: process.env.ETHERSCAN_API_KEY
                                                                                      // }
                                                                                              };
