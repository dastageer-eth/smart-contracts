//SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./Interface/IUniswapV2Factory.sol";
import "./Interface/IUniswapV2Pair.sol";
import "./Interface/IUniswapV2Router.sol";
import "./Interface/ILendingPoolAddressesProvider.sol";
import "./Interface/ILendingPool.sol";

contract StakingContract {
    ILendingPoolAddressesProvider private provider;
    ILendingPool private lendingPool;

    struct Stake {
        address staker;
        uint stakedAmount;
        uint timeStamp;
        bool status;
    }

    address internal constant aWETH =
        0x87b1f4cf9BD63f7BBD3eE1aD04E8F52540349347;
    address internal constant IWETHAddress =
        0xA61ca04DF33B72b235a8A28CfB535bb7A5271B70;
    address internal constant UNISWAP_V2_ROUTER =
        0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address internal constant WETH = 0xd0A1E359811322d97991E03f863a0C30C2cF029C;

    event LendingPool(ILendingPool lendingPoolAddress);
    event Amount(uint amount);
    event LiquidityRes(uint amountA, uint amountB, uint liquidity);
    event Logic(uint profit, uint swapAmount);

    address public owner;

    uint public immutable MINIMUM_STAKING_AMOUNT = 100;
    uint public immutable StakeEndTime = 1000;
    uint public withdrawalAmount;
    uint public amountSwapped;

    mapping(address => Stake) public stakes;

    constructor() {
        owner = msg.sender;
        provider = ILendingPoolAddressesProvider(
            0x88757f2f99175387aB4C6a4b3067c77A695b0349
        );
        lendingPool = ILendingPool(provider.getLendingPool());
        emit LendingPool(lendingPool);
    }

    function stake(address token, uint _amount) external {
        require(
            _amount >= MINIMUM_STAKING_AMOUNT,
            "Invalid Staking amount, please provide atleast minimum staking amount"
        );
        require(
            IERC20(token).transferFrom(msg.sender, address(this), _amount),
            "Token Transfer failed"
        );

        Stake memory stakers;
        stakers.staker = msg.sender;
        stakers.stakedAmount = _amount;
        stakers.timeStamp = block.timestamp + StakeEndTime;
        stakers.status = true;

        stakes[msg.sender] = stakers;
    }

    function unStake(address token, uint _amount) external {
        require(stakes[msg.sender].status, "Not a staker");
        require(
            stakes[msg.sender].timeStamp >= block.timestamp,
            "Stake Time not Over"
        );
        require(withdrawalAmount >= _amount, "Staked amount is less");

        stakes[msg.sender].stakedAmount =
            stakes[msg.sender].stakedAmount -
            _amount;
        IERC20(token).transfer(msg.sender, _amount);
    }

    function contractBal(address token) public view returns (uint) {
        return IERC20(token).balanceOf(address(this));
    }

    function depositOnAave(address token) public {
        uint amount = stakes[msg.sender].stakedAmount;
        IERC20(token).approve(address(lendingPool), amount);
        lendingPool.deposit(token, amount, address(this), 0);
    }

    function totalFunds() public view returns (uint256) {
        return IERC20(aWETH).balanceOf(address(this));
    }

    function withdrawFromAave(address token) public {
        uint amount = totalFunds();
        IERC20(aWETH).approve(IWETHAddress, amount);
        lendingPool.withdraw(token, amount, address(this));
        withdrawalAmount = amount;
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin
    ) public {
        IERC20(tokenA).transferFrom(msg.sender, address(this), amountADesired);
        IERC20(tokenB).transferFrom(msg.sender, address(this), amountBDesired);

        IERC20(tokenA).approve(UNISWAP_V2_ROUTER, amountADesired);
        IERC20(tokenB).approve(UNISWAP_V2_ROUTER, amountBDesired);

        (uint amountA, uint amountB, uint liquidity) = IUniswapV2Router02(
            UNISWAP_V2_ROUTER
        ).addLiquidity(
                tokenA,
                tokenB,
                amountADesired,
                amountBDesired,
                amountAMin,
                amountBMin,
                msg.sender,
                block.timestamp + 1000
            );
        emit LiquidityRes(amountA, amountB, liquidity);
    }

    function swap(
        address tokenIn,
        address tokenOut,
        uint amountIn,
        address _to
    ) public {
        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
        IERC20(tokenIn).approve(UNISWAP_V2_ROUTER, amountIn);

        address[] memory path;

        path = new address[](2);
        path[0] = tokenIn;
        path[1] = tokenOut;

        uint[] memory amountOutMins = IUniswapV2Router02(UNISWAP_V2_ROUTER)
            .getAmountsOut(amountIn, path);
        amountSwapped = amountOutMins[path.length - 1];

        IUniswapV2Router02(UNISWAP_V2_ROUTER).swapExactTokensForTokens(
            amountIn,
            amountSwapped,
            path,
            _to,
            block.timestamp + 1000
        );
    }

    // function getAmountOutMin(address _tokenIn, address _tokenOut, uint _amountIn) external view returns (uint) {
    //     address[] memory path;

    //     path = new address[](2);
    //     path[0] = _tokenIn;
    //     path[1] = _tokenOut;

    //     uint[] memory amountOutMins = IUniswapV2Router02(UNISWAP_V2_ROUTER).getAmountsOut(_amountIn, path);

    //     return amountOutMins[path.length - 1];
    // }

    function profitDistribution(address token) public {
        uint profitUser = ((withdrawalAmount -
            stakes[msg.sender].stakedAmount) * 80) / 100;

        IERC20(token).transfer(msg.sender, profitUser);
        IERC20(token).transfer(owner, (profitUser * 25) / 100);
    }

    function originalValueDistribution(address token, address tokenB) public {
        uint userTransfer = (stakes[msg.sender].stakedAmount * 80) / 100;
        uint swapAmount = (stakes[msg.sender].stakedAmount * 20) / 100;

        IERC20(token).transfer(msg.sender, userTransfer);

        swap(token, tokenB, swapAmount, msg.sender);

        IERC20(token).transfer(msg.sender, amountSwapped / 2);
    }
}
