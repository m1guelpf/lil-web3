// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.10;

contract LilGnosis {
    error InvalidSignatures();
    error ExecutionFailed();

    event QuorumUpdated(uint256 newQuorum);
    event Executed(address target, uint256 value, bytes payload);
    event SignerUpdated(address indexed signer, bool shouldTrust);

    struct Signature {
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    uint256 public nonce;
    uint256 public quorum;
    bytes32 public immutable domainSeparator;

    mapping(address => bool) public isSigner;

    bytes32 public constant QUORUM_HASH =
        keccak256("UpdateQuorum(uint256 newQuorum,uint256 nonce)");
    bytes32 public constant SIGNER_HASH =
        keccak256(
            "UpdateSigner(address signer,bool shouldTrust,uint256 nonce)"
        );
    bytes32 public constant EXECUTE_HASH =
        keccak256(
            "Execute(address target,uint256 value,bytes payload,uint256 nonce)"
        );

    constructor(
        string memory name,
        address[] memory signers,
        uint256 _quorum
    ) payable {
        unchecked {
            for (uint256 i = 0; i < signers.length; i++)
                isSigner[signers[i]] = true;
        }

        quorum = _quorum;

        domainSeparator = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256(bytes(name)),
                keccak256(bytes("1")),
                block.chainid,
                address(this)
            )
        );
    }

    /// @param sigs An array of Ethereum signatures, sorted ascending by the signer's address (otherwise verification fails!!!!)
    function execute(
        address target,
        uint256 value,
        bytes calldata payload,
        Signature[] calldata sigs
    ) public payable {
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator,
                keccak256(
                    abi.encode(EXECUTE_HASH, target, value, payload, nonce++)
                )
            )
        );

        address previous;

        unchecked {
            for (uint256 i = 0; i < quorum; i++) {
                address sigAddress = ecrecover(
                    digest,
                    sigs[i].v,
                    sigs[i].r,
                    sigs[i].s
                );

                if (!isSigner[sigAddress] || previous >= sigAddress)
                    revert InvalidSignatures();

                previous = sigAddress;
            }
        }

        emit Executed(target, value, payload);

        (bool success, ) = target.call{value: value}(payload);

        if (!success) revert ExecutionFailed();
    }

    function setQuorum(uint256 _quorum, Signature[] calldata sigs)
        public
        payable
    {
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator,
                keccak256(abi.encode(QUORUM_HASH, _quorum, nonce++))
            )
        );

        address previous;

        unchecked {
            for (uint256 i = 0; i < quorum; i++) {
                address sigAddress = ecrecover(
                    digest,
                    sigs[i].v,
                    sigs[i].r,
                    sigs[i].s
                );

                if (!isSigner[sigAddress] || previous >= sigAddress)
                    revert InvalidSignatures();

                previous = sigAddress;
            }
        }

        emit QuorumUpdated(_quorum);

        quorum = _quorum;
    }

    function setSigner(
        address signer,
        bool shouldTrust,
        Signature[] calldata sigs
    ) public payable {
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator,
                keccak256(abi.encode(SIGNER_HASH, signer, shouldTrust, nonce++))
            )
        );

        address previous;

        unchecked {
            for (uint256 i = 0; i < quorum; i++) {
                address sigAddress = ecrecover(
                    digest,
                    sigs[i].v,
                    sigs[i].r,
                    sigs[i].s
                );

                if (!isSigner[sigAddress] || previous >= sigAddress)
                    revert InvalidSignatures();

                previous = sigAddress;
            }
        }

        emit SignerUpdated(signer, shouldTrust);

        isSigner[signer] = shouldTrust;
    }

    receive() external payable {}
}
