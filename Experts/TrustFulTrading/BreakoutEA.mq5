// https://www.youtube.com/watch?v=I84L4O081XA
//+------------------------------------------------------------------+
//|                                                   BreakoutEA.mq5 |
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

enum STOP_LOSS_ENUM
{
  SL_NEGATIVE_END_CHANNEL, // Negative end channel
  SL_HALF_CHANNEL,         // Half the channel
  SL_VALUE                 // Value in points
};

enum TAKE_PROFIT_ENUM
{
  TP_CHANNEL_MULTIPLY, // Channel height will be multiplied by
  TP_VALUE             // Value in points
};

enum BREAKOUT_MODE_ENUM
{
  ONE_SIGNAL,
  TWO_SIGNALS
};

struct POSTION_SUMMARY_STRUCT
{
  datetime start_time;
  datetime end_time;
  datetime close_time;
  double high;
  double low;
  bool f_entry;
  bool f_high_breakout;
  bool f_low_breakout;

  POSTION_SUMMARY_STRUCT() : start_time(0),
                             end_time(0),
                             close_time(9),
                             high(0),
                             low(DBL_MAX),
                             f_entry(false),
                             f_high_breakout(false),
                             f_low_breakout(false){};
};

input group "===General input===";
input long InpMagicNumber = 830766;
input LOT_MODE_ENUM InpLotMode = OFF;
input double InpLots = 0.01;
input STOP_LOSS_ENUM InpStopLossMode = SL_VALUE;
input int InpStopLoss = 150;
input TAKE_PROFIT_ENUM InpTakeProfitMode = TP_VALUE;
input int InpTakeProfit = 200;

input group "===Range inputs===";
input int InpRangeStart = 600;             // Time for open range in minutes from 0:00 (600 min = 10:00)
input int InpRangeDuration = 120;          // Time for range in minutes
input int InpRangeClose = 1200;            // Time for close positions in minutes from 0:00 (1200 min = 20:00)
input bool InpHandleLongTimeSpans = false; // If time span start on the end of a day, there is no need to wait for upcoming day

input group "===Custom filters===";
input int InpFilterFromUpRange = 0;   // If range high-low is higher than this value filter out transaction
input int InpFilterFromDownRange = 0; // If range high-low is lower than this value filter out transaction
input bool InpBuyOn = true;           // If false, filter out buy transactions
input bool InpSellOn = true;          // If false, filter out sell transactions
input BREAKOUT_MODE_ENUM InpBreakoutMode = ONE_SIGNAL;

input group "===Money saving===";
input int InpBreakEvenFromPoints = 0;    // Break event from N points; 0=off
input int InpTrailingStopLoss = 0;       // Move sl up after N points from last; 0=off
input double InpTrailingStopAtr = 0;     // Move sl by multiply ATR; 0=off
input int InpTrailingStopAtrPeriod = 14; // ATR period

input group "===Day of week filter===";
input bool InpMonday = true;
input bool InpTuesday = true;
input bool InpWednesday = true;
input bool InpThursday = true;
input bool InpFriday = true;

POSTION_SUMMARY_STRUCT range;
MqlTick prevTick, lastTick;
CTrade trade;
bool calcSpan = false;
int time_cycle = 86400; // whole day in minutes
int atrHandle;

int OnInit()
{
  if (!CheckInputs())
  {
    return INIT_PARAMETERS_INCORRECT;
  }

  trade.SetExpertMagicNumber(InpMagicNumber);

  if (_UninitReason == REASON_PARAMETERS && CountOpenPositions() == 0)
  {
    CalculateRange();
  }

  atrHandle = iATR(_Symbol, _Period, InpTrailingStopAtrPeriod);

  DrawObjects();

  return (INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
  ObjectDelete(NULL, "range");
  ObjectDelete(NULL, "range start");
  ObjectDelete(NULL, "range end");
  ObjectDelete(NULL, "range close");
  ObjectDelete(NULL, "range high");
  ObjectDelete(NULL, "range low");
  IndicatorRelease(atrHandle);
}

void OnTick()
{
  prevTick = lastTick;
  SymbolInfoTick(_Symbol, lastTick);

  // range check - if we need transaction
  if (lastTick.time >= range.start_time && lastTick.time < range.end_time)
  {
    // set flag
    range.f_entry = true;

    // new high
    if (lastTick.ask > range.high)
    {
      range.high = lastTick.ask;
      DrawObjects();
    }

    // new low
    if (lastTick.bid < range.low)
    {
      range.low = lastTick.bid;
      DrawObjects();
    }
  }

  // manage open positions
  ManageOpenPositionForeach();

  // close positions
  if (InpRangeClose >= 0 && lastTick.time >= range.close_time) // close time init set to 0
  {
    if (!ClosePositions())
    {
      return;
    }
  }

  // calculate new range if
  if (((InpRangeClose >= 0 && lastTick.time >= range.close_time) ||
       (range.f_high_breakout && range.f_low_breakout) ||
       (range.end_time == 0) ||
       (range.end_time != 0 && lastTick.time > range.end_time &&
        !range.f_entry)) &&
      CountOpenPositions() == 0)
  {
    CalculateRange();
  }

  CheckBreakouts();
}

bool CheckInputs()
{
  if (InpMagicNumber <= 0)
  {
    Alert("Magic number below 0");
    return false;
  }
  if (InpLots < 0)
  {
    Alert("InpLots below 0");
    return false;
  }
  if (InpStopLoss < 0)
  {
    Alert("InpStopLoss below 0");
    return false;
  }
  if (InpStopLossMode != SL_VALUE && InpStopLoss != 0)
  {
    Alert("InpStopLossMode != SL_VALUE && InpStopLoss != 0");
    return false;
  }
  if (InpRangeClose < 0)
  {
    Alert("InpRangeClose below 0");
    return false;
  }
  if (InpRangeStart <= 0 || InpRangeStart > 1440)
  {
    Alert("InpRangeStart number below 0 or higher than 1440");
    return false;
  }
  if (InpRangeDuration <= 0 || InpRangeDuration > 1440)
  {
    Alert("InpRangeDuration number below 0 or higher than 1440");
    return false;
  }
  if (InpRangeClose >= 1440 ||
      (InpRangeStart + InpRangeDuration) % 1440 == InpRangeClose)
  {
    Alert(
        "InpRangeClose number below 0 or higher than 1440 or end_time == "
        "close_time");
    return false;
  }
  if (InpMonday + InpTuesday + InpWednesday + InpThursday + InpFriday == 0)
  {
    Alert("All week filtered nothing to trade");
    return false;
  }

  if (InpBreakEvenFromPoints < 0)
  {
    Alert("InpBreakEvenFromPoints below 0");
    return false;
  }

  if (InpTrailingStopAtr > 0 && InpTrailingStopLoss > 0)
  {
    Alert("InpTrailingStopAtr and InpTrailingStopLoss can't be both > 0");
    return false;
  }

  if (InpTrailingStopLoss != 0 && InpTakeProfit != 0 && InpTakeProfitMode == TP_VALUE && InpTrailingStopLoss >= InpTakeProfit)
  {
    Alert("InpTrailingStopLoss >= InpTakeProfit");
    return false;
  }

  if (InpTrailingStopAtr == 0 && InpTrailingStopAtrPeriod != 0)
  {
    Alert("Setup obsolete InpTrailingStopAtrPeriod != 0 && InpTrailingStopAtr == 0");
    return false;
  }

  return true;
}

void CalculateRange()
{
  InitRange();

  // calc range start
  range.start_time = (lastTick.time - (lastTick.time % time_cycle)) + InpRangeStart * 60;

  ForwardRangeStartTimeIfDayOff();

  if (InpHandleLongTimeSpans)
  {
    HandleLongTimeSpans_SetStartRange();
  }

  // calculate range end time
  range.end_time = range.start_time + InpRangeDuration * 60;
  // rewind date to first trading in future
  IfWeekendMoveToWorkingDay(1, range.end_time);

  // calculate range close
  if (InpRangeClose >= 0)
  {
    range.close_time = (range.end_time - (range.end_time % time_cycle)) + InpRangeClose * 60;
    if (range.close_time <= range.end_time)
    {
      range.close_time += time_cycle;
    }
    IfWeekendMoveToWorkingDay(1, range.close_time);
  }

  if (InpHandleLongTimeSpans && calcSpan)
  {
    HandleLongTimeSpans_SetHighLowRange();
  }

  // draw objects
  DrawObjects();
}

void InitRange()
{
  range.start_time = 0;
  range.end_time = 0;
  range.close_time = 0;
  range.high = 0.0;
  range.low = DBL_MAX;
  range.f_entry = false;
  range.f_high_breakout = false;
  range.f_low_breakout = false;
}

void ForwardRangeStartTimeIfDayOff()
{
  for (int i = 0; i < 8; i++)
  {
    MqlDateTime tmp;
    TimeToStruct(range.start_time, tmp);
    int dow = tmp.day_of_week;
    if (lastTick.time >= range.start_time || dow == 6 || dow == 0 ||
        (dow == 1 && !InpMonday) || (dow == 2 && !InpTuesday) ||
        (dow == 3 && !InpWednesday) || (dow == 4 && !InpThursday) ||
        (dow == 5 && !InpFriday))
    {
      range.start_time += time_cycle;
    }
  }
}

void HandleLongTimeSpans_SetStartRange()
{
  if (lastTick.time <= range.start_time)
  {
    MqlDateTime startTime, endTime;
    TimeToStruct(range.start_time, startTime);
    TimeToStruct(range.end_time, endTime);

    if (IsLastClosedTransactionInCurrentRange())
    {
      calcSpan = false;
      return;
    }

    if (lastTick.time <= range.start_time && endTime.day != startTime.day)
    {
      range.start_time -= time_cycle;
    }

    // rewind date to first trading in past
    IfWeekendMoveToWorkingDay(-1, range.start_time);

    calcSpan = true;
  }
}

void HandleLongTimeSpans_SetHighLowRange()
{
  int indexRangeStart = iBarShift(_Symbol, PERIOD_CURRENT, range.start_time, false);
  int indexRangeEnd;
  if (range.end_time >= lastTick.time)
  {
    indexRangeEnd = 0;
  }
  else
  {
    indexRangeEnd = iBarShift(_Symbol, PERIOD_CURRENT, range.end_time, false);
  }

  int indexHighestBar = iHighest(_Symbol, PERIOD_CURRENT, MODE_HIGH, indexRangeStart - indexRangeEnd, indexRangeEnd);
  int indexLowestBar = iLowest(_Symbol, PERIOD_CURRENT, MODE_LOW, indexRangeStart - indexRangeEnd, indexRangeEnd);

  range.high = iHigh(_Symbol, PERIOD_CURRENT, indexHighestBar);
  range.low = iLow(_Symbol, PERIOD_CURRENT, indexLowestBar);

  calcSpan = false;
}

void IfWeekendMoveToWorkingDay(int direction, datetime &date)
{
  MqlDateTime currentTime;
  TimeToStruct(date, currentTime);
  if (currentTime.day_of_week == 0 || currentTime.day_of_week == 6)
  {
    while (currentTime.day_of_week != 5 && currentTime.day_of_week != 1)
    {
      if (direction == 1)
      {
        date += time_cycle;
      }
      if (direction == -1)
      {
        date -= time_cycle;
      }
      TimeToStruct(date, currentTime);
    }
  }
}

int CountOpenPositions()
{
  int counter = 0;
  int total = PositionsTotal();
  for (int i = total - 1; i >= 0; i--)
  {
    ulong ticket = PositionGetTicket(i);
    if (ticket <= 0)
    {
      Print("Failed to get position ticket");
      return -1;
    }
    if (!PositionSelectByTicket(ticket))
    {
      Print("Failed to select pos by ticket");
      return -1;
    }
    ulong magicNumber;
    if (!PositionGetInteger(POSITION_MAGIC, magicNumber))
    {
      Print("Failed to get magic number from position");
      return -1;
    }
    if (InpMagicNumber == magicNumber)
    {
      counter++;
    }
  }

  return counter;
}

void CheckBreakouts()
{
  double rangeInPoints = range.high - range.low;
  double limitTop = InpFilterFromUpRange * _Point;
  double limitDown = InpFilterFromDownRange * _Point;
  if (range.f_entry && InpFilterFromUpRange > 0 && rangeInPoints > limitTop)
  {
    Print("Range filter #ON length", (string)rangeInPoints, " is above limit ", (string)limitTop, ". Skipping");
    range.f_entry = false;
    return;
  }

  if (range.f_entry && InpFilterFromDownRange > 0 && limitDown > rangeInPoints)
  {
    Print("Range filter #ON length", (string)rangeInPoints, " is below limit ", (string)limitDown, ". Skipping");
    range.f_entry = false;
    return;
  }

  if (lastTick.time >= range.end_time && range.end_time > 0 && range.f_entry)
  {
    if (!range.f_high_breakout && lastTick.ask >= range.high)
    {
      range.f_high_breakout = true;
      if (InpBreakoutMode == ONE_SIGNAL)
      {
        range.f_low_breakout = true;
      }

      double sl = 0;
      // calc sl tp
      if (InpStopLossMode == SL_VALUE)
      {
        sl = InpStopLoss == 0 ? 0 : NormalizeDouble(lastTick.ask - (InpStopLoss * _Point), _Digits);
      }
      if (InpStopLossMode == SL_HALF_CHANNEL)
      {
        sl = NormalizeDouble(
            ((range.high - range.low) / 2) + range.low,
            _Digits);
      }

      if (InpStopLossMode == SL_NEGATIVE_END_CHANNEL)
      {
        sl = NormalizeDouble(
            range.low,
            _Digits);
      }

      double tp = 0;
      if (InpTakeProfitMode == TP_VALUE)
      {
        tp = InpTakeProfit == 0 ? 0 : NormalizeDouble(lastTick.ask + (InpTakeProfit * _Point), _Digits);
      }

      if (InpTakeProfitMode == TP_CHANNEL_MULTIPLY)
      {
        tp = NormalizeDouble(lastTick.ask + ((range.high - range.low) * InpTakeProfit), _Digits);
      }

      // calc lots
      double lots;
      if (!CalculateLots(lastTick.ask - sl, lots))
      {
        Print("❌[BreakoutEA.mq5:498]: ", "!CalculateLots(lastTick.ask - sl, lots)");
        return;
      }

      // open buy
      if (InpBuyOn && !trade.PositionOpen(_Symbol, ORDER_TYPE_BUY, lots, lastTick.ask, sl, tp,
                                          "BreakoutEA"))
      {
        Print("❌[BreakoutEA.mq5:506]: ", "PositionOpen Buy failed: sl ", (string)sl, " tp: ", (string)tp, " lots: ", (string)lots,
              (string)trade.ResultRetcode() + ":" +
                  trade.ResultRetcodeDescription());
      }
    }

    if (!range.f_low_breakout && lastTick.bid <= range.low)
    {
      range.f_low_breakout = true;
      if (InpBreakoutMode == ONE_SIGNAL)
      {
        range.f_high_breakout = true;
      }

      // calc sl tp
      double sl = 0;
      if (InpStopLossMode == SL_VALUE)
      {
        sl = InpStopLoss == 0 ? 0 : NormalizeDouble(lastTick.bid + (InpStopLoss * _Point), _Digits);
      }
      if (InpStopLossMode == SL_HALF_CHANNEL)
      {
        sl = NormalizeDouble(
            ((range.high - range.low) / 2) + range.low,
            _Digits);
      }

      if (InpStopLossMode == SL_NEGATIVE_END_CHANNEL)
      {
        sl = NormalizeDouble(
            range.high,
            _Digits);
      }

      double tp = 0;
      if (InpTakeProfitMode == TP_VALUE)
      {
        tp = InpTakeProfit == 0 ? 0 : NormalizeDouble(lastTick.bid - (InpTakeProfit * _Point), _Digits);
      }

      if (InpTakeProfitMode == TP_CHANNEL_MULTIPLY)
      {
        tp = NormalizeDouble(lastTick.bid - ((range.high - range.low) * InpTakeProfit), _Digits);
      }

      // calc lots
      double lots;
      if (!CalculateLots(sl - lastTick.bid, lots))
      {
        Print("❌[BreakoutEA.mq5:555]: ", "!CalculateLots(sl - lastTick.bid, lots)");
        return;
      }

      // open sell
      if (InpSellOn && !trade.PositionOpen(_Symbol, ORDER_TYPE_SELL, lots, lastTick.bid, sl, tp,
                                           "BreakoutEA"))
      {
        Print("❌[BreakoutEA.mq5:563]: ", "PositionOpen Sell failed: sl ", (string)sl, " tp: ", (string)tp, " lots: ", (string)lots,
              (string)trade.ResultRetcode() + ":" +
                  trade.ResultRetcodeDescription());
      }
    }
  }
}

bool ClosePositions()
{
  int total = PositionsTotal();
  for (int i = total - 1; i >= 0; i--)
  {
    if (total != PositionsTotal())
    {
      total = PositionsTotal();
      i = total;
      continue;
    }
    ulong ticket = PositionGetTicket(i);
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
      trade.PositionClose(ticket);
      if (trade.ResultRetcode() != TRADE_RETCODE_DONE)
      {
        Print("Failed to close position result " +
              (string)trade.ResultRetcode() + ":" +
              trade.ResultRetcodeDescription());
        return false;
      }
    }
  }
  return true;
}

void DrawObjects()
{
  // start time
  ObjectDelete(NULL, "range start");
  if (range.start_time > 0)
  {
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
  if (range.end_time > 0)
  {
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
  if (range.close_time > 0)
  {
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
  if (range.high > 0)
  {
    ObjectCreate(NULL, "range high", OBJ_TREND, 0, range.start_time, range.high,
                 range.end_time, range.high);
    ObjectSetString(
        NULL, "range high", OBJPROP_TOOLTIP,
        "high of the range \n" + DoubleToString(range.high, _Digits));
    ObjectSetInteger(NULL, "range high", OBJPROP_COLOR, clrBlue);
    ObjectSetInteger(NULL, "range high", OBJPROP_WIDTH, 2);
    ObjectSetInteger(NULL, "range high", OBJPROP_BACK, true);

    ObjectCreate(NULL, "range high", OBJ_TREND, 0, range.end_time, range.high,
                 InpRangeClose >= 0 ? range.close_time : (datetime)INT_MAX, range.high);
    ObjectSetString(
        NULL, "range high", OBJPROP_TOOLTIP,
        "high of the range \n" + DoubleToString(range.high, _Digits));
    ObjectSetInteger(NULL, "range high", OBJPROP_COLOR, clrBlue);
    ObjectSetInteger(NULL, "range high", OBJPROP_BACK, true);
    ObjectSetInteger(NULL, "range high", OBJPROP_STYLE, STYLE_DOT);
  }

  // low
  ObjectDelete(NULL, "range low");
  if (range.low < 99999)
  {
    ObjectCreate(NULL, "range low", OBJ_TREND, 0, range.start_time, range.low,
                 range.end_time, range.low);
    ObjectSetString(NULL, "range low", OBJPROP_TOOLTIP,
                    "low of the range \n" + DoubleToString(range.low, _Digits));
    ObjectSetInteger(NULL, "range low", OBJPROP_COLOR, clrBlue);
    ObjectSetInteger(NULL, "range low", OBJPROP_WIDTH, 2);
    ObjectSetInteger(NULL, "range low", OBJPROP_BACK, true);

    ObjectCreate(NULL, "range low", OBJ_TREND, 0, range.end_time, range.low,
                 InpRangeClose >= 0 ? range.close_time : (datetime)INT_MAX, range.low);
    ObjectSetString(NULL, "range low", OBJPROP_TOOLTIP,
                    "low of the range \n" + DoubleToString(range.low, _Digits));
    ObjectSetInteger(NULL, "range low", OBJPROP_COLOR, clrBlue);
    ObjectSetInteger(NULL, "range low", OBJPROP_BACK, true);
    ObjectSetInteger(NULL, "range low", OBJPROP_STYLE, STYLE_DOT);
  }
}

bool CalculateLots(double slDistance, double &lots)
{
  lots = 0.0;
  if (InpLotMode == OFF)
  {
    lots = InpLots;
    if (!CheckLots(lots))
    {
      Print("❌[BreakoutEA.mq5]: ", "!CheckLots(lots) wrong lots");
      return false;
    }
  }
  if (InpLotMode == LOT_MODE_PCT_EQUITY)
  {
    lots = AccountInfoDouble(ACCOUNT_EQUITY) * InpLots;

    if (!CheckLots(lots))
    {
      Print("❌[BreakoutEA.mq5]: ", "!CheckLots(lots) wrong lots");
      return false;
    }
  }
  if (InpLotMode == LOT_MODE_MONEY || InpLotMode == LOT_MODE_PCT_ACCOUNT)
  {
    double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double volumeStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

    double riskMoney = 0;

    if (InpLotMode == LOT_MODE_MONEY)
    {
      riskMoney = InpLots; // should contain money value ex: 50 in usd
    }

    if (InpLotMode == LOT_MODE_PCT_ACCOUNT)
    {
      riskMoney = AccountInfoDouble(ACCOUNT_EQUITY) * InpLots * 0.01; // should contain percent ex 14 value for 14 % of account
    }

    if (tickSize == 0)
    {
      Print("tickSize equal 0");
      tickSize = 1;
    }

    double moneyVolumeStep = (slDistance / tickSize) * tickValue * volumeStep;

    if (moneyVolumeStep == 0)
    {
      Print("❌[BreakoutEA.mq5]: ", "moneyVolumeStep equal 0 , slDistance = ", slDistance, " tickSize ", tickSize, " tickValue ", tickValue, " volumeStep ", volumeStep);
      return false;
    }

    lots = MathFloor(riskMoney / moneyVolumeStep) * volumeStep;
  }

  if (!CheckLots(lots))
  {
    Print("❌[BreakoutEA.mq5]: ", "!CheckLots(lots) wrong lots");
    return false;
  }

  return true;
}

bool CheckLots(double &lots)
{

  double min = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
  double max = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
  double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

  if (min == 0)
  {
    Print("CheckLots: min lots equal 0");
  }

  if (max == 0)
  {
    Print("CheckLots: max lots equal 0");
  }

  if (lots < min)
  {
    Print("CheckLots: Lots below min lots");
    lots = min;
    return true;
  }

  if (lots > max)
  {
    Print("CheckLots: Lots above max");
    return false;
  }

  if (step == 0)
  {
    // Print("CheckLots: step equal 0");
    step = 1;
  }

  lots = (int)MathFloor(lots / step) * step;

  return true;
}

bool IsLastClosedTransactionInCurrentRange()
{
  return false;
  /*
  // TODO find a way to check if last closed position due to force close or TP / SL was done in current range breakout bounds
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
        posProfit += HistoryDealGetDouble(dealTicket, DEAL_PROFIT) + HistoryDeUUalGetDouble(dealTicket, DEAL_SWAP) + HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
      }
    }
  }
    */
}

void ManageOpenPositionForeach()
{

  int total = PositionsTotal();
  for (int i = total - 1; i >= 0; i--)
  {
    ulong ticket = PositionGetTicket(i);
    if (ticket <= 0)
    {
      Print("Failed to get position ticket");
      return;
    }
    if (!PositionSelectByTicket(ticket))
    {
      Print("Failed to select pos by ticket");
      return;
    }
    ulong magicNumber;
    if (!PositionGetInteger(POSITION_MAGIC, magicNumber))
    {
      Print("Failed to get magic number from position");
      return;
    }
    if (InpMagicNumber == magicNumber)
    {
      // do your stuff
      if (InpBreakEvenFromPoints > 0)
      {
        SetSlToBreakEven(ticket);
      }

      if (InpTrailingStopAtr > 0)
      {
        SetTrailingStopAtr(ticket);
      }

      if (InpTrailingStopLoss > 0)
      {
        SetTrailingStopLoss(ticket);
      }

      // end your stuff
    }
  }
}

void SetSlToBreakEven(ulong ticket)
{
  double openPrice = 0;
  if (!PositionGetDouble(POSITION_PRICE_OPEN, openPrice))
  {
    Print("Failed to get open price");
    return;
  }

  long positionType = 0;
  if (!PositionGetInteger(POSITION_TYPE, positionType))
  {
    Print("Failed to get position type");
    return;
  }

  double sl = 0;
  if (!PositionGetDouble(POSITION_SL, sl))
  {
    Print("Failed to get position sl");
    return;
  }

  double tp = 0;
  if (!PositionGetDouble(POSITION_TP, tp))
  {
    Print("Failed to get position tp");
    return;
  }

  if (positionType == POSITION_TYPE_BUY)
  {
    if (sl >= openPrice)
    {
      return;
    }

    double currentPrice = lastTick.ask;
    double currentDistancePoints = (currentPrice - openPrice) / _Point;

    if (currentDistancePoints < 0 || currentDistancePoints < InpBreakEvenFromPoints)
    {
      return;
    }

    if (!trade.PositionModify(ticket, openPrice, tp))
    {
      Print("Failed to set buy sl to break even");
      return;
    }
  }

  if (positionType == POSITION_TYPE_SELL)
  {
    if (sl <= openPrice)
    {
      return;
    }

    double currentPrice = lastTick.bid;
    double currentDistancePoints = (openPrice - currentPrice) / _Point;

    if (currentDistancePoints < 0 || currentDistancePoints < InpBreakEvenFromPoints)
    {
      return;
    }

    if (!trade.PositionModify(ticket, openPrice, tp))
    {
      Print("Failed to set sell sl to break even");
      return;
    }
  }
}

void SetTrailingStopLoss(ulong ticket)
{
  double openPrice = 0;
  if (!PositionGetDouble(POSITION_PRICE_OPEN, openPrice))
  {
    Print("Failed to get open price");
    return;
  }

  long positionType = 0;
  if (!PositionGetInteger(POSITION_TYPE, positionType))
  {
    Print("Failed to get position type");
    return;
  }

  double sl = 0;
  if (!PositionGetDouble(POSITION_SL, sl))
  {
    Print("Failed to get position sl");
    return;
  }

  double tp = 0;
  if (!PositionGetDouble(POSITION_TP, tp))
  {
    Print("Failed to get position tp");
    return;
  }

  if (positionType == POSITION_TYPE_BUY)
  {
    double currentPrice = lastTick.ask;
    double newStopLoss = NormalizeDouble(currentPrice - (InpTrailingStopLoss * _Point), _Digits);

    if (newStopLoss <= sl)
    {
      return;
    }

    if (!trade.PositionModify(ticket, newStopLoss, tp))
    {
      Print("Failed to set buy sl to trailing stop loss");
      return;
    }
  }

  if (positionType == POSITION_TYPE_SELL)
  {
    double currentPrice = lastTick.bid;
    double newStopLoss = NormalizeDouble(currentPrice + (InpTrailingStopLoss * _Point), _Digits);

    if (newStopLoss >= sl)
    {
      return;
    }

    if (!trade.PositionModify(ticket, newStopLoss, tp))
    {
      Print("Failed to set sell sl to trailing stop loss");
      return;
    }
  }
}

void SetTrailingStopAtr(ulong ticket)
{
  double atrBuffer[];
  CopyBuffer(atrHandle, 0, 0, 1, atrBuffer);

  double openPrice = 0;
  if (!PositionGetDouble(POSITION_PRICE_OPEN, openPrice))
  {
    Print("Failed to get open price");
    return;
  }

  long positionType = 0;
  if (!PositionGetInteger(POSITION_TYPE, positionType))
  {
    Print("Failed to get position type");
    return;
  }

  double sl = 0;
  if (!PositionGetDouble(POSITION_SL, sl))
  {
    Print("Failed to get position sl");
    return;
  }

  double tp = 0;
  if (!PositionGetDouble(POSITION_TP, tp))
  {
    Print("Failed to get position tp");
    return;
  }

  if (positionType == POSITION_TYPE_BUY)
  {
    double currentPrice = lastTick.ask;
    double newStopLoss = NormalizeDouble(currentPrice - (atrBuffer[0] * InpTrailingStopAtr), _Digits);

    if (newStopLoss <= sl)
    {
      return;
    }

    if (!trade.PositionModify(ticket, newStopLoss, tp))
    {
      Print("Failed to set buy sl to trailing stop loss by ATR multiplier");
      return;
    }
  }

  if (positionType == POSITION_TYPE_SELL)
  {
    double currentPrice = lastTick.bid;
    double newStopLoss = NormalizeDouble(currentPrice + (atrBuffer[0] * InpTrailingStopAtr), _Digits);

    if (newStopLoss >= sl)
    {
      return;
    }

    if (!trade.PositionModify(ticket, newStopLoss, tp))
    {
      Print("Failed to set sell sl to trailing stop loss by ATR multiplier");
      return;
    }
  }
}