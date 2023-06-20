// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TankToken is ERC20, Ownable {
    event Burn(address account, uint amount);

    mapping(address => bool) isMinters;
    modifier onlyMinter() {
        require(isMinters[msg.sender], "Permission denied");
        _;
    }

    function setMinter(address to, bool isMinter) external onlyOwner {
        isMinters[to] = isMinter;
    }

    constructor(uint initialSupply) ERC20("DeFiTankLand Token", "DFTL") {
        _mint(msg.sender, initialSupply);
    }

    function mint(address to, uint amount) external onlyMinter {
        _mint(to, amount);
    }

    function burn(uint amount) external {
        _burn(msg.sender, amount);
        emit Burn(msg.sender, amount);
    }
}
