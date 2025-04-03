// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v3-periphery/contracts/interfaces/IQuoter.sol";

import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-core/contracts/interfaces/callback/IUniswapV3FlashCallback.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import "hardhat/console.sol"; // Uncomment for debugging if needed

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
        // Decode the data we passed from initiateFlashSwap
        FlashCallbackData memory decodedData = abi.decode(data, (FlashCallbackData));

        // --- Security Check ---
        // Ensure the callback is coming ONLY from the pool we initiated the flash loan with.
        require(msg.sender == decodedData.poolAddress, "FlashSwap: Callback from unexpected pool");
        // Note: Inside the callback, `msg.sender` IS the address of the Uniswap V3 Pool contract.

        // Get token addresses directly from the pool contract for reliability
        IUniswapV3Pool pool = IUniswapV3Pool(decodedData.poolAddress);
        address token0 = pool.token0();
        address token1 = pool.token1();

        // Calculate the total amounts required for repayment (amount borrowed + fee)
        uint totalAmount0ToRepay = decodedData.amount0Borrowed + fee0;
        uint totalAmount1ToRepay = decodedData.amount1Borrowed + fee1;

        // --- ARBITRAGE LOGIC GOES HERE ---
        // 1. Identify which token(s) were borrowed (amount > 0).
        // 2. Approve the `swapRouter` to spend the borrowed token(s) from this contract:
        //    `IERC20(borrowedToken).approve(address(swapRouter), amountBorrowed);`
        // 3. Perform swap(s) using `swapRouter` to generate profit (e.g., swap borrowed WETH for USDC on Pool A, then swap USDC back to WETH on Pool B).
        // 4. Use `decodedData.params` if you passed extra instructions for the arbitrage.
        // 5. The key goal: Ensure this contract's balance of the borrowed token(s) is >= the `totalAmountXToRepay` AFTER the swaps.
        //    `require(IERC20(tokenX).balanceOf(address(this)) >= totalAmountXToRepay, "Insufficient funds after arbitrage");`

        // --- Repayment Approval ---
        // After successful arbitrage, approve the pool contract (`msg.sender`) to pull the repayment amount + fee.
        // The pool contract will call `transferFrom` on the token contract to take the funds from this contract.

        if (totalAmount0ToRepay > 0) {
            // Ensure sufficient balance exists (crucial check after arbitrage)
            require(IERC20(token0).balanceOf(address(this)) >= totalAmount0ToRepay, "FlashSwap: Insufficient token0 for repayment");
            // Approve the pool (msg.sender) to withdraw the repayment amount
            IERC20(token0).approve(msg.sender, totalAmount0ToRepay);
            // console.log("Approved pool", msg.sender, "to take", totalAmount0ToRepay, "of token0", token0);
        }

        if (totalAmount1ToRepay > 0) {
            require(IERC20(token1).balanceOf(address(this)) >= totalAmount1ToRepay, "FlashSwap: Insufficient token1 for repayment");
            IERC20(token1).approve(msg.sender, totalAmount1ToRepay);
            // console.log("Approved pool", msg.sender, "to take", totalAmount1ToRepay, "of token1", token1);
        }

        // If the require checks pass and approvals are done, the pool's subsequent `transferFrom` call will succeed.
        // If any require fails, the entire transaction initiated by `initiateFlashSwap` reverts.
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
        // Ensure only one token amount is non-zero (standard flash swap practice)
        require((_amount0 > 0 && _amount1 == 0) || (_amount1 > 0 && _amount0 == 0), "FlashSwap: Borrow only one token");

        // Prepare the data struct to be passed to the callback
        FlashCallbackData memory callbackData = FlashCallbackData({
            amount0Borrowed: _amount0,
            amount1Borrowed: _amount1,
            caller: msg.sender,          // Store the original caller's address
            poolAddress: _poolAddress,   // Store pool address for verification
            params: _params              // Pass through any extra data
        });

        // Trigger the flash loan on the specified pool
        IUniswapV3Pool(_poolAddress).flash(
            address(this),              // The recipient of the loan and caller of the callback is this contract
            _amount0,                   // Amount of token0 to borrow
            _amount1,                   // Amount of token1 to borrow
            abi.encode(callbackData)    // Encode the struct to pass as bytes data
        );
    }

    // --- Utility Functions ---

    // Withdraw ETH sent to the contract (only owner)
    function withdrawEther() external onlyOwner {
        payable(owner).transfer(address(this).balance);
    }

    // Withdraw specific ERC20 tokens sent to the contract (only owner)
    function withdrawToken(address tokenAddress) external onlyOwner {
        IERC20 token = IERC20(tokenAddress);
        uint balance = token.balanceOf(address(this));
        require(balance > 0, "FlashSwap: No tokens to withdraw");
        token.transfer(owner, balance);
    }

    // Allow the contract to receive ETH directly
    receive() external payable {}
    // fallback() external payable {} // Optional fallback if needed
}
