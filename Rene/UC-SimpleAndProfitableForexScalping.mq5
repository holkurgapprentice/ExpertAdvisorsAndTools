//+------------------------------------------------------------------+
//|                             SimpleAndProfitableForexScalping.mq5 |
//|                                  Copyright 2022, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2022, MetaQuotes Ltd."
#property link "https://www.mql5.com"
#property version "1.00"

#include <Trade/Trade.mqh>

// SetUp
int handleTrendMaFast;
int handleTrendMaSlow;

int handleMaFast;
int handleMaMiddle;
int handleMaSlow;

CTrade trade;

// Internal values
bool firstTrade = true;
double bid = 0;
int trendDirection = 0;
double maTrendFast[], maTrendSlow[], maFast[], maMiddle[], maSlow[];
int positions = 0;
int orders = 0;

// Inputs from user
input int eaMagic = 22;
input double eaLots = 0.05;
input bool tryTrade = false;
input int ordersLiveMinutes = 30;
input ENUM_TIMEFRAMES tradeTimeFrame = PERIOD_M5;
input ENUM_TIMEFRAMES trendTimeFrame = PERIOD_H1;
input int fastGetSLPoints = 100;
input bool isFastGet = true;
input int maFilterTrendPoints = 20; // maFilterTrendPoints 0 off
input double runOutPercent = 0.5;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
   trade.SetExpertMagicNumber(eaMagic);

   handleTrendMaFast = iMA(_Symbol, trendTimeFrame, 8, 0, MODE_EMA, PRICE_CLOSE);
   handleTrendMaSlow = iMA(_Symbol, trendTimeFrame, 21, 0, MODE_EMA, PRICE_CLOSE);

   handleMaFast = iMA(_Symbol, tradeTimeFrame, 8, 0, MODE_EMA, PRICE_CLOSE);
   handleMaMiddle = iMA(_Symbol, tradeTimeFrame, 13, 0, MODE_EMA, PRICE_CLOSE);
   handleMaSlow = iMA(_Symbol, tradeTimeFrame, 21, 0, MODE_EMA, PRICE_CLOSE);
   return (INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {

}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {

   if (tryTrade && firstTrade) {
      trade.Buy(0.01, _Symbol);
      firstTrade = false;
   }

   bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   positions = 0;
   orders = 0;

   RenderTrendDirection();

   LoopOnPositions();
   LoopOnOrders();

   if (trendDirection == 1) {
      HandleUpTrend();
   }

   if (trendDirection == -1) {
      HandleDownTrend();
   }

   Comment(
      "\nFast Trend Ma: ", DoubleToString(maTrendFast[0], _Digits),
      "\nSlow Trend Ma: ", DoubleToString(maTrendSlow[0], _Digits),
      "\nTrend direction: ", trendDirection,
      "\n",
      "\nFast Ma: ", DoubleToString(maFast[0], _Digits),
      "\nMid Ma: ", DoubleToString(maMiddle[0], _Digits),
      "\nSlow Ma: ", DoubleToString(maSlow[0], _Digits),
      "\n",
      "\nPositions: ", positions,
      "\nOrders: ", orders,
      "\nTrendDirection: ", trendDirection
   );
}

void RenderTrendDirection() {
   CopyBuffer(handleTrendMaFast, 0, 0, 1, maTrendFast);
   CopyBuffer(handleTrendMaSlow, 0, 0, 1, maTrendSlow);

   CopyBuffer(handleMaFast, 0, 1, 1, maFast); // take recent - 1 value
   CopyBuffer(handleMaMiddle, 0, 1, 1, maMiddle);
   CopyBuffer(handleMaSlow, 0, 1, 1, maSlow);

   trendDirection = 0;
   if (IsUpperTrendOnHigherTimeframe()) {
      trendDirection = 1;
   } else if (IsDownTrendOnHigherTimeframe()) {
      trendDirection = -1;
   }
}

bool IsUpperTrendOnHigherTimeframe() {
   return maTrendFast[0] > maTrendSlow[0] && bid > maTrendSlow[0] && maTrendFast[0] - maTrendSlow[0] > maFilterTrendPoints * _Point;
}

bool IsDownTrendOnHigherTimeframe() {
   return maTrendFast[0] < maTrendSlow[0] && bid < maTrendSlow[0] && maTrendSlow[0] - maTrendFast[0] > maFilterTrendPoints * _Point;
}

void LoopOnPositions() {
   for (int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong posTicket = PositionGetTicket(i);
      if (PositionSelectByTicket(posTicket)) {
         if (PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_MAGIC) == eaMagic) {

            positions = positions + 1;

            if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
               if (PositionGetDouble(POSITION_VOLUME) >= eaLots) {
                  CloseHalfBuyTrade(posTicket);                 
               } else {
                  TrailSlBuy(posTicket);
               }
            }
            
            if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL) {
               if (PositionGetDouble(POSITION_VOLUME) >= eaLots) {
                  CloseHalfSellTrade(posTicket);                 
               } else {
                  TrailSlSell(posTicket);
               }
            }
         }
      } else {
         Print(__FUNCTION__, " Position not selected: ", GetLastError());
      }
   }
}

void CloseHalfBuyTrade(int posTicket){
   double diferencePrice = PositionGetDouble(POSITION_PRICE_OPEN) - PositionGetDouble(POSITION_SL);
   double tp = PositionGetDouble(POSITION_PRICE_OPEN) + diferencePrice;
   double halfTp = PositionGetDouble(POSITION_PRICE_OPEN) + (diferencePrice * runOutPercent);

   if (bid >= tp) {
      if (trade.PositionClosePartial(posTicket, NormalizeDouble(PositionGetDouble(POSITION_VOLUME) / 2, 2))) {
         double sl = PositionGetDouble(POSITION_PRICE_OPEN);
         sl = NormalizeDouble(sl, _Digits);
         trade.PositionModify(posTicket, sl, 0);
      }
   } else if (bid >= halfTp) {
      double sl = PositionGetDouble(POSITION_PRICE_OPEN);
      sl = NormalizeDouble(sl, _Digits);
      trade.PositionModify(posTicket, sl, 0);
   }
}

void CloseHalfSellTrade(int posTicket){
   double diferencePrice = PositionGetDouble(POSITION_SL) - PositionGetDouble(POSITION_PRICE_OPEN);
   double tp = PositionGetDouble(POSITION_PRICE_OPEN) - diferencePrice;
   double halfTp = PositionGetDouble(POSITION_PRICE_OPEN) - (diferencePrice * runOutPercent);


   if (bid <= tp) {
      if (trade.PositionClosePartial(posTicket, NormalizeDouble(PositionGetDouble(POSITION_VOLUME) / 2, 2))) {
         double sl = PositionGetDouble(POSITION_PRICE_OPEN);
         sl = NormalizeDouble(sl, _Digits);
         trade.PositionModify(posTicket, sl, 0);
      }
   } else if (bid <= halfTp) {
      double sl = PositionGetDouble(POSITION_PRICE_OPEN);
         sl = NormalizeDouble(sl, _Digits);
         trade.PositionModify(posTicket, sl, 0);
   }
}

void TrailSlBuy(int posTicket) {
   int lowest = iLowest(_Symbol, tradeTimeFrame, MODE_LOW, 3, 0);
   double sl = iLow(_Symbol, tradeTimeFrame, lowest);
   sl = NormalizeDouble(sl, _Digits);
   
   if (sl <= PositionGetDouble(POSITION_SL)) {
      return;
   }
   
   double stopLossCurrentPriceDistance = (bid - sl) / _Point;
   
   if (stopLossCurrentPriceDistance > fastGetSLPoints && isFastGet) {
      sl = bid - ((stopLossCurrentPriceDistance / 2) * _Point);
      sl = NormalizeDouble(sl, _Digits);
   }
   if (!trade.PositionModify(posTicket, sl, 0)) {
      Print(__FUNCTION__, " Position PositionModify error");
   }
}

void TrailSlSell(int posTicket) {
   int highest = iHighest(_Symbol, tradeTimeFrame, MODE_LOW, 3, 0);
   double sl = iHigh(_Symbol, tradeTimeFrame, highest);
   sl = NormalizeDouble(sl, _Digits);
   
   if (sl >= PositionGetDouble(POSITION_SL)) {
      return;
   }
   
   double stopLossCurrentPriceDistance = (sl - bid) / _Point;
   
   if (stopLossCurrentPriceDistance > fastGetSLPoints && isFastGet) {
      sl = bid - ((stopLossCurrentPriceDistance / 2) * _Point);
      sl = NormalizeDouble(sl, _Digits);
   }
   if (!trade.PositionModify(posTicket, sl, 0)) {
      Print(__FUNCTION__, " Position PositionModify error");
   }
}

void LoopOnOrders() {
   for (int i = OrdersTotal() - 1; i >= 0; i--) {
      ulong orderTicket = OrderGetTicket(i);
      if (OrderSelect(orderTicket)) {
         if (OrderGetString(ORDER_SYMBOL) == _Symbol && OrderGetInteger(ORDER_MAGIC) == eaMagic) {
            DeleteOldOrder(orderTicket);
            orders = orders + 1;
         }
      }
   }
}

void DeleteOldOrder(int orderTicket) {
   if (OrderGetInteger(ORDER_TIME_SETUP) < TimeCurrent() - ordersLiveMinutes * PeriodSeconds(PERIOD_M1)) {
      trade.OrderDelete(orderTicket);
   }
}

void HandleUpTrend() {
   if (maFast[0] > maMiddle[0] && maMiddle[0] > maSlow[0]) {
      // look only at completed bars, so we look on previous (completed one)
      double priceBottomLastBar = iLow(_Symbol, tradeTimeFrame, 1);
   
      if (priceBottomLastBar <= maFast[0] && priceBottomLastBar >= maSlow[0]) {
         if (positions + orders <= 0) {
            int indexHighest = iHighest(_Symbol, tradeTimeFrame, MODE_HIGH, 5, 1);
            double highPrice = iHigh(_Symbol, tradeTimeFrame, indexHighest);
            double entry = NormalizeDouble(highPrice, _Digits);
   
            double stopLoss = iLow(_Symbol, tradeTimeFrame, 1) - 30 * _Point;
            stopLoss = NormalizeDouble(stopLoss, _Digits);
   
            double takeProfit = entry + (entry - stopLoss);
            if (entry <= bid) {
               Print(__FUNCTION__, " Threre is a BUY signal but I have to wait for entry (entry <= bid) ");
               trade.BuyStop(eaLots, bid, _Symbol, stopLoss);
            } else {
               trade.BuyStop(eaLots, entry, _Symbol, stopLoss);
            }
         }
      }
   }
}

void HandleDownTrend() {
   if (maFast[0] < maMiddle[0] && maMiddle[0] < maSlow[0]) {
      // look only at completed bars, so we look on previous (completed one)
      double priceHighestLastBar = iHigh(_Symbol, tradeTimeFrame, 1);
      if (priceHighestLastBar >= maFast[0] && priceHighestLastBar <= maSlow[0]) {
         if (positions + orders <= 0) {
            int indexLowest = iLowest(_Symbol, tradeTimeFrame, MODE_LOW, 5, 1);
            double entry = iLow(_Symbol, tradeTimeFrame, indexLowest);
   
            double stopLoss = iHigh(_Symbol, tradeTimeFrame, 1) + 30 * _Point;
            stopLoss = NormalizeDouble(stopLoss, _Digits);
   
            double takeProfit = entry - (stopLoss - entry);
            if (entry >= bid) {
               Print(__FUNCTION__, " Threre is a SELL signal but I have to wait for entry (entry >= bid) ");
               trade.SellStop(eaLots, bid, _Symbol, stopLoss);
            } else {
               trade.SellStop(eaLots, entry, _Symbol, stopLoss);
            }
         }
      }
   }
}
