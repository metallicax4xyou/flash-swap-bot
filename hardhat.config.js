require("@nomicfoundation/hardhat-toolbox");

/** @type import('hardhat/config').HardhatUserConfig */
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
                                                                        url: "YOUR_ALCHEMY_URL", // Replace with your Alchemy URL
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