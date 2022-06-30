// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract PriceConverter {

    function getPrice(address _oracleAddress, bool isDestinationTokenFirst) public view returns(uint256) {
        // Rinkeby ETH / USD Address
        // https://docs.chain.link/docs/ethereum-addresses/
        AggregatorV3Interface priceFeed = AggregatorV3Interface(_oracleAddress);
        (, int256 answer, , , ) = priceFeed.latestRoundData();
        if(isDestinationTokenFirst == true){
            return uint256(1e36/(answer));
        } else {
            return uint256(answer*1e10);
        }
        
        
    }

    function getConversionRate(uint256 tokenAmount, address _destinationToken, bool isDestinationTokenFirst) public view returns(uint256){
        uint tokenPrice = getPrice(_destinationToken, isDestinationTokenFirst);
        uint256 tokenPriceInUsd = (tokenPrice * tokenAmount) / 1000000000000000000;
        return tokenPriceInUsd;
    }    

}