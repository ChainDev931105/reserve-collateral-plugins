// SPDX-License-Identifier: BlueOak-1.0.0
pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "contracts/interfaces/IBroker.sol";
import "contracts/interfaces/IMain.sol";
import "contracts/interfaces/ITrade.sol";
import "contracts/libraries/Fixed.sol";
import "contracts/p0/mixins/Rewardable.sol";

/// Abstract trading mixin for all Traders, to be paired with TradingLib
abstract contract TradingP0 is RewardableP0, ITrading {
    using FixLib for int192;

    // All trades
    ITrade[] public trades;

    // First trade that is still open (or trades.length if all trades are settled)
    uint256 internal tradesStart;

    // The latest end time for any trade in `trades`.
    uint256 private latestEndtime;

    // === Governance params ===
    int192 public maxTradeSlippage; // {%}
    int192 public dustAmount; // {UoA}

    function init(ConstructorArgs calldata args) internal virtual override {
        maxTradeSlippage = args.params.maxTradeSlippage;
        dustAmount = args.params.dustAmount;
    }

    /// @return true iff this trader now has open trades.
    function hasOpenTrades() public view returns (bool) {
        return trades.length > tradesStart;
    }

    /// Settle any trades that can be settled
    /// @custom:refresher
    function settleTrades() public {
        uint256 i = tradesStart;
        for (; i < trades.length && trades[i].canSettle(); i++) {
            ITrade trade = trades[i];
            try trade.settle() returns (uint256 soldAmt, uint256 boughtAmt) {
                emit TradeSettled(i, trade.sell(), trade.buy(), soldAmt, boughtAmt);
            } catch {
                // Pass over the Trade so it does not block future trading
                emit TradeSettlementBlocked(i);
            }
        }
        tradesStart = i;
    }

    /// Try to initiate a trade with a trading partner provided by the broker
    /// @dev Can fail silently if broker is disable or reverting
    function tryOpenTrade(TradeRequest memory req) internal {
        IBroker broker = main.broker();
        if (broker.disabled()) return; // correct interaction with BackingManager/RevenueTrader

        req.sell.erc20().approve(address(broker), req.sellAmount);
        try broker.openTrade(req) returns (ITrade trade) {
            if (trade.endTime() > latestEndtime) latestEndtime = trade.endTime();

            trades.push(trade);
            uint256 i = trades.length - 1;
            emit TradeStarted(
                i,
                req.sell.erc20(),
                req.buy.erc20(),
                req.sellAmount,
                req.minBuyAmount
            );
        } catch {
            req.sell.erc20().approve(address(broker), 0);
            emit TradeBlocked(req.sell.erc20(), req.buy.erc20(), req.sellAmount, req.minBuyAmount);
        }
    }

    // === Setters ===

    function setMaxTradeSlippage(int192 val) external onlyOwner {
        emit MaxTradeSlippageSet(maxTradeSlippage, val);
        maxTradeSlippage = val;
    }

    function setDustAmount(int192 val) external onlyOwner {
        emit DustAmountSet(dustAmount, val);
        dustAmount = val;
    }
}