// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {DEX} from "./arbrMaster.sol";
import {UniswapV2Router02} from "../lib/v2-periphery/contracts/UniswapV2Router02.sol";
import {IVault} from "../node_modules/@balancer-labs/v2-interfaces/contracts/vault/IVault.sol";

contract ArbrSwap {
    error ARBR_FORBIDDEN();

    address master;
    address routerAddr;
    address vaultAddr;

    constructor(address masterAddr) {
        master = masterAddr;
    }

    function swap(
        DEX dex,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 poolId,
        address user
    ) external returns (uint256 amountOut) {
        if (msg.sender != master) revert ARBR_FORBIDDEN();

        if (dex == DEX.UNISWAP) amountOut = swapUniswap(tokenIn, tokenOut, amountIn, user);
        else if (dex == DEX.SUSHISWAP) amountOut = swapSushiswap(tokenIn, tokenOut, user);
        else amountOut swapBalancer(tokenIn, tokenOut, poolId, amountIn, user);
    }

    function swapUniswap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        address user
    ) internal returns (uint256) {
        address[] path;
        path.push(tokenIn);
        path.push(tokenOut);

        UniswapV2Router02 router = UniswapV2Router02(routerAddr);
        uint256 memory amounts[] = router.swapExactTokensForTokens(
            amountIn,
            0,
            path,
            user,
            block.timestamp + 30 seconds
        );

        return amounts[1];
    }

    function swapBalancer(
        address tokenIn,
        address tokenOut,
        uint256 poolId,
        uint256 amountIn,
        address user
    ) internal returns (uint256) {
        IVault vault = IVault(vaultAddr);
        vault.SingleSwap memory swapInstance = vault.SingleSwap({
            poolId: poolId,
            kind: vault.SwapKind.GIVEN_IN,
            assetIn: tokenIn,
            assetOut: tokenOut,
            amount: amountIn,
            userData: ""
        });

        vault.FundManagement memory funds = vault.FundManagement({
            sender: user,
            recipient: user,
            fromInternalBalance: false,
            toInternalBalance: false
        });

        uint256 amountOut = vault.swap(swapInstance, funds, 0, block.timestamp + 30 seconds);
        return amountOut;
    }

    function swapSushiswap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) internal {}
}
