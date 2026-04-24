// +------------------------------------------------------------------+
// |                                               OB_Rejection_Bot   |
// +------------------------------------------------------------------+
#include <Trade/Trade.mqh> // Equivalent to: import { CTrade } from 'mt5-standard-lib'
#include <vector>
using namespace std;

struct order{
   double entry;
   double takeProfit;
   double stopLoss;
};

// 1. Global Variables (State)
CTrade trade; // Instantiating our trade object (like: const trade = new CTrade();)

// Enforcing your strict rule. The exact string must match Deriv's symbol name.
string targetSymbol = "Volatility 25 (1s) Index"; 


// 2. Setup (Runs ONCE when you attach the bot to a chart)
int OnInit()
{
    // SECURITY CHECK: Are we on the right chart?
    // _Symbol is a built-in variable that gets the current chart's name
    if(_Symbol != targetSymbol) 
    {
        Print("ACCESS DENIED: This bot is strictly for ", targetSymbol);
        return(INIT_FAILED); // This instantly kills the bot (like process.exit(1))
    }
    
    Print("Phase 1 Init: Bot successfully attached to ", _Symbol);
    return(INIT_SUCCEEDED); // Green light to start listening for ticks
}


// 3. Cleanup (Runs ONCE when you remove the bot)
void OnDeinit(const int reason)
{
    Print("Bot shutting down. Reason code: ", reason);
}


// 4. The Event Loop (Fires every single time the price changes)
// 4. The Event Loop
void OnTick()
{
    // 1. STATE MANAGEMENT
    if(PositionsTotal() > 0) return; 
    
    //Print(PositionsTotal()); 

    // 2. DATA FETCHING
    MqlRates candles[];
    ArraySetAsSeries(candles, true);  
    if(CopyRates(_Symbol, _Period, 0, 2, candles) < 2) return;

    MqlRates live = candles[0];  
    MqlRates prev = candles[1];  

    // 3. UI DASHBOARD
    string report = StringFormat(
        "LIVE STATUS: %s\n"
        "PRICE: %.2f | PREV CLOSE: %.2f\n"
        "BALANCE: %.2f",
        _Symbol, live.close, prev.close, AccountInfoDouble(ACCOUNT_BALANCE)
    );
    Comment(report); 

    // --- PHASE 2: STRATEGY LOGIC ---

    //double bodySize = MathAbs(prev.close - prev.open);
    //double upperWick = prev.high - MathMax(prev.open, prev.close);
    //double lowerWick = MathMin(prev.open, prev.close) - prev.low;

    //bool isBearishRejection = (upperWick > (bodySize * 2.0) && bodySize > 0);
    //bool isBullishRejection = (lowerWick > (bodySize * 2.0) && bodySize > 0);
    
    bool isBuyToSellOB = (isBuy(prev) && isSell(live) && bodySize(prev)>0 && bodySize(prev)<bodySize(live));
    bool isSellToBuyOB = (isSell(prev) && isBuy(live) && bodySize(prev)>0 && bodySize(prev)<bodySize(live));

    // --- PHASE 3 & 4: TRADING WITH SL/TP ---
    double lotSize = 0.10; 

    if(isBullishRejection)
    {
        double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        
        // SL is the low of the rejection candle
        double sl = prev.low; 
        
        // TP is 2x the distance of our risk (1:2 Risk-Reward)
        double risk = ask - sl;
        double tp = ask + (risk * 2.0);

        // Execute Buy: trade.Buy(lot, symbol, price, sl, tp)
        if(trade.Buy(lotSize, _Symbol, ask, sl, tp))
        {
            string logMsg = StringFormat(
                "ACTION: BUY | ENTRY: %.2f | SL: %.2f | TP: %.2f",
                ask, sl, tp
            );
            WriteToLog(logMsg);
        }
    }
    
    if(isBearishRejection)
    {
        double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        
        // SL is the high of the rejection candle
        double sl = prev.high;
        
        // TP is 2x the risk
        double risk = sl - bid;
        double tp = bid - (risk * 2.0);

        // Execute Sell: trade.Sell(lot, symbol, price, sl, tp)
        if(trade.Sell(lotSize, _Symbol, bid, sl, tp))
        {
            string logMsg = StringFormat(
                "ACTION: SELL | ENTRY: %.2f | SL: %.2f | TP: %.2f",
                bid, sl, tp
            );
            WriteToLog(logMsg);
        }
    }
}

// Optimized Logger stays the same...
void WriteToLog(string message)
{
    int fileHandle = FileOpen("OB_Bot_Trades.txt", FILE_WRITE|FILE_READ|FILE_TXT|FILE_SHARE_READ|FILE_ANSI);
    if(fileHandle != INVALID_HANDLE)
    {
        FileSeek(fileHandle, 0, SEEK_END); 
        string timeStr = TimeToString(TimeLocal(), TIME_DATE|TIME_SECONDS);
        FileWrite(fileHandle, "[" + timeStr + "] " + message);
        FileClose(fileHandle);
    }
}
bool isBuy(MqlRates candle){
   bool buyOrNot = candle.open < candle.close;
   return buyOrNot;
}
bool isSell(MqlRates candle){
   bool SellOrNot = candle.open > candle.close;
   return SellOrNot;
}
//double bodySize = MathAbs(prev.close - prev.open);
//double upperWick = prev.high - MathMax(prev.open, prev.close);
//double lowerWick = MathMin(prev.open, prev.close) - prev.low;

double bodySize(MqlRates candle){
   double candleBodySize = MathAbs(candle.close - candle.open)
   return candleBodySize;
}
double upperWick(MqlRates candle){
   double candleUpperWick = candle.high - MathMax(candle.open,candle.close);
   return candleUpperWick
}
double lowerWick(MqlRates candle){
   double candleLowerWick = MathMin(candle.open,candle.close) - candle.low;
   return candleLowerWickj;
}