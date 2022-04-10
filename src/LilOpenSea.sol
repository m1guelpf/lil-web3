// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.10;

import { ERC721 } from 'solmate/tokens/ERC721.sol';
import { SafeTransferLib } from 'solmate/utils/SafeTransferLib.sol';

/// @title lil opensea
/// @author Miguel Piedrafita
/// @notice Barebones NFT marketplace.
contract LilOpenSea {
	/// ERRORS ///

	/// @notice Thrown when trying to cancel a listing the user hasn't created
	error Unauthorized();

	/// @notice Thrown when underpaying or overpaying a listing
	error WrongValueSent();

	/// @notice Thrown when trying to purchase a listing that doesn't exist
	error ListingNotFound();

	/// EVENTS ///

	/// @notice Emitted when a new listing is created
	/// @param listing The newly-created listing
	event NewListing(Listing listing);

	/// @notice Emitted when a listing is cancelled
	/// @param listing The removed listing
	event ListingRemoved(Listing listing);

	/// @notice Emitted when a listing is purchased
	/// @param buyer The address of the buyer
	/// @param listing The purchased listing
	event ListingBought(address indexed buyer, Listing listing);

	/// @notice Used as a counter for the next sale index.
	/// @dev Initialised at 1 because it makes the first transaction slightly cheaper.
	uint256 internal saleCounter = 1;

	/// @dev Parameters for listings
	/// @param tokenContract The ERC721 contract for the listed token
	/// @param tokenId The ID of the listed token
	/// @param creator The address of the seller
	/// @param askPrice The amount the seller is asking for in exchange for the token
	struct Listing {
		ERC721 tokenContract;
		uint256 tokenId;
		address creator;
		uint256 askPrice;
	}

	/// @notice An indexed list of listings
	/// @dev This automatically generates a getter for us!
	mapping(uint256 => Listing) public getListing;

	/// @notice List an ERC721 token for sale
	/// @param tokenContract The ERC721 contract for the token you're listing
	/// @param tokenId The ID of the token you're listing
	/// @param askPrice How much you want to receive in exchange for the token
	/// @return The ID of the created listing
	/// @dev Remember to call setApprovalForAll(<address of this contract>, true) on the ERC721's contract before calling this function
	function list(
		ERC721 tokenContract,
		uint256 tokenId,
		uint256 askPrice
	) public payable returns (uint256) {
		Listing memory listing = Listing({
			tokenContract: tokenContract,
			tokenId: tokenId,
			askPrice: askPrice,
			creator: msg.sender
		});

		getListing[saleCounter] = listing;

		emit NewListing(listing);

		listing.tokenContract.transferFrom(msg.sender, address(this), listing.tokenId);

		return saleCounter++;
	}

	/// @notice Cancel an existing listing
	/// @param listingId The ID for the listing you want to cancel
	function cancelListing(uint256 listingId) public payable {
		Listing memory listing = getListing[listingId];

		if (listing.creator != msg.sender) revert Unauthorized();

		delete getListing[listingId];

		emit ListingRemoved(listing);

		listing.tokenContract.transferFrom(address(this), msg.sender, listing.tokenId);
	}

	/// @notice Purchase one of the listed tokens
	/// @param listingId The ID for the listing you want to purchase
	function buyListing(uint256 listingId) public payable {
		Listing memory listing = getListing[listingId];

		if (listing.creator == address(0)) revert ListingNotFound();
		if (listing.askPrice != msg.value) revert WrongValueSent();

		delete getListing[listingId];

		emit ListingBought(msg.sender, listing);

		SafeTransferLib.safeTransferETH(listing.creator, listing.askPrice);
		listing.tokenContract.transferFrom(address(this), msg.sender, listing.tokenId);
	}
}
