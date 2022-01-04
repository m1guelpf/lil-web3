// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.10;

import "solmate/tokens/ERC721.sol";
import "solmate/utils/SafeTransferLib.sol";

contract LilOpenSea {
    error Unauthorized();
    error WrongValueSent();
    error ListingNotFound();

    event NewListing(Listing listing);
    event ListingRemoved(Listing listing);
    event ListingBought(address indexed buyer, Listing listing);

    uint256 internal saleCounter = 1;

    struct Listing {
        ERC721 tokenContract;
        uint256 tokenId;
        address creator;
        uint256 askPrice;
    }

    mapping(uint256 => Listing) public getListing;

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

        listing.tokenContract.transferFrom(
            msg.sender,
            address(this),
            listing.tokenId
        );

        return saleCounter++;
    }

    function cancelListing(uint256 listingId) public payable {
        Listing memory listing = getListing[listingId];

        if (listing.creator != msg.sender) revert Unauthorized();

        delete getListing[listingId];

        emit ListingRemoved(listing);

        listing.tokenContract.transferFrom(
            address(this),
            msg.sender,
            listing.tokenId
        );
    }

    function buyListing(uint256 listingId) public payable {
        Listing memory listing = getListing[listingId];

        if (listing.creator == address(0)) revert ListingNotFound();
        if (listing.askPrice != msg.value) revert WrongValueSent();

        delete getListing[listingId];

        emit ListingBought(msg.sender, listing);

        SafeTransferLib.safeTransferETH(listing.creator, listing.askPrice);
        listing.tokenContract.transferFrom(
            address(this),
            msg.sender,
            listing.tokenId
        );
    }
}
