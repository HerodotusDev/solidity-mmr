// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

/// @title KeccakHasher
/// @notice MMR hasher implementation using keccak256
library KeccakHasher {
    /// @notice Hash two bytes32 values together using keccak256(abi.encode(a, b))
    function hash(bytes32 a, bytes32 b) internal pure returns (bytes32) {
        return keccak256(abi.encode(a, b));
    }
}
