export type VoxelPosition = {
    x: number,
    y: number,
    z: number
}

export type CircuitInputs = {
    x: string,
    y: string,
    z: string,
    seed: string,
    seedCommitment: string
}

export type Groth16ProofCalldata = {
    a: [string, string];
    b: [[string, string], [string, string]];
    c: [string, string];
    input: string[];
};
