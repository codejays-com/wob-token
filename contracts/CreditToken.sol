// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Credit is ERC20, Ownable(msg.sender) {

    // Mapping to track authorized contracts
    mapping(address => bool) public authorizedContracts;

    constructor() ERC20("Credit", "CREDIT") {}

    // Modifier to restrict access to authorized contracts
    modifier onlyAuthorized() {
        require(authorizedContracts[msg.sender], "Not an authorized contract");
        _;
    }

    // Function to mint new ORES tokens (onlyOwner or authorized contract)
    function mint(address to, uint256 amount) external onlyAuthorized {
        _mint(to, amount);  // Mint the specified amount of ORES to the address "to"
    }

    // Function to allow the owner to authorize a contract for minting
    function authorizeContract(address contractAddress) external onlyOwner {
        authorizedContracts[contractAddress] = true;
    }

    // Function to remove authorization for a contract
    function revokeContractAuthorization(address contractAddress) external onlyOwner {
        authorizedContracts[contractAddress] = false;
    }

    // Function to burn tokens from the sender's balance
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }
}