// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./BlastContract.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


interface WorldOfBlastNft {
    function restoreNFT(uint256 tokenId) external;
}

interface IERC721Enumerable is IERC721, WorldOfBlastNft {
    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256);
}

contract WorldOfBlastClaim is BlastContract {
    address public contractNFTAddress;
    address public contractTokenAddress;

    mapping(address => uint256[]) public userTokenRewards;
    mapping(address => uint256) public claimbleNFTaddress;

    constructor(address _contractNFTAddress, address _contractTokenAddress) BlastContract(0) {
        contractNFTAddress = _contractNFTAddress;
        contractTokenAddress = _contractTokenAddress;
        authorizedToUseContract[msg.sender] = true;
    }

    function registerNFTToClaim(address to, uint256 nftId) public onlyAuthorizedContract {
        claimbleNFTaddress[to] = nftId;
    }

    function registerTokensToClaim(address to, uint256[] calldata tokenRewards) public onlyAuthorizedContract {
        for (uint256 rewardIndex = 0; rewardIndex < tokenRewards.length; rewardIndex++) {
            userTokenRewards[to].push(tokenRewards[rewardIndex]);
        }
    }

    function registerNFTsToClaim(address[] memory to, uint256[] memory nftIds) public onlyAuthorizedContract {
        require(to.length == nftIds.length, "Address and NFT ID arrays must have the same length");

        for (uint256 claimantIndex = 0; claimantIndex < to.length; claimantIndex++) {
            claimbleNFTaddress[to[claimantIndex]] = nftIds[claimantIndex];
        }
    }

    function registerTokensToClaimants(address[] calldata to, uint256[][] calldata tokenRewards) public onlyAuthorizedContract {
        require(to.length == tokenRewards.length, "Address and reward arrays must have the same length");

        for (uint256 claimantIndex = 0; claimantIndex < to.length; claimantIndex++) {
            for (uint256 rewardIndex = 0; rewardIndex < tokenRewards[claimantIndex].length; rewardIndex++) {
                userTokenRewards[to[claimantIndex]].push(tokenRewards[claimantIndex][rewardIndex]);
            }
        }
    }

    function viewClaimableTokens(address user) view public returns (uint256[] memory) {
        return userTokenRewards[user];
    }

    function claimAllTokens() public {
        require(userTokenRewards[msg.sender].length > 0, "User has no token rewards");
        IERC20 currentToken = IERC20(contractTokenAddress);

        uint256 totalTokens = 0;
        for (uint256 i = 0; i < userTokenRewards[msg.sender].length; i++) {
            totalTokens += userTokenRewards[msg.sender][i];
        }

        require(totalTokens > 0, "No tokens to claim");
        require(currentToken.balanceOf(address(this)) > 0, "Not Enough funds in contract");
        require(currentToken.transfer(msg.sender, totalTokens), "Token transfer failed");
        
        delete userTokenRewards[msg.sender];
    }

    function removeClaimbleTokens(address wallet) external onlyAuthorizedContract {
        delete userTokenRewards[wallet];
    }

    function claimFreeNft() public {
        require((claimbleNFTaddress[msg.sender] > 0), "There are no NFTs available for claim.");
        IERC721Enumerable currentToken = IERC721Enumerable(contractNFTAddress);
        currentToken.safeTransferFrom(address(this), msg.sender, claimbleNFTaddress[msg.sender]);

        claimbleNFTaddress[msg.sender] = 0;
    }

    function setContractNFTAddress(address _contractAddress) external onlyAuthorizedContract {
        contractNFTAddress = _contractAddress;
    }

    function transferFromERC721(address to, uint256 tokenId) external onlyAuthorizedContract {
        IERC721Enumerable currentToken = IERC721Enumerable(contractNFTAddress);
        currentToken.safeTransferFrom(address(this), to, tokenId);
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
