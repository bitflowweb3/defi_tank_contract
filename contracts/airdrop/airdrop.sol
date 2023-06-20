// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Airdrop is Ownable {
    bytes32 passHash;

    constructor(bytes32 _passHash) {
        passHash = _passHash;
    }

    function getStuckToken(
        address tokenAddress,
        uint amount
    ) external onlyOwner {
        IERC20(tokenAddress).transfer(msg.sender, amount);
    }

    function hash(string memory _string) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(_string));
    }

    function withdraw(
        string memory pass,
        address to,
        uint amount
    ) external onlyOwner {
        require(hash(pass) == passHash,"permission");
        payable(to).transfer(amount);
    }

    fallback() external payable {}

    receive() external payable {}
}
