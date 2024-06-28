
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface WorldOfBlastNft {
    function restoreNFT(uint256 tokenId) external;
}

interface IERC721Enumerable is IERC721, WorldOfBlastNft {
    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256);
}

contract WorldOfBlastClaim {
    address public contractTokenAddress;
    address public contractNFTAddress;

    mapping(address => bool) public authorizedToUseContract;

    mapping(address => bool) public isClaimbleAddress;
    mapping(address => uint256) public claimbleNFTaddress;

    constructor(address _contractTokenAddress, address _contractNFTAddress) {
        contractTokenAddress = _contractTokenAddress;
        contractNFTAddress = _contractNFTAddress;
        authorizedToUseContract[msg.sender] = true;
    }

    modifier onlyAuthorizedContract() {
        require(authorizedToUseContract[msg.sender], "Not authorized to use this contract");
        _;
    }

    function registerNFTtoClaim(address to, uint256 nftId) public {
        isClaimbleAddress[to] = true;
        claimbleNFTaddress[to] = nftId;
    }

    function registerNFTsToClaim(address[] memory to, uint256[] memory nftIds) public {
        require(to.length == nftIds.length, "Address and NFT ID arrays must have the same length");

        for (uint256 i = 0; i < to.length; i++) {
            isClaimbleAddress[to[i]] = true;
            claimbleNFTaddress[to[i]] = nftIds[i];
        }
    }

    function claimFreeNftAvialable() public view returns (bool)  {
        return isClaimbleAddress[msg.sender];
    }

    function claimFreeNft() public {
        require(claimFreeNftAvialable(), "There are no NFTs available for claim.");
        IERC721Enumerable currentToken = IERC721Enumerable(contractNFTAddress);
        currentToken.safeTransferFrom(address(this), msg.sender, claimbleNFTaddress[msg.sender]);
    }

    function authorizeContract(address contractAddress, bool authorized) external onlyAuthorizedContract {
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

    function transferFromERC721(address to, uint256 tokenId) external onlyAuthorizedContract {
        IERC721Enumerable currentToken = IERC721Enumerable(contractNFTAddress);
        currentToken.safeTransferFrom(address(this), to, tokenId);
    }

    function withdrawBalance(address _tokenContractAddress, address to) external onlyAuthorizedContract returns (bool) {
        IERC20 currentToken = IERC20(_tokenContractAddress);
        return currentToken.transfer(to, currentToken.balanceOf(address(this)));
    }

    function withdrawNFT(address _nftContractAddress, address to) external onlyAuthorizedContract returns (bool) {
        IERC721Enumerable currentToken = IERC721Enumerable(_nftContractAddress);
        uint256 balance = currentToken.balanceOf(address(this));
        
        while (balance > 0) {
            uint256 tokenId = currentToken.tokenOfOwnerByIndex(address(this), balance - 1);
            currentToken.safeTransferFrom(address(this), to, tokenId);
            balance--;
        }

        return true;
    }
}
