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

    struct FlashCallbackData {
        uint amount0Borrowed;
        uint amount1Borrowed;
        address caller;
        address poolAddress;
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
    // Trying EXPLICIT TRANSFER instead of APPROVE
    function uniswapV3FlashCallback(
        uint256 fee0,
        uint256 fee1,
        bytes calldata data // Expecting encoded FlashCallbackData
    ) external override {
        console.log("!!! TRANSFER TEST Callback Entered !!! Fee0:", fee0, "Fee1:", fee1);

        FlashCallbackData memory decodedData = abi.decode(data, (FlashCallbackData));
        console.log("Decoded Pool Address from data:", decodedData.poolAddress);
        console.log("Decoded Amount0 Borrowed:", decodedData.amount0Borrowed);
        console.log("Decoded Amount1 Borrowed:", decodedData.amount1Borrowed);
        console.log("Decoded Caller:", decodedData.caller);

        require(msg.sender == decodedData.poolAddress, "FlashSwap: Callback from unexpected pool");
        console.log("Pool address matches msg.sender.");

        address poolAddress = msg.sender; // Use msg.sender (verified pool)
        IUniswapV3Pool pool = IUniswapV3Pool(poolAddress);
        address token0 = pool.token0();
        address token1 = pool.token1();

        uint totalAmount0ToRepay = decodedData.amount0Borrowed + fee0;
        uint totalAmount1ToRepay = decodedData.amount1Borrowed + fee1;

        console.log("Pool Address (msg.sender):", poolAddress);
        console.log("Token0:", token0);
        console.log("Token1:", token1);
        console.log("Total Token0 to Repay:", totalAmount0ToRepay);
        console.log("Total Token1 to Repay:", totalAmount1ToRepay);

        // --- ARBITRAGE LOGIC GOES HERE ---

        // --- Repayment via Explicit Transfer ---
        if (totalAmount0ToRepay > 0) {
             console.log("Checking Token0 balance for transfer...");
             uint currentToken0Balance = IERC20(token0).balanceOf(address(this));
             console.log("Current Token0 Balance:", currentToken0Balance);
             require(currentToken0Balance >= totalAmount0ToRepay, "FlashSwap: Insufficient token0 for repayment");
             console.log("Token0 balance sufficient. Transferring token0 to pool...");
             //IERC20(token0).approve(poolAddress, totalAmount0ToRepay); // REMOVED APPROVE
             bool sent0 = IERC20(token0).transfer(poolAddress, totalAmount0ToRepay); // <<< USE TRANSFER
             require(sent0, "FlashSwap: Token0 transfer failed"); // <<< CHECK TRANSFER SUCCESS
             console.log("Token0 Transferred.");
        }

        if (totalAmount1ToRepay > 0) {
             console.log("Checking Token1 balance for transfer...");
             uint currentToken1Balance = IERC20(token1).balanceOf(address(this));
             console.log("Current Token1 Balance:", currentToken1Balance);
             require(currentToken1Balance >= totalAmount1ToRepay, "FlashSwap: Insufficient token1 for repayment");
             console.log("Token1 balance sufficient. Transferring token1 to pool...");
             //IERC20(token1).approve(poolAddress, totalAmount1ToRepay); // REMOVED APPROVE
             bool sent1 = IERC20(token1).transfer(poolAddress, totalAmount1ToRepay); // <<< USE TRANSFER
             require(sent1, "FlashSwap: Token1 transfer failed"); // <<< CHECK TRANSFER SUCCESS
             console.log("Token1 Transferred.");
        }

        console.log("--- Exiting TRANSFER TEST uniswapV3FlashCallback ---");
    }


    // --- Initiate Flash Swap ---
    // Restore correct data encoding
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
            abi.encode(callbackData) // Encode the struct correctly
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
