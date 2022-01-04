# lil web3

> Small, focused, utility-based smart contracts.

lil web3 aims to build really simple, intentionally-limited versions of web3 protocols & apps. By distilling them to their roots, we can better understand how they work.

## lil ens

> A stupidly-simple namespace implementation.

lil ens contains a single function `register(string name)`, which allows an address to claim a name. \

The key learning here is that the technical implementation of a namespace can be incredibly simple, and it's adoption (both of users and apps integrating with it) what makes it successful.

If you're interested in a slightly more comprehensive ENS-like implementation, I also built a simplified version of the base ENS contracts (and tests for them) following the [ENS spec](https://eips.ethereum.org/EIPS/eip-137) as [a separate repo](https://github.com/m1guelpf/ens-contracts-blindrun).

[Contract Source](src/LilENS.sol) • [Contract Tests](src/tests/LilENS.t.sol)

## lil opensea

> Barebones NFT marketplace.

lil opensea has three functions, allowing users to list their NFTs for sale (`list(ERC721 tokenContract, uint256 tokenId, uint256 askPrice)`), buy an NFT that has been listed (`buyListing(uint256 listingId)`), or cancel a listing (`cancelListing(uint256 listingId)`). These functions emit events (`NewListing`, `ListingBought`, and `ListingRemoved`) that could be picked up by [a subgraph](https://thegraph.com/) in order to build a database of available listings to present in a UI.

> Note: Remember to call `setApprovalForAll(<lil opensea address>, true)` on the contract for the NFT you're listing before calling the `list` function 😉

[Contract Source](src/LilOpenSea.sol) • [Contract Tests](src/tests/LilOpenSea.t.sol)

## lil fractional

> Barebones NFT fractionalisation factory.

lil fractional contains a `split(ERC721 nftContract, uint256 tokenId, uint256 supply, string name, string symbol)` function you can call to fractionalise your NFT into any amount of `$SYMBOL` ERC20 tokens (leaving the sale/spread of these at the discretion of the caller), and a `join(uint256 vaultId)` that you can call if you own the entirety of the `$SYMBOL` supply to burn your tokens and get the NFT back.

> Note: Remember to call `setApprovalForAll(<lil fractional address>, true)` on the contract for the NFT you're fractionalising before calling the `split` function, and to call `approve(<lil fractional address>, <supply or greater>)` on the contract for the ERC20 before calling the `join` function 😉

[Contract Source](src/LilFractional.sol) • [Contract Tests](src/tests/LilFractional.t.sol)

## Contributing

Part of the motivation behind lil web3 is to get better at Solidity. For this reason, I won't be accepting PRs that add new lil contracts, as I'd rather implement them myself.

That doesn't mean contributions are welcome tho! If you find a bug, gas optimisation, or there's something you'd have written differently, a PR will be very appreciated. New ideas for protocols/apps you'd like to see me try to build are also very welcome!

## License

This project is open-sourced software licensed under the GNU Affero GPL v3.0 license. See the [License file](LICENSE) for more information.
