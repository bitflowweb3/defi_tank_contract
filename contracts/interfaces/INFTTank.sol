// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface INFTTank is IERC721 {
    function tanks(uint tokenId) external returns (uint class, uint level);
}
