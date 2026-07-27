// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Ownable} from "../access/Ownable.sol";
import {IERC1271} from "../interfaces/IERC1271.sol";
import {ECDSA} from "../utils/cryptography/ECDSA.sol";

contract ERC1271WalletMock is Ownable, IERC1271 {
    constructor(address originalOwner) Ownable(originalOwner) {}

    function isValidSignature(bytes32 hash, bytes memory signature) public view returns (bytes4 magicValue) {
        return ECDSA.recover(hash, signature) == owner() ? this.isValidSignature.selector : bytes4(0);
    }
}

/**
 * @dev Accepts any signature, but only if the received calldata is the canonical ABI encoding of the
 * {IERC1271-isValidSignature} call. Reverts otherwise.
 *
 * Used to verify that callers encode the dynamic `signature` argument with its tail padded to a multiple of 32 bytes.
 */
contract ERC1271StrictEncodingMock is IERC1271 {
    error NonCanonicalEncoding();

    function isValidSignature(bytes32 hash, bytes calldata signature) external pure returns (bytes4) {
        if (keccak256(msg.data) != keccak256(abi.encodeCall(IERC1271.isValidSignature, (hash, signature))))
            revert NonCanonicalEncoding();
        return IERC1271.isValidSignature.selector;
    }
}

contract ERC1271MaliciousMock is IERC1271 {
    function isValidSignature(bytes32, bytes memory) public pure returns (bytes4) {
        assembly {
            mstore(0, 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff)
            return(0, 32)
        }
    }
}
