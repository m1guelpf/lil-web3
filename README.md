# lil web3

> Small, focused, utility-based smart contracts.

lil web3 aims to build really simple, intentionally-limited versions of web3 protocols & apps. By distilling them to their roots, we can better understand how they work.

## lil ens

> A stupidly-simple namespace implementation.

lil ens contains a single function `register(string name)`, which allows an address to claim a name. \

The key learning here is that the technical implementation of a namespace can be incredibly simple, and it's adoption (both of users and apps integrating with it) what makes it successful.

If you're interested in a slightly more comprehensive ENS-like implementation, I also built a simplified version of the base ENS contracts (and tests for them) following the [ENS spec](https://eips.ethereum.org/EIPS/eip-137) as [a separate repo](https://github.com/m1guelpf/ens-contracts-blindrun).

[Contract Source](src/LilENS.sol) • [Contract Tests](src/test/LilENS.t.sol)

## lil opensea

> Barebones NFT marketplace.

lil opensea has three functions, allowing users to list their NFTs for sale (`list(ERC721 tokenContract, uint256 tokenId, uint256 askPrice)`), buy an NFT that has been listed (`buyListing(uint256 listingId)`), or cancel a listing (`cancelListing(uint256 listingId)`). These functions emit events (`NewListing`, `ListingBought`, and `ListingRemoved`) that could be picked up by [a subgraph](https://thegraph.com/) in order to build a database of available listings to present in a UI.

> Note: Remember to call `setApprovalForAll(<lil opensea address>, true)` on the contract for the NFT you're listing before calling the `list` function 😉

[Contract Source](src/LilOpenSea.sol) • [Contract Tests](src/test/LilOpenSea.t.sol)

## lil fractional

> Barebones NFT fractionalisation factory.

lil fractional contains a `split(ERC721 nftContract, uint256 tokenId, uint256 supply, string name, string symbol)` function you can call to fractionalise your NFT into any amount of `$SYMBOL` ERC20 tokens (leaving the sale/spread of these at the discretion of the caller), and a `join(uint256 vaultId)` that you can call if you own the entirety of the `$SYMBOL` supply to burn your tokens and get the NFT back.

> Note: Remember to call `setApprovalForAll(<lil fractional address>, true)` on the contract for the NFT you're fractionalising before calling the `split` function, and to call `approve(<lil fractional address>, <supply or greater>)` on the contract for the ERC20 before calling the `join` function 😉

[Contract Source](src/LilFractional.sol) • [Contract Tests](src/test/LilFractional.t.sol)

## lil juicebox

> Very simple token sale + refund manager.

lil juicebox allows users to participate in a fundraising campaign by sending ETH via the `contribute()` function, in exchange for a proportional share of ERC20 tokens, until the owner decides to close the campaign (`setState(State.CLOSED)`) and withdraw the funds (calling `withdraw()`). If the owner decides to issue refunds (`setState(State.REFUNDING)`) they can send all the ETH back to the contract, where users can burn their ERC20 tokens to get back their ETH (using `refund(uint256 amount)`). Finally, the owner can renounce ownership of the campaign (making it impossible to change any of the aforementioned settings) by calling `renounce()`.

> Note: Remember to call `approve(<lil juicebox address>, <amount of tokens to refund>)` on the contract for the ERC20 before calling the `refund` function 😉

[Contract Source](src/LilJuicebox.sol) • [Contract Tests](src/test/LilJuicebox.t.sol)

## lil flashloan

> A (Proof of Concept)-level flash loan implementation

lil flashloan allows contract implementing the `onFlashLoan(ERC20 token, uint256 amount, bytes data)` to temporally receive any amount of ERC20 tokens (limited by the loaner's supply ofc), by calling the `execute(FlashBorrower receiver, ERC20 token, uint256 amount, bytes data)` function. This tokens should be repaid (along with any fees) before the end of the transaction to prevent it from reverting. The owner of the contract can set a fee percentage for any ERC20 by calling `setFees(ERC20 token, uint256 fee)` (`fee` is a percentage multiplied by 100 to avoid decimals, `10_00` would be 10% for example), and can withdraw the contract's balance by calling `withdraw(ERC20 token, uint256 amount)`.

> Note: In order to keep the contract simple, it's not compliant with [EIP-3156](https://eips.ethereum.org/EIPS/eip-3156) (the flash loan standard).

[Contract Source](src/LilFlashloan.sol) • [Contract Tests](src/test/LilFlashloan.t.sol)

## Contributing

Part of the motivation behind lil web3 is to get better at Solidity. For this reason, I won't be accepting PRs that add new lil contracts, as I'd rather implement them myself.

That doesn't mean contributions are welcome tho! If you find a bug, gas optimisation, or there's something you'd have written differently, a PR will be very appreciated. New ideas for protocols/apps you'd like to see me try to build are also very welcome!

## License

This project is open-sourced software licensed under the GNU Affero GPL v3.0 license. See the [License file](LICENSE) for more information.
