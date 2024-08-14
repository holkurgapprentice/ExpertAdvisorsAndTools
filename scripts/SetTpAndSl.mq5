//+------------------------------------------------------------------+
//|                                                   SetTpAndSl.mq5 |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Trade\Trade.mqh>
CTrade c_trade;

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
   string mainSymbol = Symbol();
   Print("symbol ", (string)mainSymbol);

   double mainTpPrice = 0, mainEntryPrice = 0, tpPrice = 0, entryPrice = 0, slPrice = 0, calcSl = 0, stopLimitPrice = 0;
   long mainType = 0, expiration = 0, type = 0;
   int tpsSet = 0;
   string symbol;

// find direction and tp
   for(int i=PositionsTotal()-1; i>=0; --i)
     {
      ulong ticket=PositionGetTicket(i);
      if(PositionGetSymbol(i)==mainSymbol)
        {

         if(!PositionGetDouble(POSITION_TP, tpPrice) || tpPrice <= 0)
           {
            continue;
           }

         tpsSet++;

         if(!PositionGetInteger(POSITION_TYPE, type))
           {
            Print("Failed to get type");
            continue;
           }

         if(!PositionGetDouble(POSITION_PRICE_OPEN, entryPrice))
           {
            continue;
           }

         if(tpsSet == 1)
           {
            Print("Found tp ", (string) tpPrice);
            mainTpPrice = tpPrice;
            mainEntryPrice = entryPrice;
            mainType = type;
            if(mainType == 0)
              {
               calcSl = mainEntryPrice - (mainTpPrice - mainEntryPrice);
              }
            if(mainType == 1)
              {
               calcSl = mainEntryPrice + (mainEntryPrice - mainTpPrice);
              }
           }


         if(tpsSet > 1)
           {
            // 0 - buy
            if(mainType == 0 && mainTpPrice < tpPrice)
              {
               mainTpPrice = tpPrice;
               mainEntryPrice = entryPrice;
               mainType = type;
               calcSl = mainEntryPrice - (mainTpPrice - mainEntryPrice);
               Print("Better price found");

              }
            // 1 - sell
            if(mainType == 1 && mainTpPrice > tpPrice)
              {
               mainTpPrice = tpPrice;
               mainEntryPrice = entryPrice;
               mainType = type;
               calcSl = mainEntryPrice + (mainEntryPrice - mainTpPrice);
               Print("Better price found");
              }
           }

         Print("tp ", (string)mainTpPrice);
         Print("entry  ", (string)mainEntryPrice);
         Print("tps set  ", (string)tpsSet);
        }
     }

   if(mainTpPrice == 0)
     {
      Alert("No tp found");
      return;
     }

// modify sl and tp positions
   for(int i=PositionsTotal()-1; i>=0; --i)
     {
      Print("Position number ", (string)i);
      ulong ticket=PositionGetTicket(i);
      if(!PositionGetInteger(POSITION_TYPE, type))
        {
         Print("Failed to get type");
         continue;
        }

      if(mainType != type)
        {
         Print("Wrong type");
         continue;
        }


      if(PositionGetSymbol(i) != mainSymbol)
        {
         Print("Wrong symbol skipping ", (string) PositionGetSymbol(i));
         continue;
        }

      if(!PositionGetDouble(POSITION_SL, slPrice))
        {

         Print("Sl reading error");
         continue;
        }

      if(slPrice!=0)
        {
         if(mainType == 0 && slPrice < calcSl)
           {
            slPrice = calcSl;
           }
         if(mainType == 1 && slPrice > calcSl)
           {
            slPrice = calcSl;
           }
        }

      if(slPrice == 0)
        {
         slPrice = calcSl;
        }

      Print("Setting position sl tp");
      c_trade.PositionModify(ticket,slPrice,mainTpPrice);
     }

// MODIFY SL AND TP orders
   for(int i=OrdersTotal()-1; i>=0; --i)
     {

      Print("Order number ", (string)i);
      ulong ticket=OrderGetTicket(i);
      if(!OrderGetInteger(ORDER_TYPE, type))
        {
         Print("Failed to get type");
         continue;
        }

      if(mainType == POSITION_TYPE_BUY && (type != ORDER_TYPE_BUY_LIMIT && type != ORDER_TYPE_BUY_STOP))
        {
         Print("Wrong type ", (string)type);
         continue;
        }

      if(mainType == POSITION_TYPE_SELL && (type != ORDER_TYPE_SELL_LIMIT && type != ORDER_TYPE_SELL_STOP))
        {
         Print("Wrong type ", (string)type);
         continue;
        }

      if(!OrderGetDouble(ORDER_SL, slPrice))
        {
         Print("Sl reading error");
         continue;
        }

      if(!OrderGetDouble(ORDER_PRICE_OPEN, entryPrice))
        {
         Print("Price open reading error");
         continue;
        }

      if(!OrderGetString(ORDER_SYMBOL, symbol))
        {
         Print("Symbol reading error");
         continue;
        }

      if(symbol != mainSymbol)
        {
         Print("Wrong symbol skipping ", (string) symbol);
         continue;
        }


      if(slPrice!=0)
        {

         if(mainType == 0 && slPrice < calcSl)
           {
            slPrice = calcSl;
           }
         if(mainType == 1 && slPrice > calcSl)
           {
            slPrice = calcSl;
           }
        }

      if(slPrice == 0)
        {
         slPrice = calcSl;
        }

      if(!OrderGetInteger(ORDER_TIME_EXPIRATION, expiration))
        {
         Print("Expiration reading error");
         continue;
        }

      if(!OrderGetDouble(ORDER_PRICE_STOPLIMIT, stopLimitPrice))
        {
         Print("pric stoplimit reading error");
         continue;
        }

      Print("Setting order sl tp");
      c_trade.OrderModify(ticket,entryPrice,slPrice,mainTpPrice,ORDER_TIME_GTC,expiration,stopLimitPrice);
     }
  }
//+------------------------------------------------------------------+
