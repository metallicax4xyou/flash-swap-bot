// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
// Quoter not needed for this version
// import "@uniswap/v3-periphery/contracts/interfaces/IQuoter.sol";

import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-core/contracts/interfaces/callback/IUniswapV3FlashCallback.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "hardhat/console.sol";

contract FlashSwap is IUniswapV3FlashCallback {

    ISwapRouter public immutable swapRouter;
    address public owner;

    struct FlashCallbackData {
        uint amount0Borrowed;
        uint amount1Borrowed;
        address caller;
        address poolAddress; // Pool where flash loan originated
        bytes params;        // For future use (passing target pool addresses etc.)
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "FlashSwap: Not owner");
        _;
    }

    // --- Constructor ---
    constructor(address _swapRouter) {
        swapRouter = ISwapRouter(_swapRouter);
        owner = msg.sender;
    }

    // --- Uniswap V3 Flash Callback ---
    // ADDED TWO-POOL SWAP LOGIC
    function uniswapV3FlashCallback(
        uint256 fee0,
        uint256 fee1,
        bytes calldata data // Expecting encoded FlashCallbackData
    ) external override {
        console.log("!!! TWO-SWAP TEST Callback Entered !!! Fee0:", fee0, "Fee1:", fee1);

        FlashCallbackData memory decodedData = abi.decode(data, (FlashCallbackData));
        require(msg.sender == decodedData.poolAddress, "FlashSwap: Callback from unexpected pool"); // Ensure callback is from the loan pool

        address loanPoolAddress = msg.sender; // Pool that initiated the flash loan (Pool A in our test case)
        IUniswapV3Pool loanPool = IUniswapV3Pool(loanPoolAddress);
        address token0 = loanPool.token0(); // USDC for pool 0x88e6...
        address token1 = loanPool.token1(); // WETH for pool 0x88e6...

        uint totalAmount0ToRepay = decodedData.amount0Borrowed + fee0;
        uint totalAmount1ToRepay = decodedData.amount1Borrowed + fee1; // Need to repay borrowed WETH + fee1

        console.log("Loan Pool:", loanPoolAddress);
        console.log("Token0 (USDC):", token0);
        console.log("Token1 (WETH):", token1);
        console.log("Total Token1 to Repay:", totalAmount1ToRepay);

        // --- ARBITRAGE LOGIC (WETH -> USDC on Pool A, then USDC -> WETH on Pool B) ---
        if (decodedData.amount1Borrowed > 0) { // If we borrowed WETH (Token1)
            console.log("Starting two-pool arbitrage simulation...");
            uint amountInWETH = decodedData.amount1Borrowed;

            // --- Define Pool Addresses and Fees (Hardcoded for test) ---
            address poolA_WETH_USDC = loanPoolAddress; // Use the loan pool for the first swap
            // FIX: Use correct checksum for pool address
            address poolB_USDC_WETH = 0x8AD599c3A0b1A56aAD039dDaC6837db27b2ff1Dc; // 0.3% Pool for second swap
            uint24 feeA = loanPool.fee(); // Should be 500 (0.05%)
            uint24 feeB = 3000; // Fee for 0.3% pool (must match poolB!)

            console.log("Pool A (WETH->USDC):", poolA_WETH_USDC, "Fee:", feeA);
            console.log("Pool B (USDC->WETH):", poolB_USDC_WETH, "Fee:", feeB);

            // --- Swap 1: WETH -> USDC on Pool A ---
            IERC20(token1).approve(address(swapRouter), amountInWETH);
            console.log("Approved SwapRouter for WETH amount:", amountInWETH);

            ISwapRouter.ExactInputSingleParams memory params1 =
                ISwapRouter.ExactInputSingleParams({
                    tokenIn: token1, tokenOut: token0, fee: feeA, // Pool A
                    recipient: address(this), deadline: block.timestamp,
                    amountIn: amountInWETH, amountOutMinimum: 0, sqrtPriceLimitX96: 0
                });

            console.log("Executing Swap 1 (WETH -> USDC)...");
            uint amountOutUSDC;
            try swapRouter.exactInputSingle(params1) returns (uint usdcReceived) {
                 amountOutUSDC = usdcReceived;
                 console.log("Swap 1 executed. Received USDC (Token0) amount:", amountOutUSDC);
            } catch Error(string memory reason) {
                 console.log("Swap 1 Failed! Reason:", reason); // Expect LOK if liquidity issue
                 revert("Swap 1 failed, cannot continue arbitrage"); // Revert if first swap fails
            } catch (bytes memory lowLevelData) {
                 // FIX: Remove lowLevelData from console.log arguments
                 console.log("Swap 1 Failed! Low level data");
                 revert("Swap 1 failed (low level), cannot continue arbitrage");
            }
            require(amountOutUSDC > 0, "Swap 1 returned 0 USDC"); // Sanity check


            // --- Swap 2: USDC -> WETH on Pool B ---
            IERC20(token0).approve(address(swapRouter), amountOutUSDC);
            console.log("Approved SwapRouter for USDC amount:", amountOutUSDC);

            ISwapRouter.ExactInputSingleParams memory params2 =
                ISwapRouter.ExactInputSingleParams({
                    tokenIn: token0, tokenOut: token1, fee: feeB, // Pool B
                    recipient: address(this), deadline: block.timestamp,
                    amountIn: amountOutUSDC, amountOutMinimum: 0, sqrtPriceLimitX96: 0
                });

            console.log("Executing Swap 2 (USDC -> WETH)...");
            uint finalWETHReceived;
             try swapRouter.exactInputSingle(params2) returns (uint wethReceived) {
                 finalWETHReceived = wethReceived;
                 console.log("Swap 2 executed. Final WETH Received (Token1):", finalWETHReceived);
            } catch Error(string memory reason) {
                 console.log("Swap 2 Failed! Reason:", reason);
                 revert("Swap 2 failed, cannot complete arbitrage"); // Revert if second swap fails
            } catch (bytes memory lowLevelData) {
                 // FIX: Remove lowLevelData from console.log arguments
                 console.log("Swap 2 Failed! Low level data");
                 revert("Swap 2 failed (low level), cannot complete arbitrage");
            }
        }
        // --- End Arbitrage ---


        // --- Repayment via Explicit Transfer ---
        if (totalAmount0ToRepay > 0) { // Should be 0 in this test
             // ... (Token0 repayment logic - unchanged) ...
             console.log("Checking Token0 balance for transfer...");
             uint currentToken0Balance = IERC20(token0).balanceOf(address(this));
             console.log("Current Token0 Balance:", currentToken0Balance);
             require(currentToken0Balance >= totalAmount0ToRepay, "FlashSwap: Insufficient token0 for repayment");
             console.log("Token0 balance sufficient. Transferring token0 to pool...");
             bool sent0 = IERC20(token0).transfer(loanPoolAddress, totalAmount0ToRepay);
             require(sent0, "FlashSwap: Token0 transfer failed");
             console.log("Token0 Transferred.");
        }

        if (totalAmount1ToRepay > 0) { // Should be > 0 (WETH repayment)
             console.log("Checking FINAL Token1 balance for transfer...");
             uint currentToken1Balance = IERC20(token1).balanceOf(address(this));
             console.log("Final Current Token1 Balance:", currentToken1Balance); // This will reflect amount after Swap 2

             // >>> RE-ENABLE BALANCE CHECK FOR FINAL TEST <<<
             require(currentToken1Balance >= totalAmount1ToRepay, "FlashSwap: Insufficient token1 post-arbitrage for repayment"); // <<< THIS SHOULD FAIL

             console.log("Token1 balance sufficient for repayment. Transferring token1 to pool..."); // Should not print
             bool sent1 = IERC20(token1).transfer(loanPoolAddress, totalAmount1ToRepay);
             require(sent1, "FlashSwap: Token1 transfer failed"); // Should not be reached
             console.log("Token1 Repayment Transferred."); // Should not print
        }

        console.log("--- Exiting TWO-SWAP TEST uniswapV3FlashCallback ---"); // Should not print
    }


    // --- Initiate Flash Swap ---
    function initiateFlashSwap(address _poolAddress, uint _amount0, uint _amount1, bytes memory _params) external {
        require((_amount0 > 0 && _amount1 == 0) || (_amount1 > 0 && _amount0 == 0), "FlashSwap: Borrow only one token");

        FlashCallbackData memory callbackData = FlashCallbackData({
            amount0Borrowed: _amount0,
            amount1Borrowed: _amount1,
            caller: msg.sender,
            poolAddress: _poolAddress,
            params: _params // Pass params through (though unused in this version)
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
