import 'package:flutter_test/flutter_test.dart';
import 'package:marsa/features/auctions/domain/auction_math.dart';

void main(){
  test('first bid may equal starting price',(){
    expect(displayMinimumBid(startingPrice:100,currentPrice:100,increment:10,acceptedBidCount:0),100);
  });
  test('later bids must exceed current by at least increment',(){
    expect(displayMinimumBid(startingPrice:100,currentPrice:150,increment:10,acceptedBidCount:4),160);
  });
  test('boundary time semantics are inclusive start and exclusive end',(){
    final from=DateTime.utc(2026,11,19,10),until=DateTime.utc(2026,11,19,11);
    expect(isAuctionClockLive(from,from,until),isTrue);
    expect(isAuctionClockLive(until,from,until),isFalse);
  });
}
