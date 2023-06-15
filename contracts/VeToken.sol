// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./ERC20Upgradeable.sol";

contract VeToken is OwnableUpgradeable, ERC20Upgradeable {
	// Max number of veToken minted for each base token locked, scaled by 1e18
	uint256 constant MAX_RATIO = 1e18;

	address public baseToken;

	// Lock period (in seconds) => mint ratio
	mapping(uint256 => uint256) public plans;

	// User => locked amount
	struct LockInfo {
		// Total amount of FUR locked
		uint256 amount;
		// Most recent lock timestamp, for calculating balance
		uint256 lockTime;
		// Most recent lock period, for calculating balance
		uint256 lockPeriod;
	}
	mapping(address => LockInfo) public lockInfo;

	// Whitelisted addresses can unlock any users' base token 
	// without burning their veToken
	mapping(address => bool) whitelisted;

	function initialize(string memory _name, string memory _symbol, address _baseToken) public initializer {
		__ERC20_init(_name, _symbol);
		__Ownable_init();

		baseToken = _baseToken;

		// 3 months, 0.2 veToken per base token locked
		setPlan(90 days, 2e17);
		// 1 year, 1 veToken per base token locked
		setPlan(365 days, 1e18);
	}
	
	/**
	 * @notice Decreases with time, becomes 0 upon reaching unlcok time
	 */ 
	function balanceOf(address account) public view override returns (uint256) {
		LockInfo memory info = lockInfo[account];

		uint256 unlockTime = info.lockTime + info.lockPeriod;
		if (block.timestamp >= unlockTime) return 0;

		// Time elapsed since most recent locking
		uint256 timeElapsed = block.timestamp - info.lockTime;

		// For how long before balance becomes 0
		uint256 timeRemaining = info.lockPeriod - timeElapsed;

        return _balanceOfMinted(account) * timeRemaining / info.lockPeriod;
    }

	/**
	 * @param _period Lock time in seconds
	 * @param _ratio Mint ratio for the plan, scaled by 1e18
	 */
	function setPlan(uint256 _period, uint256 _ratio) public onlyOwner {
		require(_ratio <= MAX_RATIO, "Invalid mint ratio");

		plans[_period] = _ratio;
	}

	/**
	 * @param _receiver Address receiving minted veTokens
	 * @param _amount Amount of base tokens to lock
	 * @param _period How long to lock for
	 * @notice Renew user balance. 
	 *   Unlock time is { the most recent timestamp + the most recent period chosen }
	 *   i.e. Locked once 3 months, then locked again but for 1 year -> amount of base
	 *   tokens locked with the 3 months plan will be unlocked after 1 year as well.
	 *   veToken for previous lock period will be minted/burnt based on the new period chosen
	 */
	function lock(address _receiver, uint256 _amount, uint256 _period) external {
		require(plans[_period] > 0, "Invalid locking period (plan)");

		// Transfer base token for locking
		IERC20(baseToken).transferFrom(msg.sender, address(this), _amount);

		// Burn all minted from previous lock
		_burn(_receiver, _balanceOfMinted(_receiver));

		LockInfo storage info = lockInfo[_receiver];
		info.amount += _amount;
		info.lockTime = block.timestamp;
		info.lockPeriod = _period;

		uint256 mintAmount = info.amount * plans[_period] / 1e18;
		_mint(_receiver, mintAmount);
	}

	/**
	 * @notice Redeem all locked base token. There is no point to redeem only 
	 *   a partial amount because valid veToken balance is 0 when unlock time is reached
	 */
	function redeem() external {
		LockInfo memory info = lockInfo[msg.sender];
		if (!whitelisted[msg.sender]) {
			uint256 unlockTime = info.lockTime + info.lockPeriod;
			require(block.timestamp > unlockTime, "Not yet reached unlock time");
			
			_burn(msg.sender, _balanceOfMinted(msg.sender));
			delete lockInfo[msg.sender];
		}

		IERC20(baseToken).transfer(msg.sender, info.amount);
	}

	/**
	 * @notice Represents only the amount of veToken minted to user, however not
	 *   all minted veToken is valid due to tiem-dependent mechanism. Actual valid
	 *   balance is obtained through querying { balanceOf() }
	 */
	function _balanceOfMinted(address _account) public view returns (uint256) {
		return _balances[_account];
	}
}