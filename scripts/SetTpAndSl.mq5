#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link "https://www.mql5.com"
#property version "1.00"
#property script_show_inputs

#include <Trade\Trade.mqh>

input bool InpDoOverwriteSl = false;          // Overwrite SL regardless if they are better found
input bool InpOverwriteUsingAverages = false; // Overwrite SL using approx TP and Entry price to calc SL

class PositionManager
{
private:
    string mainSymbol;
    double mainTpPrice;
    double mainEntryPrice;
    double calcSl;
    double averageTpPrice;
    double averageOpenPrice;
    double averageCalcSl;
    long mainType;
    int tpsSetCount;
    CTrade c_trade;

public:
    PositionManager(const string &symbol)
        : mainSymbol(symbol), mainTpPrice(0), mainEntryPrice(0), calcSl(0),
          averageTpPrice(0), averageOpenPrice(0), averageCalcSl(0), mainType(0), tpsSetCount(0) {}

    void FindBestTp()
    {
        for (int i = PositionsTotal() - 1; i >= 0; --i)
        {
            ulong ticket = PositionGetTicket(i);
            if (PositionGetSymbol(i) == mainSymbol)
            {
                double tpPrice = 0, entryPrice = 0;
                long type = 0;

                if (!PositionGetDouble(POSITION_TP, tpPrice) || tpPrice <= 0)
                    continue;
                if (!PositionGetInteger(POSITION_TYPE, type))
                    continue;
                if (!PositionGetDouble(POSITION_PRICE_OPEN, entryPrice))
                    continue;

                tpsSetCount++;
                if (tpsSetCount == 1 || IsBetterTp(type, tpPrice))
                {
                    mainTpPrice = tpPrice;
                    mainEntryPrice = entryPrice;
                    mainType = type;
                    calcSl = CalculateSl(mainEntryPrice, mainTpPrice, mainType);
                }
            }
        }

        if (mainTpPrice == 0)
        {
            Alert("No TP found");
        }
    }

    void FindAverage()
    {
        double totalTpPrice = 0;
        double totalOpenPrice = 0;

        for (int i = PositionsTotal() - 1; i >= 0; --i)
        {
            ulong ticket = PositionGetTicket(i);
            if (PositionGetSymbol(i) == mainSymbol)
            {
                double tpPrice = 0, entryPrice = 0, slPrice = 0;

                if (!PositionGetDouble(POSITION_TP, tpPrice) || tpPrice <= 0)
                    continue;
                if (!PositionGetDouble(POSITION_PRICE_OPEN, entryPrice))
                    continue;
                if (!PositionGetDouble(POSITION_SL, slPrice))
                    continue;

                totalTpPrice += tpPrice;
                totalOpenPrice += entryPrice;
            }
        }

        if (tpsSetCount > 0)
        {
            averageTpPrice = totalTpPrice / tpsSetCount;
            averageOpenPrice = totalOpenPrice / tpsSetCount;
        }
        else
        {
            Alert("No averages found");
        }

        averageCalcSl = CalculateSl(averageOpenPrice, averageTpPrice, mainType);
    }

    void ModifyPositions()
    {
        for (int i = PositionsTotal() - 1; i >= 0; --i)
        {
            ulong ticket = PositionGetTicket(i);
            long positionType = 0;
            double slPrice = 0;

            if (!PositionGetInteger(POSITION_TYPE, positionType))
                continue;
            if (mainType != positionType)
                continue;
            if (PositionGetSymbol(i) != mainSymbol)
                continue;
            if (!PositionGetDouble(POSITION_SL, slPrice))
                continue;

            slPrice = AdjustSlPrice(slPrice, mainType, InpOverwriteUsingAverages ? averageCalcSl : calcSl);
            c_trade.PositionModify(ticket, slPrice, mainTpPrice);
        }
    }

    void ModifyOrders()
    {
        for (int i = OrdersTotal() - 1; i >= 0; --i)
        {
            ulong ticket = OrderGetTicket(i);
            long positionType = 0;
            double slPrice = 0, entryPrice = 0, stopLimitPrice = 0;
            long expiration = 0;
            string symbol;

            if (!OrderGetInteger(ORDER_TYPE, positionType))
                continue;
            if (!OrderGetDouble(ORDER_SL, slPrice))
                continue;
            if (!OrderGetDouble(ORDER_PRICE_OPEN, entryPrice))
                continue;
            if (!OrderGetString(ORDER_SYMBOL, symbol))
                continue;
            if (symbol != mainSymbol)
                continue;

            slPrice = AdjustSlPrice(slPrice, mainType, calcSl);
            if (!OrderGetInteger(ORDER_TIME_EXPIRATION, expiration))
                continue;
            if (!OrderGetDouble(ORDER_PRICE_STOPLIMIT, stopLimitPrice))
                continue;

            c_trade.OrderModify(ticket, entryPrice, slPrice, mainTpPrice, ORDER_TIME_GTC, expiration, stopLimitPrice);
        }
    }

private:
    bool IsBetterTp(long type, double tpPrice)
    {
        return (mainType == POSITION_TYPE_BUY && mainTpPrice < tpPrice) ||
               (mainType == POSITION_TYPE_SELL && mainTpPrice > tpPrice);
    }

    double CalculateSl(double entryPrice, double tpPrice, long type)
    {
        return (type == POSITION_TYPE_BUY) ? entryPrice - (tpPrice - entryPrice) : entryPrice + (entryPrice - tpPrice);
    }

    double AdjustSlPrice(double currentSlPrice, long positionType, double calculatedSlPrice)
    {
        if (currentSlPrice != 0)
        {
            if ((positionType == POSITION_TYPE_BUY && currentSlPrice < calculatedSlPrice) ||
                InpDoOverwriteSl)
                return calculatedSlPrice;
            if ((positionType == POSITION_TYPE_SELL && currentSlPrice > calculatedSlPrice) ||
                InpDoOverwriteSl)
                return calculatedSlPrice;
        }
        return currentSlPrice == 0 ? calculatedSlPrice : currentSlPrice;
    }
};

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
    string mainSymbol = Symbol();
    Print("Symbol: ", mainSymbol);

    PositionManager positionManager(mainSymbol);
    positionManager.FindBestTp();
    if (InpOverwriteUsingAverages)
    {
        positionManager.FindAverage();
    }
    positionManager.ModifyPositions();
    positionManager.ModifyOrders();
}
//+------------------------------------------------------------------+
