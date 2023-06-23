// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./IExchange_latest.sol";

contract DefiToken is ERC20, Ownable {
    // tax
    uint256 FeeDecimals = 1000000;
    struct Fee {
        uint256 marketing_fee;
        uint256 reserve_fee;
        uint256 auto_lp;
    }
    struct FeeWallet {
        address marketing;
        address reserve;
    }

    uint8 _decimals = 18;

    Fee private sellFees;
    Fee private buyFees;
    FeeWallet public feeWallets;

    uint256 marketingPercent;
    uint256 reservePercent;
    uint256 autoLPPercent;

    mapping(address => bool) public isExcludeFromFee;

    // tx limit
    uint256 public _numTokensSellToAddToLiquidity;
    bool public _swapAndLiquifyEnabled = true;

    // exchange info
    IDexRouter public DexRouter;
    address public DexPair;

    //swap
    bool public inSwapAndLiquify;
    modifier lockTheSwap() {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }

    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        uint8 decimals_,
        address _RouterAddress,
        uint numTokensSellToAddToLiquidity_
    ) ERC20(name, symbol) {
        _mint(msg.sender, initialSupply);
        _decimals = decimals_;

        IDexRouter _DexRouter = IDexRouter(_RouterAddress);
        DexRouter = _DexRouter;
        DexPair = IDexFactory(_DexRouter.factory()).createPair(
            address(this),
            _DexRouter.WETH()
        );

        isExcludeFromFee[msg.sender] = true;
        isExcludeFromFee[address(this)] = true;
        _numTokensSellToAddToLiquidity = numTokensSellToAddToLiquidity_;
    }

    function setDexPair(address _RouterAddress) external onlyOwner {
        IDexRouter _DexRouter = IDexRouter(_RouterAddress);
        DexRouter = _DexRouter;
        DexPair = IDexFactory(_DexRouter.factory()).createPair(
            address(this),
            _DexRouter.WETH()
        );
    }

    function setFees(
        uint256 sell_marketing_fee, // 1000 : 0.1%
        uint256 sell_reserve_fee,
        uint256 sell_auto_lp,
        uint256 buy_marketing_fee,
        uint256 buy_reserve_fee,
        uint256 buy_auto_lp
    ) external onlyOwner {
        sellFees.marketing_fee = sell_marketing_fee;
        sellFees.reserve_fee = sell_reserve_fee;
        sellFees.auto_lp = sell_auto_lp;

        buyFees.marketing_fee = buy_marketing_fee;
        buyFees.reserve_fee = buy_reserve_fee;
        buyFees.auto_lp = buy_auto_lp;

        require(getTotalSellFee() <= 200000, "sell fees is over 20%");
        require(getTotalBuyFee() <= 200000, "buy fee is over 20%");
    }

    function setTxLimit(
        uint256 numTokensSellToAddToLiquidity,
        bool swapAndLiquifyEnabled
    ) external onlyOwner {
        _numTokensSellToAddToLiquidity = numTokensSellToAddToLiquidity;
        _swapAndLiquifyEnabled = swapAndLiquifyEnabled;
    }

    function getTotalSellFee() public view returns (uint256 totalFee) {
        totalFee =
            sellFees.marketing_fee +
            sellFees.reserve_fee +
            sellFees.auto_lp;
    }

    function getTotalBuyFee() public view returns (uint256 totalFee) {
        totalFee =
            buyFees.marketing_fee +
            buyFees.reserve_fee +
            buyFees.auto_lp;
    }

    function setFeeWallets(
        address marketing,
        address reserve
    ) external onlyOwner {
        feeWallets.marketing = marketing;
        feeWallets.reserve = reserve;
    }

    function setExcludFromFee(address to, bool _excluded) external onlyOwner {
        isExcludeFromFee[to] = _excluded;
    }

    function _transferWithOutFeeCalculate(
        address from,
        address to,
        uint256 amount
    ) internal {
        super._transfer(from, to, amount);
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        // normal transfer for fee excluded wallet
        if (isExcludeFromFee[from] || isExcludeFromFee[to]) {
            _transferWithOutFeeCalculate(from, to, amount);
            return;
        }

        uint256 recieveAmount = amount;
        if (to == DexPair) {
            //sell
            _transferWithOutFeeCalculate(
                from,
                address(this),
                (amount * getTotalSellFee()) / FeeDecimals
            );
            marketingPercent += (amount * sellFees.marketing_fee) / FeeDecimals;
            reservePercent += (amount * sellFees.reserve_fee) / FeeDecimals;
            autoLPPercent += (amount * sellFees.auto_lp) / FeeDecimals;

            recieveAmount = amount - (amount * getTotalSellFee()) / FeeDecimals;
        } else if (from == DexPair) {
            //buy
            _transferWithOutFeeCalculate(
                from,
                address(this),
                (amount * getTotalBuyFee()) / FeeDecimals
            );

            marketingPercent += (amount * buyFees.marketing_fee) / FeeDecimals;
            reservePercent += (amount * buyFees.reserve_fee) / FeeDecimals;
            autoLPPercent += (amount * buyFees.auto_lp) / FeeDecimals;

            recieveAmount = amount - (amount * getTotalBuyFee()) / FeeDecimals;
        }
        {
            // normal transfer
            uint256 contractTokenBalance = balanceOf(address(this));
            bool overMinTokenBalance = contractTokenBalance >=
                _numTokensSellToAddToLiquidity;
            if (
                !inSwapAndLiquify && from != DexPair && _swapAndLiquifyEnabled
            ) {
                if (overMinTokenBalance)
                    contractTokenBalance = _numTokensSellToAddToLiquidity;
                //add liquidity
                swapAndLiquify(contractTokenBalance);
            }
        }

        _transferWithOutFeeCalculate(from, to, recieveAmount);
    }

    function swapAndLiquify(uint256 contractTokenBalance) private lockTheSwap {
        // total reward amount
        uint256 totalPercent = autoLPPercent +
            marketingPercent +
            reservePercent;

        // split the contract balance into halves
        if (totalPercent == 0) return;

        if (contractTokenBalance > totalPercent)
            contractTokenBalance = totalPercent;

        // each fee amount base on percent
        uint256 autoLPAmount = (contractTokenBalance * autoLPPercent) /
            totalPercent;
        uint256 marketingFeeAmount = (contractTokenBalance * marketingPercent) /
            totalPercent;
        uint256 reserveFeeAmount = (contractTokenBalance * reservePercent) /
            totalPercent;

        // // fee share
        uint256 otherHalf = contractTokenBalance - autoLPAmount / 2;
        uint256 initialBalance = address(this).balance;

        if (otherHalf > 0) swapTokensForEth(otherHalf);
        if (autoLPAmount > 0)
            addLiquidity(
                autoLPAmount / 2,
                address(this).balance - initialBalance
            );

        // remained balance to reward marketing and reserve
        uint256 remainedBalance = address(this).balance - initialBalance;

        // total percent
        totalPercent = marketingPercent + reservePercent;

        // distribute fees
        uint256 marketingFeeBalance = (remainedBalance * marketingPercent) /
            totalPercent;
        uint256 reserveFeeBalance = (remainedBalance * reservePercent) /
            totalPercent;

        payable(feeWallets.marketing).transfer(marketingFeeBalance);
        payable(feeWallets.reserve).transfer(reserveFeeBalance);

        autoLPPercent -= autoLPAmount;
        marketingPercent -= marketingFeeAmount;
        reservePercent -= reserveFeeAmount;
    }

    // auto lp
    function swapTokensForEth(uint256 tokenAmount) private {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = DexRouter.WETH();

        _approve(address(this), address(DexRouter), tokenAmount);

        DexRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
        _approve(address(this), address(DexRouter), tokenAmount);

        DexRouter.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            owner(),
            block.timestamp
        );
    }

    receive() external payable {}

    function claimstuckedToken(
        address token,
        uint256 amount
    ) external onlyOwner {
        if (token == address(0)) payable(msg.sender).transfer(amount);
        else IERC20(token).transfer(msg.sender, amount);
    }
}
