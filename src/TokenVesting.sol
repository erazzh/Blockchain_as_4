// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TokenVesting is Ownable {
    IERC20 public immutable token;
    uint256 public constant VESTING_DURATION = 365 days;
    uint256 public immutable startTimestamp;
    uint256 public totalAmount;
    uint256 public released;

    constructor(address _token) Ownable(msg.sender) {
        token = IERC20(_token);
        startTimestamp = block.timestamp;
    }

    function deposit(uint256 amount) external onlyOwner {
        totalAmount += amount;
        token.transferFrom(msg.sender, address(this), amount);
    }

    function release() external {
        uint256 unreleased = _vestedAmount() - released;
        require(unreleased > 0, "No tokens to release");

        released += unreleased;
        token.transfer(owner(), unreleased);
    }

    function _vestedAmount() internal view returns (uint256) {
        if (block.timestamp >= startTimestamp + VESTING_DURATION) {
            return totalAmount;
        } else {
            return (totalAmount * (block.timestamp - startTimestamp)) / VESTING_DURATION;
        }
    }
}