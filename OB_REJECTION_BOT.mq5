// +------------------------------------------------------------------+
// |                                               OB_Rejection_Bot   |
// +------------------------------------------------------------------+
#include <Trade/Trade.mqh> // Equivalent to: import { CTrade } from 'mt5-standard-lib'
#include <Arrays/List.mqh>

class CFutureOrder : public CObject
{
public:
   double   entryPrice;
   double   stopLoss;
   double   takeProfit;
   double   volume;
   ENUM_ORDER_TYPE type;

   // Constructor to initialize all values at once
   CFutureOrder(double p, double sl, double tp, double v, ENUM_ORDER_TYPE t)
   {
      entryPrice = p;
      stopLoss   = sl;
      takeProfit = tp;
      volume     = v;
      type       = t;
      //Print("CREATING ORDER[ "+t+" ] OBJECT:: ENTRY PRICE: " + p +" STOP LOSS: "+ sl+ " TAKE PROFIT: " + tp +" VOLUME: "+ v + " NEW ORDER CREATED WITH THIS");
   }
};

CList orderQueue;

// 1. Global Variables (State)
CTrade trade; // Instantiating our trade object (like: const trade = new CTrade();)

// Enforcing your strict rule. The exact string must match Deriv's symbol name.
string targetSymbol = "Volatility 25 (1s) Index"; 
datetime lastProcessedCandleTime = 0; // NEW: Track last processed candle time to avoid adding orders on every tick
//deque<struct order> myOrders;

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
    Print("--- Final Report ---");
    Print("Bot shutting down. Reason code: ", reason);
    
    // Check how many orders never triggered
    Print("Orders remaining in queue: ", orderQueue.Total());

    // Iterate and print details of stuck orders
    CFutureOrder *currentOrder = (CFutureOrder*)orderQueue.GetFirstNode();
    /*while(currentOrder != NULL)
    {
        PrintFormat("Stuck Order: Entry %.2f | SL %.2f | Type %s", 
                    currentOrder.entryPrice, 
                    currentOrder.stopLoss, 
                    EnumToString(currentOrder.type));
                    
        currentOrder = (CFutureOrder*)orderQueue.GetNextNode();
    }
   */
    // CRITICAL: Clear memory to prevent memory leaks in the tester
    orderQueue.Clear(); 
}

double OnTester()
{
    Print("--- TEST COMPLETE ---");
    Print("Orders still in queue: ", orderQueue.Total());
    
    // You can still perform your loop here to see what went wrong
    CFutureOrder *currentOrder = (CFutureOrder*)orderQueue.GetFirstNode();
    /*while(currentOrder != NULL)
    {
        PrintFormat("Unexecuted Order Type %s at Price %.2f", 
                    EnumToString(currentOrder.type), currentOrder.entryPrice);
        currentOrder = (CFutureOrder*)orderQueue.GetNextNode();
    }
    */
    return(0.0);
}


// 4. The Event Loop (Fires every single time the price changes)
// 4. The Event Loop
void OnTick()
{
    // 1. STATE MANAGEMENT
    //CheckAndExecuteOrders();
    if(PositionsTotal() >= 6) return;
    //Print(PositionsTotal()); 

    // 2. DATA FETCHING
    MqlRates candles[];
    ArraySetAsSeries(candles, true);  
    if(CopyRates(_Symbol, _Period, 0, 3, candles) < 3) return;
    
    MqlRates confirmationCandle = candles[0];
    MqlRates live = candles[1];  
    MqlRates prev = candles[2];  

      //strategy confirmation testing 
    //if(!(bodySize(live)>bodySize(prev))) return;
    
    

    // 3. UI DASHBOARD
    string report = StringFormat(
        "LIVE STATUS: %s\n"
        "PRICE: %.2f | PREV CLOSE: %.2f\n"
        "BALANCE: %.2f",
        _Symbol, live.close, prev.close, AccountInfoDouble(ACCOUNT_BALANCE)
    );
    Comment(report); 

    // --- PHASE 2: STRATEGY LOGIC ---
    if(live.time != lastProcessedCandleTime)
    {
        double lotSize = 0.005; // Use minimum lot size for Vol 25 (1s)
        
        bool isBuyToSellOB = (isBuy(prev) && isSell(live) && bodySize(prev)>0 && bodySize(prev)<bodySize(live));
        bool isSellToBuyOB = (isSell(prev) && isBuy(live) && bodySize(prev)>0 && bodySize(prev)<bodySize(live));
        
        if(isBuyToSellOB){
            Print("Found [Buy To Sell OB] ::" + "BUY:" + prev.time + prev.open + "SELL: "+ live.time + live.open);
            
            //double sl = MathMax(upperWick(prev),upperWick(live)) + (_Point * 200) // Stop Loss With spread
            double sl = upperWick(prev)>upperWick(live) ? prev.high + (_Point * 1500) : live.high + (_Point * 1500);
            double entryOne = prev.low - (_Point * 1500);
            double entryTwo = prev.high - (bodySize(prev)/2);
            double entryThree = sl - (_Point * 1500);
            double tp = entryOne - (_Point * 3000);
            double volume = lotSize; // FIXED: Do not multiply by Account Balance!

            //Print("[B 2 S]:: STOPLOSS: "+sl+" TAKEPROFIT: "+tp+" ENTRY ONE:"+entryOne+" ENTRY TWO:"+entryTwo+" ENTRY THREE:"+entryThree);
            //bid type sell short
            CFutureOrder *newSellOrder1 = new CFutureOrder(entryOne, sl, tp, volume, ORDER_TYPE_SELL);
            orderQueue.Add(newSellOrder1);

            CFutureOrder *newSellOrder2 = new CFutureOrder(entryTwo, sl, tp, volume, ORDER_TYPE_SELL);
            orderQueue.Add(newSellOrder2);
            
            CFutureOrder *newSellOrder3 = new CFutureOrder(entryThree, sl, tp, volume, ORDER_TYPE_SELL);
            orderQueue.Add(newSellOrder3);
        }
        
        if(isSellToBuyOB){
            //Print("Found [Sell To Buy OB] :");
            Print("Found [Sell To Buy OB] ::" + "SELL:" + prev.time + prev.open + "BUY: "+ live.time + live.open);

            double sl = lowerWick(prev)>lowerWick(live) ? prev.low - (_Point * 1500) : live.low - (_Point * 1500);
            double entryOne = prev.high + (_Point * 1500);
            double entryTwo = prev.high - (bodySize(prev)/2);
            double entryThree = sl + (_Point * 1500);
            double tp = entryOne + (_Point * 3000);
            double volume = lotSize; // FIXED: Do not multiply by Account Balance!
            //Print("[S 2 B]:: STOPLOSS: "+sl+" TAKEPROFIT: "+tp+" ENTRY ONE:"+entryOne+" ENTRY TWO:"+entryTwo+" ENTRY THREE:"+entryThree);

            //ask type buy long
            CFutureOrder *newBuyOrder1 = new CFutureOrder(entryOne, sl, tp, volume, ORDER_TYPE_BUY);
            orderQueue.Add(newBuyOrder1);
            
            CFutureOrder *newBuyOrder2 = new CFutureOrder(entryTwo, sl, tp, volume, ORDER_TYPE_BUY);
            orderQueue.Add(newBuyOrder2);
            
            CFutureOrder *newBuyOrder3 = new CFutureOrder(entryThree, sl, tp, volume, ORDER_TYPE_BUY);
            orderQueue.Add(newBuyOrder3);
        }
        
        // Update the time so we don't process this same candle again
        lastProcessedCandleTime = live.time;
    }

    // --- PHASE 3 & 4: TRADING WITH SL/TP ---
     
    
    

    
}

// Optimized Logger stays the same...
void WriteToLog(string message,string msgType)
{
    int fileHandle = FileOpen("OB_Bot_Trades.txt", FILE_WRITE|FILE_READ|FILE_TXT|FILE_SHARE_READ|FILE_ANSI);
    if(fileHandle != INVALID_HANDLE)
    {
        FileSeek(fileHandle, 0, SEEK_END); 
        string timeStr = TimeToString(TimeLocal(), TIME_DATE|TIME_SECONDS);
        //FileWrite(fileHandle, "[" + timeStr + "] " + "--{"+ msgType +"}--  " + message );
        FileWrite(fileHandle, "[" + timeStr + "] "+ message );
        FileClose(fileHandle);
    }
}
bool isBuy(const MqlRates &candle){
   bool buyOrNot = candle.open < candle.close;
   return buyOrNot;
}
bool isSell(const MqlRates &candle){
   bool SellOrNot = candle.open > candle.close;
   return SellOrNot;
}
//double bodySize = MathAbs(prev.close - prev.open);
//double upperWick = prev.high - MathMax(prev.open, prev.close);
//double lowerWick = MathMin(prev.open, prev.close) - prev.low;

double bodySize(const MqlRates &candle){
   double candleBodySize = MathAbs(candle.close - candle.open);
   return candleBodySize;
}
double upperWick(const MqlRates &candle){
   double candleUpperWick = candle.high - MathMax(candle.open,candle.close);
   return candleUpperWick;
}
double lowerWick(const MqlRates &candle){
   double candleLowerWick = MathMin(candle.open,candle.close) - candle.low;
   return candleLowerWick;
}

void CheckAndExecuteOrders()
{
   if(orderQueue.Total() == 0) return;

   double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   // Start from the beginning
   CFutureOrder *currentOrder = (CFutureOrder*)orderQueue.GetFirstNode();

   while(currentOrder != NULL)
   {
      bool priceHit = false;

      // Logic for BUY orders (Wait for price to drop TO or BELOW the entry)
      if(currentOrder.type == ORDER_TYPE_BUY) {
         if(currentAsk <= currentOrder.entryPrice) priceHit = true;
      }
      
      // Logic for SELL orders (Wait for price to rise TO or ABOVE the entry)
      else if(currentOrder.type == ORDER_TYPE_SELL) {
         if(currentBid >= currentOrder.entryPrice) priceHit = true;
      }

      if(priceHit)
      {
         // 1. Execute
         bool tradeSuccess = false;
         if(currentOrder.type == ORDER_TYPE_BUY)
            tradeSuccess = trade.Buy(currentOrder.volume, _Symbol, currentAsk, currentOrder.stopLoss, currentOrder.takeProfit);
         else
            tradeSuccess = trade.Sell(currentOrder.volume, _Symbol, currentBid, currentOrder.stopLoss, currentOrder.takeProfit);

         if(!tradeSuccess) {
            Print("TRADE FAILED! Order Type: ", EnumToString(currentOrder.type), 
                  " | Entry: ", currentOrder.entryPrice,
                  " | Volume: ", currentOrder.volume,
                  " | Error: ", trade.ResultRetcodeDescription());
         } else {
            Print("TRADE EXECUTED SUCCESSFULLY! Type: ", EnumToString(currentOrder.type));
         }

         // 2. Remove and Delete
         orderQueue.DetachCurrent(); // List handles the internal pointer move
         delete currentOrder;
         
         // 3. IMPORTANT: After detaching, we restart from the beginning to ensure we don't miss any node or use a broken pointer
         currentOrder = (CFutureOrder*)orderQueue.GetFirstNode();
      }
      else 
      {
         // Only move to next if we didn't delete the current one
         currentOrder = (CFutureOrder*)orderQueue.GetNextNode();
      }
   }
}

/* 

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


*/