// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IBlast.sol";

contract OreToken is ERC20, Ownable(msg.sender) {

    IBlast public constant BLAST =
        IBlast(0x4300000000000000000000000000000000000002);
    
    // Mapping to track authorized contracts
    mapping(address => bool) public authorizedContracts;

    // Constructor initializes the Ores token with a name and symbol
    constructor() ERC20("Ore Token", "ORE") {
        BLAST.configureClaimableGas();
    }

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

    // Blast functions
    function claimAllGas() external onlyOwner {
        BLAST.claimAllGas(address(this), msg.sender);
    }
}