// +------------------------------------------------------------------+
// |                                               OB_Rejection_Bot   |
// +------------------------------------------------------------------+
#include <Trade/Trade.mqh> // Equivalent to: import { CTrade } from 'mt5-standard-lib'

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
void OnTick()
{
    // STATE MANAGEMENT: Do we already have an open trade?
    // PositionsTotal() checks the global state of your account.
    if(PositionsTotal() > 0) 
    {
        // If we are currently in a trade, we do absolutely nothing.
        // We just return and wait for the next tick.
        return; 
    }

    // --- PHASE 2 WILL GO HERE ---
    // If the code reaches this line, it means PositionsTotal() == 0.
    // This is where we will write the logic to look for the OB Rejection.
    
}