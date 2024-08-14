// Te linie to średnia krocząca (exponential movement average)
// Pomarańcz 25
// Niebieska 50
// Czerowna 100
// na H4 grane

// jak wszstkie są w ułożeniu od najmniejszej 25 - 50 - 100 to mamy trend wzrostowy
// jak są w drugą stronę 100 50 25 to spadkowy

// jak cena zejdzie pod 50 w stronę 100 to transakcja (połowa normalnej transakcji)
// jak cena zejdzie pod 100 to cała transakcjamamy  (mamy 1,5 normalnej pozycji w grze)
// jak cena spadnie jeszcze mały kawałek np 100 pips to wszystko zamykamy ze stratą
// ale jak wejdzie do góry to czekamy aż wróci na 25

// Patrze sobie na te strategie, ma to na EURUSD szanse zarobić

// jak mamy buy i cena wejdzie powyzej 25 to SL na 50tke
// jak wyjdziemy ZMEINNA ilosc punktow ponad 25 to SL po świeczkach

// filtr na minimalna odleglosc miedzy srednimi

// rozpoznawanie ranging market i gra od krawędzi do środka
// ATR na 14 a w nim ema na 50 ale oparta na first indicator data
// jak ATR jest pod EMA to oznacza że mamy ranging market

// https://www.mql5.com/en/forum/309671
//  You can use iMAOnArray:

// for(int i=rates_total-14-1;i>=0;i--) {
//    static double buffer[14];
//    adx[i] = iADX(NULL,0,14,PRICE_CLOSE,MODE_MAIN,i);
//    ArrayCopy(buffer,adx,0,i,14);
//    ma[i] = iMAOnArray(buffer,0,14,0,MODE_SMA,0);
// }

//+------------------------------------------------------------------+
//|                                       ThreeEMAsMyOwnStrategy.mq5 |
//|                                  Copyright 2022, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2022, MetaQuotes Ltd."
#property link "https://www.mql5.com"
#property version "1.00"

#include <Trade/Trade.mqh>

int maFastHandle;
int maMiddleHandle;
int maSlowHandle;
int rsiHandle;
MqlTick previousTick;
MqlTick currentTick;
bool isFilterCandleOn = false;
enum TRAIL_SL_MODE
{
	OFF,				 // Off
	BY_CURRENT_LOWER_EMA // All entries will be trailed by previous EMA
};

enum ENTER_MODE_PRICE_ENUM
{
	EMPE_OFF,			  // Off
	ONLY_IF_BETTER_PRICE, // All entries will be opened by better prices
	ONLY_IF_WORSE_PRICE	  // All entries will be opened by worse prices
};

struct POSTION_INFO_STRUCT
{
	double bestBuyPrice;
	double bestSellPrice;
	double worstBuyPrice;
	double worstSellPrice;

	POSTION_INFO_STRUCT() : bestBuyPrice(0),
							bestSellPrice(0),
							worstBuyPrice(0),
							worstSellPrice(0){};
};

struct POSTION_SUMMARY_STRUCT
{
	int smallCount;
	POSTION_INFO_STRUCT small;
	int mediumCount;
	POSTION_INFO_STRUCT medium;
	int fullCount;
	POSTION_INFO_STRUCT full;

	POSTION_SUMMARY_STRUCT() : smallCount(0),
							   small(),
							   mediumCount(0),
							   medium(),
							   fullCount(0),
							   full(){};
};
POSTION_SUMMARY_STRUCT positionSummary;

CTrade trade;

input group "====General input====";
input long InpMagicNumber = 700000;
input int InpValueMaFast = 20;
input int InpValueMaMiddle = 50;
input int InpValueMaSlow = 100;
input int InpSlowMargin = 100;
input double InpLots = 0.1;
input TRAIL_SL_MODE InpTrailingSl = OFF;

input group "====Filtering setup====";
input int InpValueRsi = 6;									  // RSI setup; step=1
input double InpValueRsiFilterThresholdDistance = 12.5;		  // RSI Filter threshold; step=.5;0=off
input int InpMaSizeFilter = 100;							  // MA channel size up-pass filter; step=1;0=off
input double InpSmallTryFactor = 1.35;						  // Small try factor; step=.05;0=wrong
input int InpDepositLoad = 25;								  // Deposit load percentage down-pass; step=1;0=off
input int InpSmallPositionsMax = 0;							  // Max small positions; step=1;0=off
input int InpMediumPositionsMax = 0;						  // Max medium positions; step=1;0=off
input int InpFullPositionsMax = 0;							  // Max full positions; step=1;0=off
input ENTER_MODE_PRICE_ENUM InpNewPositionPriceLevelShouldBe; // New position only when price is

input group "====Extras===";
input bool InpShowInfo = true;

int OnInit()
{
	bool initResult = true;
	trade.SetExpertMagicNumber(InpMagicNumber);

	maFastHandle = iMA(_Symbol, PERIOD_CURRENT, InpValueMaFast, 0, MODE_EMA, PRICE_CLOSE);
	maMiddleHandle = iMA(_Symbol, PERIOD_CURRENT, InpValueMaMiddle, 0, MODE_EMA, PRICE_CLOSE);
	maSlowHandle = iMA(_Symbol, PERIOD_CURRENT, InpValueMaSlow, 0, MODE_EMA, PRICE_CLOSE);
	rsiHandle = iRSI(_Symbol, PERIOD_CURRENT, InpValueRsi, PRICE_OPEN);

	CheckInitResult(initResult, (INVALID_HANDLE != maFastHandle), "Ma fast handle init error");
	CheckInitResult(initResult, (INVALID_HANDLE != maMiddleHandle), "Ma middle handle init error");
	CheckInitResult(initResult, (INVALID_HANDLE != maSlowHandle), "Ma slow handle init error");
	CheckInitResult(initResult, (INVALID_HANDLE != rsiHandle), "Ma rsi handle init error");

	CheckInitResult(initResult, (InpValueMaFast > 0), "Ma fast should be bigger than 0");
	CheckInitResult(initResult, (InpValueMaMiddle > 0), "Ma middle should be bigger than 0");
	CheckInitResult(initResult, (InpValueMaSlow > 0), "Ma slow should be bigger than 0");

	CheckInitResult(initResult, (InpValueMaFast < InpValueMaMiddle), "Ma fast should be smaller than ma middle");
	CheckInitResult(initResult, (InpValueMaMiddle < InpValueMaSlow), "Ma middle should be smaller than ma slow");
	CheckInitResult(initResult, (InpLots > 0), "Lots should be bigger than 0");
	CheckInitResult(initResult, (InpValueRsiFilterThresholdDistance >= 0), "RSI Filter threshold should be bigger than 0 or 0");
	CheckInitResult(initResult, (InpSmallTryFactor > 0), "Small try factor should be bigger than 0");
	CheckInitResult(initResult, (InpDepositLoad >= 0), "Deposit load percentage should be bigger than 0 or 0");

	CheckInitResult(initResult, (InpSmallPositionsMax >= 0), "Max small positions should be bigger than 0 or 0");
	CheckInitResult(initResult, (InpMediumPositionsMax >= 0), "Max medium positions should be bigger than 0 or 0");
	CheckInitResult(initResult, (InpFullPositionsMax >= 0), "Max full positions should be bigger than 0 or 0");

	if (initResult)
	{
		return (INIT_SUCCEEDED);
	}
	else
	{
		return (INIT_PARAMETERS_INCORRECT);
	}
}

void OnDeinit(const int reason)
{
	IndicatorRelease(maFastHandle);
	IndicatorRelease(maMiddleHandle);
	IndicatorRelease(maSlowHandle);
	IndicatorRelease(rsiHandle);
}

void OnTick()
{
	// read values from indicators
	double bufferMaFast[], bufferMaMiddle[], bufferMaSlow[], bufferRsi[];
	CopyBuffer(maFastHandle, 0, 0, 1, bufferMaFast);
	CopyBuffer(maMiddleHandle, 0, 0, 1, bufferMaMiddle);
	CopyBuffer(maSlowHandle, 0, 0, 1, bufferMaSlow);
	CopyBuffer(rsiHandle, 0, 0, 1, bufferRsi);

	if (InpTrailingSl == BY_CURRENT_LOWER_EMA)
	{
		TrailByLowerEma(bufferMaMiddle, bufferMaSlow);
	}

	if (!IsNewBar() && isFilterCandleOn)
	{
		return;
	}

	// read values from open positions
	PositionSummaryInit();

	previousTick = currentTick;
	if (!SymbolInfoTick(_Symbol, currentTick))
	{
		PrintIfInfo("Failed to get current tick");
		return;
	}

	// 1 for uptrend, 0 unknown, -1 for downtrend
	int trendDirection = getTrendDirection(bufferMaFast, bufferMaMiddle, bufferMaSlow);

	// filter out if trend is below size filter
	if (InpMaSizeFilter > 0 && trendDirection != 0 && ShouldBeFiltered(trendDirection, bufferMaSlow, bufferMaFast))
	{
		PrintIfInfo("❌ Filtered out trade due to MA size filtering");
		return;
	}

	double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

	// filter out when deposit load is too high
	if (InpDepositLoad > 0 && ShouldBeFilteredDepositLoad())
	{
		return;
	}

	if (trendDirection == 1)
	{
		ShouldBuy(bufferMaFast, bufferMaMiddle, bufferMaSlow, bufferRsi, trendDirection);
	}

	if (trendDirection == -1)
	{
		ShouldSell(bufferMaFast, bufferMaMiddle, bufferMaSlow, bufferRsi, trendDirection);
	}
}

bool IsNewBar()
{
	static datetime previousTime = 0;
	datetime currentTime = iTime(_Symbol, PERIOD_CURRENT, 0);
	if (previousTime != currentTime)
	{
		isFilterCandleOn = false;
		previousTime = currentTime;
		return true;
	}
	return false;
}

int getTrendDirection(double &bufferMaFast[], double &bufferMaMiddle[], double &bufferMaSlow[])
{
	if (bufferMaFast[0] > bufferMaMiddle[0] && bufferMaMiddle[0] > bufferMaSlow[0])
	{
		return 1;
	}
	else if (bufferMaFast[0] < bufferMaMiddle[0] && bufferMaMiddle[0] < bufferMaSlow[0])
	{
		return -1;
	}
	else
	{
		return 0;
	}
}

void ShouldBuy(double &bufferMaFast[], double &bufferMaMiddle[], double &bufferMaSlow[], double &bufferRsi[], int trendDirection)
{
	double slowMarginValue = bufferMaSlow[0] - (InpSlowMargin * _Point);
	if (currentTick.bid <= slowMarginValue)
	{
		PrintIfInfo("ShouldBuy - nothing should happen - below slow margin zone");
		return;
	}

	if (bufferMaSlow[0] - slowMarginValue <= currentTick.bid && currentTick.bid <= bufferMaSlow[0])
	{
		PrintIfInfo("ShouldBuy - full lot - slow margin zone");

		if (InpFullPositionsMax != 0 && InpFullPositionsMax <= positionSummary.fullCount)
		{
			PrintIfInfo("Full volume positions max count reached");
			return;
		}

		if (InpNewPositionPriceLevelShouldBe != EMPE_OFF)
		{
			if (ShouldBeFilteredByPriceLevel("fu", currentTick.ask, trendDirection))
			{
				return;
			}
		}

		double sl = NormalizeDouble(slowMarginValue, _Digits);
		double tp = NormalizeDouble(bufferMaFast[0], _Digits);

		double currentLot = InpLots;
		if (!CheckLots(currentLot))
		{
			PrintIfInfo("ShouldBuy - CheckLots failed");
			return;
		}

		if (!trade.PositionOpen(_Symbol, ORDER_TYPE_BUY, currentLot, previousTick.ask, sl, tp, "fu"))
		{
			PrintFormat("❌[ShouldBuy]:  PositionOpen failed: sl %f; tp: %f; lots: %f, || %d :: %s",
						sl, tp, currentLot,
						trade.ResultRetcode(),
						trade.ResultRetcodeDescription());
		}

		isFilterCandleOn = true;
		return;
	}

	if (bufferMaSlow[0] <= currentTick.bid && currentTick.bid <= bufferMaMiddle[0])
	{
		PrintIfInfo("ShouldBuy - should by 0.5 of stake - we are close");

		if (InpMediumPositionsMax != 0 && InpMediumPositionsMax <= positionSummary.mediumCount)
		{
			PrintIfInfo("Medium positions max count reached");
			return;
		}

		if (InpNewPositionPriceLevelShouldBe != EMPE_OFF)
		{
			if (ShouldBeFilteredByPriceLevel("me", currentTick.ask, trendDirection))
			{
				return;
			}
		}

		double sl = NormalizeDouble(bufferMaSlow[0], _Digits);
		double tp = NormalizeDouble(bufferMaFast[0], _Digits);

		double halfLot = InpLots / 2;
		if (!CheckLots(halfLot))
		{
			PrintIfInfo("ShouldBuy - CheckLots failed");
			return;
		}

		if (NormalizeDouble(sl, _Digits) == NormalizeDouble(tp, _Digits) ||
			NormalizeDouble(sl, _Digits) == NormalizeDouble(currentTick.ask, _Digits) ||
			NormalizeDouble(tp, _Digits) == NormalizeDouble(currentTick.ask, _Digits))
		{
			PrintIfInfo("ShouldBuy - sl == tp || sl == currentTick.bid || tp == currentTick.bid - no way to send positions");
			return;
		}

		if (!trade.PositionOpen(_Symbol, ORDER_TYPE_BUY, halfLot, previousTick.ask, sl, tp, "me"))
		{
			PrintFormat("❌[ShouldBuy]:  PositionOpen failed: sl %f; tp: %f; lots: %f, || %d :: %s",
						sl, tp, halfLot,
						trade.ResultRetcode(),
						trade.ResultRetcodeDescription());
		}
		isFilterCandleOn = true;
		return;
	}

	if (currentTick.bid <= bufferMaFast[0])
	{
		PrintIfInfo("ShouldBuy - should by 0.25 of stake - just a small try");

		if (InpValueRsiFilterThresholdDistance > 0 && bufferRsi[0] > InpValueRsiFilterThresholdDistance + 30)
		{
			PrintIfInfo("RSI filter #ON - filtered out");
			return;
		}

		if (InpSmallPositionsMax != 0 && InpSmallPositionsMax <= positionSummary.smallCount)
		{
			PrintIfInfo("Small positions max count reached");
			return;
		}

		if (InpNewPositionPriceLevelShouldBe != EMPE_OFF)
		{
			if (ShouldBeFilteredByPriceLevel("sm", currentTick.ask, trendDirection))
			{
				return;
			}
		}

		double sl = NormalizeDouble(bufferMaMiddle[0], _Digits);
		double tp = NormalizeDouble(((currentTick.bid - bufferMaMiddle[0]) * InpSmallTryFactor) + currentTick.bid, _Digits);

		double quarterOfLot = InpLots / 4;
		if (!CheckLots(quarterOfLot))
		{
			PrintIfInfo("ShouldBuy - CheckLots failed");
			return;
		}

		if (!trade.PositionOpen(_Symbol, ORDER_TYPE_BUY, quarterOfLot, previousTick.ask, sl, tp, "sm"))
		{
			PrintFormat("❌[ShouldBuy]:  PositionOpen failed: sl %f; tp: %f; lots: %f, || %d :: %s",
						sl, tp, quarterOfLot,
						trade.ResultRetcode(),
						trade.ResultRetcodeDescription());
		}
		isFilterCandleOn = true;
		return;
	}
}

void ShouldSell(double &bufferMaFast[], double &bufferMaMiddle[], double &bufferMaSlow[], double &bufferRsi[], int trendDirection)
{
	double slowMarginValue = bufferMaSlow[0] + (InpSlowMargin * _Point);
	if (currentTick.bid >= slowMarginValue)
	{
		PrintIfInfo("ShouldSell - nothing should happen - above slow margin zone");
		return;
	}

	if (currentTick.bid <= bufferMaSlow[0] + slowMarginValue && bufferMaSlow[0] <= currentTick.bid)
	{
		PrintIfInfo("ShouldSell - full lot - slow margin zone");

		if (InpFullPositionsMax != 0 && InpFullPositionsMax <= positionSummary.fullCount)
		{
			PrintIfInfo("Full volume positions max count reached");
			return;
		}

		if (InpNewPositionPriceLevelShouldBe != EMPE_OFF)
		{
			if (ShouldBeFilteredByPriceLevel("fu", currentTick.bid, trendDirection))
			{
				return;
			}
		}

		double sl = NormalizeDouble(slowMarginValue, _Digits);
		double tp = NormalizeDouble(bufferMaFast[0], _Digits);

		double currentLot = InpLots;
		if (!CheckLots(currentLot))
		{
			PrintIfInfo("ShouldSell - CheckLots failed");
			return;
		}

		if (!trade.PositionOpen(_Symbol, ORDER_TYPE_SELL, currentLot, previousTick.bid, sl, tp, "fu"))
		{
			PrintFormat("❌[ShouldSell]:  PositionOpen failed: sl %f; tp: %f; lots: %f, || %d :: %s",
						sl, tp, currentLot,
						trade.ResultRetcode(),
						trade.ResultRetcodeDescription());
		}
		isFilterCandleOn = true;
		return;
	}

	if (currentTick.bid <= bufferMaSlow[0] && bufferMaMiddle[0] <= currentTick.bid)
	{
		PrintIfInfo("ShouldSell - should by 0.5 of stake - we are close");

		if (InpMediumPositionsMax != 0 && InpMediumPositionsMax <= positionSummary.mediumCount)
		{
			PrintIfInfo("Medium positions max count reached");
			return;
		}

		if (InpNewPositionPriceLevelShouldBe != EMPE_OFF)
		{
			if (ShouldBeFilteredByPriceLevel("me", currentTick.bid, trendDirection))
			{
				return;
			}
		}

		double sl = NormalizeDouble(bufferMaSlow[0], _Digits);
		double tp = NormalizeDouble(bufferMaFast[0], _Digits);

		double halfLot = InpLots / 2;
		if (!CheckLots(halfLot))
		{
			PrintIfInfo("ShouldSell - CheckLots failed");
			return;
		}

		if (!trade.PositionOpen(_Symbol, ORDER_TYPE_SELL, halfLot, previousTick.bid, sl, tp, "me"))
		{
			PrintFormat("❌[ShouldSell]: PositionOpen failed: sl %f; tp: %f; lots: %f, || %d :: %s",
						sl, tp, halfLot,
						trade.ResultRetcode(),
						trade.ResultRetcodeDescription());
		}
		isFilterCandleOn = true;
		return;
	}

	if (bufferMaFast[0] <= currentTick.bid)
	{
		PrintIfInfo("ShouldSell - should by 0.25 of stake - just a small try");

		if (InpValueRsiFilterThresholdDistance > 0 && bufferRsi[0] < 70 - InpValueRsiFilterThresholdDistance)
		{
			PrintIfInfo("RSI filter #ON - filtered out");
			return;
		}

		if (InpNewPositionPriceLevelShouldBe != EMPE_OFF)
		{
			if (ShouldBeFilteredByPriceLevel("sm", currentTick.bid, trendDirection))
			{
				return;
			}
		}

		if (InpSmallPositionsMax != 0 && InpSmallPositionsMax <= positionSummary.smallCount)
		{
			PrintIfInfo("Small positions max count reached");
			return;
		}

		double sl = NormalizeDouble(bufferMaMiddle[0], _Digits);
		double tp = NormalizeDouble(((currentTick.bid - bufferMaMiddle[0]) * InpSmallTryFactor) + currentTick.bid, _Digits);

		double quarterOfLot = InpLots / 4;
		if (!CheckLots(quarterOfLot))
		{
			PrintIfInfo("ShouldSell - CheckLots failed");
			return;
		}

		if (NormalizeDouble(sl, _Digits) == NormalizeDouble(tp, _Digits) ||
			NormalizeDouble(sl, _Digits) == NormalizeDouble(currentTick.bid, _Digits) ||
			NormalizeDouble(tp, _Digits) == NormalizeDouble(currentTick.bid, _Digits))
		{
			PrintIfInfo("ShouldSell - sl == tp || sl == currentTick.bid || tp == currentTick.bid - no way to send positions");
			return;
		}

		if (!trade.PositionOpen(_Symbol, ORDER_TYPE_SELL, quarterOfLot, previousTick.bid, sl, tp, "sm"))
		{
			PrintFormat("❌[ShouldSell]:  PositionOpen failed: sl %f; tp: %f; lots: %f, || %d :: %s",
						sl, tp, quarterOfLot,
						trade.ResultRetcode(),
						trade.ResultRetcodeDescription());
		}
		isFilterCandleOn = true;
		return;
	}
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
		Print("CheckLots: step equal 0");
		step = 1;
	}

	lots = (int)MathFloor(lots / step) * step;

	return true;
}

bool ShouldBeFiltered(int trendDirection, double &bufferMaSlow[], double &bufferMaFast[])
{
	if (trendDirection == -1 && bufferMaSlow[0] - bufferMaFast[0] < InpMaSizeFilter * _Point)
	{
		return true;
	}

	if (trendDirection == 1 && bufferMaFast[0] - bufferMaSlow[0] < InpMaSizeFilter * _Point)
	{
		return true;
	}

	return false;
}

void CheckInitResult(bool &initResult, bool condition, string message)
{
	if (!condition)
	{
		Print(message);
		initResult = false;
	}
}

bool ShouldBeFilteredDepositLoad()
{
	double accountBallanceValue = AccountInfoDouble(ACCOUNT_BALANCE);
	double marginUsedValue = accountBallanceValue - AccountInfoDouble(ACCOUNT_MARGIN_FREE);
	double userPercentage = (marginUsedValue / accountBallanceValue) * 100;

	if (userPercentage > InpDepositLoad)
	{
		PrintIfInfo("❌ Filtered out trade due to deposit load filtering");
		return true;
	}
	else
	{
		return false;
	}
}

void PrintIfInfo(string message)
{
	if (InpShowInfo)
	{
		Print(message);
	}
}

void TrailByLowerEma(double &bufferMaMiddle[], double &bufferMaSlow[])
{
	for (int i = PositionsTotal() - 1; i >= 0; i--)
	{
		ulong posTicket = PositionGetTicket(i);
		if (PositionSelectByTicket(posTicket))
		{
			if (PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
			{
				if (PositionGetString(POSITION_COMMENT) == "sm")
				{
					if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
					{
						double currentSl = PositionGetDouble(POSITION_SL);
						double currentTp = PositionGetDouble(POSITION_TP);
						double possibleSl = NormalizeDouble(bufferMaMiddle[0], _Digits);
						if (currentSl < possibleSl)
						{
							if (trade.PositionModify(posTicket, possibleSl, currentTp))
							{
								PrintFormat("TrailByLowerEma - position buy modified from sl: %d to new sl: %d", currentSl, possibleSl);
							}
						}
					}
					if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
					{
						double currentSl = PositionGetDouble(POSITION_SL);
						double currentTp = PositionGetDouble(POSITION_TP);
						double possibleSl = NormalizeDouble(bufferMaMiddle[0], _Digits);
						if (currentSl > possibleSl)
						{
							if (trade.PositionModify(posTicket, possibleSl, currentTp))
							{
								PrintFormat("TrailByLowerEma - position sell modified from sl: %d to new sl: %d", currentSl, possibleSl);
							}
						}
					}
				}

				if (PositionGetString(POSITION_COMMENT) == "me")
				{
					if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
					{
						double currentSl = PositionGetDouble(POSITION_SL);
						double currentTp = PositionGetDouble(POSITION_TP);
						double possibleSl = NormalizeDouble(bufferMaSlow[0], _Digits);
						if (currentSl < possibleSl)
						{
							if (trade.PositionModify(posTicket, possibleSl, currentTp))
							{
								PrintFormat("TrailByLowerEma - position buy modified from sl: %d to new sl: %d", currentSl, possibleSl);
							}
						}
					}
					if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
					{
						double currentSl = PositionGetDouble(POSITION_SL);
						double currentTp = PositionGetDouble(POSITION_TP);
						double possibleSl = NormalizeDouble(bufferMaSlow[0], _Digits);
						if (currentSl > possibleSl)
						{
							if (trade.PositionModify(posTicket, possibleSl, currentTp))
							{
								PrintFormat("TrailByLowerEma - position sell modified from sl: %d to new sl: %d", currentSl, possibleSl);
							}
						}
					}
				}

				if (PositionGetString(POSITION_COMMENT) == "fu")
				{
					if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
					{
						double slowMarginForBuyValue = bufferMaSlow[0] - (InpSlowMargin * _Point);
						double currentSl = PositionGetDouble(POSITION_SL);
						double currentTp = PositionGetDouble(POSITION_TP);
						double possibleSl = NormalizeDouble(slowMarginForBuyValue, _Digits);
						if (currentSl < possibleSl)
						{
							if (trade.PositionModify(posTicket, possibleSl, currentTp))
							{
								PrintFormat("TrailByLowerEma - position buy modified from sl: %d to new sl: %d", currentSl, possibleSl);
							}
						}
					}
					if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
					{
						double slowMarginForSellValue = bufferMaSlow[0] + (InpSlowMargin * _Point);
						double currentSl = PositionGetDouble(POSITION_SL);
						double currentTp = PositionGetDouble(POSITION_TP);
						double possibleSl = NormalizeDouble(slowMarginForSellValue, _Digits);
						if (currentSl > possibleSl)
						{
							if (trade.PositionModify(posTicket, possibleSl, currentTp))
							{
								PrintFormat("TrailByLowerEma - position sell modified from sl: %d to new sl: %d", currentSl, possibleSl);
							}
						}
					}
				}
			}
		}
	}
}

void PositionSummaryInit()
{
	positionSummary.smallCount = 0;
	positionSummary.small.bestBuyPrice = 0;
	positionSummary.small.bestSellPrice = 0;
	positionSummary.small.worstBuyPrice = 0;
	positionSummary.small.worstSellPrice = 0;
	positionSummary.mediumCount = 0;
	positionSummary.medium.bestBuyPrice = 0;
	positionSummary.medium.bestSellPrice = 0;
	positionSummary.medium.worstBuyPrice = 0;
	positionSummary.medium.worstSellPrice = 0;
	positionSummary.fullCount = 0;
	positionSummary.full.bestBuyPrice = 0;
	positionSummary.full.bestSellPrice = 0;
	positionSummary.full.worstBuyPrice = 0;
	positionSummary.full.worstSellPrice = 0;

	for (int i = PositionsTotal() - 1; i >= 0; i--)
	{
		ulong posTicket = PositionGetTicket(i);
		if (PositionSelectByTicket(posTicket))
		{
			if (PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
			{
				if (PositionGetString(POSITION_COMMENT) == "sm")
				{
					positionSummary.smallCount = positionSummary.smallCount + 1;

					if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
					{
						double currentPrice = PositionGetDouble(POSITION_PRICE_OPEN);
						if (positionSummary.small.bestBuyPrice == 0 || positionSummary.small.bestBuyPrice > currentPrice)
						{
							positionSummary.small.bestBuyPrice = currentPrice;
						}
						if (positionSummary.small.worstBuyPrice == 0 || positionSummary.small.worstBuyPrice < currentPrice)
						{
							positionSummary.small.worstBuyPrice = currentPrice;
						}
					}
					if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
					{
						double currentPrice = PositionGetDouble(POSITION_PRICE_OPEN);
						if (positionSummary.small.bestSellPrice == 0 || positionSummary.small.bestSellPrice < currentPrice)
						{
							positionSummary.small.bestSellPrice = currentPrice;
						}
						if (positionSummary.small.worstSellPrice == 0 || positionSummary.small.worstSellPrice < currentPrice)
						{
							positionSummary.small.worstSellPrice = currentPrice;
						}
					}
				}

				if (PositionGetString(POSITION_COMMENT) == "me")
				{
					positionSummary.mediumCount = positionSummary.mediumCount + 1;

					if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
					{
						double currentPrice = PositionGetDouble(POSITION_PRICE_OPEN);
						if (positionSummary.medium.bestBuyPrice == 0 || positionSummary.medium.bestBuyPrice > currentPrice)
						{
							positionSummary.medium.bestBuyPrice = currentPrice;
						}
						if (positionSummary.medium.worstBuyPrice == 0 || positionSummary.medium.worstBuyPrice < currentPrice)
						{
							positionSummary.medium.worstBuyPrice = currentPrice;
						}
					}
					if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
					{
						double currentPrice = PositionGetDouble(POSITION_PRICE_OPEN);
						if (positionSummary.medium.bestSellPrice == 0 || positionSummary.medium.bestSellPrice < currentPrice)
						{
							positionSummary.medium.bestSellPrice = currentPrice;
						}
						if (positionSummary.medium.worstSellPrice == 0 || positionSummary.medium.worstSellPrice < currentPrice)
						{
							positionSummary.medium.worstSellPrice = currentPrice;
						}
					}
				}

				if (PositionGetString(POSITION_COMMENT) == "fu")
				{
					positionSummary.fullCount = positionSummary.fullCount + 1;

					if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
					{
						double currentPrice = PositionGetDouble(POSITION_PRICE_OPEN);
						if (positionSummary.full.bestBuyPrice == 0 || positionSummary.full.bestBuyPrice > currentPrice)
						{
							positionSummary.full.bestBuyPrice = currentPrice;
						}
						if (positionSummary.full.worstBuyPrice == 0 || positionSummary.full.worstBuyPrice < currentPrice)
						{
							positionSummary.full.worstBuyPrice = currentPrice;
						}
					}
					if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
					{
						double currentPrice = PositionGetDouble(POSITION_PRICE_OPEN);
						if (positionSummary.full.bestSellPrice == 0 || positionSummary.full.bestSellPrice < currentPrice)
						{
							positionSummary.full.bestSellPrice = currentPrice;
						}
						if (positionSummary.full.worstSellPrice == 0 || positionSummary.full.worstSellPrice < currentPrice)
						{
							positionSummary.full.worstSellPrice = currentPrice;
						}
					}
				}
			}
		}
	}
}

bool ShouldBeFilteredByPriceLevel(string positionSize, double currentPrice, int trendDirection)
{
	if (positionSize == "sm")
	{
		if (InpNewPositionPriceLevelShouldBe == ONLY_IF_BETTER_PRICE)
		{
			if (trendDirection == 1 && positionSummary.small.bestBuyPrice > 0)
			{
				if (currentPrice > positionSummary.small.bestBuyPrice)
				{
					return true;
				}
			}
			if (trendDirection == -1 && positionSummary.small.bestSellPrice > 0)
			{
				if (currentPrice < positionSummary.small.bestSellPrice)
				{
					return true;
				}
			}
		}

		if (InpNewPositionPriceLevelShouldBe == ONLY_IF_WORSE_PRICE)
		{
			if (trendDirection == 1 && positionSummary.small.worstBuyPrice > 0)
			{
				if (currentPrice < positionSummary.small.worstBuyPrice)
				{
					return true;
				}
			}
			if (trendDirection == -1 && positionSummary.small.worstSellPrice > 0)
			{
				if (currentPrice > positionSummary.small.worstSellPrice)
				{
					return true;
				}
			}
		}
	}

	if (positionSize == "me")
	{
		if (InpNewPositionPriceLevelShouldBe == ONLY_IF_BETTER_PRICE)
		{
			if (trendDirection == 1 && positionSummary.medium.bestBuyPrice > 0)
			{
				if (currentPrice > positionSummary.medium.bestBuyPrice)
				{
					return true;
				}
			}
			if (trendDirection == -1 && positionSummary.medium.bestSellPrice > 0)
			{
				if (currentPrice < positionSummary.medium.bestSellPrice)
				{
					return true;
				}
			}
		}

		if (InpNewPositionPriceLevelShouldBe == ONLY_IF_WORSE_PRICE)
		{
			if (trendDirection == 1 && positionSummary.medium.worstBuyPrice > 0)
			{
				if (currentPrice < positionSummary.medium.worstBuyPrice)
				{
					return true;
				}
			}
			if (trendDirection == -1 && positionSummary.medium.worstSellPrice > 0)
			{
				if (currentPrice > positionSummary.medium.worstSellPrice)
				{
					return true;
				}
			}
		}
	}

	if (positionSize == "fu")
	{
		if (InpNewPositionPriceLevelShouldBe == ONLY_IF_BETTER_PRICE)
		{
			if (trendDirection == 1 && positionSummary.full.bestBuyPrice > 0)
			{
				if (currentPrice > positionSummary.full.bestBuyPrice)
				{
					return true;
				}
			}
			if (trendDirection == -1 && positionSummary.full.bestSellPrice > 0)
			{
				if (currentPrice < positionSummary.full.bestSellPrice)
				{
					return true;
				}
			}
		}

		if (InpNewPositionPriceLevelShouldBe == ONLY_IF_WORSE_PRICE)
		{
			if (trendDirection == 1 && positionSummary.full.worstBuyPrice > 0)
			{
				if (currentPrice < positionSummary.full.worstBuyPrice)
				{
					return true;
				}
			}
			if (trendDirection == -1 && positionSummary.full.worstSellPrice > 0)
			{
				if (currentPrice > positionSummary.full.worstSellPrice)
				{
					return true;
				}
			}
		}
	}

	return false;
}