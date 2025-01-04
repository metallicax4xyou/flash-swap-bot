// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v3-periphery/contracts/interfaces/IQuoter.sol";
import "@uniswap/v3-periphery/contracts/interfaces/IPeripheryImmutableState.sol";

import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-core/contracts/interfaces/callback/IUniswapV3FlashCallback.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract FlashSwap is IUniswapV3FlashCallback {

        ISwapRouter public immutable swapRouter;
            IQuoter public immutable quoter;

                constructor(address _swapRouter, address _quoter) {
                            swapRouter = ISwapRouter(_swapRouter);
                                    quoter = IQuoter(_quoter);
                }

                    function uniswapV3FlashCallback(
                                uint256 fee0,
                                        uint256 fee1,
                                                bytes calldata data
                    ) external override {
                                // Your arbitrage logic will go here in the future

                                        // Now, pay back the loan (example with WETH)
                                                (address token0, address token1, uint24 poolFee, address weth, uint amount0, uint amount1) = abi.decode(data, (address, address, uint24, address, uint, uint));

                                                        // Calculate total amount to repay for token0
                                                                uint totalAmount0 = amount0 + fee0;

                                                                        // Approve the pool to take tokens for repayment
                                                                                IERC20(weth).approve(msg.sender, totalAmount0);
                    }

                        function initiateFlashSwap(address pool, address tokenBorrow, uint amount) external {
                                    // initiate flash loan logic
                                            bytes memory data = abi.encode(pool, amount);
                                                    IUniswapV3Pool(pool).flash(address(this), amount, 0, data);
                        }
}