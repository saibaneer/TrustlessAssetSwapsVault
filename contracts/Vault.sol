//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "./interfaces/IERC20.sol";

contract Vault {

    address creator;
    address beneficiary;
    address token;
    address manager;
    uint timeout;
    uint balance;


    constructor(address _creator, address _beneficiary, address _token, address _manager, uint _bidTimeInHours){
        creator = _creator;
        beneficiary = _beneficiary;
        token = _token;
        manager = _manager;
        timeout = block.timestamp + (_bidTimeInHours * 1 hours);
    }

    function getCreator() public view returns(address){        
        return creator;
    }
    function getBeneficiary() public view returns(address){
        return beneficiary;
    }
    function getTimeout() public view returns(uint){
        return timeout;
    }

    

    
     

    
}