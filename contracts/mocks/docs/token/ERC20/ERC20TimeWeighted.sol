// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {ERC20} from "../../../../token/ERC20/ERC20.sol";
import {IERC6372} from "../../../../interfaces/IERC6372.sol";
import {SafeCast} from "../../../../utils/math/SafeCast.sol";
import {Time} from "../../../../utils/types/Time.sol";

/**
 * @dev Example of an ERC-20 that reports the integral of each balance over time, in `balance * seconds`.
 *
 * Each account stores only the integral up to its last balance change and the timepoint of that change, in one storage
 * slot that every transfer overwrites. To get the average balance over a window, record {cumulativeBalanceOf} and
 * {clock} at its start, then call {getAverageBalanceSince}.
 *
 * TIP: This extension suits windows whose start is known in advance, since someone must read the integral at that
 * moment. To query any past window, consider {ERC20TimeWeightedHistory} instead, which keeps a history at a higher
 * cost per transfer.
 *
 * NOTE: This extension assumes that the integral fits in 208 bits, which holds for balances that fit in 160 bits and
 * timepoints that fit in 48 bits.
 */
abstract contract ERC20TimeWeighted is ERC20, IERC6372 {
    using SafeCast for uint256;

    /// @dev The integral of a balance up to `timepoint`, the last time the balance changed.
    struct Accumulator {
        uint208 cumulative;
        uint48 timepoint;
    }

    /// @dev The accumulator of each account.
    mapping(address account => Accumulator) private _accumulators;

    /// @dev The window from `startTimepoint` to the current `clock` is empty or reversed.
    error ERC20TimeWeightedInvalidWindow(uint48 startTimepoint, uint48 clock);

    /// @inheritdoc IERC6372
    function clock() public view virtual returns (uint48) {
        return Time.timestamp();
    }

    /// @inheritdoc IERC6372
    // solhint-disable-next-line func-name-mixedcase
    function CLOCK_MODE() public view virtual returns (string memory) {
        return "mode=timestamp";
    }

    /// @dev Returns the integral of the balance of `account` over time, up to now.
    function cumulativeBalanceOf(address account) public view returns (uint256) {
        Accumulator memory accumulator = _accumulators[account];
        return accumulator.cumulative + balanceOf(account) * (clock() - accumulator.timepoint);
    }

    /**
     * @dev Returns the average balance of `account` from `startTimepoint` until now, given `startCumulative`, its
     * {cumulativeBalanceOf} at `startTimepoint`.
     */
    function getAverageBalanceSince(
        address account,
        uint256 startCumulative,
        uint48 startTimepoint
    ) public view returns (uint256) {
        uint48 currentTimepoint = clock();
        if (startTimepoint >= currentTimepoint) revert ERC20TimeWeightedInvalidWindow(startTimepoint, currentTimepoint);
        return (cumulativeBalanceOf(account) - startCumulative) / (currentTimepoint - startTimepoint);
    }

    /// @dev Integrates the balances of `from` and `to` up to now, before they change.
    function _update(address from, address to, uint256 value) internal virtual override {
        if (from != address(0)) _accrue(from);
        if (to != address(0)) _accrue(to);
        super._update(from, to, value);
    }

    /// @dev Records the integral of the balance of `account` up to now.
    function _accrue(address account) private {
        _accumulators[account] = Accumulator({
            cumulative: cumulativeBalanceOf(account).toUint208(),
            timepoint: clock()
        });
    }
}
