![](/banner.png)

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
    yarn install   # required for the keccak off-chain interoperability tests
    forge build
    forge test                          # default: 10 fuzz runs (fast)
    FOUNDRY_PROFILE=full forge test     # 256 fuzz runs (thorough)
```

## Pluggable Hash Functions

All `StatelessMmr` functions accept a `hasher` parameter:

```solidity
function(bytes32, bytes32) internal pure returns (bytes32)
```

This lets you choose the hashing algorithm without forking the library.
Two ready-made implementations are provided in `src/lib/hashers/`:

| File | Algorithm | Use-case |
|------|-----------|----------|
| `KeccakHasher.sol` | `keccak256(abi.encode(a, b))` | General-purpose EVM hashing (default) |
| `Poseidon2Hasher.sol` | Poseidon2 over BN254 (via [poseidon2-evm](https://github.com/zemse/poseidon2-evm)) | ZK-SNARK / ZK-STARK circuits |

Both expose a single function `hash(bytes32 a, bytes32 b) internal pure returns (bytes32)` that
can be passed directly to any `StatelessMmr` call.

> **Poseidon2 note:** The Poseidon2 implementation operates over the BN254 scalar field.
> Input values are interpreted as field elements without range checking. For full ZK
> compatibility, leaf values should be within the BN254 scalar field
> (< `0x30644e72e131a029b85045b68181585d2833e84879b9709143e1f593f0000001`).
> Internal MMR nodes are always valid field elements because Poseidon2 output is
> reduced modulo the prime.

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

## Usage examples

### Keccak256 MMR (default)

```solidity
import {StatelessMmr} from "solidity-mmr/src/lib/StatelessMmr.sol";
import {KeccakHasher} from "solidity-mmr/src/lib/hashers/KeccakHasher.sol";

contract MyKeccakMmr {
    bytes32[] peaks;
    uint    elementsCount;
    bytes32 root;

    function append(bytes32 element) external {
        (elementsCount, root, peaks) = StatelessMmr.appendWithPeaksRetrieval(
            element, peaks, elementsCount, root, KeccakHasher.hash
        );
    }

    function verifyProof(
        uint index, bytes32 value,
        bytes32[] calldata proof, bytes32[] calldata _peaks,
        uint _elementsCount, bytes32 _root
    ) external pure {
        StatelessMmr.verifyProof(
            index, value, proof, _peaks, _elementsCount, _root,
            KeccakHasher.hash
        );
    }
}
```

### Poseidon2 MMR (ZK-friendly)

```solidity
import {StatelessMmr} from "solidity-mmr/src/lib/StatelessMmr.sol";
import {Poseidon2Hasher} from "solidity-mmr/src/lib/hashers/Poseidon2Hasher.sol";

contract MyPoseidon2Mmr {
    bytes32[] peaks;
    uint    elementsCount;
    bytes32 root;

    function append(bytes32 element) external {
        (elementsCount, root, peaks) = StatelessMmr.appendWithPeaksRetrieval(
            element, peaks, elementsCount, root, Poseidon2Hasher.hash
        );
    }

    function verifyProof(
        uint index, bytes32 value,
        bytes32[] calldata proof, bytes32[] calldata _peaks,
        uint _elementsCount, bytes32 _root
    ) external pure {
        StatelessMmr.verifyProof(
            index, value, proof, _peaks, _elementsCount, _root,
            Poseidon2Hasher.hash
        );
    }
}
```

### Custom hasher

You can pass any function with the signature
`function(bytes32, bytes32) internal pure returns (bytes32)`:

```solidity
function myHasher(bytes32 a, bytes32 b) internal pure returns (bytes32) {
    return sha256(abi.encode(a, b));
}

// Then pass it directly:
StatelessMmr.append(element, peaks, count, root, myHasher);
```

## Generate a proof (keccak)

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

  // Encode `solidityVerifyProof` as calldata to then call verifyProof function in the contract.
  // Verifying a proof does _not_ cost gas (view function), so it can also be done off-chain.
  // You can take a look at `./helpers/off-chain-mmr.js` for a full example.
}

const numberStringToBytes32 = (numberAsString) =>
  utils.hexZeroPad(BigNumber.from(numberAsString).toHexString(), 32);
```

---

Herodotus Dev Ltd - 2023
