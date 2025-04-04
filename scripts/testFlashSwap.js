const hre = require("hardhat");

// Uniswap V3 Addresses - Using MANUALLY VERIFIED CHECKSUMMED strings
const WETH_ADDRESS = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"; // Already correct
const USDC_ADDRESS = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"; // Already correct

// Pool Addresses for Test - Using MANUALLY VERIFIED CHECKSUMMED strings
const POOL_A_WETH_USDC_005 = "0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640"; // Already correct
const POOL_B_USDC_WETH_030 = "0x8ad599c3A0b1A56AAd039ddAc6837Db27B2f64C5"; // <<< CORRECT CHECKSUM USED DIRECTLY

// Router Address - Using MANUALLY VERIFIED CHECKSUMMED string
const ROUTER_ADDRESS = "0xE592427A0AEce92De3Edee1F18E0157C05861564"; // Already correct

// Pool Fees
const FEE_A = 500;  // 0.05%
const FEE_B = 3000; // 0.3%

async function main() {
    const [deployer] = await hre.ethers.getSigners();
    console.log("Deploying contracts with the account:", deployer.address);

    // Ensure the deployer has some ETH
    let balance = await hre.ethers.provider.getBalance(deployer.address);
    console.log("Account balance:", hre.ethers.formatUnits(balance, "ether"), "ETH");
    if (balance === 0n) {
        console.warn("Deployer has no ETH...");
        await hre.network.provider.send("hardhat_setBalance", [deployer.address, "0x56BC75E2D63100000"]); // 100 ETH
        console.log("Sent 100 ETH to deployer");
    }

    const FlashSwap = await hre.ethers.getContractFactory("FlashSwap");

    console.log("Deploying FlashSwap...");
    // Pass the directly checksummed router address
    const flashSwap = await FlashSwap.deploy(ROUTER_ADDRESS);
    const flashSwapAddress = flashSwap.target;
    console.log("FlashSwap deployed to:", flashSwapAddress);

    // --- No Pre-funding ---
    const WETH_ABI = ["function balanceOf(address) view returns (uint)"];
    const wethContract = new hre.ethers.Contract(WETH_ADDRESS, WETH_ABI, hre.ethers.provider);
    console.log(`FlashSwap contract initial WETH balance: ${hre.ethers.formatUnits(await wethContract.balanceOf(flashSwapAddress), 18)} WETH`);

    // --- Define Flash Loan Parameters ---
    const poolForLoan = POOL_A_WETH_USDC_005;
    const amount0ToBorrow = 0n;
    const amount1ToBorrow = hre.ethers.parseUnits("1", 18);

    // --- Encode Arbitrage Parameters ---
    // Pass the directly checksummed addresses to encode
    const abiCoder = hre.ethers.AbiCoder.defaultAbiCoder();
    const arbitrageParams = abiCoder.encode(
        ['address', 'address', 'address', 'uint24', 'uint24', 'uint256', 'uint256'],
        [
            USDC_ADDRESS,           // Directly checksummed
            POOL_A_WETH_USDC_005,   // Directly checksummed
            POOL_B_USDC_WETH_030,   // Directly checksummed
            FEE_A,
            FEE_B,
            0,                      // amountOutMinimum1
            0                       // amountOutMinimum2
        ]
    );
    console.log("Encoded Arbitrage Params:", arbitrageParams);

    console.log(`Attempting to borrow: ${hre.ethers.formatUnits(amount1ToBorrow, 18)} WETH (Token1) from ${poolForLoan}`);

    // --- Call initiateFlashSwap ---
    console.log(`Initiating flash swap...`);
    try {
        console.warn(`Executing: flashSwap.initiateFlashSwap(${poolForLoan}, ${amount0ToBorrow}, ${amount1ToBorrow}, [params])`);

        const tx = await flashSwap.initiateFlashSwap(
            poolForLoan,
            amount0ToBorrow,
            amount1ToBorrow,
            arbitrageParams
        );
        console.log("Transaction sent:", tx.hash);
        await tx.wait();
        console.log("⚠️ Flash swap SUCCEEDED? (UNEXPECTED)");

    } catch (error) {
        console.error("\n--- Flash swap transaction failed (EXPECTED) ---");
        console.error("Error executing initiateFlashSwap:");
        // ... (Error logging remains the same) ...
        if (error.transactionHash) { console.error("  Transaction Hash:", error.transactionHash); }
        let reason = error.reason;
        if (error.data && !reason) { try { const ERROR_SELECTOR = "0x08c379a0"; if (error.data.startsWith(ERROR_SELECTOR)) { reason = hre.ethers.AbiCoder.defaultAbiCoder().decode(['string'], "0x" + error.data.substring(10))[0]; } else { reason = hre.ethers.toUtf8String("0x" + error.data.substring(138)); } } catch (e) { /* Ignore */ } }
         if (reason) { console.error("  Revert Reason:", reason); } else if (error.message && error.message.includes("reverted with reason string")) { try { reason = error.message.split("reverted with reason string '")[1].split("'")[0]; console.error("  Revert Reason:", reason); } catch (e) { /* Ignore */ } }
        if (!reason) { console.error("  Error message:", error.message); }

        console.error("\n  This failure is EXPECTED. Look for 'FlashSwap: Insufficient funds...' or 'Swap X failed...'");
        console.error("------------------------------------------------------\n");
    }
}

main().catch((error) => { console.error(error); process.exitCode = 1; });
