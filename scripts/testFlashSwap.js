const hre = require("hardhat");

// Uniswap V3 Addresses
const UNISWAP_V3_FACTORY = "0x1F98431c8aD98523631AE4a59f267346ea31F984";
const WETH_ADDRESS = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"; // Example: WETH on mainnet

async function main() {
    // 1. Get Signer
        const [deployer] = await hre.ethers.getSigners();
            console.log("Deploying contracts with the account:", deployer.address);

                // 2. Get Contract Factories
                    const FlashSwap = await hre.ethers.getContractFactory("FlashSwap");

                        // 3. Define Uniswap V3 Router and Quoter Addresses
                            const uniswapV3RouterAddress = "0xE592427A0AEce92De3Edee1F18E0157C05861564";
                                const uniswapV3QuoterAddress = "0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6";

                                    // 4. Deploy the FlashSwap Contract
                                        const flashSwap = await FlashSwap.deploy(uniswapV3RouterAddress, uniswapV3QuoterAddress
                                            const flashSwapAddress = await flashSwap.getAddress();
                                                console.log("FlashSwap deployed to:", flashSwapAddress);

                                                        // 5. Define Pool Address
                                                            // Replace with the actual pool address you want to interact with
                                                                const poolAddress = "0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640"; // Example: USDC/WETH 0.05% pool on mainnet

                                                                    // 6. Define Amount to Borrow
                                                                        const amountToBorrow = hre.ethers.parseUnits("10", 18); // Example: Borrow 10 WETH

                                                                            // 7. Call the initiateFlashSwap Function
                                                                                console.log("Initiating flash swap...");
                                                                                    const tx = await flashSwap.initiateFlashSwap(poolAddress, WETH_ADDRESS, amountToBorrow);
                                                                                        await tx.wait();

                                                                                            console.log("Flash swap initiated successfully!");
                                                                                            }

                                                                                            main()
                                                                                                .then(() => process.exit(0))
                                                                                                    .catch((error) => {
                                                                                                            console.error(error);
                                                                                                                    process.exit(1);
                                                                                                                        });