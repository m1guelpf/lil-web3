// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.10;

contract LilENS {
    error AlreadyRegistered();

    mapping(string => address) public lookup;

    function register(string memory name) public payable {
        if (lookup[name] != address(0)) revert AlreadyRegistered();

        lookup[name] = msg.sender;
    }
}
