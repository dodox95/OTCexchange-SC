// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol"; 

contract OTCMarket is ReentrancyGuard, Ownable {
    struct Order {
        address issuer;
        uint256 amount;
        uint256 price;
        bool isBuyOrder;
        bool isActive;
    }

    Order[] public buyOrders;
    Order[] public sellOrders;

    IERC20 public token;
    IERC20 public stablecoin;  
    uint256 public fee = 1 * (10 ** 18);
    address public feeRecipient = 0xE8661a43dA567b60bADb5559b5b33a246c058F3e; 

    event OrderMatched(uint256 buyOrderId, uint256 sellOrderId);
    event OrderCreated(uint256 orderId, bool isBuyOrder);
    event OrderCancelled(uint256 orderId, bool isBuyOrder);
    event DepositWithdrawn(uint256 orderId, bool isBuyOrder);
    event FeePaid(address indexed payer, uint256 feeAmount);

    uint256 public minOrderValue = 1000 * (10 ** 18);

    constructor(address _token, address initialOwner) 
        Ownable(initialOwner)
    {
        token = IERC20(_token);
        feeRecipient = msg.sender; 
    }


    function createBuyOrder(uint256 amount, uint256 price) public {
        require(amount > 0 && price > 0, "Amount and price should be greater than 0");
        uint256 orderValue = amount * price;
        require(orderValue >= minOrderValue, "Order value must meet the minimum requirement");
        require(stablecoin.transferFrom(msg.sender, address(this), orderValue), "Transfer failed");
        require(stablecoin.transferFrom(msg.sender, feeRecipient, fee), "Fee transfer failed");
        buyOrders.push(Order(msg.sender, amount, price, true, true));
        emit OrderCreated(buyOrders.length - 1, true);
        emit FeePaid(msg.sender, fee);
    }

    function createSellOrder(uint256 amount, uint256 price) public {
        require(amount > 0 && price > 0, "Amount and price should be greater than 0");
        require(token.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        require(stablecoin.transferFrom(msg.sender, feeRecipient, fee), "Fee transfer failed");
        sellOrders.push(Order(msg.sender, amount, price, false, true));
        emit OrderCreated(sellOrders.length - 1, false);
        emit FeePaid(msg.sender, fee);
    }

    function cancelOrder(uint256 orderId, bool isBuyOrder) public {
        Order storage order = isBuyOrder ? buyOrders[orderId] : sellOrders[orderId];
        require(msg.sender == order.issuer, "Only issuer can cancel");
        require(order.isActive, "Order already cancelled or matched");
        
        order.isActive = false;

        if(isBuyOrder) {
            require(stablecoin.transfer(msg.sender, order.amount * order.price), "Refund failed");
        } else {
            require(token.transfer(msg.sender, order.amount), "Refund failed");
        }

        emit OrderCancelled(orderId, isBuyOrder);
    }

    function withdrawDeposit(uint256 orderId, bool isBuyOrder) public nonReentrant {
        Order storage order = isBuyOrder ? buyOrders[orderId] : sellOrders[orderId];
        require(msg.sender == order.issuer, "Only issuer can withdraw");
        require(order.isActive, "Order must be active to withdraw deposit");

        order.isActive = false;

        if (isBuyOrder) {
            require(stablecoin.transfer(msg.sender, order.amount * order.price), "Withdrawal failed");
        } else {
            require(token.transfer(msg.sender, order.amount), "Withdrawal failed");
        }

        emit DepositWithdrawn(orderId, isBuyOrder);
    }

    function matchOrders(uint256 buyOrderId, uint256 sellOrderId) public {
        Order storage buyOrder = buyOrders[buyOrderId];
        Order storage sellOrder = sellOrders[sellOrderId];

        require(buyOrder.isActive && sellOrder.isActive, "Both orders must be active");
        require(buyOrder.price >= sellOrder.price, "Buy price must be higher than or equal to sell price");

        uint256 matchedAmount = min(buyOrder.amount, sellOrder.amount);
        uint256 matchedValue = matchedAmount * sellOrder.price;

        buyOrder.amount -= matchedAmount;
        sellOrder.amount -= matchedAmount;

        if(buyOrder.amount == 0) {
            buyOrder.isActive = false;
        }

        if(sellOrder.amount == 0) {
            sellOrder.isActive = false;
        }

        stablecoin.transfer(sellOrder.issuer, matchedValue);
        token.transfer(buyOrder.issuer, matchedAmount);

        emit OrderMatched(buyOrderId, sellOrderId);
    }

    function min(uint256 a, uint256 b) private pure returns (uint256) {
        return a < b ? a : b;
    }

    function setMinOrderValue(uint256 _minOrderValue) public onlyOwner {
        minOrderValue = _minOrderValue;
    }

    function setFeeRecipient(address _feeRecipient) public onlyOwner {
        feeRecipient = _feeRecipient;
    }

    function setFee(uint256 _fee) public onlyOwner {
        fee = _fee;
    }
}
