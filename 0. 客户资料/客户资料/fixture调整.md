Specifically there are now 2 types of fixtures - partial and full.
A partial fixture doesn't have a fixed strike price, it's the one that people can place a bet on, the strike price is always the current mid price of the underlying asset. This will be displayed in the main UI with the Up / Down buttons.
A full fixture is a fixture that users placed a bet on, and their strike price is therefore fixed. This can be displayed in the UI for user's bet positions.
3:46
Also the current underlying price is not repeated over and over again in every opened fixture but send in the message only once at the top.
Underlying price is included only in closed fixtures as the last underlying price at expiration.
So for example for the /fixtures endpoint
image.png
 
image.png


3:46
Partial fixtures also don't have open interest, ITM ...
3:46
Their price (odds) are calculated with the assumption that the strike price is the underlying price.
3:47
in the /history endpoint I include open, high, low, close prices of the underlying asset, and no fixture prices.
3:48
in the graph you can plot only the close price to get a simple line
3:51
or it can be plotted as a candle stick chart with all the information
3:52
there won't be any historical prices of the fixtures
3:52
I think the remains of the legacy design were a source of confusion before