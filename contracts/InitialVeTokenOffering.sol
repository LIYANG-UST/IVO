// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

interface IVeToken {
	function lock(address _receiver, uint256 _amount, uint256 _period) external;
}

interface IERC20Mintable {
	function mint(address _receiver, uint256 _amount) external;
}

contract InitialVeTokenOffering is Ownable {
	// Mainnet WETH address
	address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
	address public baseToken;
	address public veToken;

	uint256 public endTimestamp;

	// Token address => Chainlink price feed address, address(0) means unsupported
	// ETH & WETH are supported by default
	mapping(address => address) supportedToken;

	struct FundingInfo {
		// Funded value in USD, scaled by 1e8
		uint256 fundValue;
		uint256 option;
	}
	mapping(address => FundingInfo) public record;

	// Option => ICO price
	mapping(uint256 => uint256) public options;

	constructor(address _baseToken, address _veToken, uint256 _durationInDays) {
		baseToken = _baseToken;
		veToken = _veToken;
		endTimestamp = block.timestamp + _durationInDays * 24 * 3600;
		// Chainlink mainnet ETH/USD price feed
		supportedToken[WETH] = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
		// ICO prices for different options, scaled by 1e8
		options[1] = 5e7; // 0.5 USD
		options[2] = 4e7; // 0.4 USD
		options[3] = 2e7; // 0.2 USD
	}

	function supportToken(address _token, address _feedAddress) external onlyOwner {
		supportedToken[_token] = _feedAddress;
	}

	function setOption(uint256 _option, uint256 _price) external onlyOwner {
		require(_option > 0, "Option cannot be 0");

		options[_option] = _price;
	}

	function fund(address _token, uint256 _amount, uint256 _option) external {
		require(block.timestamp < endTimestamp, "IVO already ended");
		require(supportedToken[_token] != address(0), "Token not supported");

		IERC20(_token).transferFrom(msg.sender, address(this), _amount);

		FundingInfo storage info = record[msg.sender];
		record[msg.sender].fundValue += _getValue(_token, _amount);
		// Never funded before
		if (info.option == 0) {
			changeOption(_option);
		} 
		// Funded before, add funds, _option == 0 means option unchanged
		else {
			if (_option != 0) changeOption(_option);
		}
	}

	function fundWithETH(uint256 _option) payable external {
		require(block.timestamp < endTimestamp, "IVO already ended");

		FundingInfo storage info = record[msg.sender];
		record[msg.sender].fundValue += _getValue(WETH, msg.value);
		// Never funded before
		if (info.option == 0) {
			changeOption(_option);
		} 
		// Funded before, add funds, _option == 0 means option unchanged
		else {
			if (_option != 0) changeOption(_option);
		}
	}

	function changeOption(uint256 _newOption) public {
		require(record[msg.sender].fundValue > 0, "You did not fund anything");
		require(_newOption > 0 && _newOption < 4, "Invalid option"); 
		record[msg.sender].option = _newOption;
	}

	function claim() external {
		require(block.timestamp > endTimestamp, "IVO not yet ended");

		FundingInfo memory info = record[msg.sender];
		require(info.fundValue > 0, "You did not participate");

		uint256 mintAmount = info.fundValue * 1e18 / options[info.option];
		if (info.option == 1) IERC20Mintable(baseToken).mint(msg.sender, mintAmount);
		else IERC20Mintable(baseToken).mint(address(this), mintAmount);

		// Lock into veToken for 3 months 
		if (info.option == 2) IVeToken(veToken).lock(msg.sender, mintAmount, 90 days);
		// Lock into veToken for 1 year
		else IVeToken(veToken).lock(msg.sender, mintAmount, 365 days);

		delete record[msg.sender];
	}

	// Get USD value of fund amount, scaled by 1e8
	function _getValue(address _token, uint256 _amount) internal view returns (uint256 value) {
		(
            /* uint80 roundID */,
            int256 price,
            /*uint startedAt*/,
            /*uint timeStamp*/,
            /*uint80 answeredInRound*/
        ) = AggregatorV3Interface(supportedToken[_token]).latestRoundData();
        uint256 formatPrice = price < 0 ? 0 : uint256(price);

		value = formatPrice * _amount / IERC20Metadata(_token).decimals();
	}
}