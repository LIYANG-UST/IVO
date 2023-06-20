// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockBaseToken is ERC20 {
    uint256 public constant INIT_MINT = 100 ether;

    constructor() ERC20("BaseToken", "BASE") {
        _mint(msg.sender, INIT_MINT);
    }

    function mint(address _user, uint256 _amount) public {
        _mint(_user, _amount);
    }
}