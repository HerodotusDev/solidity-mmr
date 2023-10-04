// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

library StatelessMmrHelpers {
    // Returns the height of a given `index`. The height of the root is 0
    function getHeight(uint index) internal pure returns (uint) {
        require(index >= 1, "index must be at least 1");

        uint bits = bitLength(index);
        uint ones = allOnes(bits);

        if (index != ones) {
            uint shifted = 1 << (bits - 1);
            uint recHeight = getHeight(index - (shifted - 1));
            return recHeight;
        }

        return bits - 1;
    }

    // Returns the number of bits in `num`
    function bitLength(uint256 num) internal pure returns (uint256) {
        require(num >= 0, "num must be greater than or equal to zero");

        uint256 bitPosition = 0;
        uint256 curN = 1;
        while (num >= curN) {
            bitPosition += 1;
            curN <<= 1;
        }
        return bitPosition;
    }

    // Returns a number having all its bits set to 1 for a given `bitsLength`
    function allOnes(uint256 bitsLength) internal pure returns (uint256) {
        require(bitsLength >= 0, "bitsLength must be greater or equal to zero");
        return (1 << bitsLength) - 1;
    }

    // Returns a number of ones in bit representation of a number
    function countOnes(uint256 num) internal pure returns (uint256) {
        uint256 count = 0;
        for (; num > 0; count++) {
            num = num & (num - 1);
        }
        return count;
    }

    // Returns the sibling offset from `height`
    function siblingOffset(uint256 height) internal pure returns (uint256) {
        return (2 << height) - 1;
    }

    // Returns the parent offset from `height`
    function parentOffset(uint256 height) internal pure returns (uint256) {
        return 2 << height;
    }

    // Returns number of leaves for a given mmr size
    function mmrSizeToLeafCount(uint256 mmrSize) internal pure returns (uint256) {
        uint256 leafCount = 0;
        uint256 mountainLeafCount = 1 << bitLength(mmrSize);
        for(; mountainLeafCount > 0; mountainLeafCount /= 2) {
            uint256 mountainSize = 2 * mountainLeafCount - 1;
            if (mountainSize <= mmrSize) {
                leafCount += mountainLeafCount;
                mmrSize -= mountainSize;
            }
        }
        require(mmrSize == 0, "mmrSize can't be associated with a valid MMR size");
        return leafCount;
    }


    // Creates a new array from source and returns a new one containing all previous elements + `elem`
    function newArrWithElem(
        bytes32[] memory sourceArr,
        bytes32 elem
    ) internal pure returns (bytes32[] memory) {
        bytes32[] memory outputArray = new bytes32[](sourceArr.length + 1);
        uint i = 0;
        for (; i < sourceArr.length; i++) {
            outputArray[i] = sourceArr[i];
        }
        outputArray[i] = elem;
        return outputArray;
    }

    // Returns true if `elem` is in `arr`
    function arrayContains(
        bytes32 elem,
        bytes32[] memory arr
    ) internal pure returns (bool) {
        for (uint i = 0; i < arr.length; ++i) {
            if (arr[i] == elem) {
                return true;
            }
        }
        return false;
    }
}
