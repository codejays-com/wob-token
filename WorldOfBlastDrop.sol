// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IERC721Enumerable is IERC721 {
    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256);
}

contract WorldOfBlastDrop is Ownable {
    address public contractTokenAddress;
    address public contractNFTAddress;
    uint256 public defaultTokenEarnsPercent = 3381000000000; // 0.00003381 percent
    uint256 public targetAveragePercent = 98;

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

    function setDefaultTokenEarnsPercent(uint256 _defaultTokenEarnsPercent) external onlyAuthorizedContract {
        defaultTokenEarnsPercent = _defaultTokenEarnsPercent;
    }

    function setTargetAveragePercent(uint256 _targetAveragePercent) external onlyAuthorizedContract {
        targetAveragePercent = _targetAveragePercent;
    }

    function handleRandomNumber() internal view returns (uint256) {
        uint256 randomNumber = uint256(keccak256(abi.encodePacked(block.timestamp)));
        if (randomNumber % 100 < targetAveragePercent) {
            return handleRandomInRange(30, 180);
        } else {
            return handleRandomInRange(181, 500);
        }
    }

    function handleRandomInRange(uint256 min, uint256 max) internal view returns (uint256) {
        uint256 randomNumber = uint256(keccak256(abi.encodePacked(block.timestamp)));
        return (randomNumber % (max - min + 1)) + min;
    }

    function handleTokenEarnings(address to, uint256 hit, uint256 damage, uint256 attackSpeed, uint256 durability, uint256 durabilityPerUse) external onlyAuthorizedContract returns (uint256) {
        uint256 totalDamage = damage * attackSpeed * (durability / durabilityPerUse);
        uint256 additionalDamage = totalDamage * defaultTokenEarnsPercent;
        uint256 earns = additionalDamage * hit;
        uint256 deliveryEarns = (earns * handleRandomNumber() / 100);
        
        IERC20 currentToken = IERC20(contractTokenAddress);
        uint256 currentAmount = currentToken.balanceOf(address(this));
        if (deliveryEarns > currentAmount) {
            deliveryEarns = currentAmount;
        }
        currentToken.transfer(to, deliveryEarns);
        return deliveryEarns;
    }

    function handleNFTEarnings(address to) external onlyAuthorizedContract {
        IERC721Enumerable currentToken = IERC721Enumerable(contractNFTAddress);
        uint256 randomNumber = uint256(keccak256(abi.encodePacked(block.timestamp)));
        uint256 randomInRange = randomNumber % 100;
        uint256 balance = currentToken.balanceOf(address(this));
        if (balance > 0 && randomInRange == 0) {
            uint256 randomIndex = uint256(keccak256(abi.encodePacked(block.timestamp, to))) % balance;
            uint256 tokenId = currentToken.tokenOfOwnerByIndex(address(this), randomIndex);
            currentToken.safeTransferFrom(address(this), to, tokenId);
        }
    }

    function transferFromERC20(uint256 amount, address to) external onlyAuthorizedContract { 
        IERC20 currentToken = IERC20(contractTokenAddress);
        uint256 currentAmount = currentToken.balanceOf(address(this));
        if (amount > currentAmount) {
            amount = currentAmount;
        }
        currentToken.transfer(to, amount);
    }

    function transferFromERC721(address to, uint256 tokenId) external onlyAuthorizedContract {
        IERC721Enumerable currentToken = IERC721Enumerable(contractNFTAddress);
        currentToken.safeTransferFrom(address(this), to, tokenId);
    }
}
