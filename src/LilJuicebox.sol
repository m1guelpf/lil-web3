// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.10;

import "solmate/tokens/ERC20.sol";
import "solmate/utils/SafeTransferLib.sol";

/// @title Project Share ERC20
/// @author Miguel Piedrafita
/// @notice ERC20 token representing a share on LilJuicebox
contract ProjectShare is ERC20 {
    /// ERRORS ///

    /// @notice Thrown when trying to directly call the mint or burn functions
    error Unauthorized();

    /// @notice The manager of this campaign
    address public immutable manager;

    /// @notice Deploys a ProjectShare instance with the specified name and symbol
    /// @param name The name of the deployed token
    /// @param symbol The symbol of the deployed token
    /// @dev Deployed from the constructor of the LilJuicebox contract
    constructor(string memory name, string memory symbol)
        payable
        ERC20(name, symbol, 18)
    {
        manager = msg.sender;
    }

    /// @notice Grants the specified address a specified amount of tokens
    /// @param to The address that will receive the tokens
    /// @param amount the amount of tokens to receive
    /// @dev This function should be called from within LilJuicebox, and will revert if manually accessed
    function mint(address to, uint256 amount) public payable {
        if (msg.sender != manager) revert Unauthorized();

        _mint(to, amount);
    }

    /// @notice Burns a specified amount of tokens from a specified address' balance
    /// @param from The address that will get their tokens burned
    /// @param amount the amount of tokens to burn
    /// @dev This function should be called from within LilJuicebox, and will revert if manually accessed
    function burn(address from, uint256 amount) public payable {
        if (msg.sender != manager) revert Unauthorized();

        _burn(from, amount);
    }
}

/// @title lil juicebox
/// @author Miguel Piedrafita
/// @notice Very simple token sale + refund manager.
contract LilJuicebox {
    /// ERRORS ///

    /// @notice Thrown when trying to change the state of the campaign or renounce the contract without being the manager
    error Unauthorized();

    /// @notice Thrown when trying to claim a refund while refunds are closed
    error RefundsClosed();

    /// @notice Thrown when trying to contribute while contributions are closed
    error ContributionsClosed();

    /// EVENTS ///

    /// @notice Emitted when the manager renounces the contract, locking its current state forever
    event Renounced();

    /// @notice Emitted when the manager withdrawns a share of the raised funds
    /// @param amount The amount of ETH withdrawn
    event Withdrawn(uint256 amount);

    /// @notice Emitted when the state of the campaign is changed
    /// @param state The new state of the campaign
    event StateUpdated(State state);

    /// @notice Emitted when a contributor successfully claims a refund
    /// @param contributor The address of the contributor
    /// @param amount The amount of ETH refunded
    event Refunded(address indexed contributor, uint256 amount);

    /// @notice Emitted when a user contributes to the campaign
    /// @param contributor The address of the contributor
    /// @param amount The amount of ETH contributed
    event Contributed(address indexed contributor, uint256 amount);

    /// @notice Possible states of a campagin
    enum State {
        CLOSED,
        OPEN,
        REFUNDING
    }

    /// @notice The address of the user who can withdraw funds and change the state of the campaign
    address public manager;

    /// @notice The current state of the campaign
    /// @dev This automatically generates a getter for us!
    State public getState;

    /// @notice The address of the ERC20 token representing shares of this campaign
    ProjectShare public immutable token;

    /// @notice The amount of ERC20 tokens to issue per ETH received
    uint256 public constant TOKENS_PER_ETH = 1_000_000;

    /// @notice Deploys a LilJuicebox instance with the specified name and symbol
    /// @param name The name of the ERC20 token
    /// @param symbol The symbol of the ERC20 token
    constructor(string memory name, string memory symbol) payable {
        manager = msg.sender;
        getState = State.OPEN;
        token = new ProjectShare(name, symbol);
    }

    /// @notice Contribute to the campaign by sending ETH, if contributions are open
    function contribute() public payable {
        if (getState != State.OPEN) revert ContributionsClosed();

        emit Contributed(msg.sender, msg.value);

        token.mint(msg.sender, msg.value * TOKENS_PER_ETH);
    }

    /// @notice Receive a refund for your contribution to the campaign, if refunds are open
    function refund(uint256 amount) public payable {
        if (getState != State.REFUNDING) revert RefundsClosed();

        uint256 refundETH;
        assembly {
            refundETH := div(amount, TOKENS_PER_ETH)
        }

        token.burn(msg.sender, amount);
        emit Refunded(msg.sender, refundETH);

        SafeTransferLib.safeTransferETH(msg.sender, refundETH);
    }

    /// @notice Withdraw a share of the raised funds, only available to the manager of the campaign
    function withdraw() public payable {
        if (msg.sender != manager) revert Unauthorized();

        uint256 amount = address(this).balance;

        emit Withdrawn(amount);
        SafeTransferLib.safeTransferETH(msg.sender, amount);
    }

    /// @notice Update the state of the campaign, only available to the manager of the campaign
    /// @param state The new state of the campaign
    function setState(State state) public payable {
        if (msg.sender != manager) revert Unauthorized();

        getState = state;
        emit StateUpdated(state);
    }

    /// @notice Renounce ownership of the campaign, effectively locking all settings in place. Only available to the manager of the campaign
    function renounce() public payable {
        if (msg.sender != manager) revert Unauthorized();

        emit Renounced();
        manager = address(0);
    }

    /// @dev This function ensures this contract can receive ETH
    receive() external payable {}
}
