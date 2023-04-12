const { utils, BigNumber } = require("ethers"); // Use ethers@5.2.7
const { default: CoreMMR } = require("@herodotus_dev/mmr-core");
const { KeccakHasher } = require("@herodotus_dev/mmr-hashes");
const { default: MMRInMemoryStore } = require("@herodotus_dev/mmr-memory"); // @herodotus_dev/mmr-rocksdb also available

const store = new MMRInMemoryStore();
const hasher = new KeccakHasher();
const mmr = new CoreMMR(store, hasher);

async function main() {
  await mmr.append("1");
  await mmr.append("2");
  const result = await mmr.append("3"); // Element to prove
  const peaks = await mmr.getPeaks();
  await mmr.append("4");

  // Generate an inclusion proof of the third element
  const proof = await mmr.getProof(result.leafIndex);
  const solidityVerifyProof = {
    index: result.leafIndex.toString(),
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
}

const numberStringToBytes32 = (numberAsString) =>
  utils.hexZeroPad(BigNumber.from(numberAsString).toHexString(), 32);

main().catch(console.error);
