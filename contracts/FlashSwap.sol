// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v3-periphery/contracts/interfaces/IQuoter.sol";

import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-core/contracts/interfaces/callback/IUniswapV3FlashCallback.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "hardhat/console.sol"; // Import for logging

contract FlashSwap is IUniswapV3FlashCallback {

    ISwapRouter public immutable swapRouter;
    IQuoter public immutable quoter;
    address public owner; // Owner for utility functions

    // Struct to pass necessary data to the callback
    struct FlashCallbackData {
        uint amount0Borrowed; // Amount of token0 requested in the flash call
        uint amount1Borrowed; // Amount of token1 requested in the flash call
        address caller;       // Original initiator of the flash swap
        address poolAddress;  // Address of the pool for verification in callback
        bytes params;         // Optional extra data from the caller for their logic
    }

    // --- Modifiers ---
    modifier onlyOwner() {
        require(msg.sender == owner, "FlashSwap: Not owner");
        _;
    }

    // --- Constructor ---
    constructor(address _swapRouter, address _quoter) {
        swapRouter = ISwapRouter(_swapRouter);
        quoter = IQuoter(_quoter);
        owner = msg.sender; // Set the contract deployer as the owner
    }

    // --- Uniswap V3 Flash Callback ---
    /**
     * @notice Callback function executed by the Uniswap V3 pool after assets are sent.
     * @dev This function must contain the logic to execute arbitrage and ensure repayment.
     * @param fee0 The fee amount owed for borrowing token0, calculated by the pool.
     * @param fee1 The fee amount owed for borrowing token1, calculated by the pool.
     * @param data Arbitrary data passed from the `flash` call, encoded as FlashCallbackData.
     */
    function uniswapV3FlashCallback(
        uint256 fee0,
        uint256 fee1,
        bytes calldata data
    ) external override {
        console.log("!!! uniswapV3FlashCallback Entered !!!"); // <<< ADD THIS LINE VERY FIRST
        
        // Decode the data we passed from initiateFlashSwap
        FlashCallbackData memory decodedData = abi.decode(data, (FlashCallbackData));

        // --- Security Check ---
        require(msg.sender == decodedData.poolAddress, "FlashSwap: Callback from unexpected pool");

        IUniswapV3Pool pool = IUniswapV3Pool(decodedData.poolAddress);
        address token0 = pool.token0();
        address token1 = pool.token1();

        uint totalAmount0ToRepay = decodedData.amount0Borrowed + fee0;
        uint totalAmount1ToRepay = decodedData.amount1Borrowed + fee1;

        // --- Logging Start ---
        console.log("--- Inside uniswapV3FlashCallback ---");
        console.log("Pool Address (msg.sender):", msg.sender);
        console.log("Token0:", token0);
        console.log("Token1:", token1);
        console.log("Fee0:", fee0);
        console.log("Fee1:", fee1); // Check this value!
        console.log("Amount0 Borrowed:", decodedData.amount0Borrowed);
        console.log("Amount1 Borrowed:", decodedData.amount1Borrowed);
        console.log("Total Token0 to Repay:", totalAmount0ToRepay);
        console.log("Total Token1 to Repay:", totalAmount1ToRepay); // Loan + Fee

        // --- ARBITRAGE LOGIC GOES HERE ---
        // Placeholder for where swaps would occur

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
             uint currentToken1Balance = IERC20(token1).balanceOf(address(this)); // Get current balance
             console.log("Current Token1 Balance:", currentToken1Balance); // Log balance BEFORE check
             require(currentToken1Balance >= totalAmount1ToRepay, "FlashSwap: Insufficient token1 for repayment"); // Balance check
             console.log("Token1 balance sufficient. Approving pool for Token1..."); // Log if check passes
             IERC20(token1).approve(msg.sender, totalAmount1ToRepay); // Approve call
             console.log("Token1 Approved."); // Log if approval done
        }

        console.log("--- Exiting uniswapV3FlashCallback ---"); // Log end of callback
    }


    // --- Initiate Flash Swap ---
    /**
     * @notice Initiates a flash loan from a specific Uniswap V3 pool.
     * @param _poolAddress The address of the Uniswap V3 pool.
     * @param _amount0 The amount of token0 to borrow (pass 0 if borrowing token1).
     * @param _amount1 The amount of token1 to borrow (pass 0 if borrowing token0).
     * @param _params Optional extra data (encoded bytes) to pass to the callback for custom logic.
     */
    function initiateFlashSwap(address _poolAddress, uint _amount0, uint _amount1, bytes memory _params) external {
        require((_amount0 > 0 && _amount1 == 0) || (_amount1 > 0 && _amount0 == 0), "FlashSwap: Borrow only one token");

        FlashCallbackData memory callbackData = FlashCallbackData({
            amount0Borrowed: _amount0,
            amount1Borrowed: _amount1,
            caller: msg.sender,
            poolAddress: _poolAddress,
            params: _params
        });

        IUniswapV3Pool(_poolAddress).flash(
            address(this),
            _amount0,
            _amount1,
            abi.encode(callbackData)
        );
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
