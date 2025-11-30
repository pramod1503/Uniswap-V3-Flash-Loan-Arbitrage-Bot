// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./interfaces/IUniswapV3Pool.sol";
import "./interfaces/IUniswapV3FlashCallback.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IUniswapV2Router02 {
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
}

contract FlashloanArb is IUniswapV3FlashCallback, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    error InvalidFlashLoan();
    error UnauthorizedCallback();
    error InsufficientOutputAmount();

    address public immutable factoryV3;
    address public immutable routerTarget;

    struct FlashCallData {
        uint256 amount0;
        uint256 amount1;
        address player;
        address[] tradePath;
    }

    constructor(address _factoryV3, address _routerTarget) Ownable(msg.sender) {
        require(_factoryV3 != address(0) && _routerTarget != address(0), "zero addr");
        factoryV3 = _factoryV3;
        routerTarget = _routerTarget;
    }

    function requestFlashLoan(address pool, uint256 amount0, uint256 amount1, address[] calldata tradePath)
        external
        onlyOwner
        nonReentrant
    {
        if (amount0 == 0 && amount1 == 0) revert InvalidFlashLoan();
        if (pool == address(0)) revert InvalidFlashLoan();

        bytes memory data =
            abi.encode(FlashCallData({amount0: amount0, amount1: amount1, player: msg.sender, tradePath: tradePath}));

        IUniswapV3Pool(pool).flash(address(this), amount0, amount1, data);
    }

    function uniswapV3FlashCallback(uint256 fee0, uint256 fee1, bytes calldata data) external override {
        FlashCallData memory decoded = abi.decode(data, (FlashCallData));

        _verifyCallback(msg.sender);

        address borrowedToken =
            decoded.amount0 > 0 ? IUniswapV3Pool(msg.sender).token0() : IUniswapV3Pool(msg.sender).token1();

        uint256 borrowedAmount = decoded.amount0 > 0 ? decoded.amount0 : decoded.amount1;
        uint256 feeAmount = decoded.amount0 > 0 ? fee0 : fee1;

        _executeTrade(borrowedToken, borrowedAmount, decoded.tradePath);

        uint256 amountOwed = borrowedAmount + feeAmount;

        uint256 balance = IERC20(borrowedToken).balanceOf(address(this));

        if (balance < amountOwed) {
            revert InsufficientOutputAmount();
        }

        IERC20(borrowedToken).safeTransfer(msg.sender, amountOwed);
    }

    function _executeTrade(address tokenIn, uint256 amountIn, address[] memory path) internal {
        _ensureApprove(IERC20(tokenIn), routerTarget, amountIn);

        IUniswapV2Router02(routerTarget)
            .swapExactTokensForTokens(amountIn, 0, path, address(this), block.timestamp + 300);
    }

    function _ensureApprove(IERC20 token, address spender, uint256 amount) internal {
        uint256 current = token.allowance(address(this), spender);
        if (current < amount) {
            uint256 diff = amount - current;
            token.safeIncreaseAllowance(spender, diff);
        }
    }

    function _verifyCallback(address pool) internal view {
        address token0 = IUniswapV3Pool(pool).token0();
        address token1 = IUniswapV3Pool(pool).token1();
        uint24 fee = IUniswapV3Pool(pool).fee();

        (address tokenA, address tokenB) = token0 < token1 ? (token0, token1) : (token1, token0);

        address computedAddress = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            hex"ff",
                            factoryV3,
                            keccak256(abi.encode(tokenA, tokenB, fee)),
                            bytes32(0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54)
                        )
                    )
                )
            )
        );

        if (pool != computedAddress) revert UnauthorizedCallback();
    }

    function withdrawToken(address token) external onlyOwner {
        uint256 balance = IERC20(token).balanceOf(address(this));
        IERC20(token).safeTransfer(msg.sender, balance);
    }
}
