//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "./interfaces/WETHInterface.sol";
import "./interfaces/IUniswapV2Router.sol";
import "./interfaces/IERC20.sol";
import "./Vault.sol";

contract AssetLockFactory {

    event Deposited(address indexed depositor, address indexed beneficiary, address token);
    event Swapped(address indexed caller, address indexed vault);
    event CreatorWithdrew(address indexed owner, uint indexed amount, uint time);
    event UnlockerWithdrew(address indexed beneficiary, uint indexed amount, uint time);

    address owner;
    

    address private constant UNISWAP_V2_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address private constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    constructor(){
        owner = msg.sender;
    }
    

    mapping(address => mapping(address => mapping(address => uint))) public userToBeneficiaryToTokenToAmount;
    mapping(address => mapping(address => mapping(address => address))) private vaultAddresses;
    mapping(address => mapping(address => mapping(address => uint))) public userToBeneficiaryToTokenToSwappedAmount;
    
    

    function createDeposit(address token, address beneficiary) public payable {
        require(msg.value >= 1 ether, "Send at least 1 ether");
        require(token != address(0), "UserInterface: Token address must exist!"); //improve by validating user ERC165
        require(beneficiary != address(0), "UserInterface: Address must not be address zero!");
        require(userToBeneficiaryToTokenToAmount[msg.sender][beneficiary][token] == 0, "You have a pending swap, withdraw it first!");

        
        userToBeneficiaryToTokenToAmount[msg.sender][beneficiary][token] = msg.value;
        emit Deposited(msg.sender, beneficiary, token);
    }

    function initiateSwap(address beneficiary, address token, uint _timeInHours) public {
        require(userToBeneficiaryToTokenToAmount[msg.sender][beneficiary][token] > 0, "Make deposit first!");
                
        IWETH weth = IWETH(WETH);
        uint amount = userToBeneficiaryToTokenToAmount[msg.sender][beneficiary][token];
        userToBeneficiaryToTokenToAmount[msg.sender][beneficiary][token] = 0;
        weth.deposit{value: amount}();
        weth.transfer(address(this), amount);
        // amount = 0;

        //2. WETH(account) to destination ERC20
        weth.approve(UNISWAP_V2_ROUTER, amount);

        //3. Create swap path
        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = token;

        //4. Perform swap
        
        Vault vault = new Vault(msg.sender, beneficiary, token, address(this), _timeInHours);
        address creator = vault.getCreator();
        address unlocker = vault.getBeneficiary();
        // uint256 MAX_INT = 2**256 - 1;
        // IERC20(token).approve(unlocker, type(uint256).max);
        vaultAddresses[creator][unlocker][token] = address(vault);
        uint tokenBalanceBeforeSwap = IERC20(token).balanceOf(address(this));
        IUniswapV2Router(UNISWAP_V2_ROUTER).swapExactTokensForTokens(amount,1,path,address(this),block.timestamp);
        uint tokenBalanceAfterSwap = IERC20(token).balanceOf(address(this));
        uint diff = tokenBalanceAfterSwap - tokenBalanceBeforeSwap;
        userToBeneficiaryToTokenToSwappedAmount[creator][unlocker][token] = diff;


        emit Swapped(msg.sender, address(vault));
        amount = 0;     


    }


    

    function withdraw(address creator, address beneficiary, address token) external {
        require(vaultAddresses[creator][beneficiary][token] != address(0), "You cannot withdraw!");
        address vaultAddress = vaultAddresses[creator][beneficiary][token];
        Vault vault = Vault(vaultAddress);
        
        if(msg.sender == vault.getCreator()) {
            require(block.timestamp >= vault.getTimeout(), "Wait until timeout!");
            uint balance = userToBeneficiaryToTokenToSwappedAmount[creator][beneficiary][token];       
            IERC20(token).transferFrom(address(this), msg.sender, balance);
            emit CreatorWithdrew(msg.sender, balance, block.timestamp);
            vaultAddresses[creator][beneficiary][token] = address(0);
        
        } else if(msg.sender == vault.getBeneficiary()) {
            require(block.timestamp < vault.getTimeout(), "Timeout has passed, cannot withdraw!");
            uint balance = userToBeneficiaryToTokenToSwappedAmount[creator][beneficiary][token];       
            IERC20(token).transferFrom(address(this), msg.sender, balance);
            emit UnlockerWithdrew(msg.sender, balance, block.timestamp);
            vaultAddresses[creator][beneficiary][token] = address(0);
        } else {
            revert("You are neither depositor nor beneficiary!");
        }      
        
    }

    function getVaultAddress(address creator, address beneficiary, address token) external view returns(address) {
            require(msg.sender == owner, "You cannot call this function");
            return vaultAddresses[creator][beneficiary][token];
        }

}