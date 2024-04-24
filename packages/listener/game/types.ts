export type VoxelPosition = {
    x: number,
    y: number,
    z: number
}

export type VoxelArea = {
    sizeX: number,
    sizeY: number,
    sizeZ: number
}

export type CircuitInputs = {
    x: string,
    y: string,
    z: string,
    sizeX: string,
    sizeY: string,
    sizeZ: string,
    seed: string,
    seedCommitment: string,
    gameStartBlock: string,
}

export type Groth16ProofCalldata = {
    proof: {
        a: [string, string];
        b: [[string, string], [string, string]];
        c: [string, string];
    },
    publicSignals: string[];
};
