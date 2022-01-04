// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.10;

import "solmate/tokens/ERC20.sol";
import "solmate/tokens/ERC721.sol";

contract NFTShare is ERC20 {
    constructor(
        string memory name,
        string memory symbol,
        uint256 mintSupply,
        address mintTo
    ) payable ERC20(name, symbol, 18) {
        _mint(mintTo, mintSupply);
    }

    function burnFrom(address from, uint256 amount) public payable {
        uint256 allowed = allowance[from][msg.sender]; // Saves gas for limited approvals.

        if (allowed != type(uint256).max)
            allowance[from][msg.sender] = allowed - amount;

        _burn(from, amount);
    }
}

contract LilFractional {
    error VaultNotFound();

    struct Vault {
        ERC721 nftContract;
        uint256 tokenId;
        uint256 tokenSupply;
        NFTShare tokenContract;
    }

    event VaultCreated(Vault vault);
    event VaultDestroyed(Vault vault);

    uint256 internal vaultId = 1;

    mapping(uint256 => Vault) public getVault;

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

    function join(uint256 vaultId) public payable {
        Vault memory vault = getVault[vaultId];

        if (vault.tokenContract == NFTShare(address(0))) revert VaultNotFound();

        delete getVault[vaultId];

        vault.tokenContract.burnFrom(msg.sender, vault.tokenSupply);
        vault.nftContract.transferFrom(
            address(this),
            msg.sender,
            vault.tokenId
        );
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) public payable returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
