//+------------------------------------------------------------------+
//|                                             ScalpingBreakout.mq5 |
//|                                  Copyright 2022, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2022, MetaQuotes Ltd."
#property link "https://www.mql5.com"
#property version "1.00"

#include <Trade\Trade.mqh>


input group "==== General ====";
static input long InpMagicNumber = 241131;
input double InpLots = 0.01;
input int InpBars = 20;
input int InpIndexFilter = 0; // Index filer percents from 0 to 50
input int InpSizeFilter = 0; // Size filter in points 0 to resonable point value
input int InpStopLoss = 0;
input bool InpTrailingSl = true;
input int InpTakeProfit = 0;


double high = 0;
double low = 0;
int highIdx = 0;
int lowIdx = 0;
MqlTick currentTick, previousTick;
CTrade trade;


int OnInit() {

  if (!CheckInputs()) {
  
    if (InpMagicNumber<=0) {
      Print("Wrong input magic number");
      return false;
    }
    
    if (InpLots<=0) {
      Print("Wrong input lot size <= 0");
      return false;
    }
    
    if (InpBars<=0) {
      Print("Wrong input InpBars<=0");
      return false;
    }
    
    if (InpIndexFilter<0 || InpIndexFilter >= 50) {
      Print("Wrong input InpIndexFilter<0 || InpIndexFilter >= 50");
      return false;
    }
    
    if (InpSizeFilter<0) {
      Print("Wrong input InpSizeFilter<0");
      return false;
    }
    
    if (InpStopLoss<0) {
      Print("Wrong input InpStopLoss<0");
      return false;
    }
    
    if (InpTakeProfit<0) {
      Print("Wrong input InpTakeProfit<0");
      return false;
    }
  
    return INIT_PARAMETERS_INCORRECT;
  }

  trade.SetExpertMagicNumber(InpMagicNumber);

  return (INIT_SUCCEEDED);
}


void OnDeinit(const int reason) {

  ObjectDelete(NULL, "high");
  ObjectDelete(NULL, "low");
  ObjectDelete(NULL, "text");
  ObjectDelete(NULL, "indexFilter");
}


void OnTick() {

  if (!IsNewBar()) {
    return;
  }

  previousTick = currentTick;
  if (!SymbolInfoTick(_Symbol, currentTick)) {
    Print("Failed to get current tick");
    return;
  }

  int cntBuy, cntSell;
  if (!CountOpenPositions(cntBuy, cntSell)) {
    return;
  }

  if (cntBuy == 0 && high != 0 && previousTick.ask < high && currentTick.ask >= high && CheckIndexFilter(highIdx) && CheckSizeFilter()) {
    double sl = 0;
    double tp = 0;

    sl = InpStopLoss == 0 ? 0 : currentTick.bid - InpStopLoss * _Point;
    tp = InpTakeProfit == 0 ? 0 : currentTick.bid + InpTakeProfit * _Point;

    if (!NormalizePrice(sl)) {
      return;
    }
    if (!NormalizePrice(tp)) {
      return;
    }
    trade.PositionOpen(_Symbol, ORDER_TYPE_BUY, InpLots, currentTick.ask, sl, tp, "Sclaping Breakout trade");
  }

  if (cntSell == 0 && low != 0 && previousTick.bid > low && currentTick.bid <= low && CheckIndexFilter(highIdx) && CheckSizeFilter()) {
    double sl = 0;
    double tp = 0;

    sl = InpStopLoss == 0 ? 0 : currentTick.ask + InpStopLoss * _Point;
    tp = InpTakeProfit == 0 ? 0 : currentTick.ask - InpTakeProfit * _Point;

    if (!NormalizePrice(sl)) {
      return;
    }
    if (!NormalizePrice(tp)) {
      return;
    }
    trade.PositionOpen(_Symbol, ORDER_TYPE_SELL, InpLots, currentTick.bid, sl, tp, "Sclaping Breakout trade");
  }

  if (InpStopLoss > 0 && InpTrailingSl) {
    UpdateStopLoss(InpStopLoss * _Point);
  }

  highIdx = iHighest(_Symbol, PERIOD_CURRENT, MODE_HIGH, InpBars, 1);
  lowIdx = iLowest(_Symbol, PERIOD_CURRENT, MODE_LOW, InpBars, 1);
  high = iHigh(_Symbol, PERIOD_CURRENT, highIdx);
  low = iLow(_Symbol, PERIOD_CURRENT, lowIdx);

  DrawObjects();
}


bool CheckInputs() {

  return true;
}


bool CheckIndexFilter(int index) {

  if (InpIndexFilter > 0 && (index <= round(InpBars * InpIndexFilter * 0.01) || index > InpBars - round(InpBars * InpIndexFilter * 0.01))) {
    return false;
  }
  return true;
}


bool CheckSizeFilter() {

  if (InpSizeFilter > 0 && (high - low) > InpSizeFilter * _Point) {
    return false;
  }
  return true;
}


void DrawObjects() {

  datetime time1 = iTime(_Symbol, PERIOD_CURRENT, InpBars);
  datetime time2 = iTime(_Symbol, PERIOD_CURRENT, 1);

  //high
  ObjectDelete(NULL, "high");
  ObjectCreate(NULL, "high", OBJ_TREND, 0, time1, high, time2, high);
  ObjectSetInteger(NULL, "high", OBJPROP_WIDTH, 3);
  ObjectSetInteger(NULL, "high", OBJPROP_COLOR, CheckIndexFilter(highIdx) && CheckSizeFilter() ? clrGreen : clrBlack);

  //low
  ObjectDelete(NULL, "low");
  ObjectCreate(NULL, "low", OBJ_TREND, 0, time1, low, time2, low);
  ObjectSetInteger(NULL, "low", OBJPROP_WIDTH, 3);
  ObjectSetInteger(NULL, "low", OBJPROP_COLOR, CheckIndexFilter(lowIdx) && CheckSizeFilter() ? clrGreen : clrBlack);

  //index filter
  ObjectDelete(NULL, "indexFilter");
  if (InpIndexFilter > 0) {
    datetime timeIF1 = iTime(_Symbol, PERIOD_CURRENT, (int)(InpBars - round(InpBars * InpIndexFilter * 0.01)));
    datetime timeIF2 = iTime(_Symbol, PERIOD_CURRENT, (int)(round(InpBars * InpIndexFilter * 0.01)));
    ObjectDelete(NULL, "indexFilter");
    ObjectCreate(NULL, "indexFilter", OBJ_RECTANGLE, 0, timeIF1, low, timeIF2, high);
    ObjectSetInteger(NULL, "indexFilter", OBJPROP_BACK, true);
    ObjectSetInteger(NULL, "indexFilter", OBJPROP_FILL, true);
    ObjectSetInteger(NULL, "indexFilter", OBJPROP_COLOR, clrMintCream);
  }

  //text
  ObjectDelete(NULL, "text");
  ObjectCreate(NULL, "text", OBJ_TEXT, 0, time2, low);
  ObjectSetInteger(NULL, "text", OBJPROP_ANCHOR, ANCHOR_RIGHT_UPPER);
  ObjectSetInteger(NULL, "text", OBJPROP_COLOR, clrBlack);
  ObjectSetString(NULL, "text", OBJPROP_TEXT, "Bars: " + (string) InpBars +
    " index filter: " + DoubleToString(round(InpBars * InpIndexFilter * 0.01), 0) +
    " high index: " + (string) highIdx +
    " low index: " + (string) lowIdx +
    " size: " + DoubleToString((high - low) / _Point, 0));
}


void UpdateStopLoss(double slDistance) {

  int total = PositionsTotal();
  for (int i = total - 1; i >= 0; i--) {
    ulong ticket = PositionGetTicket(i);

    if (ticket <= 0) {
      Print("Failed to get ticket");
      return;
    }

    if (!PositionSelectByTicket(ticket)) {
      Print("Failed to PositionSelectByTicket");
      return;
    }

    long magic;

    if (!PositionGetInteger(POSITION_MAGIC, magic)) {
      Print("Failed to get magic");
      return;
    }

    if (magic == InpMagicNumber) {
      long type;
      if (!PositionGetInteger(POSITION_TYPE, type)) {
        Print("Failed to get type");
        return;
      }

      double currSL, currTP;

      if (!PositionGetDouble(POSITION_SL, currSL)) {
        Print("Failed to get current SL");
        return;
      }

      if (!PositionGetDouble(POSITION_TP, currTP)) {
        Print("Failed to get current TP");
        return;
      }

      double currPrice = type == POSITION_TYPE_BUY ? currentTick.bid : currentTick.ask;
      int n = type == POSITION_TYPE_BUY ? 1 : -1;
      double newSL = currPrice - slDistance * n;

      if (!NormalizePrice(newSL)) {
        Print("Failed to normalize price");
        return;
      }

      if ((newSL * n) < (currSL * n) || NormalizeDouble(MathAbs(newSL - currSL), _Digits) < _Point) {
        continue;
      }

      long level = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);

      if (level != 0 && MathAbs(currPrice - newSL) < level * _Point) {
        Print("New SL lower than minimal stop level");
        return;
      }

      if (!trade.PositionModify(ticket, newSL, currTP)) {
        Print("Failed to set new SL for position:" + (string) ticket +
          " currSL: " + (string) currSL + " newSL: " + (string) newSL +
          " currTP: " + (string) currTP);
        return;
      }

    }
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