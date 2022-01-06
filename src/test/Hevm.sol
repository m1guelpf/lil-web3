// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

library stdError {
	bytes public constant assertionError = abi.encodeWithSignature('Panic(uint256)', 0x01);
	bytes public constant arithmeticError = abi.encodeWithSignature('Panic(uint256)', 0x11);
	bytes public constant divisionError = abi.encodeWithSignature('Panic(uint256)', 0x12);
	bytes public constant enumConversionError = abi.encodeWithSignature('Panic(uint256)', 0x21);
	bytes public constant encodeStorageError = abi.encodeWithSignature('Panic(uint256)', 0x22);
	bytes public constant popError = abi.encodeWithSignature('Panic(uint256)', 0x31);
	bytes public constant indexOOBError = abi.encodeWithSignature('Panic(uint256)', 0x32);
	bytes public constant memOverflowError = abi.encodeWithSignature('Panic(uint256)', 0x41);
	bytes public constant zeroVarError = abi.encodeWithSignature('Panic(uint256)', 0x51);
}

interface Hevm {
	// Set block.timestamp (newTimestamp)
	function warp(uint256) external;

	// Set block.height (newHeight)
	function roll(uint256) external;

	// Set block.basefee (newBasefee)
	function fee(uint256) external;

	// Loads a storage slot from an address (who, slot)
	function load(address, bytes32) external returns (bytes32);

	// Stores a value to an address' storage slot, (who, slot, value)
	function store(
		address,
		bytes32,
		bytes32
	) external;

	// Signs data, (privateKey, digest) => (r, v, s)
	function sign(uint256, bytes32)
		external
		returns (
			uint8,
			bytes32,
			bytes32
		);

	// Gets address for a given private key, (privateKey) => (address)
	function addr(uint256) external returns (address);

	// Performs a foreign function call via terminal, (stringInputs) => (result)
	function ffi(string[] calldata) external returns (bytes memory);

	// Sets the *next* call's msg.sender to be the input address
	function prank(address) external;

	// Sets all subsequent calls' msg.sender to be the input address until `stopPrank` is called
	function startPrank(address) external;

	// Resets subsequent calls' msg.sender to be `address(this)`
	function stopPrank() external;

	// Sets an address' balance, (who, newBalance)
	function deal(address, uint256) external;

	// Sets an address' code, (who, newCode)
	function etch(address, bytes calldata) external;

	// Expects an error on next call
	function expectRevert(bytes calldata) external;

	// Expects an event on next call
	function expectEmit(
		bool,
		bool,
		bool,
		bool
	) external;

	// Record all storage reads and writes
	function record() external;

	// Gets all accessed reads and write slot from a recording session, for a given address
	function accesses(address) external returns (bytes32[] memory reads, bytes32[] memory writes);
}
