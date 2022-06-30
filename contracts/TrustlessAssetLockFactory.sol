//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "./interfaces/WETHInterface.sol";
import "./interfaces/IUniswapV2Router.sol";
import "./interfaces/IERC20.sol";

error InsufficientDeposit (uint256 sent, uint256 minRequired);
error InvalidAddress (address sent);
error BalanceIsZero();
error MakeDeposit();
error UnAuthorizedEntry();

contract AssetLockFactory {
    

    event Deposited(address indexed depositor, address indexed beneficiary, uint amount, address token, uint nonce);
    event Swapped(address indexed caller, address indexed recipient, address token, uint amount, uint unlockTime);
    event CreatorWithdrew(address indexed owner, uint indexed amount, uint time);
    event UnlockerWithdrew(address indexed beneficiary, uint indexed amount, uint time);
 

    address private constant UNISWAP_V2_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address private constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    struct SwapRequest {
        address creator;
        address unlocker;
        address token;
        uint unlockTime;
        uint lockedValue;
        uint destinationTokenValue;
    }
    
    mapping(address => mapping(uint => SwapRequest)) public userToIdToRequest;
    mapping(address => uint) public userRequestCount;
   

    function createDeposit(address token, address beneficiary) external payable {
        if(msg.value <= 1 ether){
            revert InsufficientDeposit({sent: msg.value, minRequired: 1 ether});
        }
        if(token == address(0)){
            revert InvalidAddress({sent: token});
        } //improve by validating user ERC165
        if(beneficiary == address(0)){
            revert InvalidAddress({sent: beneficiary});
        }
        

        if(userRequestCount[msg.sender] < 1){
            uint nonce = 1;            
            SwapRequest memory item = userToIdToRequest[msg.sender][nonce];
            item.creator = msg.sender;
            item.destinationTokenValue = 0;
            item.lockedValue = msg.value;
            item.unlocker = beneficiary;
            item.unlockTime = 0;
            item.token = token;  
            userToIdToRequest[msg.sender][nonce] = item;
            userRequestCount[msg.sender] += 1;    
            emit Deposited(msg.sender, beneficiary, msg.value, token, nonce);    
        } else {
            uint nonce = userRequestCount[msg.sender]; 
            SwapRequest memory item = userToIdToRequest[msg.sender][nonce];
            item.creator = msg.sender;
            item.destinationTokenValue = 0;
            item.lockedValue = msg.value;
            item.unlocker = beneficiary;
            item.unlockTime = 0;
            item.token = token;  
            userToIdToRequest[msg.sender][nonce] = item;
            userRequestCount[msg.sender] += 1;   
            emit Deposited(msg.sender, beneficiary,msg.value, token, nonce);
        }
        
    }

    function initiateSwap(uint nonce, uint _timeInHours) external {
        SwapRequest storage item = userToIdToRequest[msg.sender][nonce];

        if(item.creator != msg.sender){
            revert UnAuthorizedEntry();
        }
                
        IWETH weth = IWETH(WETH);
        uint amount = item.lockedValue;
        item.lockedValue = 0;
        item.unlockTime = block.timestamp + (1 hours * _timeInHours);


        weth.deposit{value: amount}();
        weth.transfer(address(this), amount);

        //2. WETH(account) to destination ERC20
        weth.approve(UNISWAP_V2_ROUTER, amount);

        //3. Create swap path
        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = item.token;

        //4. Perform swap

        uint tokenBalanceBeforeSwap = IERC20(item.token).balanceOf(address(this));
        
        IUniswapV2Router(UNISWAP_V2_ROUTER).swapExactTokensForTokens(amount,1,path,address(this),block.timestamp);
        uint tokenBalanceAfterSwap = IERC20(item.token).balanceOf(address(this));
        uint diff = tokenBalanceAfterSwap - tokenBalanceBeforeSwap;
        item.destinationTokenValue = diff;

        emit Swapped(msg.sender, item.unlocker,item.token, item.destinationTokenValue, item.unlockTime);
        amount = 0;     
    }
    

    function withdraw(address creator, uint nonce) external {
        SwapRequest storage item = userToIdToRequest[creator][nonce];
        // if(item.creator != msg.sender || item.unlocker != msg.sender){
        //     revert UnAuthorizedEntry();
        // }
        
        if(msg.sender == item.creator) {
            require(block.timestamp >= item.unlockTime, "Wait until timeout!");
            uint balance = item.destinationTokenValue;       
            IERC20(item.token).transferFrom(address(this), msg.sender, balance);
            emit CreatorWithdrew(msg.sender, balance, block.timestamp);
            item.creator = address(0);
            item.destinationTokenValue = 0;
            item.lockedValue = 0;
            item.token = address(0);
            item.unlocker = address(0);
            item.unlockTime = 0;
        
        } else if(msg.sender == item.unlocker) {
            require(block.timestamp < item.unlockTime, "Timeout has passed, cannot withdraw!");
            uint balance = item.destinationTokenValue;       
            IERC20(item.token).transferFrom(address(this), msg.sender, balance);
            emit UnlockerWithdrew(msg.sender, balance, block.timestamp);
            item.creator = address(0);
            item.destinationTokenValue = 0;
            item.lockedValue = 0;
            item.token = address(0);
            item.unlocker = address(0);
            item.unlockTime = 0;
        } else {
            revert("You are neither depositor nor beneficiary!");
        }      
        
    }

    

}