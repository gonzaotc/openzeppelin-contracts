// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC1271StrictEncodingMock} from "@openzeppelin/contracts/mocks/ERC1271WalletMock.sol";
import {SignatureChecker} from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";

contract SignatureCheckerTest is Test {
    ERC1271StrictEncodingMock private _wallet;

    function setUp() public {
        _wallet = new ERC1271StrictEncodingMock();
    }

    function testERC1271EncodingMemory(bytes32 hash, bytes memory signature) public view {
        assertTrue(SignatureChecker.isValidERC1271SignatureNow(address(_wallet), hash, signature));
    }

    function testERC1271EncodingCalldata(bytes32 hash, bytes calldata signature) public view {
        assertTrue(SignatureChecker.isValidERC1271SignatureNowCalldata(address(_wallet), hash, signature));
    }
}
