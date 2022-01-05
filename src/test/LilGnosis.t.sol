// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.10;

import "./Hevm.sol";
import "../LilGnosis.sol";
import "ds-test/test.sol";

contract User {}

contract CallTestUtils is DSTest {
    uint256 internal expectedValue;
    bytes internal expectedData;
    bool internal willRevert;

    function expectValue(uint256 _expectedValue) public payable {
        expectedValue = _expectedValue;
    }

    function expectData(bytes calldata _expectedData) public payable {
        expectedData = _expectedData;
    }

    function shouldRevert(bool _willRevert) public payable {
        willRevert = _willRevert;
    }

    fallback() external payable {
        assertEq(msg.value, expectedValue);
        assertEq(bytes32(msg.data), bytes32(expectedData));

        require(!willRevert, "forced revert");
    }
}

abstract contract SigUtils {
    Hevm internal hevm;
    LilGnosis internal lilGnosis;

    function signExecution(
        uint256 signer,
        address target,
        uint256 value,
        bytes memory payload
    ) internal returns (LilGnosis.Signature memory) {
        (uint8 v, bytes32 r, bytes32 s) = hevm.sign(
            signer,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    lilGnosis.domainSeparator(),
                    keccak256(
                        abi.encode(
                            lilGnosis.EXECUTE_HASH(),
                            target,
                            value,
                            payload,
                            lilGnosis.nonce()
                        )
                    )
                )
            )
        );

        return LilGnosis.Signature({v: v, r: r, s: s});
    }

    function signQuorum(uint256 signer, uint256 quorum)
        internal
        returns (LilGnosis.Signature memory)
    {
        (uint8 v, bytes32 r, bytes32 s) = hevm.sign(
            signer,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    lilGnosis.domainSeparator(),
                    keccak256(
                        abi.encode(
                            lilGnosis.QUORUM_HASH(),
                            quorum,
                            lilGnosis.nonce()
                        )
                    )
                )
            )
        );

        return LilGnosis.Signature({v: v, r: r, s: s});
    }

    function signSignerUpdate(
        uint256 signer,
        address addr,
        bool shouldTrust
    ) internal returns (LilGnosis.Signature memory) {
        (uint8 v, bytes32 r, bytes32 s) = hevm.sign(
            signer,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    lilGnosis.domainSeparator(),
                    keccak256(
                        abi.encode(
                            lilGnosis.SIGNER_HASH(),
                            addr,
                            shouldTrust,
                            lilGnosis.nonce()
                        )
                    )
                )
            )
        );

        return LilGnosis.Signature({v: v, r: r, s: s});
    }
}

contract LilGnosisTest is DSTest, SigUtils {
    User internal user;
    CallTestUtils internal target;

    // @Note: This list of keys has been chosen specifically because their corresponding addresses are in ascending order
    uint256[] internal privKeys = [
        0xBEEF,
        0xBEEE,
        0x1234,
        0x3221,
        0x0010,
        0x0100,
        0x0323
    ];
    address[] internal signers = new address[](privKeys.length);

    event QuorumUpdated(uint256 newQuorum);
    event Executed(address target, uint256 value, bytes payload);
    event SignerUpdated(address indexed signer, bool shouldTrust);

    function setUp() public {
        user = new User();
        hevm = Hevm(HEVM_ADDRESS);
        target = new CallTestUtils();

        // Get addresses from the private keys above
        for (uint256 i = 0; i < privKeys.length; i++) {
            signers[i] = hevm.addr(privKeys[i]);
        }
    }

    function testCanExecute() public {
        lilGnosis = new LilGnosis("Test Multisig", signers, privKeys.length);

        LilGnosis.Signature[] memory signatures = new LilGnosis.Signature[](
            privKeys.length
        );
        for (uint256 i = 0; i < privKeys.length; i++) {
            signatures[i] = signExecution(privKeys[i], address(target), 0, "");
        }

        hevm.expectEmit(false, false, false, true);
        emit Executed(address(target), 0, "");

        lilGnosis.execute(address(target), 0, "", signatures);
    }

    function testCanExecuteWithValue() public {
        lilGnosis = new LilGnosis("Test Multisig", signers, privKeys.length);
        hevm.deal(address(lilGnosis), 10 ether);

        target.expectValue(1 ether);

        LilGnosis.Signature[] memory signatures = new LilGnosis.Signature[](
            privKeys.length
        );
        for (uint256 i = 0; i < privKeys.length; i++) {
            signatures[i] = signExecution(
                privKeys[i],
                address(target),
                1 ether,
                ""
            );
        }

        hevm.expectEmit(false, false, false, true);
        emit Executed(address(target), 1 ether, "");

        lilGnosis.execute(address(target), 1 ether, "", signatures);

        assertEq(address(target).balance, 1 ether);
        assertEq(address(lilGnosis).balance, 9 ether);
    }

    function testCanExecuteWithData() public {
        lilGnosis = new LilGnosis("Test Multisig", signers, privKeys.length);
        hevm.deal(address(lilGnosis), 10 ether);

        target.expectData("test");

        LilGnosis.Signature[] memory signatures = new LilGnosis.Signature[](
            privKeys.length
        );
        for (uint256 i = 0; i < privKeys.length; i++) {
            signatures[i] = signExecution(
                privKeys[i],
                address(target),
                0,
                "test"
            );
        }

        hevm.expectEmit(false, false, false, true);
        emit Executed(address(target), 0, "test");

        lilGnosis.execute(address(target), 0, "test", signatures);
    }

    function testCannotExecuteWithoutEnoughSignatures() public {
        lilGnosis = new LilGnosis(
            "Test Multisig",
            signers,
            privKeys.length + 1
        );

        LilGnosis.Signature[] memory signatures = new LilGnosis.Signature[](
            privKeys.length
        );
        for (uint256 i = 0; i < privKeys.length; i++) {
            signatures[i] = signExecution(privKeys[i], address(target), 0, "");
        }

        hevm.expectRevert(stdError.indexOOBError);
        lilGnosis.execute(address(target), 0, "", signatures);
    }

    function testCannotExecuteWithInvalidSignatures() public {
        lilGnosis = new LilGnosis("Test Multisig", signers, privKeys.length);

        LilGnosis.Signature[] memory signatures = new LilGnosis.Signature[](
            privKeys.length
        );
        for (uint256 i = 0; i < privKeys.length; i++) {
            signatures[i] = signExecution(privKeys[i], address(target), 1, "");
        }

        hevm.expectRevert(abi.encodeWithSignature("InvalidSignatures()"));
        lilGnosis.execute(address(target), 0, "", signatures);
    }

    function testCannotExecuteWithDuplicatedSignatures() public {
        lilGnosis = new LilGnosis("Test Multisig", signers, privKeys.length);

        LilGnosis.Signature[] memory signatures = new LilGnosis.Signature[](
            privKeys.length
        );
        for (uint256 i = 0; i < privKeys.length; i++) {
            signatures[i] = signExecution(privKeys[i], address(target), 0, "");
        }

        signatures[0] = signatures[1];

        hevm.expectRevert(abi.encodeWithSignature("InvalidSignatures()"));
        lilGnosis.execute(address(target), 0, "", signatures);
    }

    function testCannotExecuteWithUntrustedSignatures() public {
        lilGnosis = new LilGnosis("Test Multisig", signers, privKeys.length);

        LilGnosis.Signature[] memory signatures = new LilGnosis.Signature[](
            privKeys.length
        );
        for (uint256 i = 0; i < privKeys.length; i++) {
            signatures[i] = signExecution(privKeys[i], address(target), 0, "");
        }

        signatures[4] = signExecution(0xDEAD, address(target), 0, "");

        hevm.expectRevert(abi.encodeWithSignature("InvalidSignatures()"));
        lilGnosis.execute(address(target), 0, "", signatures);
    }

    function testRevertsWhenCallReverts() public {
        lilGnosis = new LilGnosis("Test Multisig", signers, privKeys.length);

        target.shouldRevert(true);

        LilGnosis.Signature[] memory signatures = new LilGnosis.Signature[](
            privKeys.length
        );
        for (uint256 i = 0; i < privKeys.length; i++) {
            signatures[i] = signExecution(privKeys[i], address(target), 0, "");
        }

        hevm.expectRevert(abi.encodeWithSignature("ExecutionFailed()"));
        lilGnosis.execute(address(target), 0, "", signatures);
    }

    function testCanSetQuorum(uint256 newQuorum) public {
        lilGnosis = new LilGnosis("Test Multisig", signers, privKeys.length);

        LilGnosis.Signature[] memory signatures = new LilGnosis.Signature[](
            privKeys.length
        );
        for (uint256 i = 0; i < privKeys.length; i++) {
            signatures[i] = signQuorum(privKeys[i], newQuorum);
        }

        hevm.expectEmit(false, false, false, true);
        emit QuorumUpdated(newQuorum);

        lilGnosis.setQuorum(newQuorum, signatures);

        assertEq(lilGnosis.quorum(), newQuorum);
    }

    function testCannotSetQuorumWithoutEnoughSignatures() public {
        lilGnosis = new LilGnosis(
            "Test Multisig",
            signers,
            privKeys.length + 1
        );

        LilGnosis.Signature[] memory signatures = new LilGnosis.Signature[](
            privKeys.length
        );
        for (uint256 i = 0; i < privKeys.length; i++) {
            signatures[i] = signQuorum(privKeys[i], 1);
        }

        hevm.expectRevert(stdError.indexOOBError);
        lilGnosis.setQuorum(1, signatures);
    }

    function testCannotSetQuorumWithInvalidSignatures() public {
        lilGnosis = new LilGnosis("Test Multisig", signers, privKeys.length);

        LilGnosis.Signature[] memory signatures = new LilGnosis.Signature[](
            privKeys.length
        );
        for (uint256 i = 0; i < privKeys.length; i++) {
            signatures[i] = signQuorum(privKeys[i], 5);
        }

        hevm.expectRevert(abi.encodeWithSignature("InvalidSignatures()"));
        lilGnosis.setQuorum(4, signatures);
    }

    function testCannotSetQuorumWithDuplicatedSignatures() public {
        lilGnosis = new LilGnosis("Test Multisig", signers, privKeys.length);

        LilGnosis.Signature[] memory signatures = new LilGnosis.Signature[](
            privKeys.length
        );
        for (uint256 i = 0; i < privKeys.length; i++) {
            signatures[i] = signQuorum(privKeys[1], 10);
        }

        hevm.expectRevert(abi.encodeWithSignature("InvalidSignatures()"));
        lilGnosis.setQuorum(10, signatures);
    }

    function testCannotSetQuorumWithUntrustedSignatures() public {
        lilGnosis = new LilGnosis("Test Multisig", signers, privKeys.length);

        LilGnosis.Signature[] memory signatures = new LilGnosis.Signature[](
            privKeys.length
        );
        for (uint256 i = 0; i < privKeys.length; i++) {
            signatures[i] = signQuorum(privKeys[i], 5);
        }

        signatures[4] = signQuorum(0xDEAD, 5);

        hevm.expectRevert(abi.encodeWithSignature("InvalidSignatures()"));
        lilGnosis.setQuorum(5, signatures);
    }

    function testCanSetSigner() public {
        lilGnosis = new LilGnosis("Test Multisig", signers, privKeys.length);
        assertTrue(!lilGnosis.isSigner(address(this)));

        LilGnosis.Signature[] memory signatures = new LilGnosis.Signature[](
            privKeys.length
        );
        for (uint256 i = 0; i < privKeys.length; i++) {
            signatures[i] = signSignerUpdate(privKeys[i], address(this), true);
        }

        hevm.expectEmit(true, false, false, true);
        emit SignerUpdated(address(this), true);

        lilGnosis.setSigner(address(this), true, signatures);

        assertTrue(lilGnosis.isSigner(address(this)));
    }

    function testCannotSetSignerWithoutEnoughSignatures() public {
        lilGnosis = new LilGnosis(
            "Test Multisig",
            signers,
            privKeys.length + 1
        );

        LilGnosis.Signature[] memory signatures = new LilGnosis.Signature[](
            privKeys.length
        );
        for (uint256 i = 0; i < privKeys.length; i++) {
            signatures[i] = signSignerUpdate(privKeys[i], address(this), true);
        }

        hevm.expectRevert(stdError.indexOOBError);
        lilGnosis.setSigner(address(this), true, signatures);
    }

    function testCannotSetSignerWithInvalidSignatures() public {
        lilGnosis = new LilGnosis("Test Multisig", signers, privKeys.length);

        LilGnosis.Signature[] memory signatures = new LilGnosis.Signature[](
            privKeys.length
        );
        for (uint256 i = 0; i < privKeys.length; i++) {
            signatures[i] = signSignerUpdate(privKeys[i], address(0x1), true);
        }

        hevm.expectRevert(abi.encodeWithSignature("InvalidSignatures()"));
        lilGnosis.setSigner(address(this), true, signatures);
    }

    function testCannotSetSignerWithDuplicatedSignatures() public {
        lilGnosis = new LilGnosis("Test Multisig", signers, privKeys.length);

        LilGnosis.Signature[] memory signatures = new LilGnosis.Signature[](
            privKeys.length
        );
        for (uint256 i = 0; i < privKeys.length; i++) {
            signatures[i] = signSignerUpdate(privKeys[1], address(this), true);
        }

        hevm.expectRevert(abi.encodeWithSignature("InvalidSignatures()"));
        lilGnosis.setSigner(address(this), true, signatures);
    }

    function testCannotSetSignerWithUntrustedSignatures() public {
        lilGnosis = new LilGnosis("Test Multisig", signers, privKeys.length);

        LilGnosis.Signature[] memory signatures = new LilGnosis.Signature[](
            privKeys.length
        );
        for (uint256 i = 0; i < privKeys.length; i++) {
            signatures[i] = signSignerUpdate(privKeys[i], address(this), true);
        }

        signatures[4] = signSignerUpdate(0xDEAD, address(this), true);

        hevm.expectRevert(abi.encodeWithSignature("InvalidSignatures()"));
        lilGnosis.setSigner(address(this), true, signatures);
    }
}
