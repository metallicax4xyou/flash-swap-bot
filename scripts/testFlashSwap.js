const hre = require("hardhat");

// Uniswap V3 Addresses
// const UNISWAP_V3_FACTORY = "0x1F98431c8aD98523631AE4a59f267346ea31F984"; // Factory not strictly needed for this script
const WETH_ADDRESS = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"; // WETH on mainnet

async function main() {
    // 1. Get Signer
    const [deployer] = await hre.ethers.getSigners();
    console.log("Deploying contracts with the account:", deployer.address);
    console.log("Account balance:", (await hre.ethers.provider.getBalance(deployer.address)).toString()); // Log balance

    // 2. Get Contract Factory
    const FlashSwap = await hre.ethers.getContractFactory("FlashSwap");

    // 3. Define Uniswap V3 Router and Quoter Addresses (Mainnet)
    const uniswapV3RouterAddress = "0xE592427A0AEce92De3Edee1F18E0157C05861564";
    const uniswapV3QuoterAddress = "0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6";

    // 4. Deploy the FlashSwap Contract
    console.log("Deploying FlashSwap...");
    const flashSwap = await FlashSwap.deploy(uniswapV3RouterAddress, uniswapV3QuoterAddress);
    // In ethers v6, await deploy() waits for deployment, no need for waitForDeployment()
    const flashSwapAddress = await flashSwap.getAddress();
    console.log("FlashSwap deployed to:", flashSwapAddress);

    // 5. Define Pool Address
    // Example: USDC/WETH 0.05% pool on mainnet
    const poolAddress = "0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640";

    // 6. Define Amount to Borrow (Make sure it's reasonable for the pool)
    // Borrowing 1 WETH for testing (10 might exceed pool liquidity sometimes)
    const amountToBorrow = hre.ethers.parseUnits("1", 18); // Borrow 1 WETH
    console.log(`Attempting to borrow: ${hre.ethers.formatUnits(amountToBorrow, 18)} WETH`);

    // 7. Call the initiateFlashSwap Function
    console.log(`Initiating flash swap on pool ${poolAddress}...`);
    try {
        const tx = await flashSwap.initiateFlashSwap(
            poolAddress,
            WETH_ADDRESS, // Address of the token we intend to borrow (WETH)
            amountToBorrow // Amount of WETH to borrow (passed as amount0 in contract)
        );
        console.log("Transaction sent:", tx.hash);
        console.log("Waiting for transaction confirmation...");
        const receipt = await tx.wait();
        console.log("Transaction confirmed in block:", receipt.blockNumber);
        console.log("Flash swap apparently succeeded! (Check contract logic)"); // This is unlikely with current contract
    } catch (error) {
        console.error("\n--- Flash swap transaction failed as expected ---");
        console.error("Error executing initiateFlashSwap:");
        // console.error(error); // Log the full error object if needed for deep debug
        if (error.reason) {
             console.error("Revert Reason:", error.reason); // Often helpful
        } else {
             console.error("Error message:", error.message); // Fallback message
        }
        console.error("This failure is expected because the uniswapV3FlashCallback currently lacks repayment logic.");
        console.error("-------------------------------------------------\n");
        // We don't exit(1) here in an educational context, just report.
    }
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error("\n--- Script execution failed ---");
        console.error(error);
        process.exit(1);
    });
