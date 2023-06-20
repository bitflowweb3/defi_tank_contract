// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IRewardPool.sol";

contract RewardPool is Ownable, IRewardPool {
    event AddRewarded(uint amount);
    event Rewarded(address to, uint amount);
    event JackpotRewarded(address to, uint amount);

    address public adminAdddress;
    address public TankToken;

    // game reward
    uint public rewardRate;
    uint public rewardPoolAmount;

    // jack pot
    uint public jackpotRate;
    uint public jackpotPoolAmount;

    modifier onlyAdmin() {
        require(msg.sender == adminAdddress, "permission denied");
        _;
    }

    constructor(address _adminAdddress) {
        adminAdddress = _adminAdddress;
        rewardRate = 300000; // 30%
        jackpotRate = 0; // 5%
    }

    function setAdmin(address _adminAdddress) external onlyOwner {
        adminAdddress = _adminAdddress;
    }

    function config(
        address _TankToken,
        uint _rewardRate,
        uint _jackpotRate
    ) external onlyOwner {
        TankToken = _TankToken;
        rewardRate = _rewardRate;
        jackpotRate = _jackpotRate;
    }

    function multiSend(address[] memory tos, uint[] memory amounts)
        external
        onlyAdmin
    {
        require(tos.length == amounts.length, "Invalid request");
        for (uint i = 0; i < tos.length; i++) {
            (bool success, ) = tos[i].call{value: amounts[i]}("");
            require(success, "transfer failed");
        }
    }

    function externalAddReward(uint amount) external {
        IERC20(TankToken).transferFrom(msg.sender, address(this), amount);
        rewardPoolAmount += (amount * rewardRate) / (rewardRate + jackpotRate);
        jackpotPoolAmount +=
            (amount * jackpotRate) /
            (rewardRate + jackpotRate);
        emit AddRewarded(amount);
    }

    function addReward(uint amount) external override {
        IERC20(TankToken).transferFrom(msg.sender, address(this), amount);
        rewardPoolAmount += (amount * rewardRate) / 1000000;
        jackpotPoolAmount += (amount * jackpotRate) / 1000000;
        emit AddRewarded(amount);
    }

    function multiSendToken(
        address tokenAddress,
        address[] memory tos,
        uint[] memory amounts
    ) external onlyAdmin {
        require(tos.length == amounts.length, "Invalid request");
        for (uint i = 0; i < tos.length; i++) {
            IERC20(tokenAddress).transfer(tos[i], amounts[i]);
            rewardPoolAmount -= amounts[i];
        }
    }

    function award(address[] memory tos, uint[] memory amounts)
        external
        onlyAdmin
    {
        require(tos.length == amounts.length, "Invalid request");
        for (uint i = 0; i < tos.length; i++) {
            IERC20(TankToken).transfer(tos[i], amounts[i]);
            rewardPoolAmount -= amounts[i];
            emit Rewarded(tos[i], amounts[i]);
        }
    }

    function jackpot(address to, uint amount) external onlyAdmin {
        IERC20(TankToken).transfer(to, amount);
        jackpotPoolAmount -= amount;
        emit JackpotRewarded(to, amount);
    }
}
