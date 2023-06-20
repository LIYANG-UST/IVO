// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface IVeToken {
    function delegateLock(address _receiver, uint256 _amount, uint256 _period) external;
}

interface IERC20Mintable {
    function mint(address _receiver, uint256 _amount) external;
}

contract InitialVeTokenOffering is Ownable {
    address public immutable baseToken;
    address public immutable veToken;
    struct TokenType {
        bool isVeToken;
        uint256 lockedPeriod;
    }
    // 1 => Base Token, no lock
    // 2 => VeToken locked for 3 months
    mapping(uint256 saleId => TokenType tokenType) public tokenTypes;

    uint256 public constant INIT_STATUS = 0;
    uint256 public constant PENDING_START = 1;
    uint256 public constant LIVE = 2;
    uint256 public constant CLAIMABLE = 3;

    struct Sale {
        uint256 price;
        uint256 totalAmount;
        uint256 soldAmount;
        uint256 deadline;
        uint256 status;
    }
    mapping(uint256 saleId => Sale sale) public sales;

    // User address => Sale ID => User bought amount
    mapping(address user => mapping(uint256 saleId => uint256 amount)) public userBought;

    uint256 public currentSaleId;

    event IVOTokenClaimed(address indexed user, uint256 indexed saleId, uint256 _amount);
    event NewSaleAdded(
        uint256 indexed saleId,
        bool _isVeToken,
        uint256 _lockedPeriod,
        uint256 _price,
        uint256 _totalAmount,
        uint256 _deadline
    );
    event SaleStarted(uint256 indexed saleId);
    event SaleSettled(uint256 saleId);
    event IVOTokenBought(address user, uint256 saleId, uint256 amount);

    constructor(address _baseToken, address _veToken) {
        baseToken = _baseToken;
        veToken = _veToken;
    }

    modifier notContract() {
        // solhint-disable-next-line avoid-tx-origin
        require(msg.sender == tx.origin, "Contracts are not allowed");
        _;
    }

    function getUserBoughtAmount(address _user, uint256 _saleId) public view returns (uint256) {
        return userBought[_user][_saleId];
    }

    function addNewSale(
        bool _isVeToken,
        uint256 _lockedPeriod,
        uint256 _price,
        uint256 _totalAmount,
        uint256 _deadline
    ) public {
        require(block.timestamp < _deadline, "Endtime already passed");
        require(_totalAmount > 0, "Total amount cannot be 0");
        if (_isVeToken) require(_lockedPeriod > 0, "Lock period cannot be 0");

        uint256 currentId = ++currentSaleId;

        TokenType storage tokenType = tokenTypes[currentId];
        tokenType.isVeToken = _isVeToken;
        tokenType.lockedPeriod = _lockedPeriod;

        Sale storage sale = sales[currentId];
        sale.price = _price;
        sale.totalAmount = _totalAmount;
        sale.deadline = _deadline;

        sale.status = PENDING_START;

        emit NewSaleAdded(currentId, _isVeToken, _lockedPeriod, _price, _totalAmount, _deadline);
    }

    function startSale(uint256 _saleId) external onlyOwner {
        Sale storage sale = sales[_saleId];

        require(sale.status == PENDING_START, "Sale already started");

        sale.status = LIVE;

        emit SaleStarted(_saleId);
    }

    function buy(uint256 _saleId, uint256 _amount) external payable notContract {
        Sale storage sale = sales[_saleId];

        require(block.timestamp < sale.deadline, "Sale already ended");
        require(sale.soldAmount + _amount <= sale.totalAmount, "Not enough tokens left");
        require((sale.price * _amount) / 1e18 <= msg.value, "Invalid amount");

        sale.soldAmount += _amount;

        userBought[msg.sender][_saleId] += _amount;

        uint256 extraFund = msg.value - (sale.price * _amount) / 1e18;
        _refund(msg.sender, extraFund);

        emit IVOTokenBought(msg.sender, _saleId, _amount);
    }

    function settle(uint256 _saleId) external onlyOwner {
        Sale storage sale = sales[_saleId];

        require(block.timestamp >= sale.deadline, "Sale not ended yet");

        sale.status = CLAIMABLE;

        emit SaleSettled(_saleId);
    }

    function claim(uint256 _saleId) external {
        Sale storage sale = sales[_saleId];

        require(sale.status == CLAIMABLE, "Sale not claimable");

        uint256 amount = userBought[msg.sender][_saleId];

        require(amount > 0, "No tokens to claim");

        if (tokenTypes[_saleId].isVeToken) {
            IERC20Mintable(baseToken).mint(address(this), amount);
            IVeToken(veToken).delegateLock(msg.sender, amount, tokenTypes[_saleId].lockedPeriod);
        } else {
            IERC20Mintable(baseToken).mint(msg.sender, amount);
        }

        emit IVOTokenClaimed(msg.sender, _saleId, amount);
    }

    function _refund(address _user, uint256 _amount) internal {
        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory res) = payable(_user).call{ value: _amount }("");
        require(success, "Refund failed");
    }
}
