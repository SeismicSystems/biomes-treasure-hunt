import { groth16, Groth16Proof } from "snarkjs";
import { CircuitInputs, Groth16ProofCalldata } from "../game/types";

const circuitWasmPath = "../circuits/build/circuit.wasm";
const circuitZkeyPath = "../circuits/build/circuit.zkey";

const exportCallDataGroth16 = async (
    prf: Groth16Proof,
    pubSigs: any
): Promise<Groth16ProofCalldata> => {
    const proofCalldata: string = await groth16.exportSolidityCallData(
        prf,
        pubSigs
    );
    const argv: string[] = proofCalldata
        .replace(/["[\]\s]/g, "")
        .split(",")
        .map((x: string) => BigInt(x).toString());
    return {
        proof: {
            a: argv.slice(0, 2) as [string, string],
            b: [
                argv.slice(2, 4) as [string, string],
                argv.slice(4, 6) as [string, string],
            ],
            c: argv.slice(6, 8) as [string, string],
        },
        publicSignals: argv.slice(8),
    };
}

export const proveCircuit = async (
    inputs: CircuitInputs
): Promise<Groth16ProofCalldata> => {
    const { proof, publicSignals } = await groth16.fullProve(
        inputs,
        circuitWasmPath,
        circuitZkeyPath
    );

    return await exportCallDataGroth16(proof, publicSignals);
}
