//+------------------------------------------------------------------+
//|                                               BollingerBands.mq5 |
//|                                  Copyright 2022, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2022, MetaQuotes Ltd."
#property link "https://www.mql5.com"
#property version "1.00"

#include <Trade\Trade.mqh>

static input long InpMagicNumber = 837462;
input double InpLotSize = 0.01;
input int InpPeroid = 21;
input double InpDeviation = 2.0;
input int InpStopLoss = 100;
input int InpTakeProfit = 200;

// Global variables
int handle;
double upperBuffer[];
double baseBuffer[];
double lowerBuffer[];
MqlTick currentTick;
CTrade trade;
datetime openTimeBuy = 0;
datetime openTimeSell = 0;

int OnInit() {
    if (InpMagicNumber <= 0) {
        Alert("Magic number negaive or zero");
        return INIT_PARAMETERS_INCORRECT;
    }

    if (InpLotSize <= 0) {
        Alert("InpLotSize negaive or zero");
        return INIT_PARAMETERS_INCORRECT;
    }

    if (InpPeroid <= 0) {
        Alert("InpPeroid negaive or zero");
        return INIT_PARAMETERS_INCORRECT;
    }

    if (InpDeviation <= 0) {
        Alert("InpDeviation negaive or zero");
        return INIT_PARAMETERS_INCORRECT;
    }

    if (InpStopLoss <= 0) {
        Alert("InpStopLoss negaive or zero");
        return INIT_PARAMETERS_INCORRECT;
    }

    if (InpTakeProfit < 0) {
        Alert("InpTakeProfit negaive");
        return INIT_PARAMETERS_INCORRECT;
    }

    trade.SetExpertMagicNumber(InpMagicNumber);

    handle = iBands(_Symbol, PERIOD_CURRENT, InpPeroid, 1, InpDeviation, PRICE_CLOSE);
    if (handle == INVALID_HANDLE) {
        Alert("Failed to creae indicator handle");
        return INIT_FAILED;
    }
    
    ArraySetAsSeries(upperBuffer,true);
    ArraySetAsSeries(baseBuffer,true);
    ArraySetAsSeries(lowerBuffer,true);

    return (INIT_SUCCEEDED);
}

void OnDeinit(const int reason) {
    if (handle != INVALID_HANDLE) {
        IndicatorRelease(handle);
    }
}

void OnTick() {
    if (!IsNewBar()) {
        return;
    }

    if (!SymbolInfoTick(_Symbol, currentTick)) {
        Print("Failed to get tick");
        return;
    }

    int values = CopyBuffer(handle, 0, 0, 1, baseBuffer) +
        CopyBuffer(handle, 1, 0, 1, upperBuffer) +
        CopyBuffer(handle, 2, 0, 1, lowerBuffer);

    if (values != 3) {
        Print("Failed to get indicator values");
        return;
    }

    Comment("up[0]:", upperBuffer[0],
        "\nbase[0]", baseBuffer[0],
        "\nlow[0]:", lowerBuffer[0]);

    int cntBuy, cntSell;

    if (!CountOpenPositions(cntBuy, cntSell)) {
        return;
    }

    if (cntBuy == 0 && currentTick.ask <= lowerBuffer[0] && openTimeBuy != iTime(_Symbol, PERIOD_CURRENT, 0)) {
        openTimeBuy = iTime(_Symbol, PERIOD_CURRENT, 0);
        double sl = currentTick.bid - InpStopLoss * _Point;
        double tp = InpTakeProfit == 0 ? 0 : currentTick.bid + InpTakeProfit * _Point;
        if (!NormalizeDouble(sl, sl)) {
            return;
        }

        if (!NormalizeDouble(tp, tp)) {
            return;
        }

        if (!trade.PositionOpen(_Symbol, ORDER_TYPE_BUY, InpLotSize, currentTick.ask, sl, tp, "Bollinger band EA")) {
            Print("Result code", (string) trade.ResultRetcode()," : ", trade.ResultRetcodeDescription());
        }
    }

    if (cntSell == 0 && currentTick.bid >= upperBuffer[0] && openTimeSell != iTime(_Symbol, PERIOD_CURRENT, 0)) {
        openTimeSell = iTime(_Symbol, PERIOD_CURRENT, 0);
        double sl = currentTick.ask + InpStopLoss * _Point;
        double tp = InpTakeProfit == 0 ? 0 : currentTick.ask - InpTakeProfit * _Point;
        if (!NormalizeDouble(sl, sl)) {
            return;
        }

        if (!NormalizeDouble(tp, tp)) {
            return;
        }

        
        if (!trade.PositionOpen(_Symbol, ORDER_TYPE_SELL, InpLotSize, currentTick.bid, sl, tp, "Bollinger band EA")) {
            Print("Result code", (string) trade.ResultRetcode()," : ", trade.ResultRetcodeDescription());
        }
    }

    if (!CountOpenPositions(cntBuy, cntSell)) {
        return;
    }

    if (cntBuy > 0 && currentTick.bid >= baseBuffer[0]) {
        ClosePositions(1);
    }

    if (cntSell > 0 && currentTick.ask <= baseBuffer[0]) {
        ClosePositions(2);
    }
}

bool IsNewBar() {
    static datetime previousTime = 0;
    datetime currentTime = iTime(_Symbol, PERIOD_CURRENT, 0);
    if (previousTime != currentTime) {
        previousTime = currentTime;
        return true;
    }
    return false;
}

bool CountOpenPositions(int &countBuy, int &countSell) {
    countBuy = 0;
    countSell = 0;
    int total = PositionsTotal();
    for (int i = total - 1; i >= 0; i--) {
        ulong positionTicket = PositionGetTicket(i);
        if (positionTicket <= 0) {
            Print("Failted to get ticket");
            return false;
        }
        if (!PositionSelectByTicket(positionTicket)) {
            Print("Failed select by ticket");
            return false;
        }
        long magic;
        if (!PositionGetInteger(POSITION_MAGIC, magic)) {
            Print("Failed to get magic");
            return false;
        }
        if (magic == InpMagicNumber) {
            long type;
            if (!PositionGetInteger(POSITION_TYPE, type)) {
                Print("Failed to get type");
                return false;
            }
            if (type == POSITION_TYPE_BUY) {
                countBuy++;
            }
            if (type == POSITION_TYPE_SELL) {
                countSell++;
            }
        }
    }
    return true;
}

bool NormalizePrice(double price, double &normalizedPrice) {
    double tickSize = 0;
    if (!SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE, tickSize)) {
        Print("Failed to get tick size");
        return false;
    }
    normalizedPrice = NormalizeDouble(MathRound(price / tickSize) * tickSize, _Digits);

    return true;
}

bool ClosePositions(int all_buy_sell) {
    int total = PositionsTotal();
    for (int i = total - 1; i >= 0; i--) {
        ulong positionTicket = PositionGetTicket(i);

        if (positionTicket <= 0) {
            Print("Failed to get ticket");
            return false;
        }

        if (!PositionSelectByTicket(positionTicket)) {
            Print("Failed to PositionSelectByTicket");
            return false;
        }

        long magic;

        if (!PositionGetInteger(POSITION_MAGIC, magic)) {
            Print("Failed to get magic");
            return false;
        }
        if (magic == InpMagicNumber) {
            long type;
            if (!PositionGetInteger(POSITION_TYPE, type)) {
                Print("Failed to get type");
                return false;
            }
            if (all_buy_sell == 1 && type == POSITION_TYPE_SELL) {
                continue;
            }
            if (all_buy_sell == 2 && type == POSITION_TYPE_BUY) {
                continue;
            }

            trade.PositionClose(positionTicket);
            if (trade.ResultRetcode() != TRADE_RETCODE_DONE) {
                Print("Failed to close position ticket", (string) positionTicket,
                    "result", (string) trade.ResultRetcode() + ":", trade.ResultRetcodeDescription());
                return false;
            }
        }
    }
    return true;
}