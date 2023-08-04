// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "hardhat/console.sol";

contract PurchasableNFT is ERC721Enumerable, Ownable {
    event ClassAdded(uint id, string description, uint price);
    event Mint(uint id, address user, bytes32 refCode, uint price);

    using Address for address;
    using Strings for uint;

    uint constant DECIMALS = 1e18;

    // Item class structure
    struct Class {
        uint id;
        string description;
        uint price;
    }

    /**
     * partner program
     * user can buy tank NFT with partner project token
     * There are total NFT count limit and max NFT per wallet limit with partner token purchase
     */
    struct Partner {
        address tokenAddress;
        uint price; // DECIMALS
        uint maxNFT;
        uint maxPerWallet;
        uint totalNFT;
        mapping(address => uint) userNFTCount;
    }

    // admin info
    address public admin;

    // base Info
    string private baseUri;
    mapping(uint => Class) public classInfos;
    uint private classCount;

    address public mainToken;
    mapping(address => Partner) public partners;

    // token info
    mapping(uint => address) creators;
    mapping(uint => uint) public itemClasses;

    constructor(
        string memory _name,
        string memory _symbol,
        string memory _baseUri,
        address _mainToken
    ) ERC721(_name, _symbol) {
        baseUri = _baseUri;
        mainToken = _mainToken;
        admin = msg.sender;
    }

    // admin action
    function setBaseUri(string memory newUri) external onlyOwner {
        baseUri = newUri;
    }

    function setAdmin(address _newAdmin) external onlyOwner {
        admin = _newAdmin;
    }

    function addPartner(
        address tokenAddress,
        uint price,
        uint maxNFT,
        uint maxPerWallet
    ) external onlyOwner {
        partners[tokenAddress].tokenAddress = tokenAddress;
        partners[tokenAddress].price = price;
        partners[tokenAddress].maxNFT = maxNFT;
        partners[tokenAddress].maxPerWallet = maxPerWallet;
    }

    function config(address _mainToken) external onlyOwner {
        mainToken = _mainToken;
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

    function updateClass(
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

    function mint(uint classType, bytes32 refCode) public {
        require(classType < classCount, "Invalid class type");

        _getPayment(mainToken, classInfos[classType].price);
        _mintItem(msg.sender, classType, refCode);
    }

    // mint with partner project tokens
    function mintWithTokens(
        uint classType,
        bytes32 refCode,
        address paymentToken
    ) public {
        require(classType < classCount, "Invalid class type");

        _getPayment(paymentToken, classInfos[classType].price);
        _mintItem(msg.sender, classType, refCode);

        _checkLimitation(msg.sender, paymentToken);
    }

    function mints(uint[] memory classTypes, bytes32 refCode) public {
        uint totalPrice = 0;
        for (uint i = 0; i < classTypes.length; i++) {
            uint classType = classTypes[i];

            _mintItem(msg.sender, classType, refCode);
            totalPrice += classInfos[classType].price;
        }

        _getPayment(mainToken, totalPrice);
    }

    //Air drop from owner
    function airdrop(
        address[] memory tos,
        uint[] memory classTypes,
        bytes32 refCode
    ) external {
        require(msg.sender == admin, "only admin can airdrop");
        for (uint i = 0; i < tos.length; i++) {
            _mintItem(tos[i], classTypes[i], refCode);
        }
    }

    function _checkLimitation(address to, address paymentToken) internal {
        partners[paymentToken].totalNFT += 1;
        partners[paymentToken].userNFTCount[to] += 1;
        require(
            partners[paymentToken].totalNFT <= partners[paymentToken].maxNFT,
            "Max NFT Exceeded"
        );
        require(
            partners[paymentToken].userNFTCount[to] <=
                partners[paymentToken].maxPerWallet,
            "Max NFT per Wallet Exceeded"
        );
    }

    function _getPayment(address paymentToken, uint amount) internal {
        if (paymentToken == mainToken) {
            IERC20(paymentToken).transferFrom(msg.sender, admin, amount);
        } else {
            require(partners[paymentToken].price > 0, "Invalid tokenAddress");
            uint amountP = (amount * partners[paymentToken].price) / DECIMALS;
            IERC20(paymentToken).transferFrom(msg.sender, admin, amountP);
        }
    }

    function _mintItem(
        address to,
        uint classType,
        bytes32 refCode
    ) internal returns (uint tokenId) {
        tokenId = totalSupply();
        creators[tokenId] = to;
        itemClasses[tokenId] = classType;
        _safeMint(to, tokenId);
        emit Mint(tokenId, to, refCode, classInfos[classType].price);
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
}
