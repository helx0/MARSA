// Presentation helper ONLY: the authoritative minimum is computed in the SQL RPC.
num displayMinimumBid({required num startingPrice,required num currentPrice,
  required num increment,required int acceptedBidCount}) =>
  acceptedBidCount==0?startingPrice:currentPrice+increment;

bool isAuctionClockLive(DateTime serverNow,DateTime startsAt,DateTime endsAt) =>
  !serverNow.isBefore(startsAt) && serverNow.isBefore(endsAt);
