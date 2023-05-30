//+------------------------------------------------------------------+
//|                             SimpleAndProfitableForexScalping.mq5 |
//|                                  Copyright 2022, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2022, MetaQuotes Ltd."
#property link "https://www.mql5.com"
#property version "1.00"

#include <Trade/Trade.mqh>

int handleTrendMaFast;
int handleTrendMaSlow;

int maFastHandle;
int maMiddleHandle;
int maSlowHandle;

CTrade trade;

int eaMagic = 22;
input double eaLots = 0.05;
input bool tryTrade = false;
bool firstTrade = true;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
   trade.SetExpertMagicNumber(eaMagic);

   handleTrendMaFast = iMA(_Symbol, PERIOD_H1, 8, 0, MODE_EMA, PRICE_CLOSE);
   handleTrendMaSlow = iMA(_Symbol, PERIOD_H1, 21, 0, MODE_EMA, PRICE_CLOSE);

   maFastHandle = iMA(_Symbol, PERIOD_M5, 8, 0, MODE_EMA, PRICE_CLOSE);
   maMiddleHandle = iMA(_Symbol, PERIOD_M5, 13, 0, MODE_EMA, PRICE_CLOSE);
   maSlowHandle = iMA(_Symbol, PERIOD_M5, 21, 0, MODE_EMA, PRICE_CLOSE);
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

   double maTrendFast[], maTrendSlow[];
   CopyBuffer(handleTrendMaFast, 0, 0, 1, maTrendFast);
   CopyBuffer(handleTrendMaSlow, 0, 0, 1, maTrendSlow);

   double maFast[], maMiddle[], maSlow[];
   CopyBuffer(maFastHandle, 0, 0, 1, maFast);
   CopyBuffer(maMiddleHandle, 0, 0, 1, maMiddle);
   CopyBuffer(maSlowHandle, 0, 0, 1, maSlow);

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   int trendDirection = 0;
   if (maTrendFast[0] > maTrendSlow[0] && bid > maTrendFast[0]) {
      trendDirection = 1;
   } else if (maTrendFast[0] < maTrendSlow[0] && bid < maTrendFast[0]) {
      trendDirection = -1;
   }

   int positions = 0;

   for (int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong posTicket = PositionGetTicket(i);
      if (PositionSelect(posTicket)) {
         if (PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_MAGIC) == eaMagic) {
            positions = positions + 1;

            if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
               if (PositionGetDouble(POSITION_VOLUME) >= eaLots) {

                  double tp = PositionGetDouble(POSITION_PRICE_OPEN) + (PositionGetDouble(POSITION_PRICE_OPEN) - PositionGetDouble(POSITION_SL));

                  if (bid >= tp) {
                     if (trade.PositionClosePartial(posTicket, NormalizeDouble(PositionGetDouble(POSITION_VOLUME) / 2, 2))) {
                        double sl = PositionGetDouble(POSITION_PRICE_OPEN);
                        sl = NormalizeDouble(sl, _Digits);
                        if (trade.PositionModify(posTicket, sl, 0)) {}
                     }
                  }
               } else {
                  int lowest = iLowest(_Symbol, PERIOD_M5, MODE_LOW, 3, 1);
                  double sl = PositionGetDouble(POSITION_PRICE_OPEN);
                  sl = NormalizeDouble(sl, _Digits);
                  if (trade.PositionModify(posTicket, sl, 0)) {}
               }
            }
         }
      }
   }

   int orders = 0;

   for (int i = OrdersTotal() - 1; i >= 0; i--) {
      ulong orderTicket = OrderGetTicket(i);
      if (OrderSelect(orderTicket)) {
         if (OrderGetString(ORDER_SYMBOL) == _Symbol && OrderGetInteger(ORDER_MAGIC) == eaMagic) {
            if (OrderGetInteger(ORDER_TIME_SETUP) < TimeCurrent() - 30 * PeriodSeconds(PERIOD_M1)) {
               trade.OrderDelete(orderTicket);

            }
            orders = orders + 1;
         }
      }
   }
   
   if (trendDirection == 1 ) {
      if(maFast[0] > maMiddle[0] && maMiddle[0] > maSlow[0]) {
         if(bid <= maFast[0]) {
            if(positions + orders <= 0) {
            int indexHighest = iHighest(_Symbol,PERIOD_M5, MODE_HIGH, 5,1);
            double highPrice = iHigh(_Symbol, PERIOD_M5, indexHighest);
            highPrice = NormalizeDouble(highPrice,_Digits);
            
            double sl = iLow(_Symbol,PERIOD_M5,0) - 30 * _Point;
            sl = NormalizeDouble(sl,_Digits);
            
            trade.BuyStop(eaLots, highPrice, _Symbol, sl);
            
            }
         }
      }
   
   } else if (trendDirection == -1 ) {
      if(maFast[0]<maMiddle[0] && maMiddle[0] < maSlow[0]) {
         if (bid >=maFast[0]) {
            if (positions + orders <= 0) {
                int indexLowest = iLowest(_Symbol,PERIOD_M5, MODE_LOW,5,1);
                double lowestPrice = iLow(_Symbol,PERIOD_M5, indexLowest);
                
                double sl = iHigh(_Symbol, PERIOD_M5,0) + 30 * _Point;
                sl = NormalizeDouble(sl,_Digits);
                
                trade.SellStop(eaLots,lowestPrice,_Symbol,sl);
            
            }
         }
      }
   }
   
   Comment("\nFast Trend Ma: ",DoubleToString(maTrendFast[0],_Digits),
   "\nSlow Trend Ma: ",DoubleToString(maTrendSlow[0],_Digits),
   "\nTrend direction: ",trendDirection,
   "\n",
   "\nFast Ma: ",DoubleToString(maFast[0],_Digits),
   "\nMid Ma: ",DoubleToString(maMiddle[0],_Digits),
   "\nSlow Ma: ",DoubleToString(maSlow[0],_Digits),
    "\n",
    "\nPositions: ", positions,
    "\nOrders: ", orders
    );
}