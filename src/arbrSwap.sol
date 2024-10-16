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
    ) external {
        if (msg.sender != master) revert ARBR_FORBIDDEN();
    }

    function swapUniswap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        address user
    ) internal {
        address[] path;
        path.push(tokenIn);
        path.push(tokenOut);

        UniswapV2Router02 router = UniswapV2Router02(routerAddr);
        router.swapExactTokensForTokens(
            amountIn,
            0,
            path,
            user,
            block.timestamp + 30 seconds
        );
    }

    function swapBalancer(
        address tokenIn,
        address tokenOut,
        uint256 poolId,
        uint256 amountIn,
        address user
    ) internal {
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

        vault.swap(swapInstance, funds, 0, block.timestamp + 30 seconds);
    }

    function swapSushiswap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) internal {}
}
