//+------------------------------------------------------------------+
//|                                             CurrentResult.mq5 |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link "https://www.mql5.com"
#property version "1.00"

enum LayoutSize
{
  small, // Small fonts, distances
  normal // Normal fonts, distances
};

//--- input parameters
input group "Layout sizing"
input bool InpIsHorizontalOrientation = true; // Layout type horizontal/vertical
input LayoutSize InpLayoutSize = small;       // Layout size
input group "Break event line"
input bool InpPresentBELine = true;           // Break even line on/off
input string InpBELineLabel = "  BE line";    // Break Even line label
input group "Colors"
input color InpPresentBELineColor = clrGreen; // Break even line color
input color InpPositiveColor = clrGreen; // TP color
input color InpNeutralColor = clrBlack; // Neutral color
input color InpBackgroundColor = clrLightSlateGray; // Background color
input color InpBackgroundColor2 = clrDarkBlue; // Used for top labels
input color InpPositiveCurrentColor = clrBlue; // Positive Current result
input color InpNegativeColor = clrRed; // Negative color

input group "Debug"
input bool InpIsLogginEnabled = false;        // Logs enabled

string objectLabels[] = {
    "ProjLoss",
    "ProjLossPerc",
    "CurrentResult",
    "CurrentResultPerc",
    "ProjWin",
    "ProjWinPerc",
    "WithoutTpOrSl",
    "Label"};

struct SummaryDetail
{
  double currentResult;
  double profit;
  double loss;
  int withoutTp;
  int withoutSl;
  double risk;
};

struct LayoutConfig
{
  int horizontalColumnWidth;
  int xDrawingStartingPoint;
  int yHorizontalLineHeight;
  int yVerticalLineHeight;
  int columnMultiplier;
  int fontSize;
};

// Logger class to handle logging
class Logger
{
public:
  static void Log(const string &message)
  {
    if (InpIsLogginEnabled)
    {
      Print(message);
    }
  }
};

// SummaryCalculator class to calculate order and position results
class SummaryCalculator
{
public:
  static void InitializeStruct(SummaryDetail &summary)
  {
    summary.currentResult = 0;
    summary.profit = 0;
    summary.loss = 0;
    summary.withoutTp = 0;
    summary.withoutSl = 0;
    summary.risk = 0;
  }

  static void CalculateOrderResults(SummaryDetail &orderSummary)
  {
    for (int i = OrdersTotal() - 1; i >= 0; i--)
    {
      ulong ticket = OrderGetTicket(i);

      if (!OrderSelect(ticket))
      {
        Logger::Log("OrderSelect failed");
        continue;
      }

      string symbol;
      if (!OrderGetString(ORDER_SYMBOL, symbol) || symbol != Symbol())
      {
        continue;
      }

      double tp, price, sl, lots, tickValue, tickSize;
      if (!OrderGetDouble(ORDER_TP, tp) || !OrderGetDouble(ORDER_PRICE_OPEN, price) ||
          !OrderGetDouble(ORDER_SL, sl) || !OrderGetDouble(ORDER_VOLUME_CURRENT, lots) ||
          !SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE, tickValue) ||
          !SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_SIZE, tickSize))
      {
        continue;
      }

      long orderType;
      bool isBuy = false;
      if (!OrderGetInteger(ORDER_TYPE, orderType))
      {
        continue;
      }
      else
      {
        isBuy = (orderType == ORDER_TYPE_BUY || orderType == ORDER_TYPE_BUY_LIMIT ||
                 orderType == ORDER_TYPE_BUY_STOP || orderType == ORDER_TYPE_BUY_STOP_LIMIT);
      }

      double profit = 0;
      if (tp != 0)
      {
        double difference = isBuy ? (tp - price) : (price - tp);
        profit = (difference * lots * tickValue) / tickSize;
        orderSummary.profit += profit;
      }
      else
      {
        orderSummary.withoutTp++;
      }

      double loss = 0;
      if (sl != 0)
      {
        double difference = isBuy ? (price - sl) : (sl - price);
        loss = (difference * lots * tickValue) / tickSize;
        orderSummary.loss += loss;
      }
      else
      {
        orderSummary.withoutSl++;
      }

      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      orderSummary.risk = (orderSummary.loss / balance) * 100;

      Logger::Log(StringFormat("IsBuy: %s, OrderSelect: %d, Symbol: %s, Tp: %.5f, Price: %.5f, Sl: %.5f, TickValue: %.5f, TickSize: %.5f, Lots: %.2f, Profit: %.2f, Loss: %.2f, Risk: %.2f",
                               isBuy ? "true" : "false", ticket, symbol, tp, price, sl, tickValue, tickSize, lots, profit, loss, orderSummary.risk));
    }
  }

  static void CalculatePositionResults(SummaryDetail &positionSummary)
  {
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);

    for (int i = PositionsTotal() - 1; i >= 0; i--)
    {
      ulong ticket = PositionGetTicket(i);

      if (!PositionSelectByTicket(ticket))
      {
        Logger::Log("PositionSelectByTicket failed");
        continue;
      }

      string symbol;
      if (!PositionGetString(POSITION_SYMBOL, symbol) || symbol != Symbol())
      {
        continue;
      }

      double tp, price, sl, lots, result, tickValue, tickSize;
      if (!PositionGetDouble(POSITION_TP, tp) || !PositionGetDouble(POSITION_PRICE_OPEN, price) ||
          !PositionGetDouble(POSITION_SL, sl) || !PositionGetDouble(POSITION_VOLUME, lots) ||
          !PositionGetDouble(POSITION_PROFIT, result) ||
          !SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE, tickValue) ||
          !SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_SIZE, tickSize))
      {
        continue;
      }

      long positionType;
      bool isBuy = false;
      if (!PositionGetInteger(POSITION_TYPE, positionType))
      {
        continue;
      }
      else
      {
        isBuy = (positionType == POSITION_TYPE_BUY);
      }

      double profit = 0;
      if (tp != 0)
      {
        double difference = isBuy ? (tp - price) : (price - tp);
        profit = (difference * lots * tickValue) / tickSize;
        positionSummary.profit += profit;
      }
      else
      {
        positionSummary.withoutTp++;
      }

      double loss = 0;
      if (sl != 0)
      {
        double difference = isBuy ? (price - sl) : (sl - price);
        loss = (difference * lots * tickValue) / tickSize;
        positionSummary.loss += loss;
      }
      else
      {
        positionSummary.withoutSl++;
      }

      if (result != 0)
      {
        positionSummary.currentResult += result;
      }

      positionSummary.risk = (positionSummary.loss / balance) * 100;

      Logger::Log(StringFormat("IsBuy: %s, PositionSelect: %d, Symbol: %s, Tp: %.5f, Price: %.5f, Sl: %.5f, TickValue: %.5f, TickSize: %.5f, Lots: %.2f, Profit: %.2f, Loss: %.2f, Result: %.2f, Risk: %.2f",
                               isBuy ? "true" : "false", ticket, symbol, tp, price, sl, tickValue, tickSize, lots, profit, loss, result, positionSummary.risk));
    }
  }
};

// BreakEvenCalculator class to calculate break-even price
class BreakEvenCalculator
{
public:
  static void CalcBreakEven()
  {
    if (!InpPresentBELine)
      return;

    double totalBuySize = 0;
    double totalBuyPrice = 0;
    double totalSellSize = 0;
    double totalSellPrice = 0;

    for (int i = PositionsTotal() - 1; i >= 0; i--)
    {
      ulong ticket = PositionGetTicket(i);

      if (!PositionSelectByTicket(ticket))
      {
        Logger::Log("PositionSelectByTicket failed");
        continue;
      }

      string symbol;
      if (!PositionGetString(POSITION_SYMBOL, symbol) || symbol != Symbol())
      {
        continue;
      }

      double price, lots;
      if (!PositionGetDouble(POSITION_PRICE_OPEN, price) || !PositionGetDouble(POSITION_VOLUME, lots))
      {
        continue;
      }

      long positionType;
      if (!PositionGetInteger(POSITION_TYPE, positionType))
      {
        continue;
      }
      else
      {
        switch ((int)positionType)
        {
        case POSITION_TYPE_BUY:
          totalBuyPrice += price * lots;
          totalBuySize += lots;
          break;
        case POSITION_TYPE_SELL:
          totalSellPrice += price * lots;
          totalSellSize += lots;
          break;
        default:
          continue;
        }
      }
    }

    if (totalBuySize > 0)
    {
      totalBuyPrice /= totalBuySize;
    }

    if (totalSellSize > 0)
    {
      totalSellPrice /= totalSellSize;
    }

    double breakEvenPrice = (totalBuyPrice > 0 ? totalBuyPrice : totalSellPrice);
    ObjectCreate(0, "BreakEven_Line", OBJ_HLINE, 0, 0, breakEvenPrice);
    ObjectSetInteger(0, "BreakEven_Line", OBJPROP_COLOR, InpPresentBELineColor);
    ObjectSetInteger(0, "BreakEven_Line", OBJPROP_WIDTH, 1);
    ObjectSetInteger(0, "BreakEven_Line", OBJPROP_STYLE, STYLE_DASHDOTDOT);
    ObjectSetInteger(0, "BreakEven_Line", OBJPROP_BACK, true);
    string objectLabelBreakEvenLine = StringFormat(InpBELineLabel + " at %.5f", breakEvenPrice);
    ObjectSetString(0, "BreakEven_Line", OBJPROP_TEXT, objectLabelBreakEvenLine);
  }
};

// DisplayManager class to handle display of results
class DisplayManager
{
public:
  static void DisplayResults(const SummaryDetail &orderSummary, const SummaryDetail &positionSummary)
  {
    // order
    DrawLabel(0, "Order" + objectLabels[0], StringFormat("Proj Loss: %.2f", orderSummary.loss), InpNegativeColor);
    DrawLabel(1, "Order" + objectLabels[1], StringFormat("Proj Loss: %.1f%%", GetPercent(orderSummary.loss)), InpNegativeColor);
    DrawLabel(2, "Order" + objectLabels[2], " ", InpNeutralColor);
    DrawLabel(3, "Order" + objectLabels[3], " ", InpNeutralColor);
    DrawLabel(4, "Order" + objectLabels[4], StringFormat("Proj Win: %.2f", orderSummary.profit), InpPositiveColor);
    DrawLabel(5, "Order" + objectLabels[5], StringFormat("Proj Win: %.1f%%", GetPercent(orderSummary.profit)), InpPositiveColor);
    DrawLabel(6, "Order" + objectLabels[6], StringFormat("W/O SL %.0f /TP: %.0f", orderSummary.withoutSl, orderSummary.withoutTp), InpBackgroundColor);
    DrawLabel(7, "Order" + objectLabels[7], "-=Ord sum=-", InpBackgroundColor2);

    // position
    DrawLabel(0, "Position" + objectLabels[0], StringFormat("Proj Loss: %.2f", positionSummary.loss), InpNegativeColor, 1);
    DrawLabel(1, "Position" + objectLabels[1], StringFormat("Proj Loss: %.1f%%", GetPercent(positionSummary.loss)), InpNegativeColor, 1);
    DrawLabel(2, "Position" + objectLabels[2], StringFormat("Cur Res: %.2f", positionSummary.currentResult), InpNeutralColor, 1);
    DrawLabel(3, "Position" + objectLabels[3], StringFormat("Cur Res: %.1f%%", GetPercent(positionSummary.currentResult)), GetPercent(positionSummary.currentResult) >= 0 ? InpPositiveCurrentColor : InpNegativeColor, 1);
    DrawLabel(4, "Position" + objectLabels[4], StringFormat("Proj Win: %.2f", positionSummary.profit), InpPositiveColor, 1);
    DrawLabel(5, "Position" + objectLabels[5], StringFormat("Proj Win: %.1f%%", GetPercent(positionSummary.profit)), InpPositiveColor, 1);
    DrawLabel(6, "Position" + objectLabels[6], StringFormat("W/O SL %.0f /TP: %.0f", positionSummary.withoutSl, positionSummary.withoutTp), InpBackgroundColor, 1);
    DrawLabel(7, "Position" + objectLabels[7], "-=Pos sum=-", InpBackgroundColor2, 1);

    // combined
    DrawLabel(0, "Summary" + objectLabels[0], StringFormat("Proj Loss: %.2f", orderSummary.loss + positionSummary.loss), InpNegativeColor, 2);
    DrawLabel(1, "Summary" + objectLabels[1], StringFormat("Proj Loss: %.1f%%", GetPercent(orderSummary.loss + positionSummary.loss)), InpNegativeColor, 2);
    DrawLabel(2, "Summary" + objectLabels[2], " ", InpNeutralColor, 2);
    DrawLabel(3, "Summary" + objectLabels[3], " ", InpNeutralColor, 2);
    DrawLabel(4, "Summary" + objectLabels[4], StringFormat("Proj Win: %.2f", orderSummary.profit + positionSummary.profit), InpPositiveColor, 2);
    DrawLabel(5, "Summary" + objectLabels[5], StringFormat("Proj Win: %.1f%%", GetPercent(orderSummary.profit + positionSummary.profit)), InpPositiveColor, 2);
    DrawLabel(6, "Summary" + objectLabels[6], StringFormat("W/O SL %.0f /TP: %.0f", positionSummary.withoutSl + orderSummary.withoutSl, positionSummary.withoutTp + orderSummary.withoutTp), InpBackgroundColor, 2);
    DrawLabel(7, "Summary" + objectLabels[7], "-=Comb sum=-", InpBackgroundColor2, 2);

    ChartRedraw();
  }

private:
  static void DrawLabel(int row, string objectName, string text, int colorEnum, int column = 0)
  {
    if (ObjectFind(0, objectName) == -1)
      ObjectCreate(0, objectName, OBJ_LABEL, 0, 0, 0);

    LayoutConfig layout;

    // Set layout configuration based on selected size
    if (InpLayoutSize == small)
    {
      layout.horizontalColumnWidth = 100;
      layout.xDrawingStartingPoint = 10;
      layout.yHorizontalLineHeight = 13;
      layout.yVerticalLineHeight = 14;
      layout.columnMultiplier = 8;
      layout.fontSize = 8;
    }
    if (InpLayoutSize == normal)
    {
      layout.horizontalColumnWidth = 130;
      layout.xDrawingStartingPoint = 10;
      layout.yHorizontalLineHeight = 16;
      layout.yVerticalLineHeight = 18;
      layout.columnMultiplier = 8;
      layout.fontSize = 10;
    }

    int xDistance, yDistance;

    // Calculate distances based on orientation
    if (InpIsHorizontalOrientation)
    {
      xDistance = (column * layout.horizontalColumnWidth) + layout.xDrawingStartingPoint;
      yDistance = (row + 1) * layout.yHorizontalLineHeight;
    }
    else
    {
      xDistance = layout.xDrawingStartingPoint;
      yDistance = ((row + 1) * layout.yVerticalLineHeight) + (column * layout.columnMultiplier * layout.yVerticalLineHeight);
    }

    ObjectSetInteger(0, objectName, OBJPROP_CORNER, CORNER_LEFT_LOWER);
    ObjectSetInteger(0, objectName, OBJPROP_COLOR, colorEnum);
    ObjectSetInteger(0, objectName, OBJPROP_XDISTANCE, xDistance);
    ObjectSetInteger(0, objectName, OBJPROP_YDISTANCE, yDistance);
    ObjectSetInteger(0, objectName, OBJPROP_FONTSIZE, layout.fontSize);
    ObjectSetString(0, objectName, OBJPROP_TEXT, text);
  }

  static double GetPercent(double value)
  {
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    return (value / balance) * 100;
  }
};

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
  Logger::Log("Init");
  EventSetTimer(3);
  return (INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
  Logger::Log("Deinit");
  EventKillTimer();
  int Size = ArraySize(objectLabels);
  for (int i = 0; i < Size; i++)
  {
    ObjectsDeleteAll(0, "Order" + objectLabels[i]);
    ObjectsDeleteAll(0, "Position" + objectLabels[i]);
    ObjectsDeleteAll(0, "Summary" + objectLabels[i]);
  }
  ObjectsDeleteAll(0, "BreakEven_Line");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
}

//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
{
  Logger::Log("Timer hit");

  SummaryDetail orderSummary;
  SummaryDetail positionSummary;

  SummaryCalculator::InitializeStruct(orderSummary);
  SummaryCalculator::InitializeStruct(positionSummary);
  SummaryCalculator::CalculateOrderResults(orderSummary);
  SummaryCalculator::CalculatePositionResults(positionSummary);
  BreakEvenCalculator::CalcBreakEven();
  DisplayManager::DisplayResults(orderSummary, positionSummary);
}
