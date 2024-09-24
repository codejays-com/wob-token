// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract WorldOfBlastSwap is Ownable {
    using SafeERC20 for IERC20;

    IERC20 public wob;
    IERC20 public wobx;

    event Deposited(
        address indexed user,
        address indexed token,
        uint256 amount
    );
    event Withdrawn(
        address indexed user,
        address indexed token,
        uint256 amount
    );
    event Swapped(
        address indexed user,
        address indexed fromToken,
        address indexed toToken,
        uint256 amount
    );
    event WobTokenUpdated(
        address indexed oldAddress,
        address indexed newAddress
    );
    event WobxTokenUpdated(
        address indexed oldAddress,
        address indexed newAddress
    );

    constructor(IERC20 _wob, IERC20 _wobx) Ownable(msg.sender) {
        wob = _wob;
        wobx = _wobx;
    }

    function approveWob(uint256 _amount) external {
        wob.approve(address(this), _amount);
    }

    function approveWobx(uint256 _amount) external {
        wobx.approve(address(this), _amount);
    }

    function withdrawWobx(address _to, uint256 _amount) external onlyOwner {
        wobx.safeTransfer(_to, _amount);
        emit Withdrawn(_to, address(wobx), _amount);
    }

    function withdrawWob(address _to, uint256 _amount) external onlyOwner {
        wob.safeTransfer(_to, _amount);
        emit Withdrawn(_to, address(wob), _amount);
    }

    function swapWobForWobx(uint256 _amount) external {
        require(
            wob.allowance(msg.sender, address(this)) >= _amount,
            "You need to approve the contract to spend your WOB tokens"
        );

        wob.safeTransferFrom(msg.sender, address(this), _amount);
        wobx.safeTransfer(msg.sender, _amount);

        emit Swapped(msg.sender, address(wob), address(wobx), _amount);
    }

    function swapWobxForWob(uint256 _amount) external {
        require(
            wobx.allowance(msg.sender, address(this)) >= _amount,
            "You need to approve the contract to spend your WOBX tokens"
        );

        wobx.safeTransferFrom(msg.sender, address(this), _amount);
        wob.safeTransfer(msg.sender, _amount);

        emit Swapped(msg.sender, address(wobx), address(wob), _amount);
    }

    function setWob(address _newWob) external onlyOwner {
        emit WobTokenUpdated(address(wob), _newWob);
        wob = IERC20(_newWob);
    }

    function setWobx(address _newWobx) external onlyOwner {
        emit WobxTokenUpdated(address(wobx), _newWobx);
        wobx = IERC20(_newWobx);
    }

    function withdrawERC20(
        address _contract,
        address to,
        uint256 amount
    ) external onlyOwner {
        require(IERC20(_contract).transfer(to, amount), "Failed to transfer");
    }
}
