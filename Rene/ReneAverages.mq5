#include <Trade/Trade.mqh>

input group "Trading Inputs"
input double Lots = 0.1;
input double TpDist = 0.001;
input double SlDist = 0.005;

input group "Indicator Inputs"
input ENUM_TIMEFRAMES StochTimeframe = PERIOD_H1;
input int StochK = 5;
input int StochD = 3;
input int StochSlowing = 3;
input double StochUpperLevel = 80;
input double StochLowerLevel = 20;

input bool IsMaFilterActive = false;
input ENUM_TIMEFRAMES MaTimeframe = PERIOD_D1;
input int MaPeriod = 100; 
input ENUM_MA_METHOD MaMethod = MODE_SMA;

int handleStoch;
int handleMa;

int totalBars;

CTrade trade;

int OnInit(){
   handleStoch = iStochastic(_Symbol,StochTimeframe,StochK,StochD,StochSlowing,MODE_SMA,STO_LOWHIGH);
   handleMa = iMA(_Symbol,MaTimeframe,MaPeriod,0,MaMethod,PRICE_CLOSE);

   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason){

}

void OnTick(){
   int bars = iBars(_Symbol,StochTimeframe);
   if(totalBars != bars){
      totalBars = bars;

      double stoch[];
      CopyBuffer(handleStoch,MAIN_LINE,1,2,stoch);
      
      double ma[];
      CopyBuffer(handleMa,MAIN_LINE,1,1,ma);
      
      double bid = SymbolInfoDouble(_Symbol,SYMBOL_BID); 
      double ask = SymbolInfoDouble(_Symbol,SYMBOL_ASK); 
   
      if(stoch[1] < StochUpperLevel && stoch[0] > StochUpperLevel){
         if(!IsMaFilterActive || bid < ma[0]){
            trade.Sell(Lots,_Symbol,bid,bid+SlDist,bid-TpDist);
         }
      }else if(stoch[1] > StochLowerLevel && stoch[0] < StochLowerLevel){
         if(!IsMaFilterActive || bid > ma[0]){
            trade.Buy(Lots,_Symbol,ask,ask-SlDist,ask+TpDist);
         }
      }
   }
}