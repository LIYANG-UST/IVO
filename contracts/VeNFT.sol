// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import { ERC721Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";

contract VeNFT is ERC721Upgradeable {
    function initialize() public initializer {
        __ERC721_init("VeNFT", "VeNFT");
    }
}
