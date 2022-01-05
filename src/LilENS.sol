// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.10;

/// @title lil ens
/// @author Miguel Piedrafita
/// @notice A stupidly-simple namespace implementation.
contract LilENS {
    /// ERRORS ///

    /// @notice Thrown when trying to update a name you don't own
    error Unauthorized();

    /// @notice Thrown when trying to register a name that's already taken
    error AlreadyRegistered();

    /// @notice Stores the registered names and their addresses
    /// @dev This automatically generates a getter for us!
    mapping(string => address) public lookup;

    /// @notice Registers a new name, and points it to your address
    /// @param name The name to register
    function register(string memory name) public payable {
        if (lookup[name] != address(0)) revert AlreadyRegistered();

        lookup[name] = msg.sender;
    }

    /// @notice Allows the owner of a name to point it to a different address
    /// @param name The name to update
    /// @param addr The new address this name should point to
    function update(string memory name, address addr) public payable {
        if (msg.sender != lookup[name]) revert Unauthorized();

        lookup[name] = addr;
    }
}
