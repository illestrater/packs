// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

import "@openzeppelin/contracts/introspection/ERC165.sol";

contract HasSecondarySaleFees is ERC165 {
    // List of tokenIDs mapping to one or more creator splits
	mapping(uint256 => address payable[]) creatorAddresses;
	mapping(uint256 => uint256[]) creatorShares;

	bytes4 private constant _INTERFACE_ID_FEES = 0xb7799584;

	constructor() public {
		_registerInterface(_INTERFACE_ID_FEES);
	}

    // Recipient addresses 
	function getFeeRecipients(uint256 tokenId) external view returns (address payable[] memory){
		return creatorAddresses[tokenId];
	}

    // Percentage shares (1000 is equal to 10%)
	function getFeeBps(uint256 tokenId) external view returns (uint[] memory){
		return creatorShares[tokenId];
	}
}