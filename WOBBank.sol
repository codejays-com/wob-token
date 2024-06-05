// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract WOBBank is ERC20, ERC20Permit, Ownable {
    // internal
    uint256 private _totalSupply;

    constructor() ERC20("WOB Bank", "WOBB") ERC20Permit("WOB Bank") Ownable(msg.sender) {
        uint256 _initialSupply = 1000000000 * 10 ** decimals();
        _totalSupply = _initialSupply;
        _mint(address(this), _initialSupply);
    }

    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    function withdrawBalance(address _tokenContractAddress) external onlyOwner {
        IERC20 currentToken = IERC20(_tokenContractAddress);
        currentToken.transfer(owner(), currentToken.balanceOf(address(this)));
    }
}
