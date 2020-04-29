/// OasisLiquidityProvider.sol
// Copyright (C) 2019 - 2020 Maker Ecosystem Growth Holdings, INC.

//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

pragma solidity >= 0.5.0;

contract TokenLike {
    function approve(address guy, uint wad) public returns (bool);
    function transferFrom(address src, address dst, uint wad) public returns (bool);
    function balanceOf(address src) public view returns (uint);
}
contract MarketLike {
    mapping (uint => OfferInfo) public offers;
    struct OfferInfo {
        uint     pay_amt;
        address  pay_gem;
        uint     buy_amt;
        address  buy_gem;
        address  owner;
        uint64   timestamp;
    }
    function getBestOffer(TokenLike sell_gem, TokenLike buy_gem) public view returns(uint);
    function getWorseOffer(uint id) public view returns(uint);
    function offer(uint pay_amt, TokenLike pay_gem, uint buy_amt, TokenLike buy_gem, uint pos) public returns (uint);
    function cancel(uint id) public returns (bool success);
}

contract OasisLiquidityProvider {
    uint constant ONE = 10 ** 18;

    constructor() public {
    }

    function linearOffers(
        MarketLike otc, TokenLike baseToken, TokenLike quoteToken, uint midPrice, uint delta, uint baseAmount, uint count
    ) public {
        require(baseToken.transferFrom(msg.sender, address(this), baseAmount * count), "cannot-fetch-base-token");
        require(quoteToken.transferFrom(msg.sender, address(this), baseAmount * count * (midPrice - delta * (count+1)/2) / ONE), "cannot-fetch-quote-token");
        baseToken.approve(address(otc), uint(-1));
        quoteToken.approve(address(otc), uint(-1));
        linearOffersPair(otc, baseToken, quoteToken, midPrice*baseAmount/ONE, -int(delta*baseAmount/ONE), baseAmount, 0, count);
        linearOffersPair(otc, quoteToken, baseToken, baseAmount, 0, midPrice*baseAmount/ONE, int(delta*baseAmount/ONE), count);
    }

    function linearOffersPair(
        MarketLike otc, TokenLike buyToken, TokenLike payToken, uint midPriceBuy, int deltaBuy, uint midPriceSell, int deltaSell, uint count
    ) internal {
        for (uint i = 1; i <= count; i++) {
            otc.offer(
                uint(int(midPriceBuy) + int(i) * deltaBuy), payToken,
                uint(int(midPriceSell) + int(i) * deltaSell), buyToken,
                0
            );
        }
    }

    function cancelMyOffers(MarketLike otc, TokenLike baseToken, TokenLike quoteToken) public {
        cancelMyOffersPair(otc, baseToken, quoteToken);
        cancelMyOffersPair(otc, quoteToken, baseToken);
        baseToken.transferFrom(address(this), msg.sender, baseToken.balanceOf(address(this)));
        quoteToken.transferFrom(address(this), msg.sender, quoteToken.balanceOf(address(this)));
    }

    function cancelMyOffersPair(MarketLike otc, TokenLike buyToken, TokenLike payToken) internal {
        uint offerId = otc.getBestOffer(payToken, buyToken);
        while (offerId != 0) {
            (, , , , address owner, ) = otc.offers(offerId);
            if (owner == address(this))
                otc.cancel(offerId);
            offerId = otc.getWorseOffer(offerId);
        }
    }
}
