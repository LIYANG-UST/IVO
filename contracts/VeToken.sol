// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
// import "./ERC20Upgradeable.sol";

import { ERC721Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";

contract VeToken is OwnableUpgradeable, ERC721Upgradeable {
    uint256 public constant MAX_LOCK_PERIOD = 360 days;

    address public baseToken;

    uint256 public totalSupply;

    uint256 public totalVeNFTs;

    mapping(uint256 tokenId => address user) public tokenIdToOwner;
    mapping(address user => uint256[] tokens) public ownerToTokenIds;
    mapping(uint256 tokenId => uint256 ownerIndex) public tokenToOwnerIndexes;

    struct Level {
        uint256 lockedPeriod;
        uint256 mintRatio;
    }
    // Lock period level to lock time in seconds
    // e.g. 1 => 90 days, 2 => 1 year
    mapping(uint256 level => Level levelInfo) public lockPeriodLevels;

    struct LockedInfo {
        uint256 amount;
        uint256 endTimestamp;
    }
    mapping(uint256 tokenId => LockedInfo lockedInfo) public locks;

    enum DepositType {
        Create,
        Deposit,
        IncreaseAmount,
        IncreaseUnlockTime,
        Merge
    }

    function initialize(string memory _name, string memory _symbol, address _baseToken) public initializer {
        __ERC721_init(_name, _symbol);
        __Ownable_init();

        baseToken = _baseToken;

        // 3 months, 6 months, 9 months, 1 year
        lockPeriodLevels[1] = Level({ lockedPeriod: 90 days, mintRatio: 2e17 }); // 90days, 0.2
        lockPeriodLevels[2] = Level({ lockedPeriod: 180 days, mintRatio: 4e17 }); // 180days, 0.4
        lockPeriodLevels[3] = Level({ lockedPeriod: 270 days, mintRatio: 6e17 }); // 270days, 0.6
        lockPeriodLevels[4] = Level({ lockedPeriod: 360 days, mintRatio: 1e18 }); // 360days, 1
    }

    function setLockLevels(uint256[] calldata _lockPeriods, uint256[] calldata _mintRatios) external {
        for (uint256 i; i < _lockPeriods.length; i++) {
            lockPeriodLevels[i + 1] = Level({ lockedPeriod: _lockPeriods[i], mintRatio: _mintRatios[i] });
        }
    }

    /// Override ERC721 functions
    ///
    ///
    function ownerOf(uint256 _tokenId) public view override returns (address) {
        return tokenIdToOwner[_tokenId];
    }

    function balanceOf(address _owner) public view override returns (uint256) {
        return ownerToTokenIds[_owner].length;
    }

    ///
    ///
    ///

    // TODO: create a new lock
    function createLock(uint256 _amount, uint256 _lockDurationLevel, address _to) public returns (uint256 tokenId) {
        require(lockPeriodLevels[_lockDurationLevel].lockedPeriod > 0, "Invalid lock duration level");
        require(_amount > 0, "Zero lock amount");

        uint256 unlockTime = block.timestamp + lockPeriodLevels[_lockDurationLevel].lockedPeriod;

        uint256 currentTokenId = ++totalVeNFTs;
        _mintVeNFT(_to, currentTokenId);

        _deposit_for(currentTokenId, _amount, unlockTime, locks[currentTokenId], DepositType.Create);

        return currentTokenId;
    }

    function increaseAmount(uint256 _tokenId, uint256 _amount) public {
        LockedInfo memory lockedInfo = locks[_tokenId];

        assert(_amount > 0);
        require(lockedInfo.amount > 0, "No existing lock");
        require(lockedInfo.endTimestamp > block.timestamp, "Lock expired");

        _deposit_for(_tokenId, _amount, 0, lockedInfo, DepositType.IncreaseAmount);
    }

    function increaseUnlockTime(uint256 _tokenId, uint256 _lockDuration) public {
        // TODO: check approval

        LockedInfo memory lockedInfo = locks[_tokenId];

        require(lockedInfo.endTimestamp > block.timestamp, "Lock expired");
        require(lockedInfo.amount > 0, "No existing lock");

        uint256 newUnlockTime = lockedInfo.endTimestamp + _lockDuration;

        require(newUnlockTime > lockedInfo.endTimestamp, "New unlock time must be greater");
        require(newUnlockTime <= block.timestamp + MAX_LOCK_PERIOD, "Exceed max lock duration");

        _deposit_for(_tokenId, 0, newUnlockTime, lockedInfo, DepositType.IncreaseUnlockTime);
    }

    function withdraw(uint256 _tokenId) external {
        // TODO: check approval

        LockedInfo memory lockedInfo = locks[_tokenId];

        require(lockedInfo.endTimestamp <= block.timestamp, "Lock not expired");

        locks[_tokenId] = LockedInfo({ amount: 0, endTimestamp: 0 });

        totalSupply -= lockedInfo.amount;

        IERC20(baseToken).transfer(msg.sender, lockedInfo.amount);

        _burn(_tokenId);
    }

    // // TODO: deposit means only increase amount, not change lock time
    // function depositFor(uint256 _tokenId, uint256 _amount) external {
    //     LockedInfo memory lockedInfo = locks[_tokenId];

    //     require(_amount > 0, "Zero deposit amount");
    //     require(lockedInfo.amount > 0, "No existing lock");
    //     require(lockedInfo.endTimestamp > block.timestamp, "Lock expired");

    //     _deposit_for(_tokenId, _amount, 0, lockedInfo, DepositType.Deposit);
    // }

    function _mintVeNFT(address _to, uint256 _tokenId) internal returns (bool) {
        assert(_to != address(0));

        _recordNFTInfo(_to, _tokenId);
        return true;
    }

    function _recordNFTInfo(address _to, uint256 _tokenId) internal {
        assert(tokenIdToOwner[_tokenId] == address(0));

        tokenIdToOwner[_tokenId] = _to;

        uint256 currentCount = ownerToTokenIds[_to].length;
        ownerToTokenIds[_to].push(_tokenId);

        tokenToOwnerIndexes[_tokenId] = currentCount;
    }

    function _deposit_for(
        uint256 _tokenId,
        uint256 _amount,
        uint256 _unlockTime,
        LockedInfo memory _lockedInfo,
        DepositType _depositType
    ) internal {
        // Update total supply
        totalSupply += _amount;

        // Update lock info
        locks[_tokenId].amount += _amount;
        if (_unlockTime > 0) {
            locks[_tokenId].endTimestamp = _unlockTime;
        }

        // TODO: not finish this
        _checkPoint(_tokenId, _lockedInfo, locks[_tokenId]);

        // Transfer tokens
        if (_amount > 0 && _depositType != DepositType.Merge) {
            IERC20(baseToken).transferFrom(msg.sender, address(this), _amount);
        }
    }

    function _checkPoint(uint256 _tokenId, LockedInfo memory _lockedInfo, LockedInfo memory _newLockedInfo) internal {}
}
