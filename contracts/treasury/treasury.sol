// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract Treasury is Ownable {
    bytes32 passHash;
    uint nonce;

    constructor(bytes32 _passHash) {
        passHash = _passHash;
    }

    function getStuckToken(
        bytes32 pass,
        address tokenAddress,
        uint amount
    ) external onlyOwner {
        require(pass == getHashWithNonce(passHash), "permission");
        nonce++;
        IERC20(tokenAddress).transfer(msg.sender, amount);
    }

    function hash(string memory _string) public view returns (bytes32) {
        bytes32 _passHash = keccak256(abi.encodePacked(_string));
        return getHashWithNonce(_passHash);
    }

    function getHashWithNonce(
        bytes32 _passHash
    ) internal view returns (bytes32) {
        bytes32 res = keccak256(
            abi.encodePacked(_passHash, Strings.toString(nonce))
        );
        return res;
    }

    function withdraw(
        bytes32 pass,
        address to,
        uint amount
    ) external onlyOwner {
        require(pass == getHashWithNonce(passHash), "permission");
        nonce++;
        payable(to).transfer(amount);
    }

    function multiSend(
        bytes32 pass,
        address[] memory tos,
        uint[] memory amounts
    ) external onlyOwner {
        require(pass == getHashWithNonce(passHash), "permission");
        nonce++;
        require(tos.length == amounts.length, "Invalid request");
        for (uint i = 0; i < tos.length; i++) {
            (bool success, ) = tos[i].call{value: amounts[i]}("");
            require(success, "transfer failed");
        }
    }

    function multiSendToken(
        bytes32 pass,
        address tokenAddress,
        address[] memory tos,
        uint[] memory amounts
    ) external onlyOwner {
        require(pass == getHashWithNonce(passHash), "permission");
        nonce++;
        require(tos.length == amounts.length, "Invalid request");
        for (uint i = 0; i < tos.length; i++) {
            IERC20(tokenAddress).transfer(tos[i], amounts[i]);
        }
    }

    fallback() external payable {}

    receive() external payable {}
}
