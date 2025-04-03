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

<<<<<<< HEAD
        ISwapRouter public immutable swapRouter;
            // IQuoter public immutable quoter; // Removed
                address public owner;

                    // Restore struct definition
                        struct FlashCallbackData {
                                    uint amount0Borrowed;
                                            uint amount1Borrowed;
                                                    address caller;
                                                            address poolAddress;
                                                                    bytes params;
                        }
=======
    ISwapRouter public immutable swapRouter;
    // IQuoter public immutable quoter; // Removed
    address public owner;

    // Restore struct definition
    struct FlashCallbackData {
        uint amount0Borrowed;
        uint amount1Borrowed;
        address caller;
        address poolAddress;
        bytes params;
    }
>>>>>>> 44e8010a6f71e870dab33d9ddd512e1fa67165bd

                            modifier onlyOwner() {
                                        require(msg.sender == owner, "FlashSwap: Not owner");
                                                _;
                            }

<<<<<<< HEAD
                                // --- Constructor --- CORRECTED TO SINGLE ARGUMENT ---
                                    constructor(address _swapRouter) { // <<< ONLY _swapRouter HERE
                                            swapRouter = ISwapRouter(_swapRouter);
                                                    // quoter = IQuoter(_quoter); // Removed
                                                            owner = msg.sender;
                                                                }

                                                                    // --- Uniswap V3 Flash Callback ---
                                                                        // Uses EXPLICIT TRANSFER
                                                                            function uniswapV3FlashCallback(
                                                                                        uint256 fee0,
                                                                                                uint256 fee1,
                                                                                                        bytes calldata data // Expecting encoded FlashCallbackData
                                                                            ) external override {
                                                                                        console.log("!!! TRANSFER TEST Callback Entered !!! Fee0:", fee0, "Fee1:", fee1);
=======
    // --- Constructor --- CORRECTED TO SINGLE ARGUMENT ---
    constructor(address _swapRouter) { // <<< ONLY _swapRouter HERE
        swapRouter = ISwapRouter(_swapRouter);
        // quoter = IQuoter(_quoter); // Removed
        owner = msg.sender;
    }

    // --- Uniswap V3 Flash Callback ---
    // Uses EXPLICIT TRANSFER
    function uniswapV3FlashCallback(
        uint256 fee0,
        uint256 fee1,
        bytes calldata data // Expecting encoded FlashCallbackData
    ) external override {
        console.log("!!! TRANSFER TEST Callback Entered !!! Fee0:", fee0, "Fee1:", fee1);
>>>>>>> 44e8010a6f71e870dab33d9ddd512e1fa67165bd

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

<<<<<<< HEAD
                                                                                                                                                                                                                                                // --- ARBITRAGE LOGIC (Placeholder: Swap WETH -> USDC) ---
                                                                                                                                                                                                                                                        if (decodedData.amount1Borrowed > 0) {
                                                                                                                                                                                                                                                                        console.log("Starting placeholder arbitrage: Swap WETH for USDC...");
                                                                                                                                                                                                                                                                                    uint amountIn = decodedData.amount1Borrowed;
                                                                                                                                                                                                                                                                                                uint24 poolFee = pool.fee(); // Get pool fee

                                                                                                                                                                                                                                                                                                            IERC20(token1).approve(address(swapRouter), amountIn);
                                                                                                                                                                                                                                                                                                                        console.log("Approved SwapRouter", address(swapRouter), "to spend", amountIn, "WETH");

                                                                                                                                                                                                                                                                                                                                    ISwapRouter.ExactInputSingleParams memory params =
                                                                                                                                                                                                                                                                                                                                                    ISwapRouter.ExactInputSingleParams({
                                                                                                                                                                                                                                                                                                                                                                            tokenIn: token1, tokenOut: token0, fee: poolFee,
                                                                                                                                                                                                                                                                                                                                                                                                recipient: address(this), deadline: block.timestamp,
                                                                                                                                                                                                                                                                                                                                                                                                                    amountIn: amountIn, amountOutMinimum: 0, sqrtPriceLimitX96: 0
                                                                                                                                                                                                                                                                                                                                                    });
=======
        // --- ARBITRAGE LOGIC (Placeholder: Swap WETH -> USDC) ---
        if (decodedData.amount1Borrowed > 0) {
            console.log("Starting placeholder arbitrage: Swap WETH for USDC...");
            uint amountIn = decodedData.amount1Borrowed;
            uint24 poolFee = pool.fee(); // Get pool fee

            IERC20(token1).approve(address(swapRouter), amountIn);
            console.log("Approved SwapRouter", address(swapRouter), "to spend", amountIn, "WETH");

            ISwapRouter.ExactInputSingleParams memory params =
                ISwapRouter.ExactInputSingleParams({
                    tokenIn: token1, tokenOut: token0, fee: poolFee,
                    recipient: address(this), deadline: block.timestamp,
                    amountIn: amountIn, amountOutMinimum: 0, sqrtPriceLimitX96: 0
                });

            console.log("Executing swap using exactInputSingle...");
            uint amountOut = swapRouter.exactInputSingle(params);
            console.log("Swap executed. Received USDC (Token0) amount:", amountOut);
        }

        // --- Repayment via Explicit Transfer ---
        if (totalAmount0ToRepay > 0) {
             console.log("Checking Token0 balance for transfer...");
             uint currentToken0Balance = IERC20(token0).balanceOf(address(this));
             console.log("Current Token0 Balance:", currentToken0Balance);
             require(currentToken0Balance >= totalAmount0ToRepay, "FlashSwap: Insufficient token0 for repayment");
             console.log("Token0 balance sufficient. Transferring token0 to pool...");
             bool sent0 = IERC20(token0).transfer(poolAddress, totalAmount0ToRepay);
             require(sent0, "FlashSwap: Token0 transfer failed");
             console.log("Token0 Transferred.");
        }

        if (totalAmount1ToRepay > 0) {
             console.log("Checking Token1 balance for transfer...");
             uint currentToken1Balance = IERC20(token1).balanceOf(address(this));
             console.log("Current Token1 Balance:", currentToken1Balance);
             // >>> NOTE: Balance check was TEMPORARILY disabled before <<<
             // >>> Let's keep it disabled just to ensure the constructor is the ONLY problem first <<<
             // require(currentToken1Balance >= totalAmount1ToRepay, "FlashSwap: Insufficient token1 for repayment");
             console.log("WARN: Skipping Token1 balance check for test."); // Keep warning

             console.log("Attempting to transfer token1 to pool...");
             bool sent1 = IERC20(token1).transfer(poolAddress, totalAmount1ToRepay);
             require(sent1, "FlashSwap: Token1 transfer failed (EXPECTED without pre-funding)");
             console.log("Token1 Transferred.");
        }
>>>>>>> 44e8010a6f71e870dab33d9ddd512e1fa67165bd

                                                                                                                                                                                                                                                                                                                                                                console.log("Executing swap using exactInputSingle...");
                                                                                                                                                                                                                                                                                                                                                                            uint amountOut = swapRouter.exactInputSingle(params);
                                                                                                                                                                                                                                                                                                                                                                                        console.log("Swap executed. Received USDC (Token0) amount:", amountOut);
                                                                                                                                                                                                                                                        }

                                                                                                                                                                                                                                                                // --- Repayment via Explicit Transfer ---
                                                                                                                                                                                                                                                                        if (totalAmount0ToRepay > 0) {
                                                                                                                                                                                                                                                                                         console.log("Checking Token0 balance for transfer...");
                                                                                                                                                                                                                                                                                                      uint currentToken0Balance = IERC20(token0).balanceOf(address(this));
                                                                                                                                                                                                                                                                                                                   console.log("Current Token0 Balance:", currentToken0Balance);
                                                                                                                                                                                                                                                                                                                                require(currentToken0Balance >= totalAmount0ToRepay, "FlashSwap: Insufficient token0 for repayment");
                                                                                                                                                                                                                                                                                                                                             console.log("Token0 balance sufficient. Transferring token0 to pool...");
                                                                                                                                                                                                                                                                                                                                                          bool sent0 = IERC20(token0).transfer(poolAddress, totalAmount0ToRepay);
                                                                                                                                                                                                                                                                                                                                                                       require(sent0, "FlashSwap: Token0 transfer failed");
                                                                                                                                                                                                                                                                                                                                                                                    console.log("Token0 Transferred.");
                                                                                                                                                                                                                                                                        }

                                                                                                                                                                                                                                                                                if (totalAmount1ToRepay > 0) {
                                                                                                                                                                                                                                                                                                 console.log("Checking Token1 balance for transfer...");
                                                                                                                                                                                                                                                                                                              uint currentToken1Balance = IERC20(token1).balanceOf(address(this));
                                                                                                                                                                                                                                                                                                                           console.log("Current Token1 Balance:", currentToken1Balance);
                                                                                                                                                                                                                                                                                                                                        // >>> NOTE: Balance check was TEMPORARILY disabled before <<<
                                                                                                                                                                                                                                                                                                                                                     // >>> Let's keep it disabled just to ensure the constructor is the ONLY problem first <<<
                                                                                                                                                                                                                                                                                                                                                                  // require(currentToken1Balance >= totalAmount1ToRepay, "FlashSwap: Insufficient token1 for repayment");
                                                                                                                                                                                                                                                                                                                                                                               console.log("WARN: Skipping Token1 balance check for test."); // Keep warning

                                                                                                                                                                                                                                                                                                                                                                                            console.log("Attempting to transfer token1 to pool...");
                                                                                                                                                                                                                                                                                                                                                                                                         bool sent1 = IERC20(token1).transfer(poolAddress, totalAmount1ToRepay);
                                                                                                                                                                                                                                                                                                                                                                                                                      require(sent1, "FlashSwap: Token1 transfer failed (EXPECTED without pre-funding)");
                                                                                                                                                                                                                                                                                                                                                                                                                                   console.log("Token1 Transferred.");
                                                                                                                                                                                                                                                                                }

                                                                                                                                                                                                                                                                                        console.log("--- Exiting TRANSFER TEST uniswapV3FlashCallback ---");
                                                                            }


<<<<<<< HEAD
                                                                                // --- Initiate Flash Swap ---
                                                                                    function initiateFlashSwap(address _poolAddress, uint _amount0, uint _amount1, bytes memory _params) external {
                                                                                                require((_amount0 > 0 && _amount1 == 0) || (_amount1 > 0 && _amount0 == 0), "FlashSwap: Borrow only one token");
=======
    // --- Initiate Flash Swap ---
    function initiateFlashSwap(address _poolAddress, uint _amount0, uint _amount1, bytes memory _params) external {
        require((_amount0 > 0 && _amount1 == 0) || (_amount1 > 0 && _amount0 == 0), "FlashSwap: Borrow only one token");
>>>>>>> 44e8010a6f71e870dab33d9ddd512e1fa67165bd

                                                                                                        FlashCallbackData memory callbackData = FlashCallbackData({
                                                                                                                        amount0Borrowed: _amount0,
                                                                                                                                    amount1Borrowed: _amount1,
                                                                                                                                                caller: msg.sender,
                                                                                                                                                            poolAddress: _poolAddress,
                                                                                                                                                                        params: _params
                                                                                                        });

<<<<<<< HEAD
                                                                                                                IUniswapV3Pool(_poolAddress).flash(
                                                                                                                                address(this),
                                                                                                                                            _amount0,
                                                                                                                                                        _amount1,
                                                                                                                                                                    abi.encode(callbackData)
                                                                                                                );
                                                                                                                        // console.log("Initiated flash with encoded struct data."); // Optional log
                                                                                    }
=======
        IUniswapV3Pool(_poolAddress).flash(
            address(this),
            _amount0,
            _amount1,
            abi.encode(callbackData)
        );
        // console.log("Initiated flash with encoded struct data."); // Optional log
    }
>>>>>>> 44e8010a6f71e870dab33d9ddd512e1fa67165bd

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
                                                                                                }
                                                                                            }
                                                                                                                )
                                                                                                        })
                                                                                    }
                                                                                                                                                                                                                                                                                }
                                                                                                                                                                                                                                                                        }
                                                                                                                                                                                                                                                                                                                                                    })
                                                                                                                                                                                                                                                        }
                                                                            }
                                                                            )
                            }
                        }
}