// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

interface ICreditToken {
    function mint(address to, uint256 amount) external;
    function balanceOf(address account) external view returns (uint256);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external;
    function approve(address spender, uint256 amount) external returns (bool);
    function burn(uint256 amount) external;
}