// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./library/Base58.sol";
import "./library/VeryfiSignature.sol";
import "./interfaces/ITankToken.sol";
import "./interfaces/IRewardPool.sol";

contract NFTTank is ERC721Enumerable, Ownable {
    event ClassAdded(uint id, string description, uint price);
    event LevelUpgrade(uint tokenId, uint level);
    event Mint(uint id, address user, bytes32 refCode, uint price);

    using Address for address;
    using Strings for uint;
    using Base58 for bytes;

    struct Class {
        uint id;
        string description;
        uint price;
    }

    struct Tank {
        uint class;
        uint level;
    }

    // base Info
    mapping(uint => Class) public classInfos;

    // token info
    mapping(uint => address) creators;
    mapping(uint => Tank) public tanks;

    // config
    string private baseUri;
    uint private classCount;
    address public adminAddress;

    address public TreasuryAddress;
    address public TANKTOKENAddress;

    // partner program
    struct Partner {
        address tokenAddress;
        uint price;
        uint decimals;
        uint maxNFT;
        uint maxPerWallet;
        uint totalNFT;
        mapping(address => uint) userNFTs;
    }

    mapping(address => Partner) public partners;

    constructor(
        string memory _name,
        string memory _symbol,
        address _adminAddress,
        string memory _baseUri
    ) ERC721(_name, _symbol) {
        baseUri = _baseUri;
        adminAddress = _adminAddress;
    }

    // admin action
    function setBaseUri(string memory newUri) external onlyOwner {
        baseUri = newUri;
    }

    function setAdminAddress(address _adminAddress) external onlyOwner {
        adminAddress = _adminAddress;
    }

    function addPartner(
        address tokenAddress,
        uint decimals,
        uint price,
        uint maxNFT,
        uint maxPerWallet
    ) external onlyOwner {
        partners[tokenAddress].tokenAddress = tokenAddress;
        partners[tokenAddress].decimals = decimals;
        partners[tokenAddress].price = price;
        partners[tokenAddress].maxNFT = maxNFT;
        partners[tokenAddress].maxPerWallet = maxPerWallet;
    }

    function config(
        address _tankToken,
        address _treasuryAddress
    ) external onlyOwner {
        TANKTOKENAddress = _tankToken;
        TreasuryAddress = _treasuryAddress;
    }

    function addNewClasses(
        string[] memory descriptions,
        uint[] memory prices
    ) external onlyOwner {
        require(descriptions.length == prices.length, "Invalid request");
        for (uint i = 0; i < descriptions.length; i++) {
            classInfos[classCount].description = descriptions[i];
            classInfos[classCount].price = prices[i];
            emit ClassAdded(classCount, descriptions[i], prices[i]);
            classCount++;
        }
    }

    function changeClass(
        uint id,
        string memory description,
        uint price
    ) external onlyOwner {
        classInfos[id].description = description;
        classInfos[id].price = price;
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC721Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function creatorOf(uint tokenId) public view virtual returns (address) {
        address creator = creators[tokenId];
        require(
            creator != address(0),
            "ERC721: owner query for nonexistent token"
        );
        return creator;
    }

    // public
    function mint(uint classType, bytes32 refCode) public {
        require(classType < classCount, "Invalid class type");

        ITankToken(TANKTOKENAddress).transferFrom(
            msg.sender,
            address(this),
            classInfos[classType].price
        );
        ITankToken(TANKTOKENAddress).approve(
            TreasuryAddress,
            classInfos[classType].price
        );

        IRewardPool(TreasuryAddress).addReward(classInfos[classType].price);
        uint supply = totalSupply();
        _safeMint(msg.sender, supply);
        creators[supply] = msg.sender;
        tanks[supply].class = classType;

        emit Mint(supply, msg.sender, refCode, classInfos[classType].price);
    }

    // mint with partner project tokens
    function mintWithTokens(
        uint classType,
        bytes32 refCode,
        address tokenAddress
    ) public {
        require(classType < classCount, "Invalid class type");
        require(partners[tokenAddress].price > 0, "Invalid tokenAddress");
        // partner token
        require(tokenAddress != address(0), "Invalid tokenAddress");
        uint price = ((classInfos[classType].price *
            partners[tokenAddress].price) *
            10 ** partners[tokenAddress].decimals) /
            1e18 /
            1000000;
        partners[tokenAddress].totalNFT += 1;
        partners[tokenAddress].userNFTs[msg.sender] += 1;
        require(
            partners[tokenAddress].totalNFT <= partners[tokenAddress].maxNFT,
            "Max NFT Exceeded"
        );
        require(
            partners[tokenAddress].userNFTs[msg.sender] <=
                partners[tokenAddress].maxPerWallet,
            "Max NFT per Wallet Exceeded"
        );

        ITankToken(tokenAddress).transferFrom(
            msg.sender,
            TreasuryAddress,
            price
        );

        uint supply = totalSupply();
        _safeMint(msg.sender, supply);
        creators[supply] = msg.sender;
        tanks[supply].class = classType;

        emit Mint(supply, msg.sender, refCode, classInfos[classType].price);
    }

    function mints(uint[] memory classTypes, bytes32 refCode) public {
        uint totalPrice = 0;
        uint supply = totalSupply();
        for (uint i = 0; i < classTypes.length; i++) {
            uint classType = classTypes[i];
            uint id = supply + i;

            require(classType < classCount, "Invalid class type");
            _safeMint(msg.sender, id);
            creators[id] = msg.sender;
            tanks[id].class = classType;
            totalPrice += classInfos[classType].price;

            emit Mint(id, msg.sender, refCode, classInfos[classType].price);
        }

        ITankToken(TANKTOKENAddress).transferFrom(
            msg.sender,
            address(this),
            totalPrice
        );
        ITankToken(TANKTOKENAddress).approve(TreasuryAddress, totalPrice);
        IRewardPool(TreasuryAddress).addReward(totalPrice);
    }

    //Air drop
    function airdrop(
        address[] memory players,
        uint[] memory classTypes
    ) external onlyOwner {
        uint supply = totalSupply();
        for (uint i = 0; i < players.length; i++) {
            _safeMint(players[i], supply + i);
            tanks[supply + i].class = classTypes[i];
        }
    }

    function tokenIdsOfOwner(
        address _owner
    ) public view returns (uint[] memory) {
        uint ownerTokenCount = balanceOf(_owner);
        uint[] memory tokenIds = new uint[](ownerTokenCount);
        for (uint i; i < ownerTokenCount; i++) {
            tokenIds[i] = tokenOfOwnerByIndex(_owner, i);
        }
        return tokenIds;
    }

    function tokenURI(
        uint tokenId
    ) public view virtual override returns (string memory) {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );
        return string(abi.encodePacked(baseUri, "/", tokenId));
    }

    //level management
    function upgrade(
        uint tokenId,
        uint level,
        bytes memory signature
    ) external {
        require(ownerOf(tokenId) == msg.sender, "permission denied");
        require(verify(tokenId, level, signature), "Invalid signature");
        require(level > tanks[tokenId].level, "Invalid level");
        tanks[tokenId].level = level;
        emit LevelUpgrade(tokenId, level);
    }

    function getMessageHash(
        uint tokenId,
        uint level
    ) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(tokenId, level));
    }

    function verify(
        uint tokenId,
        uint level,
        bytes memory signature
    ) public view returns (bool) {
        bytes32 messageHash = getMessageHash(tokenId, level);
        bytes32 ethSignedMessageHash = VerifySignature.getEthSignedMessageHash(
            messageHash
        );
        return
            VerifySignature.recoverSigner(ethSignedMessageHash, signature) ==
            adminAddress;
    }
}
