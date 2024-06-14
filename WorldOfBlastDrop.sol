// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IERC721Enumerable is IERC721 {
    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256);
}

contract WorldOfBlastDrop is Ownable {
    address private contractTokenAddress;
    address private contractNFTAddress;

    mapping(address => bool) public authorizedToUseContract;

    constructor(address _contractTokenAddress, address _contractNFTAddress) Ownable(msg.sender) {
        contractTokenAddress = _contractTokenAddress;
        contractNFTAddress = _contractNFTAddress;
        authorizedToUseContract[msg.sender] = true;
    }

    modifier onlyAuthorizedContract() {
        require(authorizedToUseContract[msg.sender], "Not authorized to use this contract");
        _;
    }

    function authorizeContract(address contractAddress, bool authorized) external onlyOwner {
        authorizedToUseContract[contractAddress] = authorized;
    }

    function setContractTokenAddress(address _contractAddress) external onlyAuthorizedContract {
        contractTokenAddress = _contractAddress;
    }

    function setContractNFTAddress(address _contractAddress) external onlyAuthorizedContract {
        contractNFTAddress = _contractAddress;
    }

    function transferFromERC20(uint256 amount, address to) external onlyAuthorizedContract { 
        IERC20 currentToken = IERC20(contractTokenAddress);
        uint256 currentAmount = currentToken.balanceOf(address(this));
        if (amount > currentAmount) {
            amount = currentAmount;
        }
        currentToken.transfer(to, amount);
    }

    function transferFromERC721(address to) external onlyAuthorizedContract {
        IERC721Enumerable currentToken = IERC721Enumerable(contractNFTAddress);
        uint256 balance = currentToken.balanceOf(address(this));
        if (balance > 0) {
            uint256 randomIndex = uint256(keccak256(abi.encodePacked(block.timestamp, to))) % (balance + 1);
            uint256 tokenId = currentToken.tokenOfOwnerByIndex(address(this), randomIndex);
            currentToken.safeTransferFrom(address(this), to, tokenId);
        }
    }
}
