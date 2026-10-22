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
    }

    function testAverageFromSnapshot() public {
        uint256 aliceStart = _token.cumulativeBalanceOf(_alice);
        uint256 bobStart = _token.cumulativeBalanceOf(_bob);
        uint48 startTimepoint = _token.clock();

        vm.warp(_start + 2 hours);
        vm.prank(_alice);
        _token.transfer(_bob, 60);
        vm.warp(_start + 3 hours);

        assertEq(_token.getAverageBalanceSince(_alice, aliceStart, startTimepoint), 80);
        assertEq(_token.getAverageBalanceSince(_bob, bobStart, startTimepoint), 20);
    }

    function testEmptyWindowReverts() public {
        uint256 start = _token.cumulativeBalanceOf(_alice);
        uint48 startTimepoint = _token.clock();
        vm.expectRevert();
        _token.getAverageBalanceSince(_alice, start, startTimepoint);
    }

    function testCumulativeGrowsWithoutTransfers() public {
        vm.warp(_start + 1 hours);
        assertEq(_token.cumulativeBalanceOf(_alice), 100 * 1 hours);
    }
}
