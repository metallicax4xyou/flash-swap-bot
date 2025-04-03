const hre = require("hardhat");

// Uniswap V3 Addresses
// const UNISWAP_V3_FACTORY = "0x1F98431c8aD98523631AE4a59f267346ea31F984"; // Factory not strictly needed for this script
const WETH_ADDRESS = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"; // WETH on mainnet

async function main() {
    // 1. Get Signer
    const [deployer] = await hre.ethers.getSigners();
    console.log("Deploying contracts with the account:", deployer.address);
    // Ensure the deployer has some ETH in the forked environment
    const balance = await hre.ethers.provider.getBalance(deployer.address);
    console.log("Account balance:", hre.ethers.formatEther(balance), "ETH");
    if (balance === 0n) {
        console.warn("Deployer account has no ETH on the forked network. Sending some...");
        // Send 100 test ETH to the deployer account (only works on Hardhat Network)
        await hre.network.provider.send("hardhat_setBalance", [
            deployer.address,
            "0x56BC75E2D63100000", // 100 ETH in hexadecimal wei
        ]);
        console.log("New Account balance:", hre.ethers.formatEther(await hre.ethers.provider.getBalance(deployer.address)), "ETH");
    }


    // 2. Get Contract Factory
    const FlashSwap = await hre.ethers.getContractFactory("FlashSwap");

    // 3. Define Uniswap V3 Router and Quoter Addresses (Mainnet)
    const uniswapV3RouterAddress = "0xE592427A0AEce92De3Edee1F18E0157C05861564";
    const uniswapV3QuoterAddress = "0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6";

    // 4. Deploy the FlashSwap Contract
    console.log("Deploying FlashSwap...");
    const flashSwap = await FlashSwap.deploy(uniswapV3RouterAddress, uniswapV3QuoterAddress);
    // In ethers v6, await deploy() waits for deployment.
    // Get address using .target
    const flashSwapAddress = flashSwap.target; // <<< FIX IS HERE
    console.log("FlashSwap deployed to:", flashSwapAddress);

    // 5. Define Pool Address
    // Example: USDC/WETH 0.05% pool on mainnet
    const poolAddress = "0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640"; // USDC/WETH 0.05%

    // --- Get Pool Tokens for clarity ---
    const poolContract = await hre.ethers.getContractAt("IUniswapV3Pool", poolAddress);
    const token0Address = await poolContract.token0();
    const token1Address = await poolContract.token1();
    console.log(`Pool ${poolAddress} tokens: Token0=${token0Address}, Token1=${token1Address}`);
    // WETH is Token1 in this specific pool (0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2)
    // USDC is Token0 (0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48)

    // 6. Define Amount to Borrow
    const amountToBorrow = hre.ethers.parseUnits("1", 18); // Borrow 1 WETH (Token1)
    console.log(`Attempting to borrow: ${hre.ethers.formatUnits(amountToBorrow, 18)} WETH (Token1)`);


    // 7. Call the initiateFlashSwap Function
    console.log(`Initiating flash swap on pool ${poolAddress}...`);
    try {
        // We are borrowing WETH (Token1), so amount0 should be 0, amount1 is amountToBorrow
        // The current FlashSwap.sol initiateFlashSwap BORROWS TOKEN0.
        // We will keep it as is for now, but highlight the mismatch
        console.warn("NOTE: Script specifies WETH_ADDRESS, but contract's initiateFlashSwap currently requests amount0.");
        console.warn(`Executing: flashSwap.initiateFlashSwap(${poolAddress}, ${WETH_ADDRESS}, ${amountToBorrow})`);

        const tx = await flashSwap.initiateFlashSwap(
            poolAddress,
            WETH_ADDRESS, // Address of token we INTEND to borrow (currently unused in contract)
            amountToBorrow // Amount we pass (currently used as amount0 in contract)
        );
        console.log("Transaction sent:", tx.hash);
        console.log("Waiting for transaction confirmation...");
        const receipt = await tx.wait();
        console.log("Transaction confirmed in block:", receipt.blockNumber);
        console.log("Flash swap apparently succeeded! (Check contract logic)"); // Unlikely
    } catch (error) {
        console.error("\n--- Flash swap transaction failed (likely expected) ---");
        console.error("Error executing initiateFlashSwap:");
        // Log more detailed error info if available
        if (error.transactionHash) {
             console.error("  Transaction Hash:", error.transactionHash);
        }
         if (error.reason) {
             console.error("  Revert Reason:", error.reason);
        } else if (error.data) {
             console.error("  Error Data:", error.data);
             // You might need a decoder for specific contract errors if `reason` is not populated
        } else {
             console.error("  Error message:", error.message);
        }
        console.error("\n  This failure is expected because the uniswapV3FlashCallback lacks correct repayment and data handling logic.");
        console.error("------------------------------------------------------\n");
    }
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error("\n--- Script execution failed ---");
        console.error(error);
        process.exit(1);
    });
