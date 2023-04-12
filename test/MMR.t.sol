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
            0xedb38a93e6e2e82dbb40826a878df1d817a37ef13fcaa25248649a90fa47497b,
            1
        );
        mmr.append(bytes32(uint(1)));

        bytes32[] memory elementsToAppend = new bytes32[](3);
        elementsToAppend[0] = bytes32(uint(2));
        elementsToAppend[1] = bytes32(uint(3));
        elementsToAppend[2] = bytes32(uint(4));

        // Multi-append
        vm.expectEmit(true, true, true, true);
        vm.expectEmit(true, true, true, true);
        vm.expectEmit(true, true, true, true);
        emit Appended(
            bytes32(uint(2)),
            0x112e2be63bd7e73b3af704af8f4c8f6086fe3773003738f4ee9ada285d308d53,
            3
        );
        emit Appended(
            bytes32(uint(3)),
            0x9cf52726b5c1f29825fa3757402809afeb76f510e83e95559d9a5504a243b373,
            4
        );
        emit Appended(
            bytes32(uint(4)),
            0xcbd55f3f5a7a54dbc0189df36d0db9abdd5ecfa0bf59d4a9094169563b0e5c53,
            7
        );
        mmr.multiAppend(elementsToAppend);

        assertEq(mmr.getElementsCount(), 7);
    }
}
