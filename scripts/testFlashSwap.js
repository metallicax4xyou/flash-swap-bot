const hre = require("hardhat");

async function main() {
    console.log("Starting minimal script...");

    try {
        // Use the CORRECTLY checksummed address string
        const addressToCheck = "0x8ad599c3A0b1A56AAd039ddAc6837Db27B2f64C5"; // <<< CORRECT CHECKSUM
        console.log("Address string (Correct Checksum):", addressToCheck);

        if (!hre.ethers) { console.error("FATAL: hre.ethers is undefined!"); return; }
        console.log("hre.ethers object found.");

        if (typeof hre.ethers.getAddress !== 'function') { console.error("FATAL: hre.ethers.getAddress is not a function!"); return; }
        console.log("hre.ethers.getAddress function found.");

        // Try to checksum the CORRECTLY checksummed address
        // getAddress should return the same address if it's already checksummed correctly
        const checksummedAddress = hre.ethers.getAddress(addressToCheck);
        console.log("Result from getAddress:", checksummedAddress);

        // Verify it didn't change
        if (checksummedAddress === addressToCheck) {
            console.log("✅ Checksum successful (address was already correct)!");
        } else {
            console.error("❌ ERROR: getAddress changed an already correct address?");
        }

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
