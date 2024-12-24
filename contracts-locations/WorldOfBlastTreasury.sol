// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
    Handling fund transactions
**/

contract WorldOfBlastTreasury is Ownable {
    using SafeERC20 for IERC20;
    mapping(address => bool) public authorizedContracts;

    constructor() Ownable(msg.sender) {}

    function authorizeContract(
        address contractAddress,
        bool authorized
    ) public onlyOwner {
        authorizedContracts[contractAddress] = authorized;
        emit AuthorizedContract(contractAddress, authorized);
    }

    function withdrawFunds(
        address tokenAddress,
        uint256 amount
    ) public authorizeOnly {
        IERC20 token = IERC20(tokenAddress);
        SafeERC20.safeTransfer(token, msg.sender, amount);
    }

    function transferFunds(
        address tokenAddress,
        address recipient,
        uint256 amount
    ) public authorizeOnly {
        require(recipient != address(0), "Recipient address cannot be zero");
        IERC20 token = IERC20(tokenAddress);
        SafeERC20.safeTransfer(token, recipient, amount);
        emit FundsTransferred(tokenAddress, recipient, amount);
    }

    modifier authorizeOnly() {
        require(
            authorizedContracts[msg.sender],
            "Contract is not authorized to withdraw funds"
        );
        _;
    }

    event AuthorizedContract(address indexed contractAddress, bool authorized);
    event FundsTransferred(
        address indexed tokenAddress,
        address indexed recipient,
        uint256 amount
    );
}
