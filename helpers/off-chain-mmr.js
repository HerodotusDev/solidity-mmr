const { utils, BigNumber } = require('ethers')
const { default: CoreMMR } = require('@accumulators/merkle-mountain-range')
const { KeccakHasher } = require('@accumulators/hashers')
const { default: MMRInMemoryStore } = require('@accumulators/memory')

async function main() {
    const store = new MMRInMemoryStore()
    const hasher = new KeccakHasher()
    const encoder = new utils.AbiCoder()
    const mmr = new CoreMMR(store, hasher)

    const numberOfAppend = process.argv[2]
    if (!numberOfAppend) throw new Error('Number of append to perform has not been provided')
    const iterations = Number(numberOfAppend)

    const shouldGenerateProofs = process.argv[3] === 'true'

    const providedHashes = process.argv[4]

    const results = []

    const elements = providedHashes
        ? providedHashes.split(';')
        : new Array(iterations).fill(0).map((_, idx) => (idx + 1).toString())

    for (let idx = 0; idx < elements.length; ++idx) {
        const result = await mmr.append(elements[idx])

        if (shouldGenerateProofs) {
            const peaks = await mmr.getPeaks()
            const proof = await mmr.getProof(result.elementIndex)
            results.push({
                index: result.elementIndex.toString(),
                value: numberStringToBytes32(elements[idx]),
                proof: proof.siblingsHashes,
                peaks,
                pos: result.elementsCount.toString(),
                rootHash: result.rootHash,
            })
        } else {
            results.push(result.rootHash)
        }
    }

    if (shouldGenerateProofs) {
        // (uint index, bytes32 value, bytes32[] memory proof, bytes32[] memory peaks, uint pos, bytes32 root)
        const types = ['uint256', 'bytes32', 'bytes32[]', 'bytes32[]', 'uint256', 'bytes32']
        const outputs = []

        for (const result of results) {
            const { index, value, proof, peaks, pos, rootHash } = result
            const formatted = [
                index,
                value,
                proof.map(numberStringToBytes32),
                peaks.map(numberStringToBytes32),
                pos,
                rootHash,
            ]

            // Print each proof and useful values to the standard output
            outputs.push(encoder.encode(types, formatted))
        }
        process.stdout.write(outputs.join(';'))
    } else {
        // Print the root hashes to the standard output
        const onlySendFinalRootHash = process.argv[5] === 'true'

        console.log(
            encoder.encode(
                onlySendFinalRootHash ? ['bytes32'] : ['bytes32[]'],
                onlySendFinalRootHash ? [results[results.length - 1]] : [results]
            )
        )
    }
}

function numberStringToBytes32(numberAsString) {
    // Convert the number string to a BigNumber
    const numberAsBigNumber = BigNumber.from(numberAsString)

    // Convert the BigNumber to a zero-padded hex string
    const hexString = utils.hexZeroPad(numberAsBigNumber.toHexString(), 32)

    return hexString
}

main().catch(console.error)
