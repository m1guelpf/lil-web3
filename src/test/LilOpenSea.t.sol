// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.10;

import "./Hevm.sol";
import "ds-test/test.sol";
import "../LilOpenSea.sol";
import "solmate/tokens/ERC721.sol";

contract User {
    receive() external payable {}
}

contract TestNFT is ERC721("Test NFT", "TEST") {
    uint256 public tokenId = 1;

    function tokenURI(uint256) public pure override returns (string memory) {
        return "test";
    }

    function mint() public payable returns (uint256) {
        _mint(msg.sender, tokenId);

        return tokenId++;
    }
}

contract LilOpenSeaTest is DSTest {
    uint256 nftId;
    User internal user;
    Hevm internal hevm;
    TestNFT internal nft;
    LilOpenSea internal lilOpenSea;

    event NewListing(LilOpenSea.Listing listing);
    event ListingRemoved(LilOpenSea.Listing listing);
    event ListingBought(address indexed buyer, LilOpenSea.Listing listing);

    function setUp() public {
        user = new User();
        hevm = Hevm(HEVM_ADDRESS);
        nft = new TestNFT();
        lilOpenSea = new LilOpenSea();

        // Ensure marketplace can access tokens
        nft.setApprovalForAll(address(lilOpenSea), true);

        // Ensure marketplace can access user's tokens
        hevm.prank(address(user));
        nft.setApprovalForAll(address(lilOpenSea), true);

        nftId = nft.mint();
    }

    function testCanCreateSale() public {
        assertEq(nft.ownerOf(nftId), address(this));

        hevm.expectEmit(false, false, false, true);
        emit NewListing(
            LilOpenSea.Listing({
                tokenContract: nft,
                tokenId: nftId,
                askPrice: 1 ether,
                creator: address(this)
            })
        );
        uint256 listingId = lilOpenSea.list(nft, nftId, 1 ether);

        assertEq(nft.ownerOf(nftId), address(lilOpenSea));

        (
            ERC721 tokenContract,
            uint256 tokenId,
            address creator,
            uint256 askPrice
        ) = lilOpenSea.getListing(listingId);

        assertEq(address(tokenContract), address(nft));
        assertEq(tokenId, nftId);
        assertEq(creator, address(this));
        assertEq(askPrice, 1 ether);
    }

    function testNonOwnerCannotCreateSale() public {
        assertEq(nft.ownerOf(nftId), address(this));

        hevm.prank(address(user));
        hevm.expectRevert("WRONG_FROM"); // error comes from ERC721 impl. (solmate in this test)
        lilOpenSea.list(nft, nftId, 1 ether);

        assertEq(nft.ownerOf(nftId), address(this));
    }

    function testCannotListWhenTokenIsNotApproved() public {
        assertEq(nft.ownerOf(nftId), address(this));
        nft.setApprovalForAll(address(lilOpenSea), false);

        hevm.expectRevert("NOT_AUTHORIZED"); // error comes from ERC721 impl. (solmate in this test)
        lilOpenSea.list(nft, nftId, 1 ether);

        assertEq(nft.ownerOf(nftId), address(this));
    }

    function testCanCancelSale() public {
        uint256 listingId = lilOpenSea.list(nft, nftId, 1 ether);
        (, , address creator, ) = lilOpenSea.getListing(listingId);
        assertEq(creator, address(this));
        assertEq(nft.ownerOf(nftId), address(lilOpenSea));

        hevm.expectEmit(false, false, false, true);
        emit ListingRemoved(
            LilOpenSea.Listing({
                tokenContract: nft,
                tokenId: nftId,
                askPrice: 1 ether,
                creator: address(this)
            })
        );
        lilOpenSea.cancelListing(listingId);

        assertEq(nft.ownerOf(nftId), address(this));

        (, , address newCreator, ) = lilOpenSea.getListing(listingId);
        assertEq(newCreator, address(0));
    }

    function testNonOwnerCannotCancelSale() public {
        uint256 listingId = lilOpenSea.list(nft, nftId, 1 ether);
        (, , address creator, ) = lilOpenSea.getListing(listingId);
        assertEq(creator, address(this));
        assertEq(nft.ownerOf(nftId), address(lilOpenSea));

        hevm.prank(address(user));
        hevm.expectRevert(abi.encodeWithSignature("Unauthorized()"));
        lilOpenSea.cancelListing(listingId);

        assertEq(nft.ownerOf(nftId), address(lilOpenSea));

        (, , address newCreator, ) = lilOpenSea.getListing(listingId);
        assertEq(newCreator, address(this));
    }

    function testCannotBuyNotExistingValue() public {
        hevm.expectRevert(abi.encodeWithSignature("ListingNotFound()"));
        lilOpenSea.buyListing(1);
    }

    function testCannotBuyWithWrongValue() public {
        uint256 listingId = lilOpenSea.list(nft, nftId, 1 ether);

        hevm.expectRevert(abi.encodeWithSignature("WrongValueSent()"));
        lilOpenSea.buyListing{value: 0.1 ether}(listingId);

        assertEq(nft.ownerOf(nftId), address(lilOpenSea));
    }

    function testCanBuyListing() public {
        uint256 buyerBalance = address(this).balance;
        nft.transferFrom(address(this), address(user), nftId);

        hevm.prank(address(user));
        uint256 listingId = lilOpenSea.list(nft, nftId, 1 ether);

        assertEq(address(user).balance, 0);
        assertEq(nft.ownerOf(nftId), address(lilOpenSea));

        hevm.expectEmit(true, false, false, true);
        emit ListingBought(
            address(this),
            LilOpenSea.Listing({
                tokenContract: nft,
                tokenId: nftId,
                askPrice: 1 ether,
                creator: address(user)
            })
        );
        lilOpenSea.buyListing{value: 1 ether}(listingId);

        assertEq(nft.ownerOf(nftId), address(this));
        assertEq(address(user).balance, 1 ether);
        assertEq(address(this).balance, buyerBalance - 1 ether);

        (, , address creator, ) = lilOpenSea.getListing(listingId);
        assertEq(creator, address(0));
    }
}
