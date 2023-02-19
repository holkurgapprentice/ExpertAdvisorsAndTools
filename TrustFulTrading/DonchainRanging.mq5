//+------------------------------------------------------------------+
//|                                              DonchainRanging.mq5 |
//|                                  Copyright 2022, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2022, MetaQuotes Ltd."
#property link "https://www.mql5.com"
#property version "1.00"

#include <Trade\Trade.mqh>

#define INDICATOR_NAME "Trustful_Donchain"

input group "==== General ====";
static input long InpMagicNumber = 654654;
static input double InpLotSize = 0.01;
enum SL_TP_MODE_ENUM {
  SL_TP_MODE_PCT,
  SL_TP_MODE_POINTS
};
input SL_TP_MODE_ENUM InpSLTPMode = SL_TP_MODE_PCT;
input int InpStopLoss = 200;
input int InpTakeProfit = 100;
input bool InpCloseSignal = false;

input group "==== Donchain channel ====";
input int InpPeroid = 21;
input int InpOffset = 0;
input color InpColor = clrBlue;
input int InpSizeFilter = 0;



int handle;
double bufferUpper[];
double bufferLower[];
MqlTick currentTick;
CTrade trade;
datetime openTimeBuy = 0;
datetime openTimeSell = 0;

int OnInit() {
  if (InpMagicNumber <= 0) {
    Alert("InpMagicNumber <= 0");
    return INIT_PARAMETERS_INCORRECT;
  }

  if (InpLotSize <= 0 || InpLotSize > 10) {
    Alert("InpLotSize <= 0 || InpLotSize > 10");
    return INIT_PARAMETERS_INCORRECT;
  }

  if (InpStopLoss < 0) {
    Alert("InpStopLoss < 0");
    return INIT_PARAMETERS_INCORRECT;
  }

  if (InpStopLoss == 0 && !InpCloseSignal) {
    Alert("No stop loss and no close signal");
    return INIT_PARAMETERS_INCORRECT;
  }

  if (InpPeroid <= 1) {
    Alert("Donchain peroid <= 1");
    return INIT_PARAMETERS_INCORRECT;
  }

  if (InpOffset < 0 || InpOffset >= 50) {
    Alert("InpOffset < 0 || InpOffset >= 50");
    return INIT_PARAMETERS_INCORRECT;
  }

  trade.SetExpertMagicNumber(InpMagicNumber);

  handle = iCustom(_Symbol, PERIOD_CURRENT, INDICATOR_NAME, InpPeroid, InpOffset, InpColor);
  if (handle == INVALID_HANDLE) {
    Alert("Init of indicator failed");
    return INIT_FAILED;
  }

  ArraySetAsSeries(bufferUpper, true);
  ArraySetAsSeries(bufferLower, true);

  ChartIndicatorDelete(NULL, 0, "Donchain(" + IntegerToString(InpPeroid) + ")");
  ChartIndicatorAdd(NULL, 0, handle);

  return (INIT_SUCCEEDED);
}
void OnDeinit(const int reason) {

  if (handle != INVALID_HANDLE) {
    ChartIndicatorDelete(NULL, 0, "Donchain(" + IntegerToString(InpPeroid) + ")");
    IndicatorRelease(handle);
  }

}

void OnTick() {

  if (!IsNewBar()) {
    return;
  }
  
  if(!SymbolInfoTick(_Symbol, currentTick)) {
    Print("Failed to get current tick");
    return;
  }

  int values = CopyBuffer(handle, 0, 0, 1, bufferUpper) + CopyBuffer(handle, 1, 0, 1, bufferLower);
  if (values!=2) {
    Print("Failed to get indicator values");
    return;
  }
  
  Comment("bufferUpper[0]: ", bufferUpper[0], 
         "bufferLower[0]:", bufferLower[0]);
         
  int cntBuy, cntSell;
  if (!CountOpenPositions(cntBuy, cntSell)) {
    return;
  }
  
  if (InpSizeFilter > 0 && (bufferUpper[0] - bufferLower[0])<InpSizeFilter * _Point) {
    Print("Filtered out by size filter");
    return;
  }
  
  if (cntBuy == 0 && currentTick.ask <= bufferLower[0] && openTimeBuy!=iTime(_Symbol, PERIOD_CURRENT,0)) {
    openTimeBuy = iTime(_Symbol, PERIOD_CURRENT,0);
    if (InpCloseSignal) {
      if (!ClosePositions(2)) {
        return;
      }
    }
    
    double sl = 0;
    double tp = 0;
    
    if(InpSLTPMode==SL_TP_MODE_PCT) {
      sl = InpStopLoss ==0 ? 0 : currentTick.bid - (bufferUpper[0]-bufferLower[0]) * InpStopLoss * 0.01;
      tp = InpTakeProfit ==0 ? 0 : currentTick.bid + (bufferUpper[0]-bufferLower[0]) * InpTakeProfit * 0.01;
    }
    if(InpSLTPMode==SL_TP_MODE_POINTS) { 
      sl = InpStopLoss ==0 ? 0 : currentTick.bid - InpStopLoss * _Point;
      tp = InpTakeProfit ==0 ? 0 : currentTick.bid + InpTakeProfit * _Point;
    }
    
    if (!NormalizePrice(sl)) {
      return;
    }
    if (!NormalizePrice(tp)) {
      return;
    }
    trade.PositionOpen(_Symbol,ORDER_TYPE_BUY,InpLotSize,currentTick.ask,sl,tp,"Donchain trade");
  }
  
  if (cntSell == 0 && currentTick.bid >= bufferUpper[0] && openTimeBuy!=iTime(_Symbol, PERIOD_CURRENT,0)) {
    openTimeSell = iTime(_Symbol, PERIOD_CURRENT,0);
    if (InpCloseSignal) {
      if (!ClosePositions(1)) {
        return;
      }
    }
    
    double sl = 0;
    double tp = 0;
    
    if(InpSLTPMode==SL_TP_MODE_PCT) {
      sl = InpStopLoss ==0 ? 0 : currentTick.ask + (bufferUpper[0]-bufferLower[0]) * InpStopLoss * 0.01;
      tp = InpTakeProfit ==0 ? 0 : currentTick.ask - (bufferUpper[0]-bufferLower[0]) * InpTakeProfit * 0.01;
    }
    if(InpSLTPMode==SL_TP_MODE_POINTS) { 
      sl = InpStopLoss ==0 ? 0 : currentTick.ask + InpStopLoss * _Point;
      tp = InpTakeProfit ==0 ? 0 : currentTick.ask - InpTakeProfit * _Point;
    }
    
    if (!NormalizePrice(sl)) {
      return;
    }
    if (!NormalizePrice(tp)) {
      return;
    }
    trade.PositionOpen(_Symbol,ORDER_TYPE_SELL,InpLotSize,currentTick.bid,sl,tp,"Donchain trade");
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

bool NormalizePrice(double &normalizedPrice) {
  double tickSize = 0;
  if (!SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE, tickSize)) {
    Print("Failed to get tick size");
    return false;
  }
  normalizedPrice = NormalizeDouble(MathRound(normalizedPrice / tickSize) * tickSize, _Digits);

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