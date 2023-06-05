// Te linie to średnia krocząca (exponential movement average)
// Pomarańcz 25
// Niebieska 50
// Czerowna 100
// na H4 grane

// jak wszstkie są w ułożeniu od najmniejszej 25 - 50 - 100 to mamy trend wzrostowy
// jak są w drugą stronę 100 50 25 to spadkowy

// jak cena zejdzie pod 50 w stronę 100 to transakcja (połowa normalnej transakcji)
// jak cena zejdzie pod 100 to cała transakcjamamy  (mamy 1,5 normalnej pozycji w grze)
// jak cena spadnie jeszcze mały kawałek np 100 pips to wszystko zamykamy ze stratą
// ale jak wejdzie do góry to czekamy aż wróci na 25

// Patrze sobie na te strategie, ma to na EURUSD szanse zarobić

// jak mamy buy i cena wejdzie powyzej 25 to SL na 50tke
// jak wyjdziemy ZMEINNA ilosc punktow ponad 25 to SL po świeczkach

// filtr na minimalna odleglosc miedzy srednimi

// rozpoznawanie ranging market i gra od krawędzi do środka
// ATR na 14 a w nim ema na 50 ale oparta na first indicator data
// jak ATR jest pod EMA to oznacza że mamy ranging market

// https://www.mql5.com/en/forum/309671
//  You can use iMAOnArray:

// for(int i=rates_total-14-1;i>=0;i--) {
//    static double buffer[14];
//    adx[i] = iADX(NULL,0,14,PRICE_CLOSE,MODE_MAIN,i);
//    ArrayCopy(buffer,adx,0,i,14);
//    ma[i] = iMAOnArray(buffer,0,14,0,MODE_SMA,0);
// }

//+------------------------------------------------------------------+
//|                                       ThreeEMAsMyOwnStrategy.mq5 |
//|                                  Copyright 2022, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2022, MetaQuotes Ltd."
#property link "https://www.mql5.com"
#property version "1.00"

#include <Trade/Trade.mqh>

int maFastHandle;
int maMiddleHandle;
int maSlowHandle;
int rsiHandle;
MqlTick previousTick;
MqlTick currentTick;
bool isFilterCandleOn = false;
enum TRAIL_SL_MODE
{
    OFF,                 // Off
    BY_CURRENT_LOWER_EMA // All entries will be trailed by previous EMA
};

CTrade trade;

input group "====General input====";
static input long InpMagicNumber = 700000;
input int InpValueMaFast = 20;
input int InpValueMaMiddle = 50;
input int InpValueMaSlow = 100;
input int InpSlowMargin = 100;
input double InpLots = 0.1;
input TRAIL_SL_MODE InpTrailingSl = OFF;

input group "====Filtering setup====";
input int InpValueRsi = 6;                              // RSI setup; step=1
input double InpValueRsiFilterThresholdDistance = 12.5; // RSI Filter threshold; step=.5;0=off
input int InpMaSizeFilter = 100;                        // MA channel size uppass filter; step=1;0=off
input double InpSmallTryFactor = 1.35;                  // Small try factor; step=.05;0=wrong
input int InpDepositLoad = 25;                          // Deposit load percentage downpass; step=1;0=off

int OnInit()
{
    bool initResult = true;
    trade.SetExpertMagicNumber(InpMagicNumber);

    maFastHandle = iMA(_Symbol, PERIOD_CURRENT, InpValueMaFast, 0, MODE_EMA, PRICE_CLOSE);
    maMiddleHandle = iMA(_Symbol, PERIOD_CURRENT, InpValueMaMiddle, 0, MODE_EMA, PRICE_CLOSE);
    maSlowHandle = iMA(_Symbol, PERIOD_CURRENT, InpValueMaSlow, 0, MODE_EMA, PRICE_CLOSE);
    rsiHandle = iRSI(_Symbol, PERIOD_CURRENT, InpValueRsi, PRICE_OPEN);

    CheckInitResult(initResult, (INVALID_HANDLE != maFastHandle), "Ma fast handle init error");
    CheckInitResult(initResult, (INVALID_HANDLE != maMiddleHandle), "Ma middle handle init error");
    CheckInitResult(initResult, (INVALID_HANDLE != maSlowHandle), "Ma slow handle init error");
    CheckInitResult(initResult, (INVALID_HANDLE != rsiHandle), "Ma rsi handle init error");

    CheckInitResult(initResult, (InpValueMaFast > 0), "Ma fast should be bigger than 0");
    CheckInitResult(initResult, (InpValueMaMiddle > 0), "Ma middle should be bigger than 0");
    CheckInitResult(initResult, (InpValueMaSlow > 0), "Ma slow should be bigger than 0");

    CheckInitResult(initResult, (InpValueMaFast < InpValueMaMiddle), "Ma fast should be smaller than ma middle");
    CheckInitResult(initResult, (InpValueMaMiddle < InpValueMaSlow), "Ma middle should be smaller than ma slow");
    CheckInitResult(initResult, (InpLots > 0), "Lots should be bigger than 0");
    CheckInitResult(initResult, (InpValueRsiFilterThresholdDistance >= 0), "RSI Filter threshold should be bigger than 0 or 0");
    CheckInitResult(initResult, (InpSmallTryFactor > 0), "Small try factor should be bigger than 0");
    CheckInitResult(initResult, (InpDepositLoad >= 0), "Deposit load percentage should be bigger than 0 or 0");

    if (initResult)
    {
        return (INIT_SUCCEEDED);
    }
    else
    {
        return (INIT_FAILED);
    }
}

void OnDeinit(const int reason)
{
    IndicatorRelease(maFastHandle);
    IndicatorRelease(maMiddleHandle);
    IndicatorRelease(maSlowHandle);
    IndicatorRelease(rsiHandle);
}

void OnTick()
{
    // read values from indicators
    double bufferMaFast[], bufferMaMiddle[], bufferMaSlow[], bufferRsi[];
    CopyBuffer(maFastHandle, 0, 0, 1, bufferMaFast);
    CopyBuffer(maMiddleHandle, 0, 0, 1, bufferMaMiddle);
    CopyBuffer(maSlowHandle, 0, 0, 1, bufferMaSlow);
    CopyBuffer(rsiHandle, 0, 0, 1, bufferRsi);

    if (InpTrailingSl == BY_CURRENT_LOWER_EMA)
    {
        TrailByLowerEma(bufferMaMiddle);
    }

    if (!IsNewBar() && isFilterCandleOn)
    {
        return;
    }

    previousTick = currentTick;
    if (!SymbolInfoTick(_Symbol, currentTick))
    {
        Print("Failed to get current tick");
        return;
    }


    // 1 for uptrend, 0 unknown, -1 for downtrend
    int trendDirection = getTrendDirection(bufferMaFast, bufferMaMiddle, bufferMaSlow);

    if (InpMaSizeFilter > 0 && trendDirection != 0 && ShouldBeFiltered(trendDirection, bufferMaSlow, bufferMaFast))
    {
        return;
    }

    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

    // int orders = 0;

    // for (int i = OrdersTotal() - 1; i >= 0; i--)
    // {
    //     ulong orderTicket = OrderGetTicket(i);
    //     if (OrderSelect(orderTicket))
    //     {
    //         if (OrderGetString(ORDER_SYMBOL) == _Symbol && OrderGetInteger(ORDER_MAGIC) == InpMagicNumber)
    //         {
    //             if (OrderGetInteger(ORDER_TIME_SETUP) < TimeCurrent() - 30 * PeriodSeconds(PERIOD_M1))
    //             {
    //                 trade.OrderDelete(orderTicket);
    //             }
    //             orders = orders + 1;
    //         }
    //     }
    // }

    if (InpDepositLoad > 0 && ShouldBeFilteredDepositLoad())
    {
        return;
    }

    if (trendDirection == 1)
    {
        ShouldBuy(bufferMaFast, bufferMaMiddle, bufferMaSlow, bufferRsi);
    }

    if (trendDirection == -1)
    {
        // ShouldSell(bufferMaFast, bufferMaMiddle, bufferMaSlow, bufferRsi);
    }
}

bool IsNewBar()
{
    static datetime previousTime = 0;
    datetime currentTime = iTime(_Symbol, PERIOD_CURRENT, 0);
    if (previousTime != currentTime)
    {
        isFilterCandleOn = false;
        previousTime = currentTime;
        return true;
    }
    return false;
}

int getTrendDirection(double &bufferMaFast[], double &bufferMaMiddle[], double &bufferMaSlow[])
{
    if (bufferMaFast[0] > bufferMaMiddle[0] && bufferMaMiddle[0] > bufferMaSlow[0])
    {
        return 1;
    }
    else if (bufferMaFast[0] < bufferMaMiddle[0] && bufferMaMiddle[0] < bufferMaSlow[0])
    {
        return -1;
    }
    else
    {
        return 0;
    }
}

void ShouldBuy(double &bufferMaFast[], double &bufferMaMiddle[], double &bufferMaSlow[], double &bufferRsi[])
{
    double slowMarginValue = bufferMaSlow[0] - (InpSlowMargin * _Point);
    if (currentTick.bid <= slowMarginValue)
    {
        Print("ShouldBuy - nothing should happen - below slow margin zone");
        return;
    }

    if (bufferMaSlow[0] - slowMarginValue <= currentTick.bid && currentTick.bid <= bufferMaSlow[0])
    {
        Print("ShouldBuy - full lot - slow margin zone");

        double sl = NormalizeDouble(slowMarginValue, _Digits);
        double tp = NormalizeDouble(bufferMaFast[0], _Digits);

        double currentLot = InpLots;
        if (!CheckLots(currentLot))
        {
            Print("ShouldBuy - CheckLots failed");
            return;
        }

        if (!trade.PositionOpen(_Symbol, ORDER_TYPE_BUY, currentLot, previousTick.ask, sl, tp, "fu"))
        {
            PrintFormat("❌[ShouldBuy]: ", "PositionOpen failed: sl %d; tp: %d; lots: %d, || %s :: %s",
                        sl, tp, currentLot,
                        trade.ResultRetcode(),
                        trade.ResultRetcodeDescription());
        }

        isFilterCandleOn = true;
        return;
    }

    if (bufferMaSlow[0] <= currentTick.bid && currentTick.bid <= bufferMaMiddle[0])
    {
        Print("ShouldBuy - should by 0.5 of stake - we are close");

        double sl = NormalizeDouble(bufferMaSlow[0], _Digits);
        double tp = NormalizeDouble(bufferMaFast[0], _Digits);

        double halfLot = InpLots / 2;
        if (!CheckLots(halfLot))
        {
            Print("ShouldBuy - CheckLots failed");
            return;
        }

        if (!trade.PositionOpen(_Symbol, ORDER_TYPE_BUY, halfLot, previousTick.ask, sl, tp, "me"))
        {
            PrintFormat("❌[ShouldBuy]: ", "PositionOpen failed: sl %d; tp: %d; lots: %d, || %s :: %s",
                        sl, tp, halfLot,
                        trade.ResultRetcode(),
                        trade.ResultRetcodeDescription());
        }
        isFilterCandleOn = true;
        return;
    }

    if (currentTick.bid <= bufferMaFast[0])
    {
        Print("ShouldBuy - should by 0.25 of stake - just a small try");

        if (InpValueRsiFilterThresholdDistance > 0 && bufferRsi[0] > InpValueRsiFilterThresholdDistance + 30)
        {
            Print("RSI filter #ON - filtered out");
            return;
        }

        double sl = NormalizeDouble(bufferMaMiddle[0], _Digits);
        double tp = NormalizeDouble(((currentTick.bid - bufferMaMiddle[0]) * InpSmallTryFactor) + currentTick.bid, _Digits);

        double quaterOfLot = InpLots / 4;
        if (!CheckLots(quaterOfLot))
        {
            Print("ShouldBuy - CheckLots failed");
            return;
        }

        if (!trade.PositionOpen(_Symbol, ORDER_TYPE_BUY, quaterOfLot, previousTick.ask, sl, tp, "sm"))
        {
            PrintFormat("❌[ShouldBuy]: ", "PositionOpen failed: sl %d; tp: %d; lots: %d, || %s :: %s",
                        sl, tp, quaterOfLot,
                        trade.ResultRetcode(),
                        trade.ResultRetcodeDescription());
        }
        isFilterCandleOn = true;
        return;
    }
}

void ShouldSell(double &bufferMaFast[], double &bufferMaMiddle[], double &bufferMaSlow[], double &bufferRsi[])
{
    double slowMarginValue = bufferMaSlow[0] + (InpSlowMargin * _Point);
    if (currentTick.bid >= slowMarginValue)
    {
        Print("ShouldSell - nothing should happen - below slow margin zone");
        return;
    }

    if (currentTick.bid <= bufferMaSlow[0] + slowMarginValue && bufferMaSlow[0] <= currentTick.bid)
    {
        Print("ShouldSell - full lot - slow margin zone");

        double sl = NormalizeDouble(slowMarginValue, _Digits);
        double tp = NormalizeDouble(bufferMaFast[0], _Digits);

        double currentLot = InpLots;
        if (!CheckLots(currentLot))
        {
            Print("ShouldSell - CheckLots failed");
            return;
        }

        if (!trade.PositionOpen(_Symbol, ORDER_TYPE_SELL, currentLot, previousTick.bid, sl, tp, "fu"))
        {
            PrintFormat("❌[ShouldSell]: ", "PositionOpen failed: sl %d; tp: %d; lots: %d, || %s :: %s",
                        sl, tp, currentLot,
                        trade.ResultRetcode(),
                        trade.ResultRetcodeDescription());
        }
        isFilterCandleOn = true;
        return;
    }

    if (currentTick.bid <= bufferMaSlow[0] && bufferMaMiddle[0] <= currentTick.bid)
    {
        Print("ShouldSell - should by 0.5 of stake - we are close");

        double sl = NormalizeDouble(bufferMaSlow[0], _Digits);
        double tp = NormalizeDouble(bufferMaFast[0], _Digits);

        double halfLot = InpLots / 2;
        if (!CheckLots(halfLot))
        {
            Print("ShouldSell - CheckLots failed");
            return;
        }

        if (!trade.PositionOpen(_Symbol, ORDER_TYPE_SELL, halfLot, previousTick.bid, sl, tp, "me"))
        {
            PrintFormat("❌[ShouldSell]: ", "PositionOpen failed: sl %d; tp: %d; lots: %d, || %s :: %s",
                        sl, tp, halfLot,
                        trade.ResultRetcode(),
                        trade.ResultRetcodeDescription());
        }
        isFilterCandleOn = true;
        return;
    }

    if (bufferMaFast[0] <= currentTick.bid)
    {
        Print("ShouldSell - should by 0.25 of stake - just a small try");

        if (InpValueRsiFilterThresholdDistance > 0 && bufferRsi[0] < 70 - InpValueRsiFilterThresholdDistance)
        {
            Print("RSI filter #ON - filtered out");
            return;
        }

        double sl = NormalizeDouble(bufferMaMiddle[0], _Digits);
        double tp = NormalizeDouble(((currentTick.bid - bufferMaMiddle[0]) * InpSmallTryFactor) + currentTick.bid, _Digits);

        double quaterOfLot = InpLots / 4;
        if (!CheckLots(quaterOfLot))
        {
            Print("ShouldSell - CheckLots failed");
            return;
        }

        if (!trade.PositionOpen(_Symbol, ORDER_TYPE_SELL, quaterOfLot, previousTick.bid, sl, tp, "sm"))
        {
            PrintFormat("❌[ShouldSell]: ", "PositionOpen failed: sl %d; tp: %d; lots: %d, || %s :: %s",
                        sl, tp, quaterOfLot,
                        trade.ResultRetcode(),
                        trade.ResultRetcodeDescription());
        }
        isFilterCandleOn = true;
        return;
    }
}

bool CheckLots(double &lots)
{
    double min = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double max = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

    if (min == 0)
    {
        Print("CheckLots: min lots equal 0");
    }

    if (max == 0)
    {
        Print("CheckLots: max lots equal 0");
    }

    if (lots < min)
    {
        Print("CheckLots: Lots below min lots");
        lots = min;
        return true;
    }

    if (lots > max)
    {
        Print("CheckLots: Lots above max");
        return false;
    }

    if (step == 0)
    {
        Print("CheckLots: step equal 0");
        step = 1;
    }

    lots = (int)MathFloor(lots / step) * step;

    return true;
}

bool ShouldBeFiltered(int trendDirection, double &bufferMaSlow[], double &bufferMaFast[])
{
    if (trendDirection == -1 && bufferMaSlow[0] - bufferMaFast[0] < InpMaSizeFilter * _Point)
    {
        return true;
    }

    if (trendDirection == 1 && bufferMaFast[0] - bufferMaSlow[0] < InpMaSizeFilter * _Point)
    {
        return true;
    }

    return false;
}

void CheckInitResult(bool &initResult, bool condition, string message)
{
    if (!condition)
    {
        Print(message);
        initResult = false;
    }
}

bool ShouldBeFilteredDepositLoad()
{
    double accountBallanceValue = AccountInfoDouble(ACCOUNT_BALANCE);
    double marginUsedValue = accountBallanceValue - AccountInfoDouble(ACCOUNT_MARGIN_FREE);
    double userPercentage = (marginUsedValue / accountBallanceValue) * 100;

    if (userPercentage > InpDepositLoad)
    {
        Print("❌ Filtered out trade due to deposit load filtering");
        return true;
    }
    else
    {
        return false;
    }
}

void TrailByLowerEma(double &bufferMaMiddle[])
{
    for (int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong posTicket = PositionGetTicket(i);
        if (PositionSelectByTicket(posTicket))
        {
            if (PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
            {
                if (PositionGetString(POSITION_COMMENT) == "sm")
                {
                    if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
                        double currentSl = PositionGetDouble(POSITION_SL);
                        double currentTp = PositionGetDouble(POSITION_TP);
                        double possibleSl = NormalizeDouble(bufferMaMiddle[0], _Digits);
                        if (currentSl < possibleSl)
                        {
                            if (trade.PositionModify(posTicket, possibleSl, currentTp))
                            {
                                Print("TrailByLowerEma - position buy modified from sl: %d to new sl: %d",  currentSl, possibleSl);
                            }
                        }
                    } 
                    if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL) {
                        double currentSl = PositionGetDouble(POSITION_SL);
                        double currentTp = PositionGetDouble(POSITION_TP);
                        double possibleSl = NormalizeDouble(bufferMaMiddle[0], _Digits);
                        if (currentSl > possibleSl)
                        {
                            if (trade.PositionModify(posTicket, possibleSl, currentTp))
                            {
                                Print("TrailByLowerEma - position sell modified from sl: %d to new sl: %d",  currentSl, possibleSl);
                            }
                        }
                    }
                }
            }
        }
    }
}