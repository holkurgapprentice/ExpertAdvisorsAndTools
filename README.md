# What it is?
Just a dump of my previously created projects for MT5

# What for
If you find something intresting inside, feel free to fork / copy, for me it's just a backup of my daily tools.


# List of description of currently developed tools

## Current Result EA (its just an indicator)
The provided code is an Expert Advisor (EA) for MetaTrader 5 (MT5) named CurrentResult_v2.mq5. It is designed to calculate and display the current trading results, including profits, losses, and risk levels associated with open orders and positions. Below is a detailed summary of its functionality:

### Key Features:
1. **Logging**:

* The EA can log messages to the console based on the ```InpIsLogginEnabled``` parameter.

2. **Risk Level Indicator**:

* It colors the current result red if the risk level exceeds a specified percentage (```RedRiskLevel```).

3. **Layout Configuration**:

* The EA supports both horizontal and vertical layouts for displaying results, with customizable sizes (```small``` and ```normal```).

4. **Break Even Line**:

* It can display a break-even line on the chart, with configurable color and label.

5. **Summary Calculation**:

* The EA calculates the following for both orders and positions:
* Current result
* Total profit
* Total loss
* Number of orders/positions without take profit (TP) or stop loss (SL)
* Risk percentage based on the account balance

6. **Display Management**:

* It draws labels on the chart to show the calculated results, including projected loss, projected win, current result, and the number of orders/positions without TP/SL.

### Class Structure:
1. **Logger**: Handles logging messages.
2. **SummaryCalculator**: Contains methods to initialize summary data and calculate results for orders and positions.
3. **BreakEvenCalculator**: Calculates and displays the break-even price based on open positions.
4. **DisplayManager**: Manages the display of results on the chart, including layout and formatting.

### Initialization and Timer Functions:
1. The ```OnInit``` function initializes the EA, sets a timer for periodic updates, and checks the validity of the ```RedRiskLevel```.
2. The ```OnTimer``` function is called every 3 seconds (as set by the timer) to recalculate order and position results, update the break-even line, and refresh the displayed results.

### Deinitialization:
1. The ```OnDeinit``` function cleans up by deleting all drawn objects when the EA is removed from the chart.

### Summary:
Overall, this EA provides traders with a comprehensive overview of their current trading performance, allowing them to monitor profits, losses, and risk levels effectively. The visual representation on the chart aids in quick decision-making based on the calculated metrics.

## SetTp&SlScript

The provided code is an script for MetaTrader 5 (MT5) designed to manage and optimize stop-loss (SL) levels for open positions and pending orders. The script allows users to adjust SL levels based on the best take profit (TP) found among open positions and can also calculate average TP and entry prices to set more effective SL levels.

### Key Features

1. **Stop-Loss Management**:
   - The script can overwrite existing SL levels based on user-defined conditions.
   - Users can choose to overwrite SL levels regardless of whether the new SL is better or not.

2. **Take Profit Optimization**:
   - The script identifies the best TP from open positions to calculate an optimal SL.
   - It can handle both buy and sell positions, adjusting SL according to the type of position.

3. **Average Calculation**:
   - Optionally, the script can calculate average TP and entry prices from multiple positions to determine a more effective SL.

4. **Order and Position Modification**:
   - The script modifies both open positions and pending orders to apply the new SL and TP levels.

5. **User Inputs**:
   - `InpDoOverwriteSl`: Boolean to determine if SL should be overwritten.
   - `InpOverwriteUsingAverages`: Boolean to determine if averages should be used for SL calculation.

### Class Structure

#### PositionManager Class

- **Attributes**:
  - `mainSymbol`: The symbol for which the script is managing positions.
  - `mainTpPrice`: The best TP price found.
  - `mainEntryPrice`: The entry price of the position.
  - `calcSl`: The calculated SL based on the best TP.
  - `averageTpPrice`: The average TP price across all positions.
  - `averageOpenPrice`: The average entry price across all positions.
  - `averageCalcSl`: The calculated SL based on average prices.
  - `mainType`: The type of position (buy/sell).
  - `tpsSetCount`: Counter for the number of TPs found.
  - `c_trade`: An instance of the `CTrade` class for executing trade operations.

- **Methods**:
  - `FindBestTp()`: Finds the best TP among open positions and calculates the corresponding SL.
  - `FindAverage()`: Calculates average TP and entry prices for the symbol.
  - `ModifyPositions()`: Modifies SL for open positions based on calculated values.
  - `ModifyOrders()`: Modifies SL and TP for pending orders.

#### Private Methods

- `IsBetterTp(long type, double tpPrice)`: Checks if the current TP is better than the previously found TP.
- `CalculateSl(double entryPrice, double tpPrice, long type)`: Calculates the SL based on entry price and TP.
- `AdjustSlPrice(double currentSlPrice, long positionType, double calculatedSlPrice)`: Adjusts the current SL based on calculated values and user settings.

### Execution Flow

1. **Initialization**:
   - The script starts by determining the symbol for which it will manage positions.

2. **Finding Best TP**:
   - It searches for the best TP among open positions and calculates the corresponding SL.

3. **Average Calculation (if enabled)**:
   - If the user opts to use averages, the script calculates average TP and entry prices.

4. **Modification of Positions and Orders**:
   - The script modifies the SL and TP levels for both open positions and pending orders based on the calculations.

### Summary

This script provides a robust solution for traders looking to optimize their stop-loss levels based on existing market positions. By allowing for both individual and average calculations, it enhances risk management strategies and helps traders protect their capital more effectively.
