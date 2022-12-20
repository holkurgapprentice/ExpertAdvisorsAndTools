#include <Trade/Trade.mqh>

input double Lots = 0.1;
input double LotsFactor = 1.3;
input int IncreasePoints = 1000;

CTrade trade;

int handleDc;
ulong posTicket;

double lostMoney;
int lostPoints;

int OnInit() {

   handleDc = iCustom(_Symbol, PERIOD_CURRENT, "DonchianChannel.ex5", 20);

   return (INIT_SUCCEEDED);
}

void OnDeinit(const int reason) {

}

void OnTick() {

   double dcUpper[];
   double dcLower[];
   CopyBuffer(handleDc, 0, 0, 1, dcUpper);
   CopyBuffer(handleDc, 1, 0, 1, dcLower);

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   if (bid >= dcUpper[0]) {
      //Print(__FUNCTION__, " > Buy signal...");

      if (posTicket > 0) {
         if (PositionSelectByTicket(posTicket)) {
            if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL) {
               if (trade.PositionClose(posTicket)) {
                  updateLostPoints();
                  posTicket = 0;
               }
            }
         }
      }

      if (posTicket <= 0) {
         int increaseFactor = MathAbs(lostPoints / IncreasePoints);
         double lots = Lots * MathPow(LotsFactor, increaseFactor);
         lots = NormalizeDouble(lots, 2);

         if (trade.Buy(lots)) {
            posTicket = trade.ResultOrder();
         }
      }
   } else if (bid <= dcLower[0]) {
      //Print(__FUNCTION__, " > Sell signal...");

      if (posTicket > 0) {
         if (PositionSelectByTicket(posTicket)) {
            if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
               if (trade.PositionClose(posTicket)) {
                  updateLostPoints();
                  posTicket = 0;
               }
            }
         }
      }

      if (posTicket <= 0) {
         int increaseFactor = MathAbs(lostPoints / IncreasePoints);
         double lots = Lots * MathPow(LotsFactor, increaseFactor);
         lots = NormalizeDouble(lots, 2);

         if (trade.Sell(lots)) {
            posTicket = trade.ResultOrder();
         }
      }
   }

   Comment("\nPosition Ticket: ", posTicket,
      "\nLost Points: ", lostPoints,
      "\nLost Money: ", DoubleToString(lostMoney, 2));
}

void updateLostPoints() {
   int posDirection = 0;
   double posVolume = 0;
   double posProfit = 0;
   double openPrice = 0;
   double closePrice = 0;
   if (HistorySelectByPosition(posTicket)) {
      for (int i = HistoryDealsTotal() - 1; i >= 0; i--) {
         ulong dealTicket = HistoryDealGetTicket(i);
         if (HistoryDealSelect(dealTicket)) {
            if (HistoryDealGetInteger(dealTicket, DEAL_ENTRY) == DEAL_ENTRY_IN) {
               openPrice = HistoryDealGetDouble(dealTicket, DEAL_PRICE);
               posVolume = HistoryDealGetDouble(dealTicket, DEAL_VOLUME);
               posProfit += HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
               if (HistoryDealGetInteger(dealTicket, DEAL_TYPE) == DEAL_TYPE_BUY) {
                  posDirection = 1;
               } else if (HistoryDealGetInteger(dealTicket, DEAL_TYPE) == DEAL_TYPE_SELL) {
                  posDirection = -1;
               }
            } else if (HistoryDealGetInteger(dealTicket, DEAL_ENTRY) == DEAL_ENTRY_OUT) {
               closePrice = HistoryDealGetDouble(dealTicket, DEAL_PRICE);
               posProfit += HistoryDealGetDouble(dealTicket, DEAL_PROFIT) + HistoryDealGetDouble(dealTicket, DEAL_SWAP) + HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
            }
         }
      }
   }

   if (openPrice > 0 && closePrice > 0) {
      if (posDirection == 1) {
         lostPoints += (int)((closePrice - openPrice) / _Point);
      } else if (posDirection == -1) {
         lostPoints += (int)((openPrice - closePrice) / _Point);
      }
   }
   lostMoney += posProfit;
   if (lostMoney >= 0) {
      lostMoney = 0;
      lostPoints = 0;
   }
}