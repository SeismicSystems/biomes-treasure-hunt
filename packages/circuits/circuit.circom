pragma circom 2.1.1;

include "node_modules/circomlib/circuits/poseidon.circom";
include "node_modules/circomlib/circuits/comparators.circom";
include "perlin/perlin.circom";

template Main() {
    signal input x;
    signal input y;
    signal input z;
    signal input seedCommitment;

    signal input seed;

    signal output out;

    var perlin = 10;

    signal circuitSeedCommitment <== Poseidon(1)([seed]);
    signal seedCommitmentCorrect <== IsEqual()([seedCommitment, circuitSeedCommitment]);
    seedCommitmentCorrect === 1;

    out <== perlin;
}

component main { public [ seedCommitment ] } = Main();