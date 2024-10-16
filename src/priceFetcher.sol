// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {DEX} from "./arbrMaster.sol";
import {IVault} from "../node_modules/@balancer-labs/v2-interfaces/contracts/vault/IVault.sol";
import {IManagedPool} from "../node_modules/@balancer-labs/v2-interfaces/contracts/pool-utils/IManagedPool.sol";
import {IERC20} from "../node_modules/@balancer-labs/v2-interfaces/contracts/solidity-utils/openzeppelin/IERC20.sol";
import {IUniswapV2Factory} from "../lib/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Pair} from "../lib/v2-core/contracts/interfaces/IUniswapV2Pair.sol";

contract PriceFetcher {
    address balancerVault;
    address uniswapv2FactoryAddr;
    address sushiswap;

    IVault vault;
    IManagedPool poolContr;

    constructor() {
        vault = IVault(balancerVault);
    }

    function getPrice(
        address tokenA,
        address tokenB,
        DEX dex,
        uint256 poolId
    ) external returns (uint256 price) {
        if (dex == DEX.UNISWAP) price = getUniswapPrice(tokenA, tokenB);
        else if (dex == DEX.SUSHISWAP)
            price = getSushiswapPrice(tokenA, tokenB);
        else price = getBalancerPrice(tokenA, tokenB, poolId);
    }

    function getUniswapPrice(
        address tokenA,
        address tokenB
    ) internal view returns (uint256) {
        IUniswapV2Factory uniswapv2Factory = IUniswapV2Factory(
            uniswapv2FactoryAddr
        );
        address pairAddr = uniswapv2Factory.getPair(tokenA, tokenB);
        IUniswapV2Pair uniswapV2pair = IUniswapV2Pair(pairAddr);

        address token0 = uniswapV2pair.token0();
        //address token1 = uniswapV2pair.token1();

        (uint256 reserve0, uint256 reserve1, ) = uniswapV2pair.getReserves();
        uint256 balanceA;
        uint256 balanceB;

        if (tokenA == token0) {
            balanceA = reserve0;
            balanceB = reserve1;
        } else {
            balanceA = reserve1;
            balanceB = reserve0;
        }

        uint256 price = (balanceB * 1e18) / balanceA;
        return price;
    }

    function getSushiswapPrice(
        address tokenA,
        address tokenB
    ) internal returns (uint256) {}

    function getBalancerPrice(
        address tokenA,
        address tokenB,
        uint256 poolId
    ) internal returns (uint256) {
        uint256[] memory balances;
        IERC20[] memory tokens;

        (tokens, balances, ) = vault.getPoolTokens(bytes32(poolId));
        uint256 balanceA;
        uint256 balanceB;

        address pool;
        (pool, ) = vault.getPool(bytes32(poolId));

        poolContr = IManagedPool(pool);
        uint256[] memory weights;
        weights = poolContr.getNormalizedWeights();

        uint256 weightA;
        uint256 weightB;

        for (uint256 i = 0; i < tokens.length; i++) {
            if (address(tokens[i]) == tokenA) {
                balanceA = balances[i];
                weightA = weights[i];
            }

            if (address(tokens[i]) == tokenB) {
                balanceB = balances[i];
                weightB = weights[i];
            }
        }

        uint256 price = (balanceB * weightB) / (balanceA * weightA);
        return price;
    }
}
