// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import {Test} from "forge-std/Test.sol";

import {MMR} from "../src/MMR.sol";

contract MMR_Test is Test {
    MMR public mmr;

    event Appended(bytes32 element, bytes32 rootHash, uint elementsCount);

    function setUp() public {
        mmr = new MMR();
    }

    function testTreeAppends() public {
        // Simple append
        vm.expectEmit(true, true, true, true);
        emit Appended(
            bytes32(uint(1)),
            0xcc69885fda6bcc1a4ace058b4a62bf5e179ea78fd58a1ccd71c22cc9b688792f,
            1
        );
        mmr.append(bytes32(uint(1)));

        bytes32[] memory elementsToAppend = new bytes32[](3);
        elementsToAppend[0] = bytes32(uint(2));
        elementsToAppend[1] = bytes32(uint(3));
        elementsToAppend[2] = bytes32(uint(4));

        // Multi-append
        vm.expectEmit(true, true, true, true);
        emit Appended(
            bytes32(uint(2)),
            0x9b0225f2c6f59eeaf8302811ea290e95258763189b82dc033158e99a6ef45a87,
            3
        );
        vm.expectEmit(true, true, true, true);
        emit Appended(
            bytes32(uint(3)),
            0xda17729a0f5f73c4df98b68ff4594cc40ebe750cac8ff62cf71bacd99451602e,
            4
        );
        vm.expectEmit(true, true, true, true);
        emit Appended(
            bytes32(uint(4)),
            0x4cab9bd4f2a70f5a6988e8741e74f8a7504bf1ebe8c57e765ee7875731360cd0,
            7
        );
        mmr.multiAppend(elementsToAppend);

        assertEq(mmr.getElementsCount(), 7);
    }
}
