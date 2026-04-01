// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import {LibPoseidon2Yul} from "poseidon2-evm/src/bn254/yul/LibPoseidon2Yul.sol";

/// @title Poseidon2Hasher
/// @notice MMR hasher implementation using the Poseidon2 hash function over the BN254 scalar field
/// @dev Uses the Yul-optimised LibPoseidon2Yul from https://github.com/zemse/poseidon2-evm.
///      Input bytes32 values are interpreted as BN254 field elements without range checking.
///      For full ZK compatibility, leaf values should be within the BN254 scalar field.
///      Internal MMR node hashes are always valid field elements because Poseidon2 output is
///      reduced modulo the prime.
library Poseidon2Hasher {
    /// @notice Hash two bytes32 values together using Poseidon2
    function hash(bytes32 a, bytes32 b) internal pure returns (bytes32) {
        return bytes32(LibPoseidon2Yul.hash_2(uint256(a), uint256(b)));
    }
}
