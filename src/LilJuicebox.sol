// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.10;

import "solmate/tokens/ERC20.sol";
import "solmate/utils/SafeTransferLib.sol";

contract ProjectShare is ERC20 {
    error Unauthorized();

    address public immutable manager;

    constructor(string memory name, string memory symbol)
        payable
        ERC20(name, symbol, 18)
    {
        manager = msg.sender;
    }

    function mint(address to, uint256 amount) public payable {
        if (msg.sender != manager) revert Unauthorized();

        _mint(to, amount);
    }

    function burn(address from, uint256 amount) public payable {
        if (msg.sender != manager) revert Unauthorized();

        _burn(from, amount);
    }
}

contract LilJuicebox {
    error Unauthorized();
    error RefundsClosed();
    error ContributionsClosed();

    event Renounced();
    event Withdrawn(uint256 amount);
    event StateUpdated(State state);
    event Refunded(address indexed contributor, uint256 amount);
    event Contributed(address indexed contributor, uint256 amount);

    enum State {
        CLOSED,
        OPEN,
        REFUNDING
    }

    address public owner;
    State public getState;
    ProjectShare public immutable token;
    uint256 public constant TOKENS_PER_ETH = 1_000_000;

    constructor(string memory name, string memory symbol) payable {
        owner = msg.sender;
        getState = State.OPEN;
        token = new ProjectShare(name, symbol);
    }

    function contribute() public payable {
        if (getState != State.OPEN) revert ContributionsClosed();

        emit Contributed(msg.sender, msg.value);

        token.mint(msg.sender, msg.value * TOKENS_PER_ETH);
    }

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

    function withdraw() public payable {
        if (msg.sender != owner) revert Unauthorized();

        uint256 amount = address(this).balance;

        emit Withdrawn(amount);
        SafeTransferLib.safeTransferETH(msg.sender, amount);
    }

    function setState(State state) public payable {
        if (msg.sender != owner) revert Unauthorized();

        getState = state;
        emit StateUpdated(state);
    }

    function renounce() public payable {
        if (msg.sender != owner) revert Unauthorized();

        emit Renounced();
        owner = address(0);
    }

    receive() external payable {}
}
