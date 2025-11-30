// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interfaces/IUniswapV3FlashCallback.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./MockToken.sol";

contract MockPool {
    address public token0;
    address public token1;
    uint24 public constant fee = 3000; 

    constructor(address _token0, address _token1) {
        token0 = _token0;
        token1 = _token1;
    }

    function flash(
        address recipient,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external {
        uint256 balance0Before = IERC20(token0).balanceOf(address(this));
        uint256 balance1Before = IERC20(token1).balanceOf(address(this));

        if (amount0 > 0) {
            bool success = IERC20(token0).transfer(recipient, amount0);
            require(success, "FlashLoan: Transfer token0 failed");
        }
        if (amount1 > 0) {
            bool success = IERC20(token1).transfer(recipient, amount1);
            require(success, "FlashLoan: Transfer token1 failed");
        }

        uint256 fee0 = (amount0 * 3) / 997 + 1;
        uint256 fee1 = (amount1 * 3) / 997 + 1;

        IUniswapV3FlashCallback(recipient).uniswapV3FlashCallback(fee0, fee1, data);

        if (amount0 > 0) {
            uint256 balance0After = IERC20(token0).balanceOf(address(this));
            require(balance0After >= balance0Before + fee0, "FlashLoan: Repayment failed");
        }
        if (amount1 > 0) {
            uint256 balance1After = IERC20(token1).balanceOf(address(this));
            require(balance1After >= balance1Before + fee1, "FlashLoan: Repayment failed");
        }
    }

    function swapExactTokensForTokens(
        uint amountIn,
        uint /*amountOutMin */,
        address[] calldata path,
        address to,
        uint /*deadline*/
    ) external returns (uint[] memory amounts) {
        
        address tokenIn = path[0];
        address tokenOut = path[path.length - 1];

        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);

        uint256 amountOut = (amountIn * 1020) / 1000; 

        MockToken(tokenOut).mint(to, amountOut);

        amounts = new uint[](2);
        amounts[0] = amountIn;
        amounts[1] = amountOut;
        return amounts;
    }
}