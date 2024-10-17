// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Ownable} from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {PriceFetcher} from "./priceFetcher.sol";
import "../lib/aave-v3-core/contracts/flashloan/base/FlashLoanSimpleReceiverBase.sol";
import "../lib/aave-v3-core/contracts/interfaces/IPoolAddressesProvider.sol";
import {ArbrSwap} from "./arbrSwap.sol";
import {IERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

enum DEX {
    UNISWAP,
    BALANCER,
    SUSHISWAP
}

contract ArbrMaster is Ownable, FlashLoanSimpleReceiverBase {
    error Not_Allowed_To_Call_Given_Method();

    address private immutable proxy;
    address poolAddr;
    PriceFetcher priceFetcher;
    ArbrSwap arbrSwap;

    constructor(
        address proxyAddr,
        address arbrSwapAddr,
        address priceFetcherAddr,
        address admin,
        IPoolAddressesProvider provider
    ) Ownable(admin) FlashLoanSimpleReceiverBase(provider) {
        proxy = proxyAddr;
        priceFetcher = PriceFetcher(priceFetcherAddr);
        arbrSwap = ArbrSwap(arbrSwapAddr);
    }

    function execute(
        address tokenA,
        address tokenB,
        uint256 minProfit,
        uint256 dex1,
        uint256 dex2,
        address user,
        uint256 poolId
    ) external {
        if (msg.sender != proxy) revert Not_Allowed_To_Call_Given_Method();
        DEX Dex1;
        DEX Dex2;

        if (dex1 == 1) Dex1 = DEX.UNISWAP;
        else if (dex1 == 2) Dex1 = DEX.SUSHISWAP;
        else Dex1 = DEX.BALANCER;

        uint256 priceAwrtB1 = priceFetcher.getPrice(
            tokenA,
            tokenB,
            Dex1,
            poolId
        );

        if (dex2 == 1) Dex2 = DEX.UNISWAP;
        else if (dex2 == 2) Dex2 = DEX.SUSHISWAP;
        else Dex2 = DEX.BALANCER;

        uint256 priceAwrtB2 = priceFetcher.getPrice(
            tokenA,
            tokenB,
            Dex2,
            poolId
        );
        IPool pool = IPool(poolAddr);
        bool price1GreaterThan2 = priceAwrtB1 > priceAwrtB2;

        if (price1GreaterThan2) {
            uint256 amountIn = (minProfit * priceAwrtB2 * 2) /
                (priceAwrtB1 - priceAwrtB2);
            bytes memory params = abi.encode(
                tokenA,
                tokenB,
                dex1,
                dex2,
                poolId,
                minProfit,
                user,
                price1GreaterThan2
            );

            POOL.flashLoanSimple(address(this), tokenB, amountIn, params, 0);
        } else {
            uint256 amountIn = (minProfit * priceAwrtB1 * 2) /
                (priceAwrtB2 - priceAwrtB1);
            bytes memory params = abi.encode(
                tokenA,
                tokenB,
                dex1,
                dex2,
                poolId,
                minProfit,
                user,
                price1GreaterThan2
            );

            POOL.flashLoanSimple(address(this), tokenB, amountIn, params, 0);
        }
    }

    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address initiator,
        bytes calldata params
    ) external returns (bool) {
        (
            address tokenA,
            address tokenB,
            uint256 dex1,
            uint256 dex2,
            uint256 poolId,
            uint256 minProfit,
            address user,
            bool price1GreaterThan2
        ) = abi.decode(
                params,
                (
                    address,
                    address,
                    uint256,
                    uint256,
                    uint256,
                    uint256,
                    address,
                    bool
                )
            );

        if (dex1 == 1) Dex1 = DEX.UNISWAP;
        else if (dex1 == 2) Dex1 = DEX.SUSHISWAP;
        else Dex1 = DEX.BALANCER;

        if (dex2 == 1) Dex2 = DEX.UNISWAP;
        else if (dex2 == 2) Dex2 = DEX.SUSHISWAP;
        else Dex2 = DEX.BALANCER;

        if (price1GreaterThan2) {
            uint256 amountAOut = arbrSwap.swap(
                Dex2,
                tokenB,
                tokenA,
                amount,
                poolId,
                address(this)
            );
            uint256 amountBOut = arbrSwap.swap(
                Dex1,
                tokenA,
                tokenB,
                amountAOut,
                poolId,
                address(this)
            );

            uint256 amountOwing = amount + premium;
            IERC20(asset).approve(address(POOL), amountOwing);

            if (amountBOut - amountOwing < minProfit) revert();

            IERC20(asset).transfer(user, amountBOut - amountOwing);
        } else {
            uint256 amountAOut = arbrSwap.swap(
                Dex1,
                tokenB,
                tokenA,
                amount,
                poolId,
                address(this)
            );
            uint256 amountBOut = arbrSwap.swap(
                Dex2,
                tokenA,
                tokenB,
                amountAOut,
                poolId,
                address(this)
            );

            uint256 amountOwing = amount + premium;
            IERC20(asset).approve(address(POOL), amountOwing);

            if (amountBOut - amountOwing < minProfit) revert();

            IERC20(asset).transfer(user, amountBOut - amountOwing);
        }
    }
}
