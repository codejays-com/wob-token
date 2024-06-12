// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract WorldOfBlastDrop is Ownable {
    address private contractTokenAddress;
    address private contractNFTAddress;

    constructor(address _contractTokenAddress, address _contractNFTAddress) Ownable(msg.sender) {
        contractTokenAddress = _contractTokenAddress;
        contractNFTAddress = _contractNFTAddress;
    }

    function setContractTokenAddress(address _contractAddress) external onlyOwner {
        contractTokenAddress = _contractAddress;
    }

    function setContractNFTAddress(address _contractAddress) external onlyOwner {
        contractNFTAddress = _contractAddress;
    }

    function transferFromERC20(uint256 amount, address to) external onlyOwner { 
        IERC20 currentToken = IERC20(contractTokenAddress);
        uint256 currentAmount = currentToken.balanceOf(address(this));
        if (amount > currentAmount) {
            amount = currentAmount;
        }
        currentToken.transfer(to, amount);
    }

    function transferFromERC721(uint256 tokenId, address to) external onlyOwner {
        IERC721 currentToken = IERC721(contractNFTAddress);
        currentToken.safeTransferFrom(address(this), to, tokenId);
    }
}
