const hre = require("hardhat");

async function main() {
    console.log("Starting minimal script...");

    try {
        const addressToCheck = "0x8ad599c3A0b1A56AAd039ddAc6837Db27B2ff1DC";
        console.log("Address string:", addressToCheck);

        // Check if hre.ethers exists
        if (!hre.ethers) {
            console.error("FATAL: hre.ethers is undefined!");
            return;
        }
        console.log("hre.ethers object found.");

        // Check if getAddress exists
        if (typeof hre.ethers.getAddress !== 'function') {
             console.error("FATAL: hre.ethers.getAddress is not a function!");
             return;
        }
        console.log("hre.ethers.getAddress function found.");

        // Try to checksum the address
        const checksummedAddress = hre.ethers.getAddress(addressToCheck);
        console.log("Checksummed address:", checksummedAddress);
        console.log("✅ Checksum successful!");

    } catch (error) {
        console.error("\n--- Error during checksum test ---");
        console.error(error);
        console.error("----------------------------------");
    }
}

main().catch((error) => {
    console.error("Script execution failed:", error);
    process.exitCode = 1;
});
