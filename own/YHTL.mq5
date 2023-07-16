//+------------------------------------------------------------------+
//|                                      YesterdaysHighTodaysLow.mq5 |
//|                                  Copyright 2022, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2022, MetaQuotes Ltd."
#property link "https://www.mql5.com"
#property version "1.00"

#include <Trade\Trade.mqh>

enum LOT_MODE_ENUM
{
    OFF,                  // Fixed lot value
    LOT_MODE_MONEY,       // Risk exact amount of money per trade
    LOT_MODE_PCT_ACCOUNT, // Risk exact percentage of account balance per trade
    LOT_MODE_PCT_EQUITY   // Risk exact part of account equity per trade
};
enum ENTRY_TYPE_ENUM
{
    YHTL_IS_ENTRY, // Start position on level
    YHTL_IS_TP     // Level is TP
};

input group "===General input===";
input long InpMagicNumber = 813010;
input LOT_MODE_ENUM InpLotMode = OFF;
input double InpLots = 0.01;
input int InpStopLoss = 1000;
input int InpDaysExpiry = 3;                             // Days to expiry
input int InpFilterToCloseTransactions = 0;              // If distance from open to order is lower than this value don't send order
input int InpFilterToFarTransactions = 0;                // If distance from open to order is higher than this value don't send order
input int InpBreakEvenFromPoints = 0;                    // Break event from N points; 0=off
input ENTRY_TYPE_ENUM InpEntryType = YHTL_IS_ENTRY; // YHTL Should be entry or TP

input group "===Entry type related===";
input double InpTakeProfitMultiplier = 1.5; // Take profit ATR multiply by
input int InputTpAtrPeriod = 14;            // ATR period for TP

CTrade trade;
MqlTick prevTick, lastTick;
int atrHandle;
int time_cycle = 86400; // whole day in minutes
string lastOpenedDescription;

int OnInit()
{
    trade.SetExpertMagicNumber(InpMagicNumber);
    atrHandle = iATR(_Symbol, _Period, InputTpAtrPeriod);

    if (!CheckInputs())
    {
        return INIT_PARAMETERS_INCORRECT;
    }

    return INIT_SUCCEEDED;
}

bool CheckInputs()
{
    return true;
}

void OnDeinit(const int reason)
{
    IndicatorRelease(atrHandle);
}

void OnTick()
{
    prevTick = lastTick;
    SymbolInfoTick(_Symbol, lastTick);

    double openPreviousDay = iOpen(_Symbol, PERIOD_D1, 1);
    double highPreviousDay = iHigh(_Symbol, PERIOD_D1, 1);
    double lowPreviousDay = iLow(_Symbol, PERIOD_D1, 1);
    double closePreviousDay = iClose(_Symbol, PERIOD_D1, 1);

    double openTodays = iOpen(_Symbol, PERIOD_D1, 0);

    datetime previousDayTime = iTime(_Symbol, PERIOD_D1, 1);
    MqlDateTime previousDayTimeStruct;
    TimeToStruct(previousDayTime, previousDayTimeStruct);
    datetime expiry = TimeCurrent() + (InpDaysExpiry * time_cycle);
    string description = GetDescriptionForTransaction(previousDayTimeStruct);

    double positionPrice = MathAbs(highPreviousDay - openPreviousDay) + lowPreviousDay;

    double atrBuffer[];
    CopyBuffer(atrHandle, 0, 0, 1, atrBuffer);

    // if there is position for yesterday no new position
    if (!isOrderForToday(previousDayTimeStruct, lastOpenedDescription))
    {
        TryAddPosition(openTodays, description, expiry, positionPrice, atrBuffer[0]);
    }

    // manage open positions
    ManageOpenPositionForeach();
}

void TryAddPosition(double openTodays, string description, datetime expiry, double positionPrice, double atr)
{
    if (positionPrice > openTodays)
    {
        // sell limit because yesterday high is higher than today open for is_entry entry type
        // buy stop because yesterday high is higher than today open for is_tp entry type

        if (InpFilterToCloseTransactions > 0 && positionPrice - openTodays < InpFilterToCloseTransactions * _Point)
        {
            // Print("Filtering out transaction because distance is too close");
            return;
        }

        if (InpFilterToFarTransactions > 0 && positionPrice - openTodays > InpFilterToFarTransactions * _Point)
        {
            // Print("Filtering out transaction because distance is too far");
            return;
        }

        SendOrder(description, expiry, positionPrice, atr, true);
    }

    if (positionPrice < openTodays)
    {
        // buy limit because yesterday high is lower than today open for is_entry entry type
        // sell stop because yesterday high is lower than today open for is_tp entry type

        if (InpFilterToCloseTransactions > 0 && openTodays - positionPrice < InpFilterToCloseTransactions * _Point)
        {
            // Print("Filtering out transaction because distance is too close");
            return;
        }

        if (InpFilterToFarTransactions > 0 && openTodays - positionPrice > InpFilterToFarTransactions * _Point)
        {
            // Print("Filtering out transaction because distance is too far");
            return;
        }

        SendOrder(description, expiry, positionPrice, atr, false);
    }
}

void SendOrder(string description, datetime expiry, double positionPrice, double atr, bool isOpenBelow)
{
    if (isOpenBelow && InpEntryType == YHTL_IS_ENTRY)
    {
        double tp = NormalizeDouble(positionPrice - atr * InpTakeProfitMultiplier, _Digits);
        double sl = NormalizeDouble(positionPrice + (InpStopLoss * _Point), _Digits);

        double lots;
        if (!CalculateLots(sl - positionPrice, lots))
        {
            Print("❌ !CalculateLots(sl - positionPrice, lots)");
            return;
        }

        if (!trade.OrderOpen(_Symbol, ORDER_TYPE_SELL_LIMIT, lots, positionPrice, positionPrice, sl, tp, ORDER_TIME_SPECIFIED, expiry, description))
        {
            Print("Error opening position: ", (string)trade.ResultRetcode(), " ", trade.ResultRetcodeDescription());
        }
        else
        {
            lastOpenedDescription = description;
        }
    }

    if (isOpenBelow && InpEntryType == YHTL_IS_TP)
    {
        double tp = NormalizeDouble(positionPrice, _Digits);
        double entry = NormalizeDouble(positionPrice - atr * InpTakeProfitMultiplier, _Digits);
        double sl = NormalizeDouble(entry - (InpStopLoss * _Point), _Digits);

        bool isEntryBelowCurrent = entry < lastTick.ask;
        ENUM_ORDER_TYPE orderType = isEntryBelowCurrent ? ORDER_TYPE_BUY_LIMIT : ORDER_TYPE_BUY_STOP;

        double lots;
        if (!CalculateLots(entry - sl, lots))
        {
            Print("❌ !CalculateLots(entry - sl, lots)");
            return;
        }

        if (!trade.OrderOpen(_Symbol, orderType, lots, entry, entry, sl, tp, ORDER_TIME_SPECIFIED, expiry, description))
        {
            Print("Error opening position: ", (string)trade.ResultRetcode(), " ", trade.ResultRetcodeDescription());
        }
        else
        {
            lastOpenedDescription = description;
        }
    }

    if (!isOpenBelow && InpEntryType == YHTL_IS_ENTRY)
    {

        double tp = NormalizeDouble(positionPrice + atr * InpTakeProfitMultiplier, _Digits);
        double sl = NormalizeDouble(positionPrice - (InpStopLoss * _Point), _Digits);

        double lots;
        if (!CalculateLots(lastTick.ask - sl, lots))
        {
            Print("❌ !CalculateLots(lastTick.ask - sl, lots)");
            return;
        }

        if (!trade.OrderOpen(_Symbol, ORDER_TYPE_BUY_LIMIT, lots, positionPrice, positionPrice, sl, tp, ORDER_TIME_SPECIFIED, expiry, description))
        {
            Print("Error opening position: ", (string)trade.ResultRetcode(), " ", trade.ResultRetcodeDescription());
        }
        else
        {
            lastOpenedDescription = description;
        }
    }

    if (!isOpenBelow && InpEntryType == YHTL_IS_TP)
    {
        double tp = NormalizeDouble(positionPrice ,_Digits);
        double entry = NormalizeDouble(positionPrice + atr * InpTakeProfitMultiplier, _Digits);
        double sl = NormalizeDouble(entry + (InpStopLoss * _Point), _Digits);

        bool isEntryBelowCurrent = entry < lastTick.bid;
        ENUM_ORDER_TYPE orderType = isEntryBelowCurrent ? ORDER_TYPE_SELL_STOP : ORDER_TYPE_SELL_LIMIT;

        double lots;
        if (!CalculateLots(sl - entry, lots))
        {
            Print("❌ !CalculateLots(sl - entry, lots)");
            return;
        }

        if (!trade.OrderOpen(_Symbol, orderType, lots, entry, entry, sl, tp, ORDER_TIME_SPECIFIED, expiry, description))
        {
            Print("Error opening position: ", (string)trade.ResultRetcode(), " ", trade.ResultRetcodeDescription());
        }
        else
        {
            lastOpenedDescription = description;
        }
    }
}

bool isOrderForToday(MqlDateTime &dateTimeStruct, string description)
{
    string todaysDescription = GetDescriptionForTransaction(dateTimeStruct);

    if (description == todaysDescription)
    {
        return true;
    }

    int total = OrdersTotal();
    for (int i = total - 1; i >= 0; i--)
    {
        ulong ticket = OrderGetTicket(i);
        if (ticket <= 0)
        {
            Print("Failed to get order ticket");
            return false;
        }
        if (!OrderSelect(ticket))
        {
            Print("Failed to select order by ticket");
            return false;
        }
        ulong magicNumber;
        if (!OrderGetInteger(ORDER_MAGIC, magicNumber))
        {
            Print("Failed to get magic number from position");
            return false;
        }
        if (InpMagicNumber == magicNumber)
        {
            if (OrderGetString(ORDER_COMMENT) == todaysDescription)
            {
                Print("Position for today already exists");
                lastOpenedDescription = todaysDescription;
                return true;
            }
        }
    }
    return false;
}

string GetDescriptionForTransaction(MqlDateTime &dateTimeStruct)
{
    return (string)dateTimeStruct.year + "." + (string)dateTimeStruct.mon + "." + (string)dateTimeStruct.day;
}

bool CalculateLots(double slDistance, double &lots)
{
    lots = 0.0;
    if (InpLotMode == OFF)
    {
        lots = InpLots;
        if (!CheckLots(lots))
        {
            Print("❌ !CheckLots(lots) wrong lots");
            return false;
        }
    }
    if (InpLotMode == LOT_MODE_PCT_EQUITY)
    {
        lots = AccountInfoDouble(ACCOUNT_EQUITY) * InpLots;

        if (!CheckLots(lots))
        {
            Print("❌!CheckLots(lots) wrong lots");
            return false;
        }
    }
    if (InpLotMode == LOT_MODE_MONEY || InpLotMode == LOT_MODE_PCT_ACCOUNT)
    {
        double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
        double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
        double volumeStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

        double riskMoney = 0;

        if (InpLotMode == LOT_MODE_MONEY)
        {
            riskMoney = InpLots; // should contain money value ex: 50 in usd
        }

        if (InpLotMode == LOT_MODE_PCT_ACCOUNT)
        {
            riskMoney = AccountInfoDouble(ACCOUNT_EQUITY) * InpLots * 0.01; // should contain percent ex 14 value for 14 % of account
        }

        if (tickSize == 0)
        {
            Print("tickSize equal 0");
            tickSize = 1;
        }

        double moneyVolumeStep = (slDistance / tickSize) * tickValue * volumeStep;

        if (moneyVolumeStep == 0)
        {
            Print("❌ moneyVolumeStep equal 0 , slDistance = ", slDistance, " tickSize ", tickSize, " tickValue ", tickValue, " volumeStep ", volumeStep);
            return false;
        }

        lots = MathFloor(riskMoney / moneyVolumeStep) * volumeStep;
    }

    if (!CheckLots(lots))
    {
        Print("❌ !CheckLots(lots) wrong lots");
        return false;
    }

    return true;
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
        // Print("CheckLots: step equal 0");
        step = 1;
    }

    lots = (int)MathFloor(lots / step) * step;

    return true;
}

void ManageOpenPositionForeach()
{

    int total = PositionsTotal();
    for (int i = total - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if (ticket <= 0)
        {
            Print("Failed to get position ticket");
            return;
        }
        if (!PositionSelectByTicket(ticket))
        {
            Print("Failed to select pos by ticket");
            return;
        }
        ulong magicNumber;
        if (!PositionGetInteger(POSITION_MAGIC, magicNumber))
        {
            Print("Failed to get magic number from position");
            return;
        }
        if (InpMagicNumber == magicNumber)
        {
            // do your stuff
            if (InpBreakEvenFromPoints > 0)
            {
                SetSlToBreakEven(ticket);
            }

            // end your stuff
        }
    }
}

void SetSlToBreakEven(ulong ticket)
{
    double openPrice = 0;
    if (!PositionGetDouble(POSITION_PRICE_OPEN, openPrice))
    {
        Print("Failed to get open price");
        return;
    }

    long positionType = 0;
    if (!PositionGetInteger(POSITION_TYPE, positionType))
    {
        Print("Failed to get position type");
        return;
    }

    double sl = 0;
    if (!PositionGetDouble(POSITION_SL, sl))
    {
        Print("Failed to get position sl");
        return;
    }

    double tp = 0;
    if (!PositionGetDouble(POSITION_TP, tp))
    {
        Print("Failed to get position tp");
        return;
    }

    if (positionType == POSITION_TYPE_BUY)
    {
        if (sl >= openPrice)
        {
            return;
        }

        double currentPrice = lastTick.ask;
        double currentDistancePoints = (currentPrice - openPrice) / _Point;

        if (currentDistancePoints < 0 || currentDistancePoints < InpBreakEvenFromPoints)
        {
            return;
        }

        if (!trade.PositionModify(ticket, openPrice, tp))
        {
            Print("Failed to set buy sl to break even");
            return;
        }
    }

    if (positionType == POSITION_TYPE_SELL)
    {
        if (sl <= openPrice)
        {
            return;
        }

        double currentPrice = lastTick.bid;
        double currentDistancePoints = (openPrice - currentPrice) / _Point;

        if (currentDistancePoints < 0 || currentDistancePoints < InpBreakEvenFromPoints)
        {
            return;
        }

        if (!trade.PositionModify(ticket, openPrice, tp))
        {
            Print("Failed to set sell sl to break even");
            return;
        }
    }
}