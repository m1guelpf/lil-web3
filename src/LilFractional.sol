// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.10;

import 'solmate/tokens/ERC20.sol';
import 'solmate/tokens/ERC721.sol';

/// @title NFT Share Token
/// @author Miguel Piedrafita
/// @notice ERC20 token representing a share of an ERC721
contract NFTShare is ERC20 {
	/// @notice Deploys an NFTShare with the specified name and symbol, and mints an initial supply to the specified address
	/// @param name The name of the deployed token
	/// @param symbol The symbol of the deployed token
	/// @param mintSupply The supply this token will have, which be minted to the specified address
	/// @param mintTo The address the initial supply will get minted to
	/// @dev Deployed from the split() function of the LilFractional contract
	constructor(
		string memory name,
		string memory symbol,
		uint256 mintSupply,
		address mintTo
	) payable ERC20(name, symbol, 18) {
		_mint(mintTo, mintSupply);
	}

	/// @notice Burns a specified amount of tokens from a specified user after ensuring the caller has permission to
	/// @param from The address of the user who should get their tokens burned
	/// @param amount The amount of tokens that should get burned
	/// @dev The allowance check happens when substracting the amount from the allowed amount. This operation will underflow (and revert) if the caller doesn't have enough allowance.
	function burnFrom(address from, uint256 amount) public payable {
		uint256 allowed = allowance[from][msg.sender]; // Saves gas for limited approvals.

		if (allowed != type(uint256).max) allowance[from][msg.sender] = allowed - amount;

		_burn(from, amount);
	}
}

/// @title lil fractional
/// @author Miguel Piedrafita
/// @notice Barebones NFT fractionalisation factory.
contract LilFractional {
	/// ERRORS ///

	/// @notice Thrown when trying to rejoin a token from a vault that doesn't exist
	error VaultNotFound();

	/// @dev Parameters for vaults
	/// @param nftContract The ERC721 contract for the fractionalized token
	/// @param tokenId The ID of the fractionalized token
	/// @param tokenSupply The amount of issued ERC20 tokens for this vault
	/// @param tokenContract The ERC20 contract for the issued tokens
	struct Vault {
		ERC721 nftContract;
		uint256 tokenId;
		uint256 tokenSupply;
		NFTShare tokenContract;
	}

	/// EVENTS ///

	/// @notice Emitted when a token is fractionalized
	/// @param vault The details of the created vault
	event VaultCreated(Vault vault);

	/// @notice Emitted when a token is recovered from a vault
	/// @param vault The details of the destroyed vault
	event VaultDestroyed(Vault vault);

	/// @notice Used as a counter for the next vault index.
	/// @dev Initialised at 1 because it makes the first transaction slightly cheaper.
	uint256 internal vaultId = 1;

	/// @notice An indexed list of vaults
	/// @dev This automatically generates a getter for us!
	mapping(uint256 => Vault) public getVault;

	/// @notice Fractionalize an ERC721 token
	/// @param nftContract The ERC721 contract for the token you're fractionalizing
	/// @param tokenId The ID of the token you're fractionalizing
	/// @param supply The amount of ERC20 tokens to issue for this token. These will be distributed to the caller
	/// @param name The name for the resultant ERC20 token
	/// @param symbol The symbol for the resultant ERC20 token
	/// @return The ID of the created vault
	/// @dev Remember to call setApprovalForAll(<address of this contract>, true) on the ERC721's contract before calling this function
	function split(
		ERC721 nftContract,
		uint256 tokenId,
		uint256 supply,
		string memory name,
		string memory symbol
	) public payable returns (uint256) {
		NFTShare tokenContract = new NFTShare(name, symbol, supply, msg.sender);

		Vault memory vault = Vault({
			nftContract: nftContract,
			tokenId: tokenId,
			tokenSupply: supply,
			tokenContract: tokenContract
		});

		emit VaultCreated(vault);

		getVault[vaultId] = vault;

		nftContract.transferFrom(msg.sender, address(this), tokenId);

		return vaultId++;
	}

	/// @notice Recover a fractionalized ERC721 token
	/// @param vaultId The ID of the vault containing the token
	/// @dev Remember to call approve(<address of this contract>, <supply or greater>) on the ERC20's contract before calling this function
	function join(uint256 vaultId) public payable {
		Vault memory vault = getVault[vaultId];

		if (vault.tokenContract == NFTShare(address(0))) revert VaultNotFound();

		delete getVault[vaultId];

		vault.tokenContract.burnFrom(msg.sender, vault.tokenSupply);
		vault.nftContract.transferFrom(address(this), msg.sender, vault.tokenId);
	}

	/// @dev This function ensures this contract can receive ERC721 tokens
	function onERC721Received(
		address,
		address,
		uint256,
		bytes memory
	) public payable returns (bytes4) {
		return this.onERC721Received.selector;
	}
}
