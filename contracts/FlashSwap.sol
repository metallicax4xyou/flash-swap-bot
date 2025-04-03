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
    address public owner;

    // NOTE: FlashCallbackData struct is REMOVED for this minimal test

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
    // EXTREMELY SIMPLIFIED FOR DEBUGGING - DOES NOT REPAY LOAN
    function uniswapV3FlashCallback(
        uint256 fee0,
        uint256 fee1,
        bytes calldata data // data is received but unused in this version
    ) external override {
        // Only try to log entry.
        console.log("!!! MINIMAL uniswapV3FlashCallback Entered !!! Fee0:", fee0, "Fee1:", fee1);

        // --- NO DECODING ---
        // --- NO SECURITY CHECK ---
        // --- NO BALANCE CHECKS ---
        // --- NO APPROVALS ---
        // --- NO ARBITRAGE ---

        // This callback will DEFINITELY cause the pool to fail repayment checks,
        // but we want to see if this log message prints AT ALL.
    }


    // --- Initiate Flash Swap ---
    // Uses EMPTY bytes data for this test
    function initiateFlashSwap(address _poolAddress, uint _amount0, uint _amount1, bytes memory _params) external { // _params is unused now but keep signature
        require((_amount0 > 0 && _amount1 == 0) || (_amount1 > 0 && _amount0 == 0), "FlashSwap: Borrow only one token");

        // Pass completely empty bytes
        bytes memory emptyData = bytes('0x'); // <<< USE EMPTY BYTES

        IUniswapV3Pool(_poolAddress).flash(
            address(this),
            _amount0,
            _amount1,
            emptyData // <<< PASS EMPTY BYTES HERE
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
