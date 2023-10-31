# solidity-mmr

```
  _____       _ _     _ _ _           __  __ __  __ _____
 / ____|     | (_)   | (_) |         |  \/  |  \/  |  __ \
| (___   ___ | |_  __| |_| |_ _   _  | \  / | \  / | |__) |
 \___ \ / _ \| | |/ _` | | __| | | | | |\/| | |\/| |  _  /
 ____) | (_) | | | (_| | | |_| |_| | | |  | | |  | | | \ \
|_____/ \___/|_|_|\__,_|_|\__|\__, | |_|  |_|_|  |_|_|  \_\
                               __/ |
```

Pre-requisites:

- yarn
- Node.js
- Solidity compiler (solc)
- Foundry

_Note: this library can be directly inlined in your contracts and doesn't need to be deployed separately as all functions visibility are internal pure._

## Quick Start

```bash
    yarn install
    forge build
    FOUNDRY_FUZZ_RUNS=10 forge test
```

## Interface API

```typescript
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
```

## Usage example

```typescript
contract MMRExample {
    MMR public mmr;

    constructor() {
        mmr = new MMR();

        // Append a single element
        mmr.append(keccak256(abi.encodePacked(uint(1))));

        bytes32[] memory elementsToAppend = new bytes32[](3);
        elementsToAppend[0] = keccak256(abi.encode(bytes32(uint(2))));
        elementsToAppend[1] = keccak256(abi.encode(bytes32(uint(3))));
        elementsToAppend[2] = keccak256(abi.encode(bytes32(uint(4))));

        // Append multiple elements
        mmr.multiAppend(elementsToAppend);

        // Get the root hash
        bytes32 rootHash = mmr.getRootHash();

        // Get the number of nodes (i.e., tree size)
        uint elementsCount = mmr.getElementsCount();

        // ...
    }

    // Verify an inclusion proof generated off-chain
    function verifyProof(
        uint index,
        bytes32 value,
        bytes32[] memory proof,
        bytes32[] memory peaks,
        uint elementsCount,
        bytes32 root
    ) public view {
        mmr.verifyProof(index, value, proof, peaks, elementsCount, root);
    }
}
```

## Generate a proof

In order to generate a proof, the easiest way is to keep track of the MMR state off-chain and
generate a proof when needed.

The following example shows how to generate a compatible proof in TypeScript:

```typescript
const { utils, BigNumber } = require("ethers"); // Use ethers@5.2.7
const { default: CoreMMR } = require("@herodotus_dev/mmr-core");
const { KeccakHasher } = require("@herodotus_dev/mmr-hashes");
const { default: MMRInMemoryStore } = require("@herodotus_dev/mmr-memory"); // @herodotus_dev/mmr-rocksdb also available

async function main() {
  const store = new MMRInMemoryStore();
  const hasher = new KeccakHasher();
  const encoder = new utils.AbiCoder();
  const mmr = new CoreMMR(store, hasher);

  await mmr.append("1");
  await mmr.append("2");
  const { leafIndex } = await mmr.append("3");
  const peaks = await mmr.getPeaks();
  await mmr.append("4");

  // Generate an inclusion proof of the third element
  const proof = await mmr.getProof(leafIndex);
  const solidityVerifyProof = {
    index: leafIndex.toString(),
    value: numberStringToBytes32("3").toString(),
    proof: proof.siblingsHashes,
    peaks,
    pos: result.elementsCount.toString(),
    rootHash: result.rootHash,
  };
  console.log(solidityVerifyProof);
  // {
  //     index: '4',
  //     value: '0x0000000000000000000000000000000000000000000000000000000000000003',
  //     proof: [
  //         '0x04cde762ef08b6b6c5ded8e8c4c0b3f4e5c9ad7342c88fcc93681b4588b73f05',
  //         '0xf11f11f59e71ab2021e5d939a15985d1b329a7515384f5f0b33fe39db58f5bf6'
  //     ],
  //     peaks: [
  //         '0xf11f11f59e71ab2021e5d939a15985d1b329a7515384f5f0b33fe39db58f5bf6',
  //         '0x83ec6a1f0257b830b5e016457c9cf1435391bf56cc98f369a58a54fe93772465'
  //     ],
  //     pos: '4',
  //     rootHash: '0x9cf52726b5c1f29825fa3757402809afeb76f510e83e95559d9a5504a243b373'
  // }

  // Encode `solidityVerifyProof` as calldata to then call verifyProof function in the contract.
  // Verifying a proof does _not_ cost gas (view function), so it can also be done off-chain.
  // You can take a look at `./helpers/off-chain-mmr.js` for a full example.

  // ...
}

const numberStringToBytes32 = (numberAsString) =>
  utils.hexZeroPad(BigNumber.from(numberAsString).toHexString(), 32);
```

---

Herodotus Dev Ltd - 2023
