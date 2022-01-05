// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.10;

import "solmate/tokens/ERC20.sol";

interface FlashBorrower {
    function onFlashLoan(
        ERC20 token,
        uint256 amount,
        bytes calldata data
    ) external;
}

contract LilFlashloan {
    error Unauthorized();
    error InvalidPercentage();
    error TokensNotReturned();

    address public immutable manager;

    mapping(address => uint256) public fees;

    constructor() payable {
        manager = msg.sender;
    }

    function execute(
        FlashBorrower receiver,
        ERC20 token,
        uint256 amount,
        bytes calldata data
    ) public payable {
        uint256 currentBalance = token.balanceOf(address(this));

        token.transfer(address(receiver), amount);

        receiver.onFlashLoan(token, amount, data);

        if (
            currentBalance + getFee(address(token), amount) >
            token.balanceOf(address(this))
        ) revert TokensNotReturned();
    }

    function getFee(address token, uint256 amount)
        public
        payable
        returns (uint256)
    {
        if (fees[token] == 0) return 0;

        return (amount * fees[token]) / 10_000;
    }

    // Fees are a percentage, multiplied by 100 to avoid decimals (for example, 10% is 10_00)
    function setFees(address token, uint256 fee) public payable {
        if (msg.sender != manager) revert Unauthorized();
        if (fee > 100_00) revert InvalidPercentage();

        fees[token] = fee;
    }

    function withdraw(ERC20 token, uint256 amount) public payable {
        if (msg.sender != manager) revert Unauthorized();

        token.transfer(msg.sender, amount);
    }
}
