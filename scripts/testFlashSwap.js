const hre = require("hardhat");

// Uniswap V3 Addresses
// const UNISWAP_V3_FACTORY = "0x1F98431c8aD98523631AE4a59f267346ea31F984"; // Factory not strictly needed for this script
const WETH_ADDRESS = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"; // WETH on mainnet
const USDC_ADDRESS = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"; // USDC on mainnet

async function main() {
    // 1. Get Signer
    const [deployer] = await hre.ethers.getSigners();
    console.log("Deploying contracts with the account:", deployer.address);

    // Ensure the deployer has some ETH in the forked environment
    let balance = await hre.ethers.provider.getBalance(deployer.address);
    console.log("Account balance:", hre.ethers.formatUnits(balance, "ether"), "ETH");

    if (balance === 0n) {
        console.warn("Deployer account has no ETH on the forked network. Sending some...");
        await hre.network.provider.send("hardhat_setBalance", [
            deployer.address, "0x56BC75E2D63100000" // 100 ETH
        ]);
        balance = await hre.ethers.provider.getBalance(deployer.address);
        console.log("New Account balance:", hre.ethers.formatUnits(balance, "ether"), "ETH");
    }

    // 2. Get Contract Factory
    const FlashSwap = await hre.ethers.getContractFactory("FlashSwap");

    // 3. Define Uniswap V3 Router and Quoter Addresses (Mainnet)
    const uniswapV3RouterAddress = "0xE592427A0AEce92De3Edee1F18E0157C05861564";
    const uniswapV3QuoterAddress = "0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6";

    // 4. Deploy the FlashSwap Contract
    console.log("Deploying FlashSwap...");
    const flashSwap = await FlashSwap.deploy(uniswapV3RouterAddress, uniswapV3QuoterAddress);
    const flashSwapAddress = flashSwap.target;
    console.log("FlashSwap deployed to:", flashSwapAddress);

    // --- Fund the FlashSwap contract with some WETH (to cover potential fees initially) ---
    // In a real scenario, profit covers fees, but for testing, let's give it some buffer.
    // We need the WETH contract interface to transfer.
    const WETH_ABI = ["function transfer(address to, uint amount) returns (bool)", "function deposit() payable", "function balanceOf(address) view returns (uint)"];
    const wethContract = new hre.ethers.Contract(WETH_ADDRESS, WETH_ABI, deployer);

    // Get some WETH if deployer doesn't have any (by wrapping ETH)
    const deployerWethBalance = await wethContract.balanceOf(deployer.address);
    console.log(`Deployer WETH balance: ${hre.ethers.formatUnits(deployerWethBalance, 18)} WETH`);
    if (deployerWethBalance < hre.ethers.parseUnits("0.1", 18)) {
        console.log("Getting some WETH for deployer by wrapping ETH...");
        const wrapTx = await wethContract.deposit({ value: hre.ethers.parseUnits("1", 18) }); // Wrap 1 ETH
        await wrapTx.wait();
        console.log(`New Deployer WETH balance: ${hre.ethers.formatUnits(await wethContract.balanceOf(deployer.address), 18)} WETH`);
    }
     // Send a small amount of WETH to the FlashSwap contract to cover potential fees
    const feeAmount = hre.ethers.parseUnits("0.01", 18); // 0.01 WETH
    console.log(`Transferring ${hre.ethers.formatUnits(feeAmount, 18)} WETH to FlashSwap contract for fee buffer...`);
    const transferTx = await wethContract.transfer(flashSwapAddress, feeAmount);
    await transferTx.wait();
    console.log(`FlashSwap contract WETH balance: ${hre.ethers.formatUnits(await wethContract.balanceOf(flashSwapAddress), 18)} WETH`);


    // 5. Define Pool Address
    const poolAddress = "0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640"; // USDC/WETH 0.05%

    // --- Get Pool Tokens for clarity ---
    const poolContract = await hre.ethers.getContractAt("IUniswapV3Pool", poolAddress);
    const token0Address = await poolContract.token0(); // Should be USDC
    const token1Address = await poolContract.token1(); // Should be WETH
    console.log(`Pool ${poolAddress} tokens: Token0=${token0Address} (USDC), Token1=${token1Address} (WETH)`);

    // 6. Define Amounts to Borrow
    const amount0ToBorrow = 0n; // Borrowing 0 USDC (Token0)
    const amount1ToBorrow = hre.ethers.parseUnits("1", 18); // Borrow 1 WETH (Token1)
    const params = '0x'; // No extra parameters for now

    console.log(`Attempting to borrow: ${hre.ethers.formatUnits(amount0ToBorrow, 6)} USDC (Token0)`); // USDC has 6 decimals
    console.log(`Attempting to borrow: ${hre.ethers.formatUnits(amount1ToBorrow, 18)} WETH (Token1)`);


    // 7. Call the initiateFlashSwap Function
    console.log(`Initiating flash swap on pool ${poolAddress}...`);
    try {
        console.warn(`Executing: flashSwap.initiateFlashSwap(${poolAddress}, ${amount0ToBorrow}, ${amount1ToBorrow}, ${params})`);

        const tx = await flashSwap.initiateFlashSwap(
            poolAddress,
            amount0ToBorrow, // _amount0
            amount1ToBorrow, // _amount1
            params           // _params
        );
        console.log("Transaction sent:", tx.hash);
        console.log("Waiting for transaction confirmation...");
        const receipt = await tx.wait();
        console.log("Transaction confirmed in block:", receipt.blockNumber);
        console.log("Flash swap apparently succeeded! (This is unexpected without arbitrage profit)");
    } catch (error) {
        console.error("\n--- Flash swap transaction failed (likely expected) ---");
        console.error("Error executing initiateFlashSwap:");
        // Try to get more detailed revert reason
        if (error.transactionHash) {
             console.error("  Transaction Hash:", error.transactionHash);
        }
        let reason = error.reason;
        if (!reason && error.data) {
            // If no reason, try decoding internal revert data (may require specific error ABI)
             try {
                 // Attempt simple string decoding (often works for require messages)
                 reason = hre.ethers.toUtf8String("0x" + error.data.substring(138)); // Remove function selector and offset/length data
             } catch (e) { /* Ignore decoding error */ }
        }
         if (reason) {
             console.error("  Revert Reason:", reason);
        } else if (error.message.includes("reverted with reason string")) {
             try {
                 reason = error.message.split("reverted with reason string '")[1].split("'")[0];
                 console.error("  Revert Reason:", reason);
             } catch (e) { /* Ignore extraction error */ }
        }
        // Fallback to full message if reason couldn't be extracted
        if (!reason) {
            console.error("  Error message:", error.message);
        }

        console.error("\n  This failure is likely expected because the callback currently lacks arbitrage profit to cover the fee (or balance checks fail).");
        console.error("  Check the revert reason above. 'TF' often means pool failure (likely insufficient funds on repayment). 'FlashSwap: Insufficient...' means our contract's check failed.");
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
