// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.10;

import "./Hevm.sol";
import "ds-test/test.sol";
import "../LilFlashloan.sol";

contract User {}

contract TestToken is ERC20("Test Token", "TEST", 18) {
    function mintTo(address to, uint256 amount) public payable {
        _mint(to, amount);
    }
}

contract TestReceiver is FlashBorrower, DSTest {
    bytes32 internal testData;
    bool internal shouldRepay = true;
    bool internal shouldPayFees = true;

    function setTestData(bytes calldata data) public payable {
        testData = bytes32(data);
    }

    function setRepay(bool _shouldRepay) public payable {
        shouldRepay = _shouldRepay;
    }

    function setRespectFees(bool _shouldPayFees) public payable {
        shouldPayFees = _shouldPayFees;
    }

    function onFlashLoan(
        ERC20 token,
        uint256 amount,
        bytes calldata data
    ) external {
        assertEq(testData, bytes32(data));

        if (!shouldRepay) return;

        token.transfer(msg.sender, amount);

        if (!shouldPayFees) return;

        uint256 owedFees = LilFlashloan(msg.sender).getFee(token, amount);
        TestToken(address(token)).mintTo(msg.sender, owedFees);
    }
}

contract LilFlashloanTest is DSTest {
    User internal user;
    Hevm internal hevm;
    TestToken internal token;
    TestReceiver internal receiver;
    LilFlashloan internal lilFlashloan;

    event FeeUpdated(ERC20 indexed token, uint256 fee);
    event Withdrawn(ERC20 indexed token, uint256 amount);
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Flashloaned(
        FlashBorrower indexed receiver,
        ERC20 indexed token,
        uint256 amount
    );

    function setUp() public {
        user = new User();
        token = new TestToken();
        hevm = Hevm(HEVM_ADDRESS);
        receiver = new TestReceiver();
        lilFlashloan = new LilFlashloan();
    }

    function testCanFlashloan() public {
        token.mintTo(address(lilFlashloan), 100 ether);

        hevm.expectEmit(true, true, false, true);
        emit Flashloaned(receiver, token, 100 ether);
        hevm.expectEmit(true, true, false, true);
        emit Transfer(address(lilFlashloan), address(receiver), 100 ether);
        hevm.expectEmit(true, true, false, true);
        emit Transfer(address(receiver), address(lilFlashloan), 100 ether);

        lilFlashloan.execute(receiver, token, 100 ether, "");

        assertEq(token.balanceOf(address(lilFlashloan)), 100 ether);
    }

    function testDataIsForwarded() public {
        receiver.setTestData("forwarded data");
        token.mintTo(address(lilFlashloan), 100 ether);

        lilFlashloan.execute(receiver, token, 100 ether, "forwarded data");
    }

    function testCanFlashloanWithFees() public {
        token.mintTo(address(lilFlashloan), 100 ether);

        // set 10% fee for token
        lilFlashloan.setFees(token, 10_00);

        lilFlashloan.execute(receiver, token, 100 ether, "");

        assertEq(token.balanceOf(address(lilFlashloan)), 110 ether);
    }

    function testCannotFlasloanIfNotEnoughBalance() public {
        token.mintTo(address(lilFlashloan), 1 ether);

        hevm.expectRevert(stdError.arithmeticError); // error comes from ERC20 impl. (solmate in this test)
        lilFlashloan.execute(receiver, token, 2 ether, "");

        assertEq(token.balanceOf(address(lilFlashloan)), 1 ether);
    }

    function testFlashloanRevertsIfNotRepaid() public {
        receiver.setRepay(false);

        token.mintTo(address(lilFlashloan), 100 ether);

        hevm.expectRevert(abi.encodeWithSignature("TokensNotReturned()"));
        lilFlashloan.execute(receiver, token, 100 ether, "");

        assertEq(token.balanceOf(address(lilFlashloan)), 100 ether);
    }

    function testFlashloanRevertsIfNotFeesNotPaid() public {
        receiver.setRespectFees(false);

        // set 10% fee for token
        lilFlashloan.setFees(token, 10_00);

        token.mintTo(address(lilFlashloan), 100 ether);

        hevm.expectRevert(abi.encodeWithSignature("TokensNotReturned()"));
        lilFlashloan.execute(receiver, token, 100 ether, "");

        assertEq(token.balanceOf(address(lilFlashloan)), 100 ether);
    }

    function testManagerCanSetFees() public {
        assertEq(lilFlashloan.fees(token), 0);

        hevm.expectEmit(true, false, false, true);
        emit FeeUpdated(token, 10_00);

        // set 10% fee for token
        lilFlashloan.setFees(token, 10_00);

        assertEq(lilFlashloan.fees(token), 10_00);
    }

    function testCannotSetFeesHigherThan100Percent() public {
        assertEq(lilFlashloan.fees(token), 0);

        hevm.expectRevert(abi.encodeWithSignature("InvalidPercentage()"));
        lilFlashloan.setFees(token, 101_00);

        assertEq(lilFlashloan.fees(token), 0);
    }

    function testNonManagerCannotSetFees() public {
        assertEq(lilFlashloan.fees(token), 0);

        hevm.prank(address(user));
        hevm.expectRevert(abi.encodeWithSignature("Unauthorized()"));
        lilFlashloan.setFees(token, 10_00);

        assertEq(lilFlashloan.fees(token), 0);
    }

    function testManagerCanWithdrawTokens() public {
        token.mintTo(address(lilFlashloan), 10 ether);
        assertEq(token.balanceOf(address(this)), 0);

        hevm.expectEmit(true, false, false, true);
        emit Withdrawn(token, 10 ether);

        lilFlashloan.withdraw(token, 10 ether);

        assertEq(token.balanceOf(address(this)), 10 ether);
        assertEq(token.balanceOf(address(lilFlashloan)), 0);
    }

    function testNonManagerCannotWithdrawTokens() public {
        token.mintTo(address(lilFlashloan), 10 ether);
        assertEq(token.balanceOf(address(user)), 0);

        hevm.prank(address(user));
        hevm.expectRevert(abi.encodeWithSignature("Unauthorized()"));
        lilFlashloan.withdraw(token, 10 ether);

        assertEq(token.balanceOf(address(user)), 0);
        assertEq(token.balanceOf(address(lilFlashloan)), 10 ether);
    }
}
