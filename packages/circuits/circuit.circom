pragma circom 2.1.1;

include "node_modules/circomlib/circuits/poseidon.circom";
include "node_modules/circomlib/circuits/comparators.circom";
include "node_modules/circomlib/circuits/gates.circom";
include "perlin/perlin.circom";

template CheckSeedCommitment() {
    signal input seedCommitment;
    signal input seed;
    signal output out;

    signal circuitSeedCommitment <== Poseidon(1)([seed]);
    out <== IsEqual()([seedCommitment, circuitSeedCommitment]);
}

template GetMod(N, N_BITS) {
    signal input size;
    signal input seed;
    signal input gameStartBlock;
    signal output out;

    signal random <== Poseidon(2)([seed + N, gameStartBlock]);
    out <-- random % size;
    signal divisor <-- (random - out) \ size;
    random === size * divisor + out;

    signal remainderLB <== LessEqThan(N_BITS)([0, out]);
    remainderLB === 1;

    signal remainderUB <== LessThan(N_BITS)([out, size]);
    remainderUB === 1;
}

template AbsoluteDistance(N_BITS) {
    signal input a;
    signal input b;
    signal output out;

    signal aLTB <== LessThan(N_BITS)([a, b]);
    signal ifALTB <== aLTB * (b - a);

    out <== ifALTB + (1 - aLTB) * (a - b);
}

template Main() {
    signal input seedCommitment;
    signal input gameStartBlock;
    // already offseted, so (0, 0, 0) is the corner of potential reward zone
    signal input x;
    signal input y;
    signal input z;
    signal input sizeX;
    signal input sizeY;
    signal input sizeZ;

    signal input seed;

    signal output out;

    var N_BITS = 20;

    signal seedCommitmentCorrect <== CheckSeedCommitment()(seedCommitment, seed);
    seedCommitmentCorrect === 1;

    signal rewardCornerX <== GetMod(0, N_BITS)(sizeX, seed, gameStartBlock);
    signal rewardCornerY <== GetMod(1, N_BITS)(sizeY, seed, gameStartBlock);
    signal rewardCornerZ <== GetMod(2, N_BITS)(sizeZ, seed, gameStartBlock);

    signal rewardSizeX <== GetMod(3, N_BITS)(sizeX - rewardCornerX, seed, gameStartBlock);
    signal rewardSizeY <== GetMod(4, N_BITS)(sizeY - rewardCornerY, seed, gameStartBlock);
    signal rewardSizeZ <== GetMod(5, N_BITS)(sizeZ - rewardCornerZ, seed, gameStartBlock);

    signal rewardCenterX <-- (rewardCornerX + (rewardCornerX + rewardSizeX)) \ 2;
    signal rewardCenterXEven <== IsEqual()([rewardCenterX * 2, rewardCornerX + (rewardCornerX + rewardSizeX)]);
    signal rewardCenterXOdd <== IsEqual()([rewardCenterX * 2 + 1, rewardCornerX + (rewardCornerX + rewardSizeX)]);
    signal rewardCenterXCorrect <== OR()(rewardCenterXEven, rewardCenterXOdd);
    rewardCenterXCorrect === 1;

    signal rewardCenterY <-- (rewardCornerY + (rewardCornerY + rewardSizeY)) \ 2;
    signal rewardCenterYEven <== IsEqual()([rewardCenterY * 2, rewardCornerY + (rewardCornerY + rewardSizeY)]);
    signal rewardCenterYOdd <== IsEqual()([rewardCenterY * 2 + 1, rewardCornerY + (rewardCornerY + rewardSizeY)]);
    signal rewardCenterYCorrect <== OR()(rewardCenterYEven, rewardCenterYOdd);
    rewardCenterYCorrect === 1;

    signal rewardCenterZ <-- (rewardCornerZ + (rewardCornerZ + rewardSizeZ)) \ 2;
    signal rewardCenterZEven <== IsEqual()([rewardCenterZ * 2, rewardCornerZ + (rewardCornerZ + rewardSizeZ)]);
    signal rewardCenterZOdd <== IsEqual()([rewardCenterZ * 2 + 1, rewardCornerZ + (rewardCornerZ + rewardSizeZ)]);
    signal rewardCenterZCorrect <== OR()(rewardCenterZEven, rewardCenterZOdd);
    rewardCenterZCorrect === 1;
 
    log("reward corner: ", rewardCornerX, rewardCornerY, rewardCornerZ);
    log("reward size: ", rewardSizeX, rewardSizeY, rewardSizeZ);
    log("reward center: ", rewardCenterX, rewardCenterY, rewardCenterZ);

    
    signal xInRewardLB <== LessEqThan(N_BITS)([rewardCornerX, x]);
    signal xInRewardUB <== LessEqThan(N_BITS)([x, rewardCornerX + rewardSizeX]);
    signal xInReward <== AND()(xInRewardLB, xInRewardUB);
    
    signal yInRewardLB <== LessEqThan(N_BITS)([rewardCornerY, y]);
    signal yInRewardUB <== LessEqThan(N_BITS)([y, rewardCornerY + rewardSizeY]);
    signal yInReward <== AND()(yInRewardLB, yInRewardUB);

    signal zInRewardLB <== LessEqThan(N_BITS)([rewardCornerZ, z]);
    signal zInRewardUB <== LessEqThan(N_BITS)([z, rewardCornerZ + rewardSizeZ]);
    signal zInReward <== AND()(zInRewardLB, zInRewardUB);

    signal intermediateAnd <== AND()(xInReward, yInReward);
    signal inRewardZone <== AND()(intermediateAnd, zInReward);
    log("xInReward: ", xInReward);
    log("yInReward: ", yInReward);
    log("zInReward: ", zInReward);
    log("inRewardZone: ", inRewardZone);

    signal maxReward <== 
        rewardCornerX + rewardSizeX - rewardCenterX 
        + rewardCornerY + rewardSizeY - rewardCenterY 
        + rewardCornerZ + rewardSizeZ - rewardCenterZ;
    log("max reward: ", maxReward);
    
    signal distX <== AbsoluteDistance(N_BITS)(x, rewardCenterX);
    signal distY <== AbsoluteDistance(N_BITS)(y, rewardCenterY);
    signal distZ <== AbsoluteDistance(N_BITS)(z, rewardCenterZ);

    // out <== inRewardZone * (maxReward - (distX + distY + distZ));

    signal rewardPreChance <== inRewardZone * (maxReward - (distX + distY + distZ));

    signal roll <== GetMod(6, N_BITS)(3, seed, gameStartBlock);
    signal rollFail <== IsEqual()([roll, 0]);
    signal rollSuccess <== NOT()(rollFail);

    log("roll: ", roll);

    out <== rollSuccess * rewardPreChance;
}

component main { public [ seedCommitment, gameStartBlock, x, y, z, sizeX, sizeY, sizeZ ] } = Main();