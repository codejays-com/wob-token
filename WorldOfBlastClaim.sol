
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "https://github.com/codejays-com/wob-token/blob/main/BlastContract.sol";

interface WorldOfBlastNft {
    function restoreNFT(uint256 tokenId) external;
}

interface IERC721Enumerable is IERC721, WorldOfBlastNft {
    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256);
}

contract WorldOfBlastClaim is BlastContract {
    address public contractNFTAddress;

    mapping(address => bool) public isClaimbleAddress;
    mapping(address => uint256) public claimbleNFTaddress;

    constructor(address _contractNFTAddress) BlastContract(0) {
        contractNFTAddress = _contractNFTAddress;
        authorizedToUseContract[msg.sender] = true;
    }

    function registerNFTtoClaim(address to, uint256 nftId) public onlyAuthorizedContract {
        isClaimbleAddress[to] = true;
        claimbleNFTaddress[to] = nftId;
    }

    function registerNFTsToClaim(address[] memory to, uint256[] memory nftIds) public onlyAuthorizedContract {
        require(to.length == nftIds.length, "Address and NFT ID arrays must have the same length");

        for (uint256 i = 0; i < to.length; i++) {
            isClaimbleAddress[to[i]] = true;
            claimbleNFTaddress[to[i]] = nftIds[i];
        }
    }

    function claimFreeNft() public {
        require(isClaimbleAddress[msg.sender], "There are no NFTs available for claim.");
        IERC721Enumerable currentToken = IERC721Enumerable(contractNFTAddress);
        currentToken.safeTransferFrom(address(this), msg.sender, claimbleNFTaddress[msg.sender]);

        isClaimbleAddress[msg.sender] = false;
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
