//+------------------------------------------------------------------+
//|                                                      ProjectName |
//|                                      Copyright 2020, CompanyName |
//|                                       http://www.companyname.net |
//+------------------------------------------------------------------+
#property copyright "MF"
#property version "0.6"

#include <Trade\Trade.mqh>

static input long InpMagicnumber = 546812;
input double InpLotSize = 0.01;
input int InpRSIPeriod = 21;
input int InpRSILevel = 70;
input int InpMAPeriod = 21;
input ENUM_TIMEFRAMES InpMATimeFrame = PERIOD_H1;

input int InpStopLoss = 200;
input int InpTakeProfit = 200;
input bool InpCloseSignal = false; // close by opposite

int handleRSI;
int handleMA;
double bufferRSI[];
double bufferMA[];
MqlTick currentTick;
CTrade trade;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnInit()
  {

   if(InpMagicnumber <= 0)
     {
      Alert("Magic number  <= 0");
      return INIT_PARAMETERS_INCORRECT;
     }
   if(InpLotSize <= 0 || InpLotSize > 10)
     {
      Alert("InpLotSize <= 0 || InpLotSize > 10");
      return INIT_PARAMETERS_INCORRECT;
     }
   if(InpRSIPeriod <= 1)
     {
      Alert("InpRSIPeriod <= 1");
      return INIT_PARAMETERS_INCORRECT;
     }
   if(InpRSILevel >= 100 || InpRSILevel <=50)
     {
      Alert("InpRSILevel >= 100 || InpRSILevel <=50");
      return INIT_PARAMETERS_INCORRECT;
     }
   if(InpMAPeriod <= 1)
     {
      Alert("InpMAPeriod <= 1");
      return INIT_PARAMETERS_INCORRECT;
     }
   if(InpStopLoss<0)
     {
      Alert("InpStopLoss<0");
      return INIT_PARAMETERS_INCORRECT;
     }
   if(InpTakeProfit<0)
     {
      Alert("InpTakeProfit<0");
      return INIT_PARAMETERS_INCORRECT;
     }

   trade.SetExpertMagicNumber(InpMagicnumber);

   handleRSI = iRSI(_Symbol, PERIOD_CURRENT, InpRSIPeriod, PRICE_OPEN);
   if(handleRSI == INVALID_HANDLE)
     {
      Alert("handleRSI == INVALID_HANDLE");
      return INIT_FAILED;
     }

   handleMA = iMA(_Symbol, InpMATimeFrame, InpMAPeriod, 0, MODE_SMA, PRICE_OPEN);
   if(handleMA == INVALID_HANDLE)
     {
      Alert("handleMA == INVALID_HANDLE");
      return INIT_FAILED;
     }

   ArraySetAsSeries(bufferRSI, true);
   ArraySetAsSeries(bufferMA, true);
   return (INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(handleRSI!=INVALID_HANDLE)
     {
      IndicatorRelease(handleRSI);
     }
   if(handleMA!=INVALID_HANDLE)
     {
      IndicatorRelease(handleMA);
     }
  }
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick()
  {
   if(!IsNewBar())
     {
      return;
     }

   if(!SymbolInfoTick(_Symbol, currentTick))
     {
      Print("Failed to get current tick");
      return;
     }

   int values = CopyBuffer(handleRSI,0,0,2,bufferRSI);
   if(values!=2)
     {
      Print("Failed to get rsi values");
      return;
     }

   values = CopyBuffer(handleMA,0,0,1,bufferMA);
   if(values != 1)
     {
      Print("Failed to get ma value");
      return;
     }

   Comment("bufferRsi[0]", bufferRSI[0],
           "\nbufferRSI[1]", bufferRSI[1],
           "\nbufferMA[0]", bufferMA[0]);

   int cntBuy, cntSell;
   if(!CountOpenPositions(cntBuy, cntSell))
     {
      return;
     }

   if(cntBuy == 0 && bufferRSI[1] >= (100-InpRSILevel) && bufferRSI[0]<(100-InpRSILevel) && currentTick.ask > bufferMA[0])
     {
      if(InpCloseSignal)
        {
         if(!ClosePositions(2))
           {
            return;
           }
        }

      double sl = InpStopLoss == 0? 0 : currentTick.bid - InpStopLoss * _Point;
      double tp = InpTakeProfit == 0 ? 0 : currentTick.bid + InpTakeProfit * _Point;

      if(!NormalizePrice(sl))
        {
         return;
        }
      if(!NormalizePrice(tp))
        {
         return;
        }

      trade.PositionOpen(_Symbol, ORDER_TYPE_BUY, InpLotSize, currentTick.ask, sl, tp, "RSI MA FILTER EA");
     }

   if(cntSell == 0 && bufferRSI[1] <= InpRSILevel && bufferRSI[0]>InpRSILevel && currentTick.bid < bufferMA[0])
     {
      if(InpCloseSignal)
        {
         if(!ClosePositions(1))
           {
            return;
           }
        }

      double sl = InpStopLoss == 0? 0 : currentTick.ask + InpStopLoss * _Point;
      double tp = InpTakeProfit == 0 ? 0 : currentTick.ask - InpTakeProfit * _Point;

      if(!NormalizePrice(sl))
        {
         return;
        }
      if(!NormalizePrice(tp))
        {
         return;
        }

      trade.PositionOpen(_Symbol, ORDER_TYPE_SELL, InpLotSize, currentTick.bid, sl, tp, "RSI MA FILTER EA");
     }

  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsNewBar()
  {
   static datetime previousTime = 0;
   datetime currentTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(previousTime!=currentTime)
     {
      previousTime = currentTime;
      return true;
     }
   return false;
  }
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CountOpenPositions(int &cntBuy, int &cntSell)
  {
   cntBuy =0;
   cntSell =0;
   int total = PositionsTotal();
   for(int i =total -1; i>0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0)
        {
         Print("Failed to get ticket");
         return false;
        }
      if(!PositionSelectByTicket(ticket))
        {
         Print("failed to select position by ticket");
         return false;
        }
      long magic;
      if(!PositionGetInteger(POSITION_MAGIC,magic))
        {
         Print("Failed to get position magic");
         return false;
        }
      if(magic==InpMagicnumber)
        {
         long type;
         if(!PositionGetInteger(POSITION_TYPE,type))
           {
            Print("failed to get position type");
            return false;
           }
         if(type == POSITION_TYPE_BUY)
           {
            cntBuy++;
           }
         if(type == POSITION_TYPE_SELL)
           {
            cntSell++;
           }
        }
     }
   return true;
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool ClosePositions(int all_buy_sell)
  {
   int total = PositionsTotal();
   for(int i =total -1; i>0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0)
        {
         Print("Failed to get ticket");
         return false;
        }
      if(!PositionSelectByTicket(ticket))
        {
         Print("failed to select position by ticket");
         return false;
        }
      long magic;
      if(!PositionGetInteger(POSITION_MAGIC,magic))
        {
         Print("Failed to get position magic");
         return false;
        }
      if(magic==InpMagicnumber)
        {
         long type;
         if(!PositionGetInteger(POSITION_TYPE,type))
           {
            Print("failed to get position type");
            return false;
           }
         if(all_buy_sell ==1 && type == POSITION_TYPE_SELL)
           {
            continue;
           }
         if(all_buy_sell ==1 && type == POSITION_TYPE_BUY)
           {
            continue;
           }
         trade.PositionClose(ticket);
         if(trade.ResultRetcode()!=TRADE_RETCODE_DONE)
           {
            Print("failed to close position ticket", (string) ticket,
                  "result", (string) trade.ResultRetcode(), ":", trade.CheckResultRetcodeDescription());
           }
        }
     }
   return true;
  }
//+------------------------------------------------------------------+
bool NormalizePrice(double &inputPrice)
  {
   double tickSize =0;
   if(!SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE,tickSize))
     {
      Print("Failed to get tick size");
      return false;
     }
   inputPrice = NormalizeDouble(MathRound(inputPrice/tickSize)*tickSize,_Digits);

   return true;
  }
//+------------------------------------------------------------------+
