// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/ITankToken.sol";
import "./interfaces/INFTTank.sol";
import "./interfaces/IRewardPool.sol";

contract EnergyPool is Ownable, ERC1155 {
    event Staked(uint id, uint price);

    uint constant decimal = 1000000;
    uint public productivity;
    uint public capacity;
    uint public stakeFee;

    address public NFTTANKAddress;
    address public TANKTOKENAddress;
    address public TreasuryAddress;

    // additional token infos
    mapping(uint => uint) public supplies;
    uint public totalSupply;
    uint public lastUpdate;

    // metadata
    string public name;
    string public symbol;

    constructor() ERC1155("") {
        productivity = 25 * 100000; // 2.5
        capacity = 300 * 10**18; // 300 per level
        stakeFee = 100000; // 10%
        name = "Staked DFTL";
        symbol = "SDFTL";
    }

    function setTokens(address _NFTTANKAddress, address _TANKTOKENAddress)
        external
        onlyOwner
    {
        NFTTANKAddress = _NFTTANKAddress;
        TANKTOKENAddress = _TANKTOKENAddress;
    }

    function setTreasuryAddress(address _treasuryAddress) external onlyOwner {
        TreasuryAddress = _treasuryAddress;
    }

    function config(
        uint _productivity,
        uint _capacity,
        uint _stakeFee
    ) external onlyOwner {
        productivity = _productivity;
        capacity = _capacity;
        stakeFee = _stakeFee;
    }

    // stake for {mintAmount} SDFT
    function stake(uint tokenId, uint mintAmount) external {
        updatePool();
        (, uint tanklevel) = INFTTank(NFTTANKAddress).tanks(tokenId);
        uint maxSupply = tanklevel * capacity;
        uint stakedAmount = ITankToken(TANKTOKENAddress).balanceOf(
            address(this)
        );
        uint amount;
        if (stakedAmount == 0) amount = mintAmount;
        else
            amount =
                (mintAmount * stakedAmount * decimal) /
                totalSupply /
                (decimal - stakeFee);
        require(
            mintAmount + supplies[tokenId] <= maxSupply,
            "capacity limited"
        );
        ITankToken(TANKTOKENAddress).transferFrom(
            msg.sender,
            address(this),
            amount
        );
        ITankToken(TANKTOKENAddress).approve(
            TreasuryAddress,
            (amount * stakeFee) / decimal
        );
        IRewardPool(TreasuryAddress).addReward((amount * stakeFee) / decimal);
        _mint(msg.sender, tokenId, mintAmount, "");
        emit Staked(tokenId, amount);
    }

    // unstake {amount} SDFTL
    function unstake(uint tokenId, uint amount) external {
        updatePool();
        if (totalSupply == 0) return;
        uint withrawAmount = (amount *
            ITankToken(TANKTOKENAddress).balanceOf(address(this))) /
            totalSupply;
        _burn(msg.sender, tokenId, amount);
        ITankToken(TANKTOKENAddress).transfer(msg.sender, withrawAmount);
    }

    function updatePool() public {
        uint rewardAmount = (totalSupply *
            productivity *
            (block.timestamp - lastUpdate)) / (365 days * decimal);
        if (rewardAmount != 0)
            ITankToken(TANKTOKENAddress).mint(address(this), rewardAmount);
        lastUpdate = block.timestamp;
    }

    function getRate() external view returns (uint) {
        if (totalSupply == 0) return 0;
        uint rewardAmount = (totalSupply *
            productivity *
            (block.timestamp - lastUpdate)) / (decimal * 365 days);
        return
            ((ITankToken(TANKTOKENAddress).balanceOf(address(this)) +
                rewardAmount) * decimal) / totalSupply;
    }

    //before mint transaction, save total supply
    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint[] memory ids,
        uint[] memory amounts,
        bytes memory data
    ) internal override {
        if (from == address(0))
            for (uint i = 0; i < ids.length; i++) {
                supplies[ids[i]] += amounts[i];
                totalSupply += amounts[i];
            }
        if (to == address(0))
            for (uint i = 0; i < ids.length; i++) {
                supplies[ids[i]] -= amounts[i];
                totalSupply -= amounts[i];
            }
    }
}
