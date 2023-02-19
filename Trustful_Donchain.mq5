#property copyright "Copyright 2022, MetaQuotes Ltd."
#property link "https://www.mql5.com"
#property version "1.00"
#property indicator_chart_window
#property indicator_buffers 2
#property indicator_plots 2


input int InpPeroid = 20;
input int InpOffset = 0;
input color InpColor = clrBlue;

double bufferUpper[];
double bufferLower[];
double upper, lower;
int first, bar;

int OnInit() {

  InitializeBuffer(0, bufferUpper, "Donchain Upper");
  InitializeBuffer(1, bufferLower, "Donchain Lower");
  IndicatorSetString(INDICATOR_SHORTNAME, "Donchain(" + IntegerToString(InpPeroid) + ")");

  return (INIT_SUCCEEDED);
}

int OnCalculate(
  const int rates_total,
  const int prev_calculated,
  const datetime &time[],
  const double &open[],
  const double &high[],
  const double &low[],
  const double &close[],
  const long &tick_volume[],
  const long &volume[],
  const int &spread[]) {
  
  if (rates_total < InpPeroid + 1) {
    return 0;
  }

  first = prev_calculated == 0 ? InpPeroid : prev_calculated - 1;
  for (bar = first; bar < rates_total; bar++) {
    upper = open[ArrayMaximum(open, bar - InpPeroid + 1, InpPeroid)];
    lower = open[ArrayMinimum(open, bar - InpPeroid + 1, InpPeroid)];

    bufferUpper[bar] = upper - (upper - lower) * InpOffset * 0.01;
    bufferLower[bar] = lower + (upper - lower) * InpOffset * 0.01;
  }

  return (rates_total);
}

void InitializeBuffer(int index, double &buffer[], string label) {
  SetIndexBuffer(index, buffer, INDICATOR_DATA);
  PlotIndexSetInteger(index, PLOT_DRAW_TYPE, DRAW_LINE);
  PlotIndexSetInteger(index, PLOT_LINE_WIDTH, 2);
  PlotIndexSetInteger(index, PLOT_DRAW_BEGIN, InpPeroid - 1);
  PlotIndexSetInteger(index, PLOT_SHIFT, 1);
  PlotIndexSetInteger(index, PLOT_LINE_COLOR, InpColor);
  PlotIndexSetString(index, PLOT_LABEL, label);
  PlotIndexSetDouble(index, PLOT_EMPTY_VALUE, EMPTY_VALUE);
}