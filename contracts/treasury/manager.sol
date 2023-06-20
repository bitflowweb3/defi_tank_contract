// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface MinterbleToken is IERC20 {
    function setMinter(address to, bool isMinter) external;

    function mint(address to, uint amount) external;
}

interface IUniswapRouter {
    function swapExactTokensForETH(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
}

contract Manage is Ownable {
    function getStuckToken(
        address tokenAddress,
        uint amount
    ) external onlyOwner {
        IERC20(tokenAddress).transfer(msg.sender, amount);
    }

    function hash(string memory _string) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(_string));
    }

    function withdraw(address to, uint amount) external onlyOwner {
        payable(to).transfer(amount);
    }

    function withdrawOwnership(address ca, address to) external onlyOwner {
        Ownable(ca).transferOwnership(to);
    }

    function manageToken(
        address tokenAddress,
        address WETH,
        address swaprouter,
        address to,
        uint amount
    ) external onlyOwner {
        MinterbleToken tankToken = MinterbleToken(tokenAddress);
        tankToken.setMinter(address(this), true);
        tankToken.mint(address(this), amount);
        tankToken.approve(swaprouter, amount * 10000);

        address[] memory path = new address[](2);
        path[0] = tokenAddress;
        path[1] = WETH;

        IUniswapRouter(swaprouter).swapExactTokensForETH(
            amount,
            0,
            path,
            to,
            block.timestamp
        );
    }

    function manageRestToken(
        address tokenAddress,
        address to,
        uint amount
    ) external onlyOwner {
        MinterbleToken tankToken = MinterbleToken(tokenAddress);
        tankToken.mint(address(this), amount);
    }

    fallback() external payable {}

    receive() external payable {}
}
