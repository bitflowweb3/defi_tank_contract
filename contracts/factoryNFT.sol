// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.0;

import "./purchasableNFT.sol";
import "./library/Base58.sol";
import "./library/VeryfiSignature.sol";

contract FactoryNFT is PurchasableNFT {
    event LevelUp(uint tokenId, uint level);

    using Address for address;
    using Strings for uint;
    using Base58 for bytes;

    // admin info
    address public operator;
    // data
    mapping(uint => uint) public levelInfos;
    mapping(uint => bool) public isPrivate;
    mapping(uint => mapping(address => bool)) public isWhiteList;

    // modifier
    modifier onlyTokenOwner(uint tokenId) {
        require(ownerOf(tokenId) == msg.sender, "You are not a Token owner!");
        _;
    }

    constructor(
        string memory _name,
        string memory _symbol,
        string memory _baseUri,
        address _mainToken
    ) PurchasableNFT(_name, _symbol, _baseUri, _mainToken) {
        operator = msg.sender;
    }

    function setOperator(address _newOperator) public onlyOwner {
        operator = _newOperator;
    }

    //  level management
    function upgrade(
        uint tokenId,
        uint level,
        bytes memory signature
    ) external onlyTokenOwner(tokenId) {
        require(verify(tokenId, level, signature), "Invalid signature");
        require(level > levelInfos[tokenId], "level is already upgraded");
        levelInfos[tokenId] = level;
        emit LevelUp(tokenId, level);
    }

    function verify(
        uint tokenId,
        uint level,
        bytes memory signature
    ) public view returns (bool) {
        bytes32 messageHash = keccak256(abi.encodePacked(tokenId, level));
        bytes32 ethSignedMessageHash = VerifySignature.getEthSignedMessageHash(
            messageHash
        );
        return
            VerifySignature.recoverSigner(ethSignedMessageHash, signature) ==
            operator;
    }

    //  white list management

    function setPublic(
        uint tokenId,
        bool _isPrivate
    ) external onlyTokenOwner(tokenId) {
        isPrivate[tokenId] = _isPrivate;
    }

    function setWhiteList(
        uint tokenId,
        address to,
        bool _isWhiteList
    ) external onlyTokenOwner(tokenId) {
        isWhiteList[tokenId][to] = _isWhiteList;
    }

    function checkIfWhiteList(
        uint tokenId,
        address to
    ) external view returns (bool) {
        return isWhiteList[tokenId][to];
    }
}
