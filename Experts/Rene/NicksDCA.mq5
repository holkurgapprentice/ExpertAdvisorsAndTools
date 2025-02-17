#include <Trade/Trade.mqh>
#include <Arrays/ArrayLong.mqh>
#include <Arrays/ArrayObj.mqh>

class CSymbol : public CObject
{
public:
  CSymbol(string name) : symbol(name) {};
  ~CSymbol() {};

  string symbol;
  CArrayLong tickets;
  int handleAtr;
};

input double InpLots = 0.01;
input int InpIncreaseAfterX = 5;
input int InpPeriodsBack = 30;
input int InpFromHour = 10;
input double InpTriggerPercent = 8.0;
input double InpStepPercent = 2.0;
input double InpTpLotstep = 10;
input int InpAtrPeriods = 14;
input ENUM_TIMEFRAMES InpAtrTimeframe = PERIOD_H1;
input int InpAtrDeclinePeriod = 5;

CArrayObj symbols;
int barsTotal;
string arrSymbols[] = {
    _Symbol,
    // majors
    // "AUDUSD",
    // "EURUSD",
    // "GBPUSD",
    // "USDCAD",
    // "USDCHF",
    // "USDJPY",
    // minors
    // "AUDCAD",
    // "AUDCHF",
    // "AUDJPY",
    // "AUDNZD",
    // "CADCHF",
    // "CADJPY",
    // "CHFJPY",
    // "EURAUD",
    // "EURCAD",
    // "EURCHF",
    // "EURGBP",
    // "EURJPY",
    // "EURNZD",
    // "GBPAUD",
    // "GBPCAD",
    // "GBPCHF",
    // "GBPJPY",
    // "GBPNZD",
    // "NZDCAD",
    // "NZCCHF",
    // "NZDJPY",
    // "NZDUSD"
    // "USDSGD",
};

int OnInit()
{
  symbols.Clear();
  for (int i = ArraySize(arrSymbols) - 1; i >= 0; i--)
  {
    CSymbol *symbol = new CSymbol(arrSymbols[i]);
    symbol.handleAtr = iATR(symbol.symbol, InpAtrTimeframe, InpAtrPeriods);
    symbols.Add(symbol);
  }

  return (INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
}

void OnTick()
{
  MqlDateTime dt;
  TimeCurrent(dt);

  int bars = iBars(_Symbol, InpAtrTimeframe);
  if (barsTotal == bars || dt.hour < InpFromHour)
    return;

  barsTotal = bars;

  for (int j = symbols.Total() - 1; j >= 0; j--)
  {
    CSymbol *symbol = symbols.At(j);
    CTrade trade;

    double bid = SymbolInfoDouble(symbol.symbol, SYMBOL_BID);

    double atr[];
    CopyBuffer(symbol.handleAtr, MAIN_LINE, 1, InpAtrDeclinePeriod, atr);
    bool isAtrSignal = atr[InpAtrDeclinePeriod - 1] < atr[0];

    double profit = 0;
    double lots = 0;
    for (int i = symbol.tickets.Total() - 1; i >= 0; i--)
    {
      CPositionInfo pos;
      if (pos.SelectByTicket(symbol.tickets.At(i)))
      {
        profit += pos.Profit() + pos.Swap();
        lots += pos.Volume();
        if (i == symbol.tickets.Total() - 1 && isAtrSignal)
        {
          if (pos.PositionType() == POSITION_TYPE_BUY && bid < pos.PriceOpen() - pos.PriceOpen() * InpStepPercent / 100)
          {
            Print(__FUNCTION__, " > Step buy signal for", symbol.symbol, "...");

            double lots = InpLots;
            if (symbol.tickets.Total() >= InpIncreaseAfterX)
              lots += InpLots * (symbol.tickets.Total() - InpIncreaseAfterX + 1);

            trade.Buy(lots, symbol.symbol);
          }
          else if (pos.PositionType() == POSITION_TYPE_SELL && bid > pos.PriceOpen() + pos.PriceOpen() * InpStepPercent / 100)
          {
            Print(__FUNCTION__, " > Step sell signal for", symbol.symbol, "...");

            double lots = InpLots;
            if (symbol.tickets.Total() >= InpIncreaseAfterX)
              lots += InpLots * (symbol.tickets.Total() - InpIncreaseAfterX + 1);

            trade.Sell(lots, symbol.symbol);
          }
        }
      }
    }

    if (symbol.tickets.Total() == 0 && isAtrSignal)
    {
      // create first transaction for symbol
      double openBack = iOpen(symbol.symbol, Period(), InpPeriodsBack);

      if (MathAbs(openBack - bid) / openBack > InpTriggerPercent / 100)
      {
        if (openBack < bid)
        {
          Print(__FUNCTION__, " > First sell signal for ", symbol.symbol, "...");
          trade.Sell(InpLots, symbol.symbol);
        }
        else
        {
          Print(__FUNCTION__, " > First buy signal for ", symbol.symbol, "...");
          trade.Buy(InpLots, symbol.symbol);
        }
      }
    }

    if (trade.ResultOrder() > 0 && trade.ResultRetcode() == TRADE_RETCODE_DONE)
    {
      // add ticket reference if created
      Print(__FUNCTION__, " > Ticket added for ", symbol.symbol, "...");
      symbol.tickets.Add(trade.ResultOrder());
    }

    if (profit > InpTpLotstep * symbol.tickets.Total())
    {
      // close profiting trasactions
      Print(__FUNCTION__, " > Hit profit for ", symbol.symbol, " profit ", profit, " tp lotstep ", InpTpLotstep * symbol.tickets.Total(), " ... " );
      for (int i = symbol.tickets.Total() - 1; i >= 0; i--)
      {
        CPositionInfo pos;
        if (pos.SelectByTicket(symbol.tickets.At(i)))
        {
          if (trade.PositionClose(pos.Ticket()))
          {
            symbol.tickets.Delete(i);
          }
        }
      }
    }
  }
}