// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

import {MMR} from "../src/MMR.sol";

contract MMR_Test is Test {
    MMR public mmr;

    event Appended(bytes32 element, bytes32 rootHash, uint elementsCount);

    function setUp() public {
        mmr = new MMR();
    }

    function testTreeAppends() public {
        // Simple append
        // TODO: ensure emitted event correctness
        mmr.append(keccak256(abi.encodePacked(uint(1))));

        bytes32[] memory elementsToAppend = new bytes32[](3);
        elementsToAppend[0] = keccak256(abi.encode(bytes32(uint(2))));
        elementsToAppend[1] = keccak256(abi.encode(bytes32(uint(3))));
        elementsToAppend[2] = keccak256(abi.encode(bytes32(uint(4))));

        // Multi-append
        // TODO: ensure emitted events correctness
        mmr.multiAppend(elementsToAppend);

        assertEq(mmr.getElementsCount(), 7);
    }
}
