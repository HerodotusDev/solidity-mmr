// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "./interfaces/MMRTree.sol";
import "./lib/StatelessMmr.sol";

contract MMR is MMRTree {
    bytes32 treeRoot; // Root hash of the tree

    mapping(uint => bytes32) nodeIndexToRoot; // Mapping of node index to relative root hash
    mapping(uint => bytes32[]) nodeIndexToPeaks; // Mapping of node index to peaks. Peaks can be calculated and/or stored off-chain

    bytes32[] lastPeaks; // Peaks of the last tree. For illustration purpose, can be calculated and/or stored off-chain
    uint lastElementsCount; // Latest elements count
    bytes32 lastRoot; // Latest root hash

    // Emitted event after each successful `append` operation
    event Appended(bytes32 element, bytes32 rootHash, uint elementsCount);

    function append(bytes32 element) external {
        // Append element to the tree
        (
            uint nextElementsCount,
            bytes32 nextRootHash,
            bytes32[] memory nextPeaks
        ) = StatelessMmr.appendWithPeaksRetrieval(
                element,
                lastPeaks,
                lastElementsCount,
                lastRoot
            );

        // Update contract state
        lastPeaks = nextPeaks;
        lastElementsCount = nextElementsCount;
        lastRoot = nextRootHash;
        nodeIndexToRoot[nextElementsCount] = lastRoot;
        nodeIndexToPeaks[nextElementsCount] = lastPeaks;

        // Emit event
        emit Appended(element, lastRoot, lastElementsCount);
    }

    function multiAppend(bytes32[] memory elements) external {
        // Append multiple elements to the tree

        uint nextElementsCount = lastElementsCount;
        bytes32 nextRoot = lastRoot;
        bytes32[] memory nextPeaks = lastPeaks;

        for (uint i = 0; i < elements.length; ++i) {
            (nextElementsCount, nextRoot, nextPeaks) = StatelessMmr
                .appendWithPeaksRetrieval(
                    elements[i],
                    nextPeaks,
                    nextElementsCount,
                    nextRoot
                );

            // Emit event for each appended element
            emit Appended(elements[i], nextRoot, nextElementsCount);
        }

        // Update contract state
        lastPeaks = nextPeaks;
        lastElementsCount = nextElementsCount;
        lastRoot = nextRoot;
        nodeIndexToRoot[nextElementsCount] = lastRoot;
        nodeIndexToPeaks[nextElementsCount] = lastPeaks;
    }

    function getRootHash() external view returns (bytes32) {
        // Return the root hash of the tree
        return lastRoot;
    }

    function getElementsCount() external view returns (uint) {
        // Return the number of nodes in the tree
        return lastElementsCount;
    }

    function verifyProof(
        uint index,
        bytes32 value,
        bytes32[] memory proof,
        bytes32[] memory peaks,
        uint elementsCount,
        bytes32 root
    ) external pure {
        // Verify the proof
        StatelessMmr.verifyProof(
            index,
            value,
            proof,
            peaks,
            elementsCount,
            root
        );
    }
}
