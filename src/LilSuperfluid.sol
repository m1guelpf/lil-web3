// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.10;

import 'solmate/tokens/ERC20.sol';

/// @title lil superfluid
/// @author Miguel Piedrafita
/// @notice A simple token streaming manager
contract LilSuperfluid {
	/// ERRORS ///

	/// @notice Thrown trying to withdraw/refuel a function without being part of the stream
	error Unauthorized();

	/// @notice Thrown when attempting to access a non-existant or deleted stream
	error StreamNotFound();

	/// @notice Thrown when trying to withdraw excess funds while the stream hasn't ended
	error StreamStillActive();

	/// EVENTS ///

	/// @notice Emitted when creating a new steam
	/// @param stream The newly-created stream
	event StreamCreated(Stream stream);

	/// @notice Emitted when increasing the accessible balance of a stream
	/// @param streamId The ID of the stream receiving the funds
	/// @param amount The ERC20 token balance that is being added
	event StreamRefueled(uint256 indexed streamId, uint256 amount);

	/// @notice Emitted when the receiver withdraws the received funds
	/// @param streamId The ID of the stream having its funds withdrawn
	/// @param amount The ERC20 token balance being withdrawn
	event FundsWithdrawn(uint256 indexed streamId, uint256 amount);

	/// @notice Emitted when the sender withdraws excess funds
	/// @param streamId The ID of the stream having its excess funds withdrawn
	/// @param amount The ERC20 token balance being withdrawn
	event ExcessWithdrawn(uint256 indexed streamId, uint256 amount);

	/// @notice Emitted when the configuration of a stream is updated
	/// @param streamId The ID of the stream that was updated
	/// @param paymentPerBlock The new payment rate for this stream
	/// @param timeframe The new interval this stream will be active for
	event StreamDetailsUpdated(uint256 indexed streamId, uint256 paymentPerBlock, Timeframe timeframe);

	/// @dev Parameters for streams
	/// @param sender The address of the creator of the stream
	/// @param recipient The address that will receive the streamed tokens
	/// @param token The ERC20 token that is getting streamed
	/// @param balance The ERC20 balance locked in the contract for this stream
	/// @param withdrawnBalance The ERC20 balance the recipient has already withdrawn to their wallet
	/// @param paymentPerBlock The amount of tokens to stream for each new block
	/// @param timeframe The starting and ending block numbers for this stream
	struct Stream {
		address sender;
		address recipient;
		ERC20 token;
		uint256 balance;
		uint256 withdrawnBalance;
		uint256 paymentPerBlock;
		Timeframe timeframe;
	}

	/// @dev A block interval definition
	/// @param startBlock The first block where the token stream will be active
	/// @param stopBlock The last block where the token stream will be active
	struct Timeframe {
		uint256 startBlock;
		uint256 stopBlock;
	}

	/// @dev Components of an Ethereum signature
	struct Signature {
		uint8 v;
		bytes32 r;
		bytes32 s;
	}

	/// @notice Used as a counter for the next stream index.
	/// @dev Initialised at 1 because it makes the first transaction slightly cheaper
	uint256 internal streamId = 1;

	/// @notice Signature nonce, incremented with each successful execution or state change
	/// @dev This is used to prevent signature reuse
	/// @dev Initialised at 1 because it makes the first transaction slightly cheaper
	uint256 public nonce = 1;

	/// @dev The EIP-712 domain separator
	bytes32 public immutable domainSeparator;

	/// @dev EIP-712 types for a signature that updates stream details
	bytes32 public constant UPDATE_DETAILS_HASH =
		keccak256(
			'UpdateStreamDetails(uint256 streamId,uint256 paymentPerBlock,uint256 startBlock,uint256 stopBlock,uint256 nonce)'
		);

	/// @notice An indexed list of streams
	/// @dev This automatically generates a getter for us!
	mapping(uint256 => Stream) public getStream;

	/// @notice Deploy a new LilSuperfluid instance
	constructor() payable {
		domainSeparator = keccak256(
			abi.encode(
				keccak256('EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)'),
				keccak256(bytes('LilSuperfluid')),
				keccak256(bytes('1')),
				block.chainid,
				address(this)
			)
		);
	}

	/// @notice Create a stream stream that continously delivers tokens to `recipient`
	/// @param recipient The address that will receive the streamed tokens
	/// @param token The ERC20 token that will get streamed
	/// @param initialBalance How many ERC20 tokens to lock on the contract. Note that only the locked amount is guaranteed to be delivered to `recipient`
	/// @param timeframe An interval of time, defined in block numbers, during which the stream will be active
	/// @param paymentPerBlock How many tokens to deliver for each block the stream is active
	/// @return The ID of the created stream
	/// @dev Remember to call approve(<address of this contract>, <initialBalance or greater>) on the ERC20's contract before calling this function
	function streamTo(
		address recipient,
		ERC20 token,
		uint256 initialBalance,
		Timeframe memory timeframe,
		uint256 paymentPerBlock
	) external payable returns (uint256) {
		Stream memory stream = Stream({
			token: token,
			sender: msg.sender,
			withdrawnBalance: 0,
			timeframe: timeframe,
			recipient: recipient,
			balance: initialBalance,
			paymentPerBlock: paymentPerBlock
		});

		emit StreamCreated(stream);

		getStream[streamId] = stream;

		token.transferFrom(msg.sender, address(this), initialBalance);

		return streamId++;
	}

	/// @notice Increase the amount of locked tokens for a certain token stream
	/// @param streamId The ID for the stream that you are locking the tokens for
	/// @param amount The amount of tokens to lock
	/// @dev Remember to call approve(<address of this contract>, <amount or greater>) on the ERC20's contract before calling this function
	function refuel(uint256 streamId, uint256 amount) public payable {
		if (getStream[streamId].sender != msg.sender) revert Unauthorized();

		unchecked {
			getStream[streamId].balance += amount;
		}

		emit StreamRefueled(streamId, amount);

		getStream[streamId].token.transferFrom(msg.sender, address(this), amount);
	}

	/// @notice Receive some of the streamed tokens, only available to the receiver of the stream
	/// @param streamId The ID for the stream you are withdrawing the tokens from
	function withdraw(uint256 streamId) public payable {
		if (getStream[streamId].recipient != msg.sender) revert Unauthorized();

		uint256 balance = balanceOf(streamId, msg.sender);

		unchecked {
			getStream[streamId].withdrawnBalance += balance;
		}

		emit FundsWithdrawn(streamId, balance);

		getStream[streamId].token.transfer(msg.sender, balance);
	}

	/// @notice Withdraw any excess in the locked balance, only available to the creator of the stream after it's no longer active
	/// @param streamId The ID for the stream you are receiving the excess for
	function refund(uint256 streamId) public payable {
		if (getStream[streamId].sender != msg.sender) revert Unauthorized();
		if (getStream[streamId].timeframe.stopBlock > block.number) revert StreamStillActive();

		uint256 balance = balanceOf(streamId, msg.sender);

		getStream[streamId].balance -= balance;

		emit ExcessWithdrawn(streamId, balance);

		getStream[streamId].token.transfer(msg.sender, balance);
	}

	/// @dev A function used internally to calculate how many blocks the stream has been active for so far
	/// @param timeframe The time interval the stream is supposed to be active for
	/// @param delta The amount of blocks the stream has been active for so far
	function calculateBlockDelta(Timeframe memory timeframe) internal view returns (uint256 delta) {
		if (block.number <= timeframe.startBlock) return 0;
		if (block.number < timeframe.stopBlock) return block.number - timeframe.startBlock;

		return timeframe.stopBlock - timeframe.startBlock;
	}

	/// @notice Check the balance of any of the involved parties on a stream
	/// @param streamId The ID of the stream you're looking up
	/// @param who The address of the party you want to know the balance of
	/// @return The ERC20 balance of the specified party
	/// @dev This function will always return 0 for any address not involved in the stream
	function balanceOf(uint256 streamId, address who) public view returns (uint256) {
		Stream memory stream = getStream[streamId];

		if (stream.sender == address(0)) revert StreamNotFound();

		uint256 blockDelta = calculateBlockDelta(stream.timeframe);
		uint256 recipientBalance = blockDelta * stream.paymentPerBlock;

		if (who == stream.recipient) return recipientBalance - stream.withdrawnBalance;
		if (who == stream.sender) return stream.balance - recipientBalance;

		return 0;
	}

	/// @notice Update the rate at which tokens get streamed, or the interval the stream is active for. Requires both parties to authorise the change
	/// @param streamId The ID for the stream which is getting its configuration updated
	/// @param paymentPerBlock The new rate at which tokens will get streamed
	/// @param timeframe The new interval, defined in blocks, the stream will be active for
	/// @param sig The signature of the other affected party for this change, certifying they approve of it
	function updateDetails(
		uint256 streamId,
		uint256 paymentPerBlock,
		Timeframe memory timeframe,
		Signature memory sig
	) public payable {
		Stream memory stream = getStream[streamId];

		if (stream.sender == address(0)) revert StreamNotFound();

		bytes32 digest = keccak256(
			abi.encodePacked(
				'\x19\x01',
				domainSeparator,
				keccak256(
					abi.encode(
						UPDATE_DETAILS_HASH,
						streamId,
						paymentPerBlock,
						timeframe.startBlock,
						timeframe.stopBlock,
						nonce++
					)
				)
			)
		);

		address sigAddress = ecrecover(digest, sig.v, sig.r, sig.s);

		if (
			!(stream.sender == msg.sender && stream.recipient == sigAddress) &&
			!(stream.sender == sigAddress && stream.recipient == msg.sender)
		) revert Unauthorized();

		emit StreamDetailsUpdated(streamId, paymentPerBlock, timeframe);

		getStream[streamId].paymentPerBlock = paymentPerBlock;
		getStream[streamId].timeframe = timeframe;
	}
}
