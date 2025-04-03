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

    // 3. Define Uniswap V3 Router Address (Mainnet)
    const uniswapV3RouterAddress = "0xE592427A0AEce92De3Edee1F18E0157C05861564";

    // 4. Deploy the FlashSwap Contract
    console.log("Deploying FlashSwap...");
    // Ensure only ONE argument is passed to match the current constructor
    const flashSwap = await FlashSwap.deploy(uniswapV3RouterAddress); // <<< CORRECTED CALL
    console.log("FlashSwap deployed to:", flashSwapAddress);

    // --- NO Pre-funding of the FlashSwap contract ---
    const WETH_ABI = ["function balanceOf(address) view returns (uint)"];
    const wethContract = new hre.ethers.Contract(WETH_ADDRESS, WETH_ABI, hre.ethers.provider); // Use default provider
    console.log(`FlashSwap contract initial WETH balance: ${hre.ethers.formatUnits(await wethContract.balanceOf(flashSwapAddress), 18)} WETH`);


    // 5. Define Pool Address
    const poolAddress = "0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640"; // USDC/WETH 0.05%

    // --- Get Pool Tokens ---
    const poolContract = await hre.ethers.getContractAt("IUniswapV3Pool", poolAddress);
    const token0Address = await poolContract.token0();
    const token1Address = await poolContract.token1();
    console.log(`Pool ${poolAddress} tokens: Token0=${token0Address} (USDC), Token1=${token1Address} (WETH)`);

    // 6. Define Amounts to Borrow
    const amount0ToBorrow = 0n; // 0 USDC
    const amount1ToBorrow = hre.ethers.parseUnits("1", 18); // 1 WETH
    const params = '0x'; // No extra parameters

    console.log(`Attempting to borrow: ${hre.ethers.formatUnits(amount0ToBorrow, 6)} USDC (Token0)`);
    console.log(`Attempting to borrow: ${hre.ethers.formatUnits(amount1ToBorrow, 18)} WETH (Token1)`);


    // 7. Call the initiateFlashSwap Function
    console.log(`Initiating flash swap on pool ${poolAddress}...`);
    try {
        console.warn(`Executing: flashSwap.initiateFlashSwap(${poolAddress}, ${amount0ToBorrow}, ${amount1ToBorrow}, ${params})`);

        const tx = await flashSwap.initiateFlashSwap(
            poolAddress,
            amount0ToBorrow,
            amount1ToBorrow,
            params
        );
        console.log("Transaction sent:", tx.hash);
        console.log("Waiting for transaction confirmation...");
        const receipt = await tx.wait();
        console.log("Transaction confirmed in block:", receipt.blockNumber);
        const finalContractWeth = await wethContract.balanceOf(flashSwapAddress);
        console.log(`FlashSwap contract final WETH balance: ${hre.ethers.formatUnits(finalContractWeth, 18)} WETH`);
        console.log("⚠️ Flash swap SUCCEEDED? (UNEXPECTED - transfer should have failed due to insufficient funds)");

    } catch (error) {
        console.error("\n--- Flash swap transaction failed (EXPECTED) ---"); // Now expected failure
        console.error("Error executing initiateFlashSwap:");
        if (error.transactionHash) {
             console.error("  Transaction Hash:", error.transactionHash);
        }
        let reason = error.reason;
        if (error.data && !reason) {
             try {
                const ERROR_SELECTOR = "0x08c379a0";
                if (error.data.startsWith(ERROR_SELECTOR)) {
                    reason = hre.ethers.AbiCoder.defaultAbiCoder().decode(['string'], "0x" + error.data.substring(10))[0];
                } else {
                     reason = hre.ethers.toUtf8String("0x" + error.data.substring(138));
                }
             } catch (e) { /* Ignore */ }
        }
         if (reason) {
             console.error("  Revert Reason:", reason);
        } else if (error.message && error.message.includes("reverted with reason string")) {
             try {
                 reason = error.message.split("reverted with reason string '")[1].split("'")[0];
                 console.error("  Revert Reason:", reason);
             } catch (e) { /* Ignore */ }
        }
        if (!reason) {
            console.error("  Error message:", error.message);
        }
        console.error("\n  This failure is EXPECTED because the contract starts with no WETH, performs a swap (losing fees), and cannot repay the loan + fee.");
        console.error("  Look for 'FlashSwap: Token1 transfer failed...' or similar revert reason.");
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
