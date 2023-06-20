// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ITankToken is IERC20 {
    function burn(uint amount) external;

    function mint(address to, uint amount) external;
}