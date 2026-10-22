// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {ERC20} from "../../../../token/ERC20/ERC20.sol";
import {IERC6372} from "../../../../interfaces/IERC6372.sol";
import {SafeCast} from "../../../../utils/math/SafeCast.sol";
import {Checkpoints} from "../../../../utils/structs/Checkpoints.sol";
import {Time} from "../../../../utils/types/Time.sol";

/**
 * @dev Example of an ERC-20 that reports the average balance of an account over any past period, where each balance
 * counts in proportion to how long it was held.
 *
 * The token keeps a history of every balance change, so nobody needs to save anything in advance. Call
 * {getAverageBalanceBetween} with any account and any past period. For example, an airdrop decided in April can reward
 * every holder by their average balance over the first quarter.
 *
 * The history of each account is a {Checkpoints-Trace224}, with a `uint32` timepoint and a `uint224` value per
 * checkpoint. The value packs the balance set at that timepoint and the integral of all previous balances over time,
 * in `balance * seconds`:
 *
 * ```
 * | balance (96 bits) | integral (128 bits) |
 * ```
 *
 * NOTE: This extension assumes that timepoints fit in `uint32`, which holds for timestamps until the year 2106, and that
 * balances fit in 96 bits, up to about 7.9e28. Under these assumptions, the integral always fits in 128 bits: it is at
 * most the largest balance (`2**96`) times the longest time span (`2**32` timepoints).
 *
 * NOTE: Keeping a history makes transfers more expensive than in a plain ERC-20, in exchange for the average balance
 * over any past period.
 */
abstract contract ERC20TimeWeighted is ERC20, IERC6372 {
    using Checkpoints for Checkpoints.Trace224;
    using SafeCast for uint256;

    /// @dev Checkpoints of the balance of each account and its integral over time.
    mapping(address account => Checkpoints.Trace224) private _history;

    /// @dev The lookup `timepoint` is after the current `clock`.
    error ERC20TimeWeightedFutureLookup(uint256 timepoint, uint48 clock);

    /// @inheritdoc IERC6372
    function clock() public view virtual returns (uint48) {
        return Time.timestamp();
    }

    /// @inheritdoc IERC6372
    // solhint-disable-next-line func-name-mixedcase
    function CLOCK_MODE() public view virtual returns (string memory) {
        return "mode=timestamp";
    }

    /// @dev Returns the average balance of `account` from `start` until `stop`.
    function getAverageBalanceBetween(address account, uint256 start, uint256 stop) public view returns (uint256) {
        return (_cumulativeAt(account, stop) - _cumulativeAt(account, start)) / (stop - start);
    }

    /// @dev Checkpoints the balances of `from` and `to` after each transfer, mint or burn.
    function _update(address from, address to, uint256 value) internal virtual override {
        super._update(from, to, value);
        if (from != address(0)) _checkpoint(from);
        if (to != address(0)) _checkpoint(to);
    }

    /// @dev Records the current balance of `account` and its integral up to now.
    function _checkpoint(address account) private {
        uint32 key = uint256(clock()).toUint32();
        uint256 cumulative = _cumulativeAt(account, key);
        _history[account].push(key, _pack(balanceOf(account).toUint96(), cumulative.toUint128()));
    }

    /// @dev Integral of the balance of `account` up to `timepoint`, extended from the last checkpoint before it.
    function _cumulativeAt(address account, uint256 timepoint) private view returns (uint256) {
        uint48 currentTimepoint = clock();
        if (timepoint > currentTimepoint) revert ERC20TimeWeightedFutureLookup(timepoint, currentTimepoint);

        (bool exists, uint32 key, uint224 packed) = _history[account].upperLookupRecentCheckpoint(timepoint.toUint32());
        if (!exists) return 0;
        (uint96 balance, uint128 cumulative) = _unpack(packed);
        return cumulative + uint256(balance) * (timepoint - key);
    }

    /// @dev Packs `balance` in the high 96 bits and `cumulative` in the low 128 bits of a checkpoint value.
    function _pack(uint96 balance, uint128 cumulative) private pure returns (uint224) {
        return (uint224(balance) << 128) | cumulative;
    }

    /// @dev Reverse of {_pack}.
    function _unpack(uint224 packed) private pure returns (uint96 balance, uint128 cumulative) {
        return (uint96(packed >> 128), uint128(packed));
    }
}
