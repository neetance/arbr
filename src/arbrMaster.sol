// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Ownable} from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {PriceFetcher} from "../src/priceFetcher.sol";

enum DEX {
    UNISWAP,
    BALANCER,
    SUSHISWAP
}

contract ArbrMaster is Ownable {
    error Not_Allowed_To_Call_Given_Method();

    address private immutable proxy;
    PriceFetcher priceFetcher;

    constructor(
        address proxyAddr,
        address priceFetcherAddr,
        address admin
    ) Ownable(admin) {
        proxy = proxyAddr;
        priceFetcher = PriceFetcher(priceFetcherAddr);
    }

    function execute(
        address tokenA,
        address tokenB,
        uint256 amountIn,
        uint256 dex1,
        uint256 dex2,
        address user,
        uint256 poolId
    ) external onlyOwner {
        if (msg.sender != proxy) revert Not_Allowed_To_Call_Given_Method();
        DEX dex;

        if (dex1 == 1) dex = DEX.UNISWAP;
        else if (dex1 == 2) dex = DEX.SUSHISWAP;
        else dex = DEX.BALANCER;

        uint256 priceAwrtB1 = priceFetcher.getPrice(
            tokenA,
            tokenB,
            dex,
            poolId
        );

        if (dex2 == 1) dex = DEX.UNISWAP;
        else if (dex2 == 2) dex = DEX.SUSHISWAP;
        else dex = DEX.BALANCER;

        uint256 priceAwrtB2 = priceFetcher.getPrice(
            tokenA,
            tokenB,
            dex,
            poolId
        );
    }
}
