// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.10;

import "ds-test/test.sol";
import "./Hevm.sol";
import "../LilFractional.sol";
import "solmate/tokens/ERC721.sol";

contract User {}

contract TestNFT is ERC721("Test NFT", "TEST") {
    uint256 public tokenId = 1;

    function tokenURI(uint256) public pure override returns (string memory) {
        return "test";
    }

    function mint() public returns (uint256) {
        _mint(msg.sender, tokenId);

        return tokenId++;
    }
}

contract LilOpenSeaTest is DSTest {
    uint256 nftId;
    User internal user;
    Hevm internal hevm;
    TestNFT internal nft;
    LilFractional internal lilFractional;

    event VaultCreated(LilFractional.Vault vault);
    event VaultDestroyed(LilFractional.Vault vault);
    event Transfer(address indexed from, address indexed to, uint256 amount);

    function setUp() public {
        user = new User();
        hevm = Hevm(HEVM_ADDRESS);
        nft = new TestNFT();
        lilFractional = new LilFractional();

        // Ensure contract can access tokens
        nft.setApprovalForAll(address(lilFractional), true);

        // Ensure contract can access user's tokens
        hevm.prank(address(user));
        nft.setApprovalForAll(address(lilFractional), true);

        nftId = nft.mint();
    }

    function testCanSplitToken() public {
        assertEq(nft.ownerOf(nftId), address(this));

        hevm.expectEmit(true, true, false, true);
        emit Transfer(address(0), address(this), 100 ether);

        uint256 vaultId = lilFractional.split(
            nft,
            nftId,
            100 ether,
            "Fractionalised NFT",
            "FRAC"
        );

        (
            ERC721 nftContract,
            uint256 tokenId,
            uint256 supply,
            NFTShare tokenContract
        ) = lilFractional.getVault(vaultId);

        assertEq(nft.ownerOf(nftId), address(lilFractional));
        assertEq(address(nftContract), address(nft));
        assertEq(tokenId, nftId);
        assertEq(supply, 100 ether);
        assertEq(tokenContract.balanceOf(address(this)), 100 ether);
    }

    function testNonOwnerCannotSplitToken() public {
        assertEq(nft.ownerOf(nftId), address(this));

        hevm.prank(address(user));
        hevm.expectRevert("WRONG_FROM"); // error comes from ERC721 impl. (solmate in this test)
        lilFractional.split(
            nft,
            nftId,
            100 ether,
            "Fractionalised NFT",
            "FRAC"
        );

        assertEq(nft.ownerOf(nftId), address(this));
    }

    function testTotalSupplyOwnerCanJoinToken() public {
        uint256 vaultId = lilFractional.split(
            nft,
            nftId,
            100 ether,
            "Fractionalised NFT",
            "FRAC"
        );

        (, , , NFTShare tokenContract) = lilFractional.getVault(vaultId);

        assertEq(nft.ownerOf(nftId), address(lilFractional));
        assertEq(tokenContract.balanceOf(address(this)), 100 ether);

        tokenContract.approve(address(lilFractional), type(uint256).max);

        lilFractional.join(vaultId);

        assertEq(nft.ownerOf(nftId), address(this));
        assertEq(tokenContract.balanceOf(address(this)), 0);

        (, uint256 tokenId, , ) = lilFractional.getVault(vaultId);
        assertEq(tokenId, 0);
    }

    function testCannotJoinNonExistingToken() public {
        hevm.expectRevert(abi.encodeWithSignature("VaultNotFound()"));

        lilFractional.join(1);
    }

    function testPartialHolderCannotJoinToken() public {
        uint256 vaultId = lilFractional.split(
            nft,
            nftId,
            100 ether,
            "Fractionalised NFT",
            "FRAC"
        );

        (, , , NFTShare tokenContract) = lilFractional.getVault(vaultId);

        assertEq(nft.ownerOf(nftId), address(lilFractional));
        assertEq(tokenContract.balanceOf(address(this)), 100 ether);

        tokenContract.transfer(address(user), 100 ether - 1);

        hevm.startPrank(address(user));
        tokenContract.approve(address(lilFractional), type(uint256).max);

        hevm.expectRevert(stdError.arithmeticError); // error might vary depending on the ERC20 impl. (this one comes from solmate)
        lilFractional.join(vaultId);

        assertEq(nft.ownerOf(nftId), address(lilFractional));
        assertEq(tokenContract.balanceOf(address(user)), 100 ether - 1);
    }

    function testNonHolderCannotJoinToken() public {
        uint256 vaultId = lilFractional.split(
            nft,
            nftId,
            100 ether,
            "Fractionalised NFT",
            "FRAC"
        );

        (, , , NFTShare tokenContract) = lilFractional.getVault(vaultId);

        assertEq(nft.ownerOf(nftId), address(lilFractional));
        assertEq(tokenContract.balanceOf(address(this)), 100 ether);

        hevm.startPrank(address(user));
        tokenContract.approve(address(lilFractional), type(uint256).max);

        hevm.expectRevert(stdError.arithmeticError); // error might vary depending on the ERC20 impl. (this one comes from solmate)
        lilFractional.join(vaultId);

        assertEq(nft.ownerOf(nftId), address(lilFractional));
        assertEq(tokenContract.balanceOf(address(this)), 100 ether);
    }
}
