//+------------------------------------------------------------------+
//|                                               BollingerBands.mq5 |
//|                                  Copyright 2022, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2022, MetaQuotes Ltd."
#property link "https://www.mql5.com"
#property version "1.00"

#include <Trade\Trade.mqh>

input group "===General input==="
static input long InpMagicNumber = 830766;
enum LOT_MODE_ENUM {
  LOT_MODE_FIXED,
  LOT_MODE_MONEY,
  LOT_MODE_PCT_ACCOUNT
};
input LOT_MODE_ENUM InpLotMode = LOT_MODE_FIXED;
input double InpLots = 0.01;

enum STOP_LOSS_ENUM {
  NEGATIVE_END_CHANNEL,
  HALF_CHANNEL,
  VALUE
};
input STOP_LOSS_ENUM InpStopLossMode = VALUE;
input int InpStopLoss = 150;
input int InpTakeProfit = 200;

input group "===Range inputs==="
input int InpRangeStart = 600; // Time for open range in minutes from 0:00 (600 min = 10:00)
input int InpRangeDuration = 120; // Time for range in minutes
input int InpRangeClose = 1200; // Time for close positions in minutes from 0:00 (1200 min = 20:00)

enum BREAKOUT_MODE_ENUM {
  ONE_SIGNAL,
  TWO_SIGNALS
};
input BREAKOUT_MODE_ENUM InpBreakoutMode = ONE_SIGNAL;

input group "===Day of week filter==="
input bool InpMonday = true;
input bool InpTuesday = true;
input bool InpWednesday = true;
input bool InpThursday = true;
input bool InpFriday = true;

struct RANGE_STRUCT {
  datetime start_time;
  datetime end_time;
  datetime close_time;
  double high;
  double low;
  bool f_entry;
  bool f_high_breakout;
  bool f_low_breakout;

  RANGE_STRUCT(): start_time(0),
    end_time(0),
    close_time(9),
    high(0),
    low(DBL_MAX),
    f_entry(false),
    f_high_breakout(false),
    f_low_breakout(false) {};
};
RANGE_STRUCT range;
MqlTick prevTick, lastTick;
CTrade trade;


int OnInit() {

  if (!CheckInputs()) {
    return INIT_PARAMETERS_INCORRECT;
  }

  trade.SetExpertMagicNumber(InpMagicNumber);

  if (_UninitReason == REASON_PARAMETERS && CountOpenPositons() == 0) {
    CalculateRange();
  }

  DrawObjects();

  return (INIT_SUCCEEDED);
}


void OnDeinit(const int reason) {

  ObjectDelete(NULL, "range");
}


void OnTick() {

  prevTick = lastTick;
  SymbolInfoTick(_Symbol, lastTick);

  // range calculation
  if (lastTick.time >= range.start_time && lastTick.time < range.end_time) {
    // set flag
    range.f_entry = true;

    // new high
    if (lastTick.ask > range.high) {
      range.high = lastTick.ask;
      DrawObjects();
    }

    // new low
    if (lastTick.bid < range.low) {
      range.low = lastTick.bid;
      DrawObjects();
    }
  }

  // close positions
  if (InpRangeClose >= 0 && lastTick.time >= range.close_time) {
    if (!ClosePositions()) {
      return;
    }
  }

  // calculate new range if
  if (((InpRangeClose >= 0 && lastTick.time >= range.close_time) ||
      (range.f_high_breakout && range.f_low_breakout) ||
      (range.end_time == 0) ||
      (range.end_time != 0 && lastTick.time > range.end_time &&
        !range.f_entry)) &&
    CountOpenPositons() == 0) {
    CalculateRange();
  }

  CheckBreakouts();
}


bool CheckInputs() {

  if (InpMagicNumber <= 0) {
    Alert("Magic number below 0");
    return false;
  }
  if (InpLots < 0) {
    Alert("InpLots below 0");
    return false;
  }
  if (InpStopLoss < 0) {
    Alert("InpStopLoss below 0");
    return false;
  }
  if (InpRangeClose < 0) {
    Alert("InpRangeClose below 0");
    return false;
  }
  if (InpRangeStart <= 0 || InpRangeStart > 1440) {
    Alert("InpRangeStart number below 0 or higher than 1440");
    return false;
  }
  if (InpRangeDuration <= 0 || InpRangeDuration > 1440) {
    Alert("InpRangeDuration number below 0 or higher than 1440");
    return false;
  }
  if (InpRangeClose >= 1440 ||
    (InpRangeStart + InpRangeDuration) % 1440 == InpRangeClose) {
    Alert(
      "InpRangeClose number below 0 or higher than 1440 or end_time == "
      "close_time");
    return false;
  }
  if (InpMonday + InpTuesday + InpWednesday + InpThursday + InpFriday == 0) {
    Alert("All week filtered nothing to trade");
    return false;
  }

  return true;
}

void CalculateRange() {

  range.start_time = 0;
  range.end_time = 0;
  range.close_time = 0;
  range.high = 0.0;
  range.low = DBL_MAX;
  range.f_entry = false;
  range.f_high_breakout = false;
  range.f_low_breakout = false;

  // calc range start
  int time_cycle = 86400;
  range.start_time =
    (lastTick.time - (lastTick.time % time_cycle)) + InpRangeStart * 60;
  for (int i = 0; i < 8; i++) {
    MqlDateTime tmp;
    TimeToStruct(range.start_time, tmp);
    int dow = tmp.day_of_week;
    if (lastTick.time >= range.start_time || dow == 6 || dow == 0 ||
      (dow == 1 && !InpMonday) || (dow == 2 && !InpTuesday) ||
      (dow == 3 && !InpWednesday) || (dow == 4 && !InpThursday) ||
      (dow == 5 && !InpFriday)) {
      range.start_time += time_cycle;
    }
  }

  // calculate range end time
  range.end_time = range.start_time + InpRangeDuration * 60;
  for (int i = 0; i < 2; i++) {
    MqlDateTime tmp;
    TimeToStruct(range.end_time, tmp);
    int dow = tmp.day_of_week;
    if (dow == 6 || dow == 0) {
      range.end_time += time_cycle;
    }
  }

  // calculate range close
  if (InpRangeClose >= 0) {
    range.close_time =
      (range.end_time - (range.end_time % time_cycle)) + InpRangeClose * 60;
    for (int i = 0; i < 3; i++) {
      MqlDateTime tmp;
      TimeToStruct(range.close_time, tmp);
      int dow = tmp.day_of_week;
      if (range.close_time <= range.end_time || dow == 6 || dow == 0) {
        range.close_time += time_cycle;
      }
    }
  }

  // draw objects
  DrawObjects();
}


int CountOpenPositons() {

  int counter = 0;
  int total = PositionsTotal();
  for (int i = total - 1; i >= 0; i--) {
    ulong ticket = PositionGetTicket(i);
    if (ticket <= 0) {
      Print("Failed to get position ticket");
      return -1;
    }
    if (!PositionSelectByTicket(ticket)) {
      Print("Failed to selet pos by ticket");
      return -1;
    }
    ulong magicNumber;
    if (!PositionGetInteger(POSITION_MAGIC, magicNumber)) {
      Print("Failed to get magicnumber from position");
      return -1;
    }
    if (InpMagicNumber == magicNumber) {
      counter++;
    }
  }

  return counter;
}


void CheckBreakouts() {

  if (lastTick.time >= range.end_time && range.end_time > 0 && range.f_entry) {
    if (!range.f_high_breakout && lastTick.ask >= range.high) {
      range.f_high_breakout = true;
      if (InpBreakoutMode == ONE_SIGNAL) {
        range.f_low_breakout = true;
      }

      double sl;
      // calc sl tp
      if (InpStopLossMode == VALUE) {
        sl = InpStopLoss == 0 ? 0 : NormalizeDouble(
          lastTick.bid - ((range.high - range.low) *
            InpStopLoss * 0.01),
          _Digits);
      }
      if (InpStopLossMode == HALF_CHANNEL) {
        sl = NormalizeDouble(
          ((range.high - range.low) / 2) + range.low,
          _Digits);
      }

      if (InpStopLossMode == NEGATIVE_END_CHANNEL) {
        sl = NormalizeDouble(
          range.low,
          _Digits);
      }

      double tp =
        InpTakeProfit == 0 ?
        0 :
        NormalizeDouble(lastTick.bid + ((range.high - range.low) *
            InpTakeProfit * 0.01),
          _Digits);

      // calc lots
      double lots;
      if (!CalculateLots(lastTick.bid - sl, lots)) {
        return;
      }

      // open buy
      trade.PositionOpen(_Symbol, ORDER_TYPE_BUY, lots, lastTick.ask, sl, tp,
        "time range ea");
    }

    if (!range.f_low_breakout && lastTick.bid <= range.low) {
      range.f_low_breakout = true;
      if (InpBreakoutMode == ONE_SIGNAL) {
        range.f_high_breakout = true;
      }

      // calc sl tp
      double sl;
      if (InpStopLossMode == VALUE) {
        sl = InpStopLoss == 0 ? 0 : NormalizeDouble(
          lastTick.ask + ((range.high - range.low) *
            InpStopLoss * 0.01),
          _Digits);
      }
      if (InpStopLossMode == HALF_CHANNEL) {
        sl = NormalizeDouble(
          range.high - (range.high - range.low),
          _Digits);
      }

      if (InpStopLossMode == NEGATIVE_END_CHANNEL) {
        sl = NormalizeDouble(
          range.high,
          _Digits);
      }

      double tp =
        InpTakeProfit == 0 ?
        0 :
        NormalizeDouble(lastTick.ask - ((range.high - range.low) *
            InpTakeProfit * 0.01),
          _Digits);

      // calc lots
      double lots;
      if (!CalculateLots(sl - lastTick.ask, lots)) {
        return;
      }

      // open buy
      trade.PositionOpen(_Symbol, ORDER_TYPE_SELL, lots, lastTick.bid, sl, tp,
        "time range ea");
    }
  }
}


bool ClosePositions() {

  int total = PositionsTotal();
  for (int i = total - 1; i >= 0; i--) {
    if (total != PositionsTotal()) {
      total = PositionsTotal();
      i = total;
      continue;
    }
    ulong ticket = PositionGetTicket(i);
    if (ticket <= 0) {
      Print("Failed to get position ticket");
      return false;
    }
    if (!PositionSelectByTicket(ticket)) {
      Print("Failed to selet pos by ticket");
      return false;
    }
    ulong magicNumber;
    if (!PositionGetInteger(POSITION_MAGIC, magicNumber)) {
      Print("Failed to get magicnumber from position");
      return false;
    }
    if (InpMagicNumber == magicNumber) {
      trade.PositionClose(ticket);
      if (trade.ResultRetcode() != TRADE_RETCODE_DONE) {
        Print("Failed to close position result " +
          (string) trade.ResultRetcode() + ":" +
          trade.ResultRetcodeDescription());
        return false;
      }
    }
  }
  return true;
}


void DrawObjects() {

  // start time
  ObjectDelete(NULL, "range start");
  if (range.start_time > 0) {
    ObjectCreate(NULL, "range start", OBJ_VLINE, 0, range.start_time, 0);
    ObjectSetString(
      NULL, "range start", OBJPROP_TOOLTIP,
      "start of the range \n" +
      TimeToString(range.start_time, TIME_DATE | TIME_MINUTES));
    ObjectSetInteger(NULL, "range start", OBJPROP_COLOR, clrBlue);
    ObjectSetInteger(NULL, "range start", OBJPROP_WIDTH, 2);
    ObjectSetInteger(NULL, "range start", OBJPROP_BACK, true);
  }

  // end time
  ObjectDelete(NULL, "range end");
  if (range.end_time > 0) {
    ObjectCreate(NULL, "range end", OBJ_VLINE, 0, range.end_time, 0);
    ObjectSetString(NULL, "range end", OBJPROP_TOOLTIP,
      "end of the range \n" +
      TimeToString(range.end_time, TIME_DATE | TIME_MINUTES));
    ObjectSetInteger(NULL, "range end", OBJPROP_COLOR, clrBlue);
    ObjectSetInteger(NULL, "range end", OBJPROP_WIDTH, 2);
    ObjectSetInteger(NULL, "range end", OBJPROP_BACK, true);
  }

  // close time
  ObjectDelete(NULL, "range close");
  if (range.close_time > 0) {
    ObjectCreate(NULL, "range close", OBJ_VLINE, 0, range.close_time, 0);
    ObjectSetString(
      NULL, "range close", OBJPROP_TOOLTIP,
      "close of the range \n" +
      TimeToString(range.close_time, TIME_DATE | TIME_MINUTES));
    ObjectSetInteger(NULL, "range close", OBJPROP_COLOR, clrRed);
    ObjectSetInteger(NULL, "range close", OBJPROP_WIDTH, 2);
    ObjectSetInteger(NULL, "range close", OBJPROP_BACK, true);
  }

  // high
  ObjectDelete(NULL, "range high");
  if (range.high > 0) {
    ObjectCreate(NULL, "range high", OBJ_TREND, 0, range.start_time, range.high,
      range.end_time, range.high);
    ObjectSetString(
      NULL, "range high", OBJPROP_TOOLTIP,
      "high of the range \n" + DoubleToString(range.high, _Digits));
    ObjectSetInteger(NULL, "range high", OBJPROP_COLOR, clrBlue);
    ObjectSetInteger(NULL, "range high", OBJPROP_WIDTH, 2);
    ObjectSetInteger(NULL, "range high", OBJPROP_BACK, true);

    ObjectCreate(NULL, "range high", OBJ_TREND, 0, range.end_time, range.high,
      InpRangeClose >= 0 ? range.close_time : INT_MAX, range.high);
    ObjectSetString(
      NULL, "range high", OBJPROP_TOOLTIP,
      "high of the range \n" + DoubleToString(range.high, _Digits));
    ObjectSetInteger(NULL, "range high", OBJPROP_COLOR, clrBlue);
    ObjectSetInteger(NULL, "range high", OBJPROP_BACK, true);
    ObjectSetInteger(NULL, "range high", OBJPROP_STYLE, STYLE_DOT);
  }

  // low
  ObjectDelete(NULL, "range low");
  if (range.low < 99999) {
    ObjectCreate(NULL, "range low", OBJ_TREND, 0, range.start_time, range.low,
      range.end_time, range.low);
    ObjectSetString(NULL, "range low", OBJPROP_TOOLTIP,
      "low of the range \n" + DoubleToString(range.low, _Digits));
    ObjectSetInteger(NULL, "range low", OBJPROP_COLOR, clrBlue);
    ObjectSetInteger(NULL, "range low", OBJPROP_WIDTH, 2);
    ObjectSetInteger(NULL, "range low", OBJPROP_BACK, true);

    ObjectCreate(NULL, "range low", OBJ_TREND, 0, range.end_time, range.low,
      InpRangeClose >= 0 ? range.close_time : INT_MAX, range.low);
    ObjectSetString(NULL, "range low", OBJPROP_TOOLTIP,
      "low of the range \n" + DoubleToString(range.low, _Digits));
    ObjectSetInteger(NULL, "range low", OBJPROP_COLOR, clrBlue);
    ObjectSetInteger(NULL, "range low", OBJPROP_BACK, true);
    ObjectSetInteger(NULL, "range low", OBJPROP_STYLE, STYLE_DOT);
  }
}


bool CalculateLots(double slDistance, double &lots) {

  lots = 0.0;
  if (InpLotMode == LOT_MODE_FIXED) {
    lots = InpLots;
  }
  if (InpLotMode == LOT_MODE_MONEY || InpLotMode == LOT_MODE_PCT_ACCOUNT) {
    double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double volumeStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

    double riskMoney;

    if (InpLotMode == LOT_MODE_MONEY) {
      riskMoney = InpLots; // should contain money value ex: 50 in usd 
    }

    if (InpLotMode == LOT_MODE_PCT_ACCOUNT) {
      riskMoney = AccountInfoDouble(ACCOUNT_EQUITY) * InpLots * 0.01; // should contain percent ex 14 value for 14 % of account
    }

    if (tickSize == 0) {
      Print("tickSize equal 0");
      tickSize = 1;
    }

    double moneyVolumeStep = (slDistance / tickSize) * tickValue * volumeStep;

    if (moneyVolumeStep == 0) {
      Print("ERR: moneyVolumeStep equal 0");
      return false;
    }

    lots = MathFloor(riskMoney / moneyVolumeStep) * volumeStep;
  }

  if (!CheckLots(lots)) {
    return false;
  }

  return true;
}


bool CheckLots(double &lots) {

  double min = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
  double max = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
  double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

  if (min == 0) {
    Print("min equal 0");
  }

  if (max == 0) {
    Print("max equal 0");
  }

  if (lots < min) {
    Print("Lots below min lots");
    lots = min;
    return true;
  }

  if (lots > max) {
    Print("lotst above max");
    return false;
  }

  if (step == 0) {
    Print("step equal 0");
    step = 1;
  }

  lots = (int) MathFloor(lots / step) * step;

  return true;
}