// SPDX-License-Identifier: agpl-3.0

// done as part of a reserver-protocol hackathon
pragma solidity ^0.8.19;

import "../assets/AbstractCollateral.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";

//TODO sync in refresh in uniswapV2 and perhaps uniswapV3
//TODO Unsiwap uses 112 bits floating points math for price accumulators
abstract contract UniswapV2AbstractCollateral is Collateral {
    using OracleLib for AggregatorV3Interface;
    AggregatorV3Interface public immutable chainlinkFeedSecondAsset;

    constructor(
        uint192 fallbackPrice_,
        AggregatorV3Interface chainlinkFeed_,
        AggregatorV3Interface chainlinkFeedSecondAsset_,
        IUniswapV2Pair erc20_,
        uint192 maxTradeVolume_,
        uint48 oracleTimeout_,
        bytes32 targetName_,
        uint256 delayUntilDefault_
    )
        Collateral(
            fallbackPrice_,
            chainlinkFeed_,
            IERC20Metadata(address(erc20_)),
            maxTradeVolume_,
            oracleTimeout_,
            targetName_,
            delayUntilDefault_
        )
    {
        require(
            address(chainlinkFeedSecondAsset_) != address(0),
            "missing chainlink feed for second asset in pair"
        );
        chainlinkFeedSecondAsset = chainlinkFeedSecondAsset_;
    }

    function refPerTok() public view override returns (uint192) {
        IUniswapV2Pair pair = IUniswapV2Pair(address(erc20));
        // Seems like can be safety replaced with sellPrice(feeOn)
        (uint112 reserve0, uint112 reserve1, ) = pair.getReserves();
        uint256 rootK = Math.sqrt(reserve0 * reserve1);
        return uint192((rootK * 10 ** 18) / pair.totalSupply());
    }

    function _calculatePrice(
        address token0,
        address token1,
        uint256 amount0,
        uint256 amount1,
        uint256 liquidity
    ) internal view returns (uint192) {
        uint192 price0 = chainlinkFeed.price(oracleTimeout);
        uint192 price1 = chainlinkFeedSecondAsset.price(oracleTimeout);
        uint256 priceScaled0 = FIX_ONE * (price0 * amount0) /
            liquidity /
            10 ** IERC20Metadata(token0).decimals();
        uint256 priceScaled1 = FIX_ONE * (price1 * amount1) /
            liquidity /
            10 ** IERC20Metadata(token1).decimals();
        return uint192(priceScaled0 + priceScaled1);
    }

    // supply never zero on uniswap v2, so can revert only if feeds revert
    function strictPrice() public view override(Asset, IAsset) returns (uint192) {
        IUniswapV2Pair pair = IUniswapV2Pair(address(erc20));
        (uint112 reserve0, uint112 reserve1, ) = pair.getReserves();
        return
            _calculatePrice(
                pair.token0(),
                pair.token1(),
                reserve0,
                reserve1,
                IERC20(erc20).totalSupply()
            );
    }
}
