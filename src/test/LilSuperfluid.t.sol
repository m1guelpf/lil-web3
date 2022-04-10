// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.10;

import { Vm } from 'forge-std/Vm.sol';
import { DSTest } from 'ds-test/test.sol';
import { ERC20 } from 'solmate/tokens/ERC20.sol';
import { LilSuperfluid } from '../LilSuperfluid.sol';

contract TestToken is ERC20('Test Token', 'TKN', 18) {
	function mintTo(address recipient, uint256 amount) public payable {
		_mint(recipient, amount);
	}
}

contract User {}

contract LilSuperfluidTest is DSTest {
	User internal user;
	uint256 internal privKey;
	TestToken internal token;
	Vm internal hevm = Vm(HEVM_ADDRESS);
	LilSuperfluid internal lilSuperfluid;

	event StreamCreated(LilSuperfluid.Stream stream);
	event StreamRefueled(uint256 indexed streamId, uint256 amount);
	event FundsWithdrawn(uint256 indexed streamId, uint256 amount);
	event ExcessWithdrawn(uint256 indexed streamId, uint256 amount);
	event StreamDetailsUpdated(
		uint256 indexed streamId,
		uint256 paymentPerBlock,
		LilSuperfluid.Timeframe timeframe
	);

	function setUp() public {
		privKey = 0xa;
		token = new TestToken();
		user = User(hevm.addr(privKey));
		lilSuperfluid = new LilSuperfluid();

		token.mintTo(address(this), 1 ether);
		token.approve(address(lilSuperfluid), type(uint256).max);
	}

	function testCanCreateStream() public {
		assertEq(token.balanceOf(address(this)), 1 ether);
		assertEq(token.balanceOf(address(lilSuperfluid)), 0);

		LilSuperfluid.Timeframe memory timeframe = LilSuperfluid.Timeframe({
			startBlock: block.number,
			stopBlock: block.number + 10
		});

		hevm.expectEmit(false, false, false, true);
		emit StreamCreated(
			LilSuperfluid.Stream({
				sender: address(this),
				recipient: address(user),
				token: token,
				balance: 1 ether,
				withdrawnBalance: 0,
				paymentPerBlock: 0.1 ether,
				timeframe: timeframe
			})
		);

		uint256 streamId = lilSuperfluid.streamTo(
			address(user),
			token,
			1 ether,
			timeframe,
			0.1 ether
		);

		assertEq(streamId, 1);
		assertEq(token.balanceOf(address(this)), 0);
		assertEq(token.balanceOf(address(lilSuperfluid)), 1 ether);

		(
			address sender,
			address recipient,
			ERC20 streamToken,
			uint256 balance,
			uint256 withdrawnBalance,
			uint256 paymentPerBlock,
			LilSuperfluid.Timeframe memory streamTimeframe
		) = lilSuperfluid.getStream(streamId);

		assertEq(sender, address(this));
		assertEq(recipient, address(user));
		assertEq(address(streamToken), address(token));
		assertEq(balance, 1 ether);
		assertEq(withdrawnBalance, 0);
		assertEq(paymentPerBlock, 0.1 ether);
		assertEq(streamTimeframe.startBlock, timeframe.startBlock);
		assertEq(streamTimeframe.stopBlock, timeframe.stopBlock);
	}

	function testCanRefuelStream() public {
		uint256 streamId = lilSuperfluid.streamTo(
			address(user),
			token,
			0.05 ether,
			LilSuperfluid.Timeframe({ startBlock: block.number, stopBlock: block.number + 10 }),
			0.1 ether
		);

		(, , , uint256 initialBalance, , , ) = lilSuperfluid.getStream(streamId);

		assertEq(initialBalance, 0.05 ether);

		hevm.expectEmit(true, false, false, true);
		emit StreamRefueled(streamId, 0.05 ether);
		lilSuperfluid.refuel(streamId, 0.05 ether);

		(, , , uint256 newBalance, , , ) = lilSuperfluid.getStream(streamId);

		assertEq(newBalance, 0.1 ether);
	}

	function testNonSenderCannotRefuelStream() public {
		uint256 streamId = lilSuperfluid.streamTo(
			address(user),
			token,
			0.05 ether,
			LilSuperfluid.Timeframe({ startBlock: block.number, stopBlock: block.number + 10 }),
			0.1 ether
		);

		(, , , uint256 initialBalance, , , ) = lilSuperfluid.getStream(streamId);

		assertEq(initialBalance, 0.05 ether);

		hevm.prank(address(user));
		hevm.expectRevert(abi.encodeWithSignature('Unauthorized()'));
		lilSuperfluid.refuel(streamId, 0.05 ether);

		(, , , uint256 newBalance, , , ) = lilSuperfluid.getStream(streamId);

		assertEq(newBalance, 0.05 ether);
	}

	function testCannotRefuelANonExistantStream() public {
		hevm.expectRevert(abi.encodeWithSignature('Unauthorized()'));
		lilSuperfluid.refuel(1, 0 ether);
	}

	function testBalanceCalculationAndWithdrawals() public {
		uint256 streamId = lilSuperfluid.streamTo(
			address(user),
			token,
			1 ether,
			LilSuperfluid.Timeframe({ startBlock: block.number, stopBlock: block.number + 10 }),
			0.1 ether
		);

		assertEq(token.balanceOf(address(lilSuperfluid)), 1 ether);
		assertEq(lilSuperfluid.balanceOf(streamId, address(user)), 0);
		assertEq(lilSuperfluid.balanceOf(streamId, address(this)), 1 ether);

		hevm.roll(block.number + 1);

		assertEq(lilSuperfluid.balanceOf(streamId, address(this)), 0.9 ether);
		assertEq(lilSuperfluid.balanceOf(streamId, address(user)), 0.1 ether);

		hevm.roll(block.number + 4);

		assertEq(lilSuperfluid.balanceOf(streamId, address(this)), 0.5 ether);
		assertEq(lilSuperfluid.balanceOf(streamId, address(user)), 0.5 ether);

		hevm.prank(address(user));
		hevm.expectEmit(true, false, false, true);
		emit FundsWithdrawn(streamId, 0.5 ether);
		lilSuperfluid.withdraw(streamId);

		assertEq(token.balanceOf(address(user)), 0.5 ether);
		assertEq(token.balanceOf(address(lilSuperfluid)), 0.5 ether);
		assertEq(lilSuperfluid.balanceOf(streamId, address(this)), 0.5 ether);
		assertEq(lilSuperfluid.balanceOf(streamId, address(user)), 0 ether);

		hevm.roll(block.number + 4);

		assertEq(lilSuperfluid.balanceOf(streamId, address(this)), 0.1 ether);
		assertEq(lilSuperfluid.balanceOf(streamId, address(user)), 0.4 ether);

		hevm.roll(block.number + 1);

		assertEq(lilSuperfluid.balanceOf(streamId, address(this)), 0 ether);
		assertEq(lilSuperfluid.balanceOf(streamId, address(user)), 0.5 ether);

		hevm.prank(address(user));
		hevm.expectEmit(true, false, false, true);
		emit FundsWithdrawn(streamId, 0.5 ether);
		lilSuperfluid.withdraw(streamId);

		assertEq(token.balanceOf(address(lilSuperfluid)), 0 ether);
		assertEq(token.balanceOf(address(user)), 1 ether);
	}

	function testNonRecipiantCannotWithdraw() public {
		uint256 streamId = lilSuperfluid.streamTo(
			address(user),
			token,
			1 ether,
			LilSuperfluid.Timeframe({ startBlock: block.number, stopBlock: block.number + 10 }),
			0.1 ether
		);

		assertEq(token.balanceOf(address(lilSuperfluid)), 1 ether);
		assertEq(lilSuperfluid.balanceOf(streamId, address(user)), 0);
		assertEq(lilSuperfluid.balanceOf(streamId, address(this)), 1 ether);

		hevm.expectRevert(abi.encodeWithSignature('Unauthorized()'));
		lilSuperfluid.withdraw(streamId);

		assertEq(token.balanceOf(address(lilSuperfluid)), 1 ether);
		assertEq(lilSuperfluid.balanceOf(streamId, address(user)), 0);
		assertEq(lilSuperfluid.balanceOf(streamId, address(this)), 1 ether);
	}

	function testSenderCanWithdrawExcess() public {
		token.mintTo(address(this), 2 ether);

		uint256 streamId = lilSuperfluid.streamTo(
			address(user),
			token,
			2 ether,
			LilSuperfluid.Timeframe({ startBlock: block.number, stopBlock: block.number + 10 }),
			0.1 ether
		);

		hevm.roll(block.number + 5);

		hevm.expectRevert(abi.encodeWithSignature('StreamStillActive()'));
		lilSuperfluid.refund(streamId);

		hevm.roll(block.number + 5);

		assertEq(token.balanceOf(address(lilSuperfluid)), 2 ether);
		assertEq(lilSuperfluid.balanceOf(streamId, address(user)), 1 ether);
		assertEq(lilSuperfluid.balanceOf(streamId, address(this)), 1 ether);

		hevm.prank(address(user));
		lilSuperfluid.withdraw(streamId);

		assertEq(token.balanceOf(address(lilSuperfluid)), 1 ether);
		assertEq(lilSuperfluid.balanceOf(streamId, address(user)), 0 ether);
		assertEq(lilSuperfluid.balanceOf(streamId, address(this)), 1 ether);

		hevm.expectEmit(true, false, false, true);
		emit ExcessWithdrawn(streamId, 1 ether);
		lilSuperfluid.refund(streamId);

		assertEq(token.balanceOf(address(lilSuperfluid)), 0 ether);
		assertEq(lilSuperfluid.balanceOf(streamId, address(user)), 0 ether);
		assertEq(lilSuperfluid.balanceOf(streamId, address(this)), 0 ether);
	}

	function testNonSenderCannotWithdrawExcess() public {
		token.mintTo(address(this), 2 ether);

		uint256 streamId = lilSuperfluid.streamTo(
			address(user),
			token,
			2 ether,
			LilSuperfluid.Timeframe({ startBlock: block.number, stopBlock: block.number + 10 }),
			0.1 ether
		);

		hevm.roll(block.number + 10);

		hevm.prank(address(user));
		hevm.expectRevert(abi.encodeWithSignature('Unauthorized()'));
		lilSuperfluid.refund(streamId);
	}

	function testCanUpdateStreamDetails() public {
		uint256 streamId = lilSuperfluid.streamTo(
			address(user),
			token,
			1 ether,
			LilSuperfluid.Timeframe({ startBlock: block.number, stopBlock: block.number + 10 }),
			0.1 ether
		);

		(
			,
			,
			,
			,
			,
			uint256 initPaymentRate,
			LilSuperfluid.Timeframe memory initTimeframe
		) = lilSuperfluid.getStream(streamId);

		assertEq(initPaymentRate, 0.1 ether);
		assertEq(initTimeframe.startBlock, block.number);
		assertEq(initTimeframe.stopBlock, block.number + 10);

		LilSuperfluid.Timeframe memory timeframe = LilSuperfluid.Timeframe({
			startBlock: block.number + 5,
			stopBlock: block.number + 10
		});

		(uint8 v, bytes32 r, bytes32 s) = hevm.sign(
			privKey,
			keccak256(
				abi.encodePacked(
					'\x19\x01',
					lilSuperfluid.domainSeparator(),
					keccak256(
						abi.encode(
							lilSuperfluid.UPDATE_DETAILS_HASH(),
							streamId,
							0.5 ether,
							timeframe.startBlock,
							timeframe.stopBlock,
							lilSuperfluid.nonce()
						)
					)
				)
			)
		);

		LilSuperfluid.Signature memory sig = LilSuperfluid.Signature({ v: v, r: r, s: s });

		hevm.expectEmit(true, false, false, true);
		emit StreamDetailsUpdated(streamId, 0.5 ether, timeframe);
		lilSuperfluid.updateDetails(streamId, 0.5 ether, timeframe, sig);

		(
			,
			,
			,
			,
			,
			uint256 newPaymentRate,
			LilSuperfluid.Timeframe memory newTimeframe
		) = lilSuperfluid.getStream(streamId);

		assertEq(newPaymentRate, 0.5 ether);
		assertEq(newTimeframe.startBlock, timeframe.startBlock);
		assertEq(newTimeframe.stopBlock, timeframe.stopBlock);
	}

	function testCantUpdateStreamDetailsWithInvalidSignature() public {
		uint256 streamId = lilSuperfluid.streamTo(
			address(user),
			token,
			1 ether,
			LilSuperfluid.Timeframe({ startBlock: block.number, stopBlock: block.number + 10 }),
			0.1 ether
		);

		(
			,
			,
			,
			,
			,
			uint256 initPaymentRate,
			LilSuperfluid.Timeframe memory initTimeframe
		) = lilSuperfluid.getStream(streamId);

		assertEq(initPaymentRate, 0.1 ether);
		assertEq(initTimeframe.startBlock, block.number);
		assertEq(initTimeframe.stopBlock, block.number + 10);

		LilSuperfluid.Timeframe memory timeframe = LilSuperfluid.Timeframe({
			startBlock: block.number + 5,
			stopBlock: block.number + 10
		});

		(uint8 v, bytes32 r, bytes32 s) = hevm.sign(
			privKey,
			keccak256(
				abi.encodePacked(
					'\x19\x01',
					lilSuperfluid.domainSeparator(),
					keccak256(
						abi.encode(
							lilSuperfluid.UPDATE_DETAILS_HASH(),
							streamId,
							0.2 ether,
							timeframe.startBlock,
							timeframe.stopBlock,
							lilSuperfluid.nonce()
						)
					)
				)
			)
		);

		LilSuperfluid.Signature memory sig = LilSuperfluid.Signature({ v: v, r: r, s: s });

		hevm.expectRevert(abi.encodeWithSignature('Unauthorized()'));
		lilSuperfluid.updateDetails(streamId, 0.5 ether, timeframe, sig);

		(
			,
			,
			,
			,
			,
			uint256 newPaymentRate,
			LilSuperfluid.Timeframe memory newTimeframe
		) = lilSuperfluid.getStream(streamId);

		assertEq(newPaymentRate, 0.1 ether);
		assertEq(newTimeframe.startBlock, block.number);
		assertEq(newTimeframe.stopBlock, block.number + 10);
	}
}
