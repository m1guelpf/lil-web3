// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.10;

import 'solmate/tokens/ERC20.sol';

/// @title Flash Borrower Interface
/// @author Miguel Piedrafita
/// @notice Contracts must implement this interface in order to receive flash loans from LilFlashloan
interface FlashBorrower {
	/// @notice Flash loan callback
	/// @param token The ERC20 token you're receiving your flash loan on
	/// @param amount The amount of tokens received
	/// @param data Forwarded data from the flash loan request
	/// @dev Called after receiving the requested flash loan, should return tokens + any fees before the end of the transaction
	function onFlashLoan(
		ERC20 token,
		uint256 amount,
		bytes calldata data
	) external;
}

/// @title lil flashloan
/// @author Miguel Piedrafita
/// @notice A (Proof of Concept)-level flash loan implementation
/// @dev In order to keep things simple, this implementation is not compliant with EIP-3156 (the flash loan standard)
contract LilFlashloan {
	/// ERRORS ///

	/// @notice Thrown when trying to update token fees or withdraw token balance without being the manager
	error Unauthorized();

	/// @notice Thrown when trying to update token fees to an invalid percentage
	error InvalidPercentage();

	/// @notice Thrown when the loaned tokens (and any additional fees) are not returned before the end of the transaction
	error TokensNotReturned();

	/// EVENTS ///

	/// @notice Emitted when the fees for flash loaning a token have been updated
	/// @param token The ERC20 token to apply the specified fee to
	/// @param fee The new fee for this token as a percentage and multiplied by 100 to avoid decimals (for example, 10% is 10_00)
	event FeeUpdated(ERC20 indexed token, uint256 fee);

	/// @notice Emitted when the manager withdraws part of the contract's liquidity
	/// @param token The ERC20 token that was withdrawn
	/// @param amount The amount of tokens that were withdrawn
	event Withdrawn(ERC20 indexed token, uint256 amount);

	/// @notice Emitted when a flash loan is completed
	/// @param receiver The contract that received the funds
	/// @param token The ERC20 token that was loaned
	/// @param amount The amount of tokens that were loaned
	event Flashloaned(FlashBorrower indexed receiver, ERC20 indexed token, uint256 amount);

	/// @notice The manager of this contract
	address public immutable manager;

	/// @notice A list of the fee percentages (multiplied by 100 to avoid decimals, for example 10% is 10_00) for each token
	mapping(ERC20 => uint256) public fees;

	/// @notice Deploys a LilFlashloan instance and sets the deployer as manager
	constructor() payable {
		manager = msg.sender;
	}

	/// @notice Request a flash loan
	/// @param receiver The contract that will receive the flash loan
	/// @param token The ERC20 token you want to borrow
	/// @param amount The amount of tokens you want to borrow
	/// @param data Data to forward to the receiver contract along with your flash loan
	/// @dev Make sure your contract implements the FlashBorrower interface!
	function execute(
		FlashBorrower receiver,
		ERC20 token,
		uint256 amount,
		bytes calldata data
	) public payable {
		uint256 currentBalance = token.balanceOf(address(this));

		emit Flashloaned(receiver, token, amount);

		token.transfer(address(receiver), amount);
		receiver.onFlashLoan(token, amount, data);

		if (currentBalance + getFee(token, amount) > token.balanceOf(address(this))) revert TokensNotReturned();
	}

	/// @notice Calculate the fee owed for the loaned tokens
	/// @param token The ERC20 token you're receiving your loan on
	/// @param amount The amount of tokens you're receiving
	/// @return The amount of tokens you need to pay as a fee
	function getFee(ERC20 token, uint256 amount) public view returns (uint256) {
		if (fees[token] == 0) return 0;

		return (amount * fees[token]) / 10_000;
	}

	/// @notice Update the fee percentage for a specified ERC20 token, only available to the manager of the contract
	/// @param token The ERC20 token you're updating the fee percentage for
	/// @param fee The fee percentage for this token, multiplied by 100 (for example, 10% is 10_00)
	function setFees(ERC20 token, uint256 fee) public payable {
		if (msg.sender != manager) revert Unauthorized();
		if (fee > 100_00) revert InvalidPercentage();

		emit FeeUpdated(token, fee);

		fees[token] = fee;
	}

	/// @notice Withdraw part of the contract's liquidity, only available to the manager of the contract
	/// @param token The ERC20 token you want to withdraw
	/// @param amount The amount of tokens to withdraw
	function withdraw(ERC20 token, uint256 amount) public payable {
		if (msg.sender != manager) revert Unauthorized();

		emit Withdrawn(token, amount);

		token.transfer(msg.sender, amount);
	}
}
