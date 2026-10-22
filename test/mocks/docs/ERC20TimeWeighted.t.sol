// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20TimeWeighted} from "@openzeppelin/contracts/mocks/docs/token/ERC20/ERC20TimeWeighted.sol";

contract TimeWeightedToken is ERC20TimeWeighted {
    constructor() ERC20("Token", "TKN") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/// @dev Alice holds 100 for 2 hours, then sends 60 to Bob and holds 40 for 1 hour.
contract ERC20TimeWeightedTest is Test {
    TimeWeightedToken internal _token = new TimeWeightedToken();
    address internal _alice = makeAddr("alice");
    address internal _bob = makeAddr("bob");
    uint256 internal _start = 1 days;

    function setUp() public {
        vm.warp(_start);
        _token.mint(_alice, 100);
        vm.warp(_start + 2 hours);
        vm.prank(_alice);
        _token.transfer(_bob, 60);
        vm.warp(_start + 3 hours);
    }

    function testAverageBetween() public view {
        assertEq(_token.getAverageBalanceBetween(_alice, _start, _start + 3 hours), 80);
        assertEq(_token.getAverageBalanceBetween(_bob, _start, _start + 3 hours), 20);
        assertEq(_token.getAverageBalanceBetween(_alice, _start + 1 hours, _start + 3 hours), 70);
    }

    function testAverageBeforeFirstCheckpoint() public view {
        assertEq(_token.getAverageBalanceBetween(_alice, _start - 1 hours, _start + 1 hours), 50);
    }

    function testFutureLookupReverts() public {
        vm.expectRevert();
        _token.getAverageBalanceBetween(_alice, _start, _start + 4 hours);
    }
}
