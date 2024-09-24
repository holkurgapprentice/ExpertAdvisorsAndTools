//+------------------------------------------------------------------+
//|                                             CurrentResult_v1.mq5 |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link "https://www.mql5.com"
#property version "1.00"

// Global variables
double currentResult = 0;
double projWin = 0;
double projLoss = 0;

//--- input parameters
input bool IsLogginEnabled = false;
input int RedRiskLevel = 20;
input bool IsHorizontalOrientation = true;
input bool InpPresentBELine = true;

string objectLabels[] = {
    "Risk",
    "ProjLoss",
    "CurrentResult",
    "ProjWin",
    "WithoutTpOrSl",
    "Label"};

struct SummaryDetail
{
  double currentResult;
  double profit;
  double loss;
  int withoutTpOrSl;
  double risk;
};

SummaryDetail orderSummary;
SummaryDetail positionSummary;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
  // create a timer with a N second period
  EventSetTimer(3);
  if (RedRiskLevel <= 0 || RedRiskLevel > 1000)
  {
    MessageBox("RedRiskLevel should be between 1 and 1000", "Error", MB_ICONERROR);
    return (INIT_FAILED);
  }
  return (INIT_SUCCEEDED);
}

void InitializeStruct(SummaryDetail &summary)
{
  summary.currentResult = 0;
  summary.profit = 0;
  summary.loss = 0;
  summary.withoutTpOrSl = 0;
  summary.risk = 0;
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
  // destroy the timer after completing the work
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
  InitializeStruct(orderSummary);
  InitializeStruct(positionSummary);
  CalculateResults();
  DisplayResults();
}

// Calculate current results and projections
void CalculateResults()
{
  CalculateOrderResults();
  CalculatePositionResults();
  CalcBreakEven();
}

void CalculatePositionResults()
{
  for (int i = PositionsTotal() - 1; i >= 0; i--)
  {
    ulong ticket = PositionGetTicket(i);

    if (!PositionSelectByTicket(ticket))
    {
      PrintFormat("PositionSelectByTicket failed");
      continue;
    }

    string symbol;
    if (!PositionGetString(POSITION_SYMBOL, symbol) || symbol != Symbol())
    {
      continue;
    }

    double tp;
    if (!PositionGetDouble(POSITION_TP, tp))
    {
      continue;
    }

    double price;
    if (!PositionGetDouble(POSITION_PRICE_OPEN, price))
    {
      continue;
    }

    double sl;
    if (!PositionGetDouble(POSITION_SL, sl))
    {
      continue;
    }

    long positionType;
    bool isBuy;
    if (!PositionGetInteger(POSITION_TYPE, positionType))
    {
      continue;
    }
    else
    {
      switch ((int)positionType)
      {
      case POSITION_TYPE_BUY:
      {
        isBuy = true;
        break;
      }
      case POSITION_TYPE_SELL:
      {
        isBuy = false;
        break;
      }
      default:
        continue;
        break;
      }
    }

    double lots;
    if (!PositionGetDouble(POSITION_VOLUME, lots))
    {
      continue;
    }

    double result;
    if (!PositionGetDouble(POSITION_PROFIT, result))
    {
      continue;
    }

    double tickValue;
    if (!SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE, tickValue))
    {
      continue;
    }

    double tickSize;
    if (!SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_SIZE, tickSize))
    {
      continue;
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
      positionSummary.withoutTpOrSl++;
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
      positionSummary.withoutTpOrSl++;
    }

    if (result != 0)
    {
      positionSummary.currentResult += result;
    }

    double ballance = AccountInfoDouble(ACCOUNT_BALANCE);
    positionSummary.risk = (positionSummary.loss / ballance) * 100;

    if (IsLogginEnabled)
    {
      PrintFormat("IsBuy: %s, PositionSelect: %d, Symbol: %s, Tp: %.5f, Price: %.5f, Sl: %.5f, TickValue: %.5f, TickSize: %.5f, Lots: %.2f, Profit: %.2f, Loss: %.2f, Result: %.2f, Risk: %.2f",
                  isBuy ? "true" : "false", ticket, symbol, tp, price, sl, tickValue, tickSize, lots, profit, loss, result, positionSummary.risk);
    }
  }
}

void CalculateOrderResults()
{
  for (int i = OrdersTotal() - 1; i >= 0; i--)
  {
    ulong ticket = OrderGetTicket(i);

    if (!OrderSelect(ticket))
    {
      PrintFormat("OrderSelect failed");
      continue;
    }

    string symbol;
    if (!OrderGetString(ORDER_SYMBOL, symbol) || symbol != Symbol())
    {
      continue;
    }

    double tp;
    if (!OrderGetDouble(ORDER_TP, tp))
    {
      continue;
    }

    double price;
    if (!OrderGetDouble(ORDER_PRICE_OPEN, price))
    {
      continue;
    }

    double sl;
    if (!OrderGetDouble(ORDER_SL, sl))
    {
      continue;
    }

    long orderType;
    bool isBuy;
    if (!OrderGetInteger(ORDER_TYPE, orderType))
    {
      continue;
    }
    else
    {
      switch ((int)orderType)
      {
      case ORDER_TYPE_BUY:
      case ORDER_TYPE_BUY_LIMIT:
      case ORDER_TYPE_BUY_STOP:
      case ORDER_TYPE_BUY_STOP_LIMIT:
      {
        isBuy = true;
        break;
      }
      case ORDER_TYPE_SELL:
      case ORDER_TYPE_SELL_LIMIT:
      case ORDER_TYPE_SELL_STOP:
      case ORDER_TYPE_SELL_STOP_LIMIT:
      {
        isBuy = false;
        break;
      }
      default:
        continue;
        break;
      }
    }

    double lots;
    if (!OrderGetDouble(ORDER_VOLUME_CURRENT, lots))
    {
      continue;
    }

    double tickValue;
    if (!SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE, tickValue))
    {
      continue;
    }

    double tickSize;
    if (!SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_SIZE, tickSize))
    {
      continue;
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
      orderSummary.withoutTpOrSl++;
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
      orderSummary.withoutTpOrSl++;
    }

    double ballance = AccountInfoDouble(ACCOUNT_BALANCE);
    orderSummary.risk = (orderSummary.loss / ballance) * 100;

    if (IsLogginEnabled)
    {
      PrintFormat("IsBuy: %s, OrderSelect: %d, Symbol: %s, Tp: %.5f, Price: %.5f, Sl: %.5f, TickValue: %.5f, TickSize: %.5f, Lots: %.2f, Profit: %.2f, Loss: %.2f, Risk: %.2f",
                  isBuy ? "true" : "false", ticket, symbol, tp, price, sl, tickValue, tickSize, lots, profit, loss, orderSummary.risk);
    }
  }
}

void CalcBreakEven()
{
  if (!InpPresentBELine)
    return;

  int buyCount = 0;
  int sellCount = 0;
  double totalBuySize = 0;
  double totalBuyPrice = 0;
  double totalSellSize = 0;
  double totalSellPrice = 0;

  for (int i = PositionsTotal() - 1; i >= 0; i--)
  {
    ulong ticket = PositionGetTicket(i);

    if (!PositionSelectByTicket(ticket))
    {
      PrintFormat("PositionSelectByTicket failed");
      continue;
    }

    string symbol;
    if (!PositionGetString(POSITION_SYMBOL, symbol) || symbol != Symbol())
    {
      continue;
    }

    double price;
    if (!PositionGetDouble(POSITION_PRICE_OPEN, price))
    {
      continue;
    }

    double lots;
    if (!PositionGetDouble(POSITION_VOLUME, lots))
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
      {
        buyCount++;
        totalBuyPrice += price * lots;
        totalBuySize += lots;
        break;
      }
      case POSITION_TYPE_SELL:
      {
        sellCount++;
        totalSellPrice += price * lots;
        totalSellSize += lots;
        break;
      }
      default:
        continue;
        break;
      }
    }
  }

  if (totalBuyPrice > 0)
  {
    totalBuyPrice /= totalBuySize;
  }

  if (totalSellPrice > 0)
  {
    totalSellPrice /= totalSellSize;
  }

  ObjectCreate(0, "BreakEven_Line", OBJ_HLINE, 0, 0, totalBuyPrice > 0 ? totalBuyPrice : totalSellPrice);
  ObjectSetInteger(0, "BreakEven_Line", OBJPROP_COLOR, clrGreen);
  ObjectSetInteger(0, "BreakEven_Line", OBJPROP_WIDTH, 1);
  ObjectSetInteger(0, "BreakEven_Line", OBJPROP_STYLE, STYLE_DASHDOTDOT);
  ObjectSetInteger(0, "BreakEven_Line", OBJPROP_BACK, false);
  string objectLabelBreakEvenLine = StringFormat(" BreakEven line at %.5f", (totalBuyPrice > 0 ? totalBuyPrice : totalSellPrice));
  ObjectSetString(0, "BreakEven_Line", OBJPROP_TEXT, objectLabelBreakEvenLine);
}

// Display results on the chart
void DisplayResults()
{
  // order
  DrawLabel(0, "Order" + objectLabels[0], StringFormat("Risk: %.2f%%", orderSummary.risk), orderSummary.risk < RedRiskLevel ? clrBlue : clrRed);
  DrawLabel(1, "Order" + objectLabels[1], StringFormat("Proj Loss: %.2f", orderSummary.loss), clrRed);
  DrawLabel(2, "Order" + objectLabels[2], StringFormat("Cur Res: %.2f", orderSummary.currentResult), clrBlack);
  DrawLabel(3, "Order" + objectLabels[3], StringFormat("Proj Win: %.2f", orderSummary.profit), clrGreen);
  DrawLabel(4, "Order" + objectLabels[4], StringFormat("With SL/TP: %.0f", orderSummary.withoutTpOrSl), clrGray);
  DrawLabel(5, "Order" + objectLabels[5], "-=Ord sum=-", clrDarkBlue);

  // position
  DrawLabel(0, "Position" + objectLabels[0], StringFormat("Risk: %.2f%%", positionSummary.risk), positionSummary.risk < RedRiskLevel ? clrBlue : clrRed, 1);
  DrawLabel(1, "Position" + objectLabels[1], StringFormat("Proj Loss: %.2f", positionSummary.loss), clrRed, 1);
  DrawLabel(2, "Position" + objectLabels[2], StringFormat("Cur Res: %.2f", positionSummary.currentResult), clrBlack, 1);
  DrawLabel(3, "Position" + objectLabels[3], StringFormat("Proj Win: %.2f", positionSummary.profit), clrGreen, 1);
  DrawLabel(4, "Position" + objectLabels[4], StringFormat("With SL/TP: %.0f", positionSummary.withoutTpOrSl), clrGray, 1);
  DrawLabel(5, "Position" + objectLabels[5], "-=Pos sum=-", clrDarkBlue, 1);

  // combined
  DrawLabel(0, "Summary" + objectLabels[0], StringFormat("Risk: %.2f%%", orderSummary.risk + positionSummary.risk), (orderSummary.risk + positionSummary.risk) < RedRiskLevel ? clrBlue : clrRed, 2);
  DrawLabel(1, "Summary" + objectLabels[1], StringFormat("Proj Loss: %.2f", orderSummary.loss + positionSummary.loss), clrRed, 2);
  DrawLabel(2, "Summary" + objectLabels[2], StringFormat("Cur Res: %.2f", orderSummary.currentResult + positionSummary.currentResult), clrBlack, 2);
  DrawLabel(3, "Summary" + objectLabels[3], StringFormat("Proj Win: %.2f", orderSummary.profit + positionSummary.profit), clrGreen, 2);
  DrawLabel(4, "Summary" + objectLabels[4], StringFormat("With SL/TP: %.0f", orderSummary.withoutTpOrSl + positionSummary.withoutTpOrSl), clrGray, 2);
  DrawLabel(5, "Summary" + objectLabels[5], "-=Comb sum=-", clrDarkBlue, 2);

  ChartRedraw();
}

void DrawLabel(int row, string objectName, string text, int clr, int column = 0)
{
  if (ObjectFind(0, objectName) == -1)
  {
    if (IsHorizontalOrientation)
    {
      ObjectCreate(0, objectName, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, objectName, OBJPROP_CORNER, CORNER_LEFT_LOWER);
      ObjectSetInteger(0, objectName, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, objectName, OBJPROP_XDISTANCE, (column * 135) + 10);
      ObjectSetInteger(0, objectName, OBJPROP_YDISTANCE, (row + 1) * 18);
    }
    else
    {
      ObjectCreate(0, objectName, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, objectName, OBJPROP_CORNER, CORNER_LEFT_LOWER);
      ObjectSetInteger(0, objectName, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, objectName, OBJPROP_XDISTANCE, 10);
      ObjectSetInteger(0, objectName, OBJPROP_YDISTANCE, ((row + 1) * 18) + (column * 7 * 18));
    }
  }

  ObjectSetString(0, objectName, OBJPROP_TEXT, text);
}