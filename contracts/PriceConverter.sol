// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

library PriceConverter {

    function getPrice(address _oracleAddress) internal view returns(uint256) {
        // Rinkeby ETH / USD Address
        // https://docs.chain.link/docs/ethereum-addresses/
        AggregatorV3Interface priceFeed = AggregatorV3Interface(_oracleAddress);
        (, int256 answer, , , ) = priceFeed.latestRoundData();
        return uint256(answer * 10000000000);
        
    }

    function getConversionRate(uint256 tokenAmount, address _destinationToken) internal view returns(uint256){
        uint tokenPrice = getPrice(_destinationToken);
        uint256 tokenPriceInUsd = (tokenPrice * tokenAmount) / 1000000000000000000;
        return tokenPriceInUsd;
    }

}