// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Stock is ERC721Enumerable, Ownable {
    mapping(uint => string) metadatas;
    mapping(uint => address) creators;

    string public baseURI;

    uint public maxSupply;
    uint public price; // decimal 1000000
    bool public isOnsale;
    uint public endTime;

    constructor(
        string memory _name,
        string memory _symbol,
        string memory baseURI_
    ) ERC721(_name, _symbol) {
        baseURI = baseURI_;
        maxSupply = 1000;
        price = 300000 * 1e18; // 0.3BNB
        isOnsale = true;
        endTime = block.timestamp + 7 days;
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    function setMaxSupply(uint _maxSupply) external onlyOwner {
        maxSupply = _maxSupply;
    }

    function setPrice(uint _price) external onlyOwner {
        price = _price;
    }

    function setIsOnsale(bool _isOnsale) external onlyOwner {
        isOnsale = _isOnsale;
    }

    function setEndTime(uint _endTime) external onlyOwner {
        endTime = _endTime;
    }

    function setBaseURI(string calldata baseURI_) external onlyOwner {
        baseURI = baseURI_;
    }

    function creatorOf(uint tokenId) public view virtual returns (address) {
        address creator = creators[tokenId];
        require(
            creator != address(0),
            "ERC721: owner query for nonexistent token"
        );
        return creator;
    }

    function getRestTime() external view returns (uint) {
        return block.timestamp < endTime ? endTime - block.timestamp : 0;
    }

    function mints(uint amount) public payable {
        require(isOnsale, "Sales is not enabled");
        require(msg.value >= (amount * price) / 1000000, "Invalid price");
        require(amount < 50, "Max amount per mint is 50");
        uint256 supply = totalSupply();
        require(supply + amount < maxSupply, "Max supply Limit");
        for (uint i = 0; i < amount; i++) {
            _safeMint(msg.sender, supply + i);
            creators[supply + i] = msg.sender;
        }
    }

    function withDrawETH(uint amount, address to) external onlyOwner {
        payable(to).transfer(amount);
    }
}
