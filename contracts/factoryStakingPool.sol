// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IFactoryNFT is IERC721 {
    function levelInfos(uint tokenId) external view returns (uint level);

    function isPublic(uint tokenId) external view returns (bool isPublic);

    function isWhiteList(
        uint tokenId,
        address t0
    ) external view returns (bool isWhiteList);
}

contract FactoryStakingPool is Ownable, ERC1155 {
    event Staked(uint tokenId, uint amount);
    event UnStaked(uint tokenId, uint amount);

    // constants
    uint constant DECIAMLS = 1e12;

    // base datas
    uint public capacityPerLevel;

    uint public rewardRate; // decimals, per year
    uint public ethRewardRate; // decimals, per year

    uint public stakeFee; // decimals
    uint public unStakePenaltyFee; // decimals
    uint public penaltyPeriod; // decimals

    // contract datas
    address public mainToken;
    address public factoryNFT;

    // token infos
    mapping(uint => uint) public supplies;
    mapping(address => uint) public totalBalances;
    uint public totalSupply;
    uint public totalStaked;

    // timestamps
    mapping(address => uint) lastStakeTimestamps;
    uint public lastUpdate;

    // metadata
    string public name;
    string public symbol;

    // reward infos
    uint rewardPerToken; // Decimals
    uint totalRewardPendingAmount;
    mapping(address => uint) rewardDebit;

    uint rewardPerTokenETH;
    uint totalRewardPendingAmountETH;
    mapping(address => uint) rewardDebitETH;

    constructor(
        string memory _name,
        string memory _symbol,
        string memory _baseUri,
        address _mainToken,
        address _factoryNFT
    ) ERC1155(_baseUri) {
        name = _name;
        symbol = _symbol;
        mainToken = _mainToken;
        factoryNFT = _factoryNFT;

        capacityPerLevel = 10000 * 10 ** 18;
        rewardRate = 25 * 1e11; // 250% per year;
        ethRewardRate = 1e8; // 0.0001;
        stakeFee = 5 * 1e10; // 5%
        unStakePenaltyFee = 10 * 1e10; // 10%
        penaltyPeriod = 30 days;
    }

    function setContractInfos(
        address _factoryNFT,
        address _mainToken
    ) external onlyOwner {
        factoryNFT = _factoryNFT;
        mainToken = _mainToken;
    }

    function configFee(
        uint _stakeFee,
        uint _unStakePenaltyFee,
        uint _penaltyPeriod
    ) external onlyOwner {
        stakeFee = _stakeFee;
        unStakePenaltyFee = _unStakePenaltyFee;
        penaltyPeriod = _penaltyPeriod;
    }

    function configRate(
        uint _capacityPerLevel,
        uint _rewardRate,
        uint _ethRewardRate
    ) external onlyOwner {
        capacityPerLevel = _capacityPerLevel;
        rewardRate = _rewardRate;
        ethRewardRate = _ethRewardRate;
    }

    // stake for {mintAmount} SDFT
    function stake(uint tokenId, uint mintAmount) external {
        require(
            getCapacity(tokenId, msg.sender) >= mintAmount,
            "capacity is full!"
        );

        _getPayment(msg.sender, mintAmount, _getNFTOwner(tokenId));
        _mint(msg.sender, tokenId, mintAmount, "");
        lastStakeTimestamps[msg.sender] = block.timestamp;

        emit Staked(tokenId, mintAmount);
    }

    function unStake(uint tokenId, uint amount) external {
        _burn(msg.sender, tokenId, amount);

        // penalty check and withdraw
        _withdraw(msg.sender, amount);
        emit UnStaked(tokenId, amount);
    }

    function claimReward() external {
        updatePool();
        _claimTokenReward(msg.sender);
        _claimETHReward(msg.sender);
    }

    function updatePool() public {
        _updateETHReward();
        _updateTokenReward();
        lastUpdate = block.timestamp;
    }

    function getCapacity(
        uint tokenId,
        address to
    ) public view returns (uint capacity) {
        IFactoryNFT factoryContract = IFactoryNFT(factoryNFT);
        uint level = factoryContract.levelInfos(tokenId);
        capacity = level * capacityPerLevel - supplies[tokenId];

        // if factory is private
        if (!factoryContract.isPublic(tokenId)) {
            // if account isn't in whitelist, user can't stake
            if (!factoryContract.isWhiteList(tokenId, to)) capacity = 0;
        }
    }

    // internal functions
    function _getRatio() internal view returns (uint ratio) {
        return (totalStaked * DECIAMLS) / totalSupply;
    }

    function _getNFTOwner(uint tokenID) internal view returns (address owner) {
        owner = IFactoryNFT(factoryNFT).ownerOf(tokenID);
    }

    function _getPayment(
        address from,
        uint amount,
        address feeAddress
    ) internal {
        IERC20(mainToken).transferFrom(from, address(this), amount);
        IERC20(mainToken).transfer(feeAddress, (amount * stakeFee) / DECIAMLS);
        totalStaked += amount - (amount * stakeFee) / DECIAMLS;
    }

    function _withdraw(address to, uint amount) internal {
        uint withdrawAmount = (amount * _getRatio()) / DECIAMLS;
        if (block.timestamp - lastStakeTimestamps[to] < penaltyPeriod)
            withdrawAmount -= (withdrawAmount * unStakePenaltyFee) / DECIAMLS;
        IERC20(mainToken).transfer(to, withdrawAmount);
    }

    function _updateTokenReward() internal {
        uint rewardBalance = IERC20(mainToken).balanceOf(address(this)) -
            totalStaked -
            totalRewardPendingAmount;

        uint rewardAmount = (totalSupply *
            rewardRate *
            (block.timestamp - lastUpdate)) /
            365 days /
            DECIAMLS;

        if (rewardAmount > rewardBalance) rewardAmount = rewardBalance;

        rewardPerToken += (rewardAmount * DECIAMLS) / totalSupply;
    }

    function _updateETHReward() internal {
        uint rewardBalance = address(this).balance -
            totalRewardPendingAmountETH;

        uint rewardAmount = (totalSupply *
            ethRewardRate *
            (block.timestamp - lastUpdate)) /
            365 days /
            DECIAMLS;

        if (rewardAmount > rewardBalance) rewardAmount = rewardBalance;

        rewardPerTokenETH += (rewardAmount * DECIAMLS) / totalSupply;
    }

    // claim reward
    function _claimTokenReward(address to) internal {
        if (to == address(0)) return;
        uint pendingReward = rewardPerToken *
            totalBalances[to] -
            rewardDebit[to];
        IERC20(mainToken).transfer(to, pendingReward);
        totalRewardPendingAmount -= pendingReward;
        rewardDebit[to] += pendingReward;
    }

    function _claimETHReward(address to) internal {
        if (to == address(0)) return;
        uint pendingReward = rewardPerTokenETH *
            totalBalances[to] -
            rewardDebitETH[to];
        payable(to).transfer(pendingReward);
        totalRewardPendingAmountETH -= pendingReward;
        rewardDebitETH[to] += pendingReward;
    }

    function _updateRewardDebit(address to) internal {
        rewardDebitETH[to] = totalBalances[to] * rewardPerTokenETH;
        rewardDebit[to] = totalBalances[to] * rewardPerToken;
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
        updatePool();
        _claimETHReward(from);
        _claimTokenReward(to);
        // mint
        if (from == address(0))
            for (uint i = 0; i < ids.length; i++) {
                supplies[ids[i]] += amounts[i];
                totalSupply += amounts[i];
                totalBalances[to] += amounts[i];
            }
        // burn
        if (to == address(0))
            for (uint i = 0; i < ids.length; i++) {
                supplies[ids[i]] -= amounts[i];
                totalSupply -= amounts[i];
                totalBalances[from] -= amounts[i];
            }
        // transfer
        if (from != address(0) && to == address(0)) {
            for (uint i = 0; i < ids.length; i++) {
                totalBalances[from] -= amounts[i];
                totalBalances[to] += amounts[i];
            }
        }
        _updateRewardDebit(to);
        _updateRewardDebit(from);
    }
}
