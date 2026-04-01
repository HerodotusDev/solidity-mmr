// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import {Test} from "forge-std/Test.sol";

import {StatelessMmr} from "../src/lib/StatelessMmr.sol";
import {StatelessMmrHelpers} from "../src/lib/StatelessMmrHelpers.sol";
import {KeccakHasher} from "../src/lib/hashers/KeccakHasher.sol";
import {Poseidon2Hasher} from "../src/lib/hashers/Poseidon2Hasher.sol";

/// @notice Tests for StatelessMmr using the Poseidon2 hash function.
///
/// Expected hash values are computed inline using `Poseidon2Hasher.hash` rather
/// than being hardcoded, so the tests verify self-consistency and structural
/// correctness rather than specific numeric outputs.
///
/// Note: these tests do NOT include off-chain interoperability checks (FFI) because
/// there is no bundled Node.js Poseidon2 reference implementation in this project.
/// Add such tests once a compatible off-chain MMR library is available.
contract StatelessMmrPoseidon2_Test is Test {
    error InvalidProof();
    error IndexOutOfBounds();
    error InvalidRoot();
    error InvalidPeaksArrayLength();

    // ── External wrappers ────────────────────────────────────────────────────
    // vm.expectRevert requires the next call to be an external call.
    // These thin wrappers expose the internal library calls externally via `this.`.

    function _callBagPeaks(bytes32[] calldata peaks) external pure {
        StatelessMmr.bagPeaks(peaks, Poseidon2Hasher.hash);
    }

    function _callComputeRoot(bytes32[] calldata peaks, bytes32 size) external pure {
        StatelessMmr.computeRoot(peaks, size, Poseidon2Hasher.hash);
    }

    function _callVerifyProof(
        uint index,
        bytes32 value,
        bytes32[] calldata proof,
        bytes32[] calldata peaks,
        uint elementsCount,
        bytes32 root
    ) external pure {
        StatelessMmr.verifyProof(index, value, proof, peaks, elementsCount, root, Poseidon2Hasher.hash);
    }

    // ─── bagPeaks ────────────────────────────────────────────────────────────

    function testPoseidon2InvalidBagPeaks() public {
        vm.expectRevert(InvalidPeaksArrayLength.selector);
        this._callBagPeaks(new bytes32[](0));
    }

    function testPoseidon2BagPeaks() public {
        bytes32[] memory peaks = new bytes32[](0);

        // One element — bags to itself
        peaks = StatelessMmrHelpers.newArrWithElem(peaks, bytes32(uint(1)));
        bytes32 bagged = StatelessMmr.bagPeaks(peaks, Poseidon2Hasher.hash);
        assertEq(bagged, peaks[0]);

        // Two elements
        peaks = StatelessMmrHelpers.newArrWithElem(peaks, bytes32(uint(2)));
        bagged = StatelessMmr.bagPeaks(peaks, Poseidon2Hasher.hash);
        bytes32 expected2 = Poseidon2Hasher.hash(peaks[0], peaks[1]);
        assertEq(bagged, expected2);

        // Three elements: bag(a,b,c) = hash(a, hash(b,c))
        peaks = StatelessMmrHelpers.newArrWithElem(peaks, bytes32(uint(3)));
        bytes32 inner = Poseidon2Hasher.hash(peaks[1], peaks[2]);
        bytes32 expected3 = Poseidon2Hasher.hash(peaks[0], inner);
        bagged = StatelessMmr.bagPeaks(peaks, Poseidon2Hasher.hash);
        assertEq(bagged, expected3);
    }

    // ─── computeRoot ─────────────────────────────────────────────────────────

    function testPoseidon2ComputeRootEmpty() public {
        bytes32[] memory peaks = new bytes32[](0);
        vm.expectRevert(InvalidPeaksArrayLength.selector);
        this._callComputeRoot(peaks, 0);
    }

    function testPoseidon2ComputeRoot() public {
        bytes32[] memory peaks = new bytes32[](3);
        for (uint i = 0; i < 3; ++i) {
            peaks[i] = bytes32(uint(i + 1));
        }
        bytes32 bagged = StatelessMmr.bagPeaks(peaks, Poseidon2Hasher.hash);
        bytes32 size = bytes32(uint(7)); // Expected pos after 3 leaves
        bytes32 expectedRoot = Poseidon2Hasher.hash(size, bagged);
        bytes32 root = StatelessMmr.computeRoot(peaks, size, Poseidon2Hasher.hash);
        assertEq(root, expectedRoot);
    }

    // ─── append ──────────────────────────────────────────────────────────────

    function testPoseidon2AppendInitial() public returns (uint, bytes32, bytes32) {
        bytes32[] memory peaks = new bytes32[](0);
        bytes32 leaf1 = bytes32(uint(1));

        (uint newPos, bytes32 newRoot) = StatelessMmr.append(
            leaf1, peaks, 0, bytes32(0), Poseidon2Hasher.hash
        );
        assertEq(newPos, 1);

        // Root for a single-leaf MMR: hash(size=1, leaf1)
        bytes32 expectedRoot = Poseidon2Hasher.hash(bytes32(uint(1)), leaf1);
        assertEq(newRoot, expectedRoot);

        peaks = new bytes32[](1);
        peaks[0] = leaf1;
        assertEq(newRoot, StatelessMmr.computeRoot(peaks, bytes32(newPos), Poseidon2Hasher.hash));

        return (newPos, newRoot, leaf1);
    }

    function testPoseidon2AppendTwo() public returns (uint, bytes32, bytes32) {
        (uint lastPos, bytes32 lastRoot, bytes32 leaf1) = testPoseidon2AppendInitial();
        bytes32[] memory peaks = new bytes32[](1);
        peaks[0] = leaf1;

        bytes32 leaf2 = bytes32(uint(2));
        (uint newPos, bytes32 newRoot) = StatelessMmr.append(
            leaf2, peaks, lastPos, lastRoot, Poseidon2Hasher.hash
        );
        assertEq(newPos, 3);

        // After 2 leaves: single peak = hash(leaf1, leaf2), root = hash(3, peak)
        bytes32 node3 = Poseidon2Hasher.hash(leaf1, leaf2);
        bytes32 expectedRoot = Poseidon2Hasher.hash(bytes32(uint(3)), node3);
        assertEq(newRoot, expectedRoot);

        return (newPos, newRoot, node3);
    }

    function testPoseidon2AppendThree() public returns (uint, bytes32, bytes32[] memory) {
        (uint lastPos, bytes32 lastRoot, bytes32 node3) = testPoseidon2AppendTwo();
        bytes32[] memory peaks = new bytes32[](1);
        peaks[0] = node3;

        bytes32 leaf3 = bytes32(uint(3));
        (uint newPos, bytes32 newRoot) = StatelessMmr.append(
            leaf3, peaks, lastPos, lastRoot, Poseidon2Hasher.hash
        );
        assertEq(newPos, 4);

        // After 3 leaves: two peaks = [node3, leaf3]
        bytes32[] memory newPeaks = StatelessMmrHelpers.newArrWithElem(peaks, leaf3);
        bytes32 expectedRoot = StatelessMmr.computeRoot(newPeaks, bytes32(newPos), Poseidon2Hasher.hash);
        assertEq(newRoot, expectedRoot);

        return (newPos, newRoot, newPeaks);
    }

    function testPoseidon2AppendFour() public returns (uint, bytes32, bytes32[] memory) {
        (
            uint lastPos,
            bytes32 lastRoot,
            bytes32[] memory lastPeaks
        ) = testPoseidon2AppendThree();

        bytes32 leaf4 = bytes32(uint(4));
        (uint newPos, bytes32 newRoot) = StatelessMmr.append(
            leaf4, lastPeaks, lastPos, lastRoot, Poseidon2Hasher.hash
        );
        assertEq(newPos, 7);

        // After 4 leaves: single peak = hash(node3, hash(leaf3, leaf4))
        bytes32 node6 = Poseidon2Hasher.hash(lastPeaks[1], leaf4);
        bytes32 node7 = Poseidon2Hasher.hash(lastPeaks[0], node6);
        bytes32[] memory peaks = new bytes32[](1);
        peaks[0] = node7;
        bytes32 expectedRoot = StatelessMmr.computeRoot(peaks, bytes32(newPos), Poseidon2Hasher.hash);
        assertEq(newRoot, expectedRoot);

        return (newPos, newRoot, peaks);
    }

    // ─── multiAppend ─────────────────────────────────────────────────────────

    function testPoseidon2MultiAppendSingle() public {
        bytes32[] memory elems = new bytes32[](1);
        elems[0] = bytes32(uint(1));
        (uint newPos,) = StatelessMmr.multiAppend(elems, new bytes32[](0), 0, bytes32(0), Poseidon2Hasher.hash);
        assertEq(newPos, 1);
    }

    function testPoseidon2MultiAppendTwo() public {
        bytes32[] memory elems = new bytes32[](2);
        elems[0] = bytes32(uint(1));
        elems[1] = bytes32(uint(2));
        (uint newPos,) = StatelessMmr.multiAppend(elems, new bytes32[](0), 0, bytes32(0), Poseidon2Hasher.hash);
        assertEq(newPos, 3);
    }

    function testPoseidon2MultiAppendFour() public {
        bytes32[] memory elems = new bytes32[](4);
        elems[0] = bytes32(uint(1));
        elems[1] = bytes32(uint(2));
        elems[2] = bytes32(uint(3));
        elems[3] = bytes32(uint(4));
        (uint newPos,) = StatelessMmr.multiAppend(elems, new bytes32[](0), 0, bytes32(0), Poseidon2Hasher.hash);
        assertEq(newPos, 7);
    }

    function testPoseidon2MultiAppendFive() public {
        bytes32[] memory elems = new bytes32[](5);
        for (uint i = 0; i < 5; i++) elems[i] = bytes32(uint(i + 1));
        (uint newPos,) = StatelessMmr.multiAppend(elems, new bytes32[](0), 0, bytes32(0), Poseidon2Hasher.hash);
        assertEq(newPos, 8);
    }

    // ─── verifyProof ─────────────────────────────────────────────────────────

    function testPoseidon2VerifyProofOneLeaf() public {
        bytes32 leaf1 = bytes32(uint(1));
        (uint newPos, bytes32 newRoot) = StatelessMmr.append(
            leaf1, new bytes32[](0), 0, bytes32(0), Poseidon2Hasher.hash
        );
        bytes32[] memory peaks = StatelessMmrHelpers.newArrWithElem(new bytes32[](0), leaf1);
        // Empty proof: leaf is itself a peak
        StatelessMmr.verifyProof(1, leaf1, new bytes32[](0), peaks, newPos, newRoot, Poseidon2Hasher.hash);
    }

    function testPoseidon2VerifyProofTwoLeaves() public {
        (uint lastPos, bytes32 lastRoot, bytes32 leaf1) = testPoseidon2AppendInitial();
        bytes32[] memory peaks = new bytes32[](1);
        peaks[0] = leaf1;

        bytes32 leaf2 = bytes32(uint(2));
        (uint newPos, bytes32 newRoot) = StatelessMmr.append(
            leaf2, peaks, lastPos, lastRoot, Poseidon2Hasher.hash
        );

        bytes32 node3 = Poseidon2Hasher.hash(leaf1, leaf2);
        peaks = new bytes32[](1);
        peaks[0] = node3;

        // Proof for leaf2 (index 2): sibling is leaf1
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = leaf1;
        StatelessMmr.verifyProof(2, leaf2, proof, peaks, newPos, newRoot, Poseidon2Hasher.hash);

        // Proof for leaf1 (index 1): no siblings, leaf1 is the left child of node3
        bytes32[] memory proof1 = new bytes32[](1);
        proof1[0] = leaf2;
        StatelessMmr.verifyProof(1, leaf1, proof1, peaks, newPos, newRoot, Poseidon2Hasher.hash);
    }

    function testPoseidon2VerifyProofFourLeaves() public {
        (
            uint lastPos,
            bytes32 lastRoot,
            bytes32[] memory lastPeaks
        ) = testPoseidon2AppendThree();

        bytes32 leaf4 = bytes32(uint(4));
        (uint newPos, bytes32 newRoot) = StatelessMmr.append(
            leaf4, lastPeaks, lastPos, lastRoot, Poseidon2Hasher.hash
        );
        assertEq(newPos, 7);

        // Tree after 4 leaves (positions 1–7):
        //         7
        //        / \
        //       3   6
        //      / \ / \
        //     1  2 4  5  (leaf values: 1,2,3,4)
        // peaks = [7]

        bytes32 node6 = Poseidon2Hasher.hash(lastPeaks[1], leaf4);
        bytes32 node7 = Poseidon2Hasher.hash(lastPeaks[0], node6);
        bytes32[] memory peaks = new bytes32[](1);
        peaks[0] = node7;

        // Proof for leaf4 (index 5, the right child of node6): siblings = [leaf3, node3]
        bytes32[] memory proof = new bytes32[](2);
        proof[0] = lastPeaks[1]; // leaf3
        proof[1] = lastPeaks[0]; // node3
        StatelessMmr.verifyProof(5, leaf4, proof, peaks, newPos, newRoot, Poseidon2Hasher.hash);
    }

    function testPoseidon2VerifyProofFiveLeaves() public {
        (
            uint lastPos,
            bytes32 lastRoot,
            bytes32[] memory lastPeaks
        ) = testPoseidon2AppendFour();

        bytes32 leaf5 = bytes32(uint(8));
        (uint newPos, bytes32 newRoot) = StatelessMmr.append(
            leaf5, lastPeaks, lastPos, lastRoot, Poseidon2Hasher.hash
        );
        assertEq(newPos, 8);

        bytes32[] memory peaks = StatelessMmrHelpers.newArrWithElem(lastPeaks, leaf5);

        // leaf5 is a fresh peak (index 8), so its proof is empty
        StatelessMmr.verifyProof(8, leaf5, new bytes32[](0), peaks, newPos, newRoot, Poseidon2Hasher.hash);
    }

    // ─── Error cases ─────────────────────────────────────────────────────────

    function testPoseidon2VerifyProofInvalidIndex() public {
        (uint newPos, bytes32 newRoot) = StatelessMmr.append(
            bytes32(uint(1)), new bytes32[](0), 0, bytes32(0), Poseidon2Hasher.hash
        );
        bytes32[] memory peaks = StatelessMmrHelpers.newArrWithElem(new bytes32[](0), bytes32(uint(1)));

        vm.expectRevert(IndexOutOfBounds.selector);
        this._callVerifyProof(2, bytes32(uint(2)), new bytes32[](0), peaks, newPos, newRoot);
    }

    function testPoseidon2VerifyProofInvalidPeaks() public {
        (uint newPos, bytes32 newRoot) = StatelessMmr.append(
            bytes32(uint(1)), new bytes32[](0), 0, bytes32(0), Poseidon2Hasher.hash
        );
        bytes32[] memory badPeaks = StatelessMmrHelpers.newArrWithElem(new bytes32[](0), bytes32(uint(42)));

        vm.expectRevert();
        this._callVerifyProof(1, bytes32(uint(1)), new bytes32[](0), badPeaks, newPos, newRoot);
    }

    function testPoseidon2VerifyProofInvalidProof() public {
        (uint lastPos, bytes32 lastRoot, bytes32 leaf1) = testPoseidon2AppendInitial();
        bytes32[] memory peaks = new bytes32[](1);
        peaks[0] = leaf1;

        bytes32 leaf2 = bytes32(uint(2));
        (uint newPos, bytes32 newRoot) = StatelessMmr.append(
            leaf2, peaks, lastPos, lastRoot, Poseidon2Hasher.hash
        );

        bytes32 node3 = Poseidon2Hasher.hash(leaf1, leaf2);
        peaks = new bytes32[](1);
        peaks[0] = node3;

        bytes32[] memory badProof = new bytes32[](1);
        badProof[0] = node3; // Wrong sibling (should be leaf1)

        vm.expectRevert(InvalidProof.selector);
        this._callVerifyProof(2, leaf2, badProof, peaks, newPos, newRoot);
    }

    // ─── Keccak / Poseidon2 isolation ────────────────────────────────────────

    function testPoseidon2AndKeccakProduceDistinctRoots() public {
        // Verify that the two hashers are not accidentally producing the same outputs,
        // which would indicate a test configuration error.
        bytes32 leaf = bytes32(uint(0xdeadbeef));
        bytes32[] memory noPeaks = new bytes32[](0);

        (, bytes32 keccakRoot) = StatelessMmr.append(leaf, noPeaks, 0, bytes32(0), KeccakHasher.hash);
        (, bytes32 poseidon2Root) = StatelessMmr.append(leaf, noPeaks, 0, bytes32(0), Poseidon2Hasher.hash);

        assertTrue(keccakRoot != poseidon2Root, "keccak and Poseidon2 roots must differ");
    }
}
