// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

interface MMRTree {
    function append(bytes32 element) external;

    function multiAppend(bytes32[] memory elements) external;

    function getRootHash() external view returns (bytes32);

    function getElementsCount() external view returns (uint);

    function verifyProof(
        uint index,
        bytes32 value,
        bytes32[] memory proof,
        bytes32[] memory peaks,
        uint elementsCount,
        bytes32 root
    ) external view;
}
