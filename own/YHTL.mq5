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

input group "===General input===";
input long InpMagicNumber = 813010;
input LOT_MODE_ENUM InpLotMode = OFF;
input double InpLots = 0.01;
input int InpStopLoss = 1000;
input double InpTakeProfitMultiplier = 1.5; // Take profit ATR multiply by
input int InpTrailingStopAtrPeriod = 14;    // ATR period for TP
input int InpDaysExpiry = 3;                // Days to expiry
input int InpFilterToCloseTransactions = 0; // If distance from open to order is lower than this value don't send order
input int InpFilterToFarTransactions = 0;   // If distance from open to order is higher than this value don't send order

CTrade trade;
MqlTick prevTick, lastTick;
int atrHandle;
int time_cycle = 86400; // whole day in minutes
string lastOpenedDescription;

int OnInit()
{
    trade.SetExpertMagicNumber(InpMagicNumber);
    atrHandle = iATR(_Symbol, _Period, InpTrailingStopAtrPeriod);

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
}

void TryAddPosition(double openTodays, string description, datetime expiry, double positionPrice, double atr)
{
    if (positionPrice > openTodays)
    {
        // sell limit because we are in uptrend

        if (InpFilterToCloseTransactions > 0 && positionPrice - openTodays < InpFilterToCloseTransactions)
        {
            Print("Filtering out transaction because distance is too close");
            return;
        }

        if (InpFilterToFarTransactions > 0 && positionPrice - openTodays > InpFilterToFarTransactions)
        {
            Print("Filtering out transaction because distance is too far");
            return;
        }

        double tp = NormalizeDouble(positionPrice - atr * InpTakeProfitMultiplier, _Digits);
        double sl = NormalizeDouble(positionPrice + (InpStopLoss * _Point), _Digits);

        if (!trade.OrderOpen(_Symbol, ORDER_TYPE_SELL_LIMIT, InpLots, positionPrice, positionPrice, sl, tp, ORDER_TIME_SPECIFIED, expiry, description))
        {
            Print("Error opening position: ", (string)trade.ResultRetcode(), " ", trade.ResultRetcodeDescription());
        }
        lastOpenedDescription = description;
    }

    if (positionPrice < openTodays)
    {
        // buy limit because we are in downtrend

        if (InpFilterToCloseTransactions > 0 && openTodays - positionPrice < InpFilterToCloseTransactions)
        {
            Print("Filtering out transaction because distance is too close");
            return;
        }

        if (InpFilterToFarTransactions > 0 && openTodays - positionPrice > InpFilterToFarTransactions)
        {
            Print("Filtering out transaction because distance is too far");
            return;
        }

        double tp = NormalizeDouble(positionPrice + atr * InpTakeProfitMultiplier, _Digits);
        double sl = NormalizeDouble(positionPrice - (InpStopLoss * _Point), _Digits);

        if (!trade.OrderOpen(_Symbol, ORDER_TYPE_BUY_LIMIT, InpLots, positionPrice, positionPrice, sl, tp, ORDER_TIME_SPECIFIED, expiry, description))
        {
            Print("Error opening position: ", (string)trade.ResultRetcode(), " ", trade.ResultRetcodeDescription());
        }
        lastOpenedDescription = description;
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
            Print("Failed to get position ticket");
            return false;
        }
        if (!PositionSelectByTicket(ticket))
        {
            Print("Failed to select pos by ticket");
            return false;
        }
        ulong magicNumber;
        if (!PositionGetInteger(POSITION_MAGIC, magicNumber))
        {
            Print("Failed to get magic number from position");
            return false;
        }
        if (InpMagicNumber == magicNumber)
        {
            if (PositionGetString(POSITION_COMMENT) == todaysDescription)
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