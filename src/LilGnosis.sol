// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.10;

/// @title lil gnosis
/// @author Miguel Piedrafita
/// @notice An optimised ERC721-based multisig implementation
contract LilGnosis {
	/// ERRORS ///

	/// @notice Thrown when the provided signatures are invalid, duplicated, or out of order
	error InvalidSignatures();

	/// @notice Thrown when the execution of the requested transaction fails
	error ExecutionFailed();

	/// EVENTS ///

	/// @notice Emitted when the number of required signatures is updated
	/// @param newQuorum The new amount of required signatures
	event QuorumUpdated(uint256 newQuorum);

	/// @notice Emitted when a new transaction is executed
	/// @param target The address the transaction was sent to
	/// @param value The amount of ETH sent in the transaction
	/// @param payload The data sent in the transaction
	event Executed(address target, uint256 value, bytes payload);

	/// @notice Emitted when a new signer gets added or removed from the trusted signers
	/// @param signer The address of the updated signer
	/// @param shouldTrust Wether the contract will trust this signer going forwards
	event SignerUpdated(address indexed signer, bool shouldTrust);

	/// @dev Components of an Ethereum signature
	struct Signature {
		uint8 v;
		bytes32 r;
		bytes32 s;
	}

	/// @notice Signature nonce, incremented with each successful execution or state change
	/// @dev This is used to prevent signature reuse
	/// @dev Initialised at 1 because it makes the first transaction slightly cheaper
	uint256 public nonce = 1;

	/// @notice The amount of required signatures to execute a transaction or change the state
	uint256 public quorum;

	/// @dev The EIP-721 domain separator
	bytes32 public immutable domainSeparator;

	/// @notice A list of signers, and wether they're trusted by this contract
	/// @dev This automatically generates a getter for us!
	mapping(address => bool) public isSigner;

	/// @dev EIP-721 types for a signature that updates the quorum
	bytes32 public constant QUORUM_HASH = keccak256('UpdateQuorum(uint256 newQuorum,uint256 nonce)');

	/// @dev EIP-721 types for a signature that updates a signer state
	bytes32 public constant SIGNER_HASH = keccak256('UpdateSigner(address signer,bool shouldTrust,uint256 nonce)');

	/// @dev EIP-721 types for a signature that executes a transaction
	bytes32 public constant EXECUTE_HASH =
		keccak256('Execute(address target,uint256 value,bytes payload,uint256 nonce)');

	/// @notice Deploy a new LilGnosis instance, with the specified name, trusted signers and number of required signatures
	/// @param name The name of the multisig
	/// @param signers An array of addresses to trust
	/// @param _quorum The number of required signatures to execute a transaction or change the state
	constructor(
		string memory name,
		address[] memory signers,
		uint256 _quorum
	) payable {
		unchecked {
			for (uint256 i = 0; i < signers.length; i++) isSigner[signers[i]] = true;
		}

		quorum = _quorum;

		domainSeparator = keccak256(
			abi.encode(
				keccak256('EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)'),
				keccak256(bytes(name)),
				keccak256(bytes('1')),
				block.chainid,
				address(this)
			)
		);
	}

	/// @notice Execute a transaction from the multisig, providing the required amount of signatures
	/// @param target The address to send the transaction to
	/// @param value The amount of ETH to send in the transaction
	/// @param payload The data to send in the transaction
	/// @param sigs An array of signatures from trusted signers, sorted in ascending order by the signer's addresses
	/// @dev Make sure the signatures are sorted in ascending order by the signer's addresses! Otherwise the verification will fail
	function execute(
		address target,
		uint256 value,
		bytes calldata payload,
		Signature[] calldata sigs
	) public payable {
		bytes32 digest = keccak256(
			abi.encodePacked(
				'\x19\x01',
				domainSeparator,
				keccak256(abi.encode(EXECUTE_HASH, target, value, payload, nonce++))
			)
		);

		address previous;

		unchecked {
			for (uint256 i = 0; i < quorum; i++) {
				address sigAddress = ecrecover(digest, sigs[i].v, sigs[i].r, sigs[i].s);

				if (!isSigner[sigAddress] || previous >= sigAddress) revert InvalidSignatures();

				previous = sigAddress;
			}
		}

		emit Executed(target, value, payload);

		(bool success, ) = target.call{ value: value }(payload);

		if (!success) revert ExecutionFailed();
	}

	/// @notice Update the amount of required signatures to execute a transaction or change state, providing the required amount of signatures
	/// @param _quorum The new number of required signatures
	/// @param sigs An array of signatures from trusted signers, sorted in ascending order by the signer's addresses
	/// @dev Make sure the signatures are sorted in ascending order by the signer's addresses! Otherwise the verification will fail
	function setQuorum(uint256 _quorum, Signature[] calldata sigs) public payable {
		bytes32 digest = keccak256(
			abi.encodePacked('\x19\x01', domainSeparator, keccak256(abi.encode(QUORUM_HASH, _quorum, nonce++)))
		);

		address previous;

		unchecked {
			for (uint256 i = 0; i < quorum; i++) {
				address sigAddress = ecrecover(digest, sigs[i].v, sigs[i].r, sigs[i].s);

				if (!isSigner[sigAddress] || previous >= sigAddress) revert InvalidSignatures();

				previous = sigAddress;
			}
		}

		emit QuorumUpdated(_quorum);

		quorum = _quorum;
	}

	/// @notice Add or remove an address from the list of signers trusted by this contract
	/// @param signer The address of the signer
	/// @param shouldTrust Wether to trust this signer going forward
	/// @param sigs An array of signatures from trusted signers, sorted in ascending order by the signer's addresses
	/// @dev Make sure the signatures are sorted in ascending order by the signer's addresses! Otherwise the verification will fail
	function setSigner(
		address signer,
		bool shouldTrust,
		Signature[] calldata sigs
	) public payable {
		bytes32 digest = keccak256(
			abi.encodePacked(
				'\x19\x01',
				domainSeparator,
				keccak256(abi.encode(SIGNER_HASH, signer, shouldTrust, nonce++))
			)
		);

		address previous;

		unchecked {
			for (uint256 i = 0; i < quorum; i++) {
				address sigAddress = ecrecover(digest, sigs[i].v, sigs[i].r, sigs[i].s);

				if (!isSigner[sigAddress] || previous >= sigAddress) revert InvalidSignatures();

				previous = sigAddress;
			}
		}

		emit SignerUpdated(signer, shouldTrust);

		isSigner[signer] = shouldTrust;
	}

	/// @dev This function ensures this contract can receive ETH
	receive() external payable {}
}
