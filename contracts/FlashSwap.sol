// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v3-periphery/contracts/interfaces/IQuoter.sol";

import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-core/contracts/interfaces/callback/IUniswapV3FlashCallback.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "hardhat/console.sol"; // Keep for logging

contract FlashSwap is IUniswapV3FlashCallback {

    ISwapRouter public immutable swapRouter;
    IQuoter public immutable quoter;
    address public owner;

    // Restore struct definition
    struct FlashCallbackData {
        uint amount0Borrowed;
        uint amount1Borrowed;
        address caller;
        address poolAddress; // Passed for verification
        bytes params;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "FlashSwap: Not owner");
        _;
    }

    constructor(address _swapRouter, address _quoter) {
        swapRouter = ISwapRouter(_swapRouter);
        quoter = IQuoter(_quoter);
        owner = msg.sender;
    }

    // --- Uniswap V3 Flash Callback ---
    // Restore full logic WITH data decoding
    function uniswapV3FlashCallback(
        uint256 fee0,
        uint256 fee1,
        bytes calldata data // Expecting encoded FlashCallbackData
    ) external override {
        console.log("!!! FULL+DATA Callback Entered !!! Fee0:", fee0, "Fee1:", fee1);

        // Decode the data we passed from initiateFlashSwap
        FlashCallbackData memory decodedData = abi.decode(data, (FlashCallbackData));
        console.log("Decoded Pool Address from data:", decodedData.poolAddress);
        console.log("Decoded Amount0 Borrowed:", decodedData.amount0Borrowed);
        console.log("Decoded Amount1 Borrowed:", decodedData.amount1Borrowed);
        console.log("Decoded Caller:", decodedData.caller);


        // --- Security Check ---
        // Ensure the callback is coming ONLY from the pool we stored in the data.
        require(msg.sender == decodedData.poolAddress, "FlashSwap: Callback from unexpected pool");
        console.log("Pool address matches msg.sender.");

        // Get token addresses directly from the pool contract
        IUniswapV3Pool pool = IUniswapV3Pool(msg.sender); // Use msg.sender (verified pool)
        address token0 = pool.token0();
        address token1 = pool.token1();

        // Calculate the total amounts required for repayment using DECODED amounts
        uint totalAmount0ToRepay = decodedData.amount0Borrowed + fee0;
        uint totalAmount1ToRepay = decodedData.amount1Borrowed + fee1;

        console.log("Pool Address (msg.sender):", msg.sender);
        console.log("Token0:", token0);
        console.log("Token1:", token1);
        console.log("Total Token0 to Repay:", totalAmount0ToRepay);
        console.log("Total Token1 to Repay:", totalAmount1ToRepay);

        // --- ARBITRAGE LOGIC GOES HERE ---
        // (Using decodedData.params if needed)

        // --- Repayment Approval ---
        if (totalAmount0ToRepay > 0) {
             console.log("Checking Token0 balance...");
             uint currentToken0Balance = IERC20(token0).balanceOf(address(this));
             console.log("Current Token0 Balance:", currentToken0Balance);
             require(currentToken0Balance >= totalAmount0ToRepay, "FlashSwap: Insufficient token0 for repayment");
             console.log("Token0 balance sufficient. Approving pool for Token0...");
             IERC20(token0).approve(msg.sender, totalAmount0ToRepay);
             console.log("Token0 Approved.");
        }

        if (totalAmount1ToRepay > 0) {
             console.log("Checking Token1 balance...");
             uint currentToken1Balance = IERC20(token1).balanceOf(address(this));
             console.log("Current Token1 Balance:", currentToken1Balance);
             require(currentToken1Balance >= totalAmount1ToRepay, "FlashSwap: Insufficient token1 for repayment");
             console.log("Token1 balance sufficient. Approving pool for Token1...");
             IERC20(token1).approve(msg.sender, totalAmount1ToRepay);
             console.log("Token1 Approved.");
        }

        console.log("--- Exiting FULL+DATA uniswapV3FlashCallback ---");
    }


    // --- Initiate Flash Swap ---
    // Restore correct data encoding
    function initiateFlashSwap(address _poolAddress, uint _amount0, uint _amount1, bytes memory _params) external {
        require((_amount0 > 0 && _amount1 == 0) || (_amount1 > 0 && _amount0 == 0), "FlashSwap: Borrow only one token");

        // Prepare the data struct to be passed to the callback
        FlashCallbackData memory callbackData = FlashCallbackData({
            amount0Borrowed: _amount0,
            amount1Borrowed: _amount1,
            caller: msg.sender,          // Store the original caller's address
            poolAddress: _poolAddress,   // Store pool address for verification in callback
            params: _params              // Pass through any extra data
        });

        // Trigger the flash loan on the specified pool
        IUniswapV3Pool(_poolAddress).flash(
            address(this),              // Recipient is this contract
            _amount0,                   // Amount of token0 to borrow
            _amount1,                   // Amount of token1 to borrow
            abi.encode(callbackData)    // <<< Encode the STRUCT correctly
        );
        console.log("Initiated flash with encoded struct data."); // Log initiation
    }

    // --- Utility Functions ---
    function withdrawEther() external onlyOwner {
        payable(owner).transfer(address(this).balance);
    }

    function withdrawToken(address tokenAddress) external onlyOwner {
        IERC20 token = IERC20(tokenAddress);
        uint balance = token.balanceOf(address(this));
        require(balance > 0, "FlashSwap: No tokens to withdraw");
        token.transfer(owner, balance);
    }

    receive() external payable {}
}
