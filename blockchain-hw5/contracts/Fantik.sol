// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";

contract Fantik is ERC20Votes {

    constructor() ERC20("Fantik", "FNT") ERC20Permit("Fantik") {
        _mint(msg.sender, 0.1 gwei);
    }
   
    function decimals() public view virtual override returns (uint8) {
        return 6;
    }

}