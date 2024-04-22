/*
 * Adapted from darkforest-v0.6's implementation of perlin noise. All
 * credit is due to the Darkforest team for the original source.
 * Original source: https://github.com/darkforest-eth/darkforest-v0.6. 
 * Only change is import paths.
 */

pragma circom 2.0.3;

include "../node_modules/circomlib/circuits/mimcsponge.circom";
include "../node_modules/circomlib/circuits/comparators.circom";
include "../node_modules/circomlib/circuits/sign.circom";
include "../node_modules/circomlib/circuits/bitify.circom";
include "../range_proof/circuit.circom";
include "QuinSelector.circom";

// input: three field elements: x, y, scale (all absolute value < 2^32)
// output: pseudorandom integer in [0, 15]
template Random() {
    signal input in[4];
    signal input KEY;
    signal output out;

    component mimc = MiMCSponge(4, 4, 1);

    mimc.ins[0] <== in[0];
    mimc.ins[1] <== in[1];
    mimc.ins[2] <== in[2];
    mimc.ins[3] <== in[3];
    mimc.k <== KEY;

    component num2Bits = Num2Bits(254);
    num2Bits.in <== mimc.outs[0];
    out <== num2Bits.out[4] * 16 + num2Bits.out[3] * 8 + num2Bits.out[2] * 4 + num2Bits.out[1] * 2 + num2Bits.out[0];
}

// input: any field elements
// output: 1 if field element is in (p/2, p-1], 0 otherwise
template IsNegative() {
    signal input in;
    signal output out;

    component num2Bits = Num2Bits(254);
    num2Bits.in <== in;
    component sign = Sign();

    for (var i = 0; i < 254; i++) {
        sign.in[i] <== num2Bits.out[i];
    }

    out <== sign.sign;
}

// input: dividend and divisor field elements in [0, sqrt(p))
// output: remainder and quotient field elements in [0, p-1] and [0, sqrt(p)
// Haven't thought about negative divisor yet. Not needed.
// -8 % 5 = 2. [-8 -> 8. 8 % 5 -> 3. 5 - 3 -> 2.]
// (-8 - 2) // 5 = -2
// -8 + 2 * 5 = 2
// check: 2 - 2 * 5 = -8
template Modulo(divisor_bits, SQRT_P) {
    signal input dividend; // -8
    signal input divisor; // 5
    signal output remainder; // 2
    signal output quotient; // -2

    component is_neg = IsNegative();
    is_neg.in <== dividend;

    signal output is_dividend_negative;
    is_dividend_negative <== is_neg.out;

    signal output dividend_adjustment;
    dividend_adjustment <== 1 + is_dividend_negative * -2; // 1 or -1

    signal output abs_dividend;
    abs_dividend <== dividend * dividend_adjustment; // 8

    signal output raw_remainder;
    raw_remainder <-- abs_dividend % divisor;

    signal output neg_remainder;
    neg_remainder <-- divisor - raw_remainder;

    // 0xsage: https://github.com/0xSage/nightmarket/blob/fc4e5264436c75d37940fead3f47d650927a9120/circuits/list/Perlin.circom#L93-L108
    component raw_rem_is_zero = IsZero();
    raw_rem_is_zero.in <== raw_remainder;

    signal raw_rem_not_zero;
    raw_rem_not_zero <== 1 - raw_rem_is_zero.out;

    signal iff;
    iff <== is_dividend_negative * raw_rem_not_zero;

    signal is_neg_remainder;
    is_neg_remainder <== neg_remainder * iff;

    signal elsef;
    elsef <== 1 - iff;

    remainder <== raw_remainder * elsef + is_neg_remainder;

    quotient <-- (dividend - remainder) / divisor; // (-8 - 2) / 5 = -2.

    dividend === divisor * quotient + remainder; // -8 = 5 * -2 + 2.

    component rp = MultiRangeProof(3, 128);
    rp.in[0] <== divisor;
    rp.in[1] <== quotient;
    rp.in[2] <== dividend;
    rp.max_abs_value <== SQRT_P;

    // check that 0 <= remainder < divisor
    component remainderUpper = LessThan(divisor_bits);
    remainderUpper.in[0] <== remainder;
    remainderUpper.in[1] <== divisor;
    remainderUpper.out === 1;
}

// input: three field elements x, y, scale (all absolute value < 2^32)
// output: (NUMERATORS) a random unit vector in one of 16 directions
template RandomGradientAt(DENOMINATOR) {
    var vecs[32][3] = [
        [1000, 0, 0], [-1000, 0, 0], [0, 1000, 0], [0, -1000, 0], [0, 0, 1000], [0, 0, -1000],
        [707, 707, 0], [-707, 707, 0], [707, -707, 0], [-707, -707, 0],
        [707, 0, 707], [-707, 0, 707], [707, 0, -707], [-707, 0, -707],
        [0, 707, 707], [0, -707, 707], [0, 707, -707], [0, -707, -707],
        [577, 577, 577], [-577, 577, 577], [577, -577, 577], [-577, -577, 577],
        [577, 577, -577], [-577, 577, -577], [577, -577, -577], [-577, -577, -577],
        [1000, 0, 0], [-1000, 0, 0], [0, 1000, 0], [0, -1000, 0], [0, 0, 1000], [0, 0, -1000]
    ];

    signal input in[3];
    signal input scale;
    signal input KEY;

    signal output out[3];
    component rand = Random();
    rand.in[0] <== in[0];
    rand.in[1] <== in[1];
    rand.in[2] <== in[2];
    rand.in[3] <== scale;
    rand.KEY <== KEY;
    component xSelector = QuinSelector(32);
    component ySelector = QuinSelector(32);
    component zSelector = QuinSelector(32);
    for (var i = 0; i < 32; i++) {
        xSelector.in[i] <== vecs[i][0];
        ySelector.in[i] <== vecs[i][1];
        zSelector.in[i] <== vecs[i][2];
    }
    log("RAND");
    log(rand.out);
    xSelector.index <== rand.out;
    ySelector.index <== rand.out;
    zSelector.index <== rand.out;

    signal vectorDenominator;
    vectorDenominator <== DENOMINATOR / 1000;

    out[0] <== xSelector.out * vectorDenominator;
    out[1] <== ySelector.out * vectorDenominator;
    out[2] <== zSelector.out * vectorDenominator;
}

// input: x, y, scale (field elements absolute value < 2^32)
// output: 4 corners of a square with sidelen = scale (INTEGER coords)
// and parallel array of 4 gradient vectors (NUMERATORS)
template GetCornersAndGradVectors(scale_bits, DENOMINATOR, SQRT_P) {
    signal input p[3];
    signal input scale;
    signal input KEY;

    component xmodulo = Modulo(scale_bits, SQRT_P);
    xmodulo.dividend <== p[0];
    xmodulo.divisor <== scale;

    component ymodulo = Modulo(scale_bits, SQRT_P);
    ymodulo.dividend <== p[1];
    ymodulo.divisor <== scale;

    component zmodulo = Modulo(scale_bits, SQRT_P);
    zmodulo.dividend <== p[2];
    zmodulo.divisor <== scale;

        signal bottomLeftBackCoords[3];
    bottomLeftBackCoords[0] <== p[0] - xmodulo.remainder;
    bottomLeftBackCoords[1] <== p[1] - ymodulo.remainder;
    bottomLeftBackCoords[2] <== p[2] - zmodulo.remainder;

    signal bottomRightBackCoords[3];
    bottomRightBackCoords[0] <== bottomLeftBackCoords[0] + scale;
    bottomRightBackCoords[1] <== bottomLeftBackCoords[1];
    bottomRightBackCoords[2] <== bottomLeftBackCoords[2];

    signal topLeftBackCoords[3];
    topLeftBackCoords[0] <== bottomLeftBackCoords[0];
    topLeftBackCoords[1] <== bottomLeftBackCoords[1] + scale;
    topLeftBackCoords[2] <== bottomLeftBackCoords[2];

    signal topRightBackCoords[3];
    topRightBackCoords[0] <== bottomLeftBackCoords[0] + scale;
    topRightBackCoords[1] <== bottomLeftBackCoords[1] + scale;
    topRightBackCoords[2] <== bottomLeftBackCoords[2];

    signal bottomLeftFrontCoords[3];
    bottomLeftFrontCoords[0] <== bottomLeftBackCoords[0];
    bottomLeftFrontCoords[1] <== bottomLeftBackCoords[1];
    bottomLeftFrontCoords[2] <== bottomLeftBackCoords[2] + scale;

    signal bottomRightFrontCoords[3];
    bottomRightFrontCoords[0] <== bottomLeftBackCoords[0] + scale;
    bottomRightFrontCoords[1] <== bottomLeftBackCoords[1];
    bottomRightFrontCoords[2] <== bottomLeftBackCoords[2] + scale;

    signal topLeftFrontCoords[3];
    topLeftFrontCoords[0] <== bottomLeftBackCoords[0];
    topLeftFrontCoords[1] <== bottomLeftBackCoords[1] + scale;
    topLeftFrontCoords[2] <== bottomLeftBackCoords[2] + scale;

    signal topRightFrontCoords[3];
    topRightFrontCoords[0] <== bottomLeftBackCoords[0] + scale;
    topRightFrontCoords[1] <== bottomLeftBackCoords[1] + scale;
    topRightFrontCoords[2] <== bottomLeftBackCoords[2] + scale;

    component bottomLeftBackRandGrad = RandomGradientAt(DENOMINATOR);
    bottomLeftBackRandGrad.in[0] <== bottomLeftBackCoords[0];
    bottomLeftBackRandGrad.in[1] <== bottomLeftBackCoords[1];
    bottomLeftBackRandGrad.in[2] <== bottomLeftBackCoords[2];
    bottomLeftBackRandGrad.scale <== scale;
    bottomLeftBackRandGrad.KEY <== KEY;
    signal bottomLeftBackGrad[3];
    bottomLeftBackGrad[0] <== bottomLeftBackRandGrad.out[0];
    bottomLeftBackGrad[1] <== bottomLeftBackRandGrad.out[1];
    bottomLeftBackGrad[2] <== bottomLeftBackRandGrad.out[2];

    component bottomRightBackRandGrad = RandomGradientAt(DENOMINATOR);
    bottomRightBackRandGrad.in[0] <== bottomRightBackCoords[0];
    bottomRightBackRandGrad.in[1] <== bottomRightBackCoords[1];
    bottomRightBackRandGrad.in[2] <== bottomRightBackCoords[2];
    bottomRightBackRandGrad.scale <== scale;
    bottomRightBackRandGrad.KEY <== KEY;
    signal bottomRightBackGrad[3];
    bottomRightBackGrad[0] <== bottomRightBackRandGrad.out[0];
    bottomRightBackGrad[1] <== bottomRightBackRandGrad.out[1];
    bottomRightBackGrad[2] <== bottomRightBackRandGrad.out[2];

    component topLeftBackRandGrad = RandomGradientAt(DENOMINATOR);
    topLeftBackRandGrad.in[0] <== topLeftBackCoords[0];
    topLeftBackRandGrad.in[1] <== topLeftBackCoords[1];
    topLeftBackRandGrad.in[2] <== topLeftBackCoords[2];
    topLeftBackRandGrad.scale <== scale;
    topLeftBackRandGrad.KEY <== KEY;
    signal topLeftBackGrad[3];
    topLeftBackGrad[0] <== topLeftBackRandGrad.out[0];
    topLeftBackGrad[1] <== topLeftBackRandGrad.out[1];
        topLeftBackGrad[2] <== topLeftBackRandGrad.out[2];

    component topRightBackRandGrad = RandomGradientAt(DENOMINATOR);
    topRightBackRandGrad.in[0] <== topRightBackCoords[0];
    topRightBackRandGrad.in[1] <== topRightBackCoords[1];
    topRightBackRandGrad.in[2] <== topRightBackCoords[2];
    topRightBackRandGrad.scale <== scale;
    topRightBackRandGrad.KEY <== KEY;
    signal topRightBackGrad[3];
    topRightBackGrad[0] <== topRightBackRandGrad.out[0];
    topRightBackGrad[1] <== topRightBackRandGrad.out[1];
    topRightBackGrad[2] <== topRightBackRandGrad.out[2];

    component bottomLeftFrontRandGrad = RandomGradientAt(DENOMINATOR);
    bottomLeftFrontRandGrad.in[0] <== bottomLeftFrontCoords[0];
    bottomLeftFrontRandGrad.in[1] <== bottomLeftFrontCoords[1];
    bottomLeftFrontRandGrad.in[2] <== bottomLeftFrontCoords[2];
    bottomLeftFrontRandGrad.scale <== scale;
    bottomLeftFrontRandGrad.KEY <== KEY;
    signal bottomLeftFrontGrad[3];
    bottomLeftFrontGrad[0] <== bottomLeftFrontRandGrad.out[0];
    bottomLeftFrontGrad[1] <== bottomLeftFrontRandGrad.out[1];
    bottomLeftFrontGrad[2] <== bottomLeftFrontRandGrad.out[2];

    component bottomRightFrontRandGrad = RandomGradientAt(DENOMINATOR);
    bottomRightFrontRandGrad.in[0] <== bottomRightFrontCoords[0];
    bottomRightFrontRandGrad.in[1] <== bottomRightFrontCoords[1];
    bottomRightFrontRandGrad.in[2] <== bottomRightFrontCoords[2];
    bottomRightFrontRandGrad.scale <== scale;
    bottomRightFrontRandGrad.KEY <== KEY;
    signal bottomRightFrontGrad[3];
    bottomRightFrontGrad[0] <== bottomRightFrontRandGrad.out[0];
    bottomRightFrontGrad[1] <== bottomRightFrontRandGrad.out[1];
    bottomRightFrontGrad[2] <== bottomRightFrontRandGrad.out[2];

    component topLeftFrontRandGrad = RandomGradientAt(DENOMINATOR);
    topLeftFrontRandGrad.in[0] <== topLeftFrontCoords[0];
    topLeftFrontRandGrad.in[1] <== topLeftFrontCoords[1];
    topLeftFrontRandGrad.in[2] <== topLeftFrontCoords[2];
    topLeftFrontRandGrad.scale <== scale;
    topLeftFrontRandGrad.KEY <== KEY;
    signal topLeftFrontGrad[3];
    topLeftFrontGrad[0] <== topLeftFrontRandGrad.out[0];
    topLeftFrontGrad[1] <== topLeftFrontRandGrad.out[1];
    topLeftFrontGrad[2] <== topLeftFrontRandGrad.out[2];

    component topRightFrontRandGrad = RandomGradientAt(DENOMINATOR);
    topRightFrontRandGrad.in[0] <== topRightFrontCoords[0];
    topRightFrontRandGrad.in[1] <== topRightFrontCoords[1];
    topRightFrontRandGrad.in[2] <== topRightFrontCoords[2];
    topRightFrontRandGrad.scale <== scale;
    topRightFrontRandGrad.KEY <== KEY;
    signal topRightFrontGrad[3];
    topRightFrontGrad[0] <== topRightFrontRandGrad.out[0];
    topRightFrontGrad[1] <== topRightFrontRandGrad.out[1];
    topRightFrontGrad[2] <== topRightFrontRandGrad.out[2];

    signal output grads[8][3];
    signal output coords[8][3];

    // INTS
    coords[0][0] <== bottomLeftBackCoords[0];
    coords[0][1] <== bottomLeftBackCoords[1];
    coords[0][2] <== bottomLeftBackCoords[2];
    coords[1][0] <== bottomRightBackCoords[0];
    coords[1][1] <== bottomRightBackCoords[1];
    coords[1][2] <== bottomRightBackCoords[2];
    coords[2][0] <== topLeftBackCoords[0];
    coords[2][1] <== topLeftBackCoords[1];
    coords[2][2] <== topLeftBackCoords[2];
        coords[3][0] <== topRightBackCoords[0];
    coords[3][1] <== topRightBackCoords[1];
    coords[3][2] <== topRightBackCoords[2];
    coords[4][0] <== bottomLeftFrontCoords[0];
    coords[4][1] <== bottomLeftFrontCoords[1];
    coords[4][2] <== bottomLeftFrontCoords[2];
    coords[5][0] <== bottomRightFrontCoords[0];
    coords[5][1] <== bottomRightFrontCoords[1];
    coords[5][2] <== bottomRightFrontCoords[2];
    coords[6][0] <== topLeftFrontCoords[0];
    coords[6][1] <== topLeftFrontCoords[1];
    coords[6][2] <== topLeftFrontCoords[2];
    coords[7][0] <== topRightFrontCoords[0];
    coords[7][1] <== topRightFrontCoords[1];
    coords[7][2] <== topRightFrontCoords[2];

    // FRACTIONS
    grads[0][0] <== bottomLeftBackGrad[0];
    grads[0][1] <== bottomLeftBackGrad[1];
    grads[0][2] <== bottomLeftBackGrad[2];
    grads[1][0] <== bottomRightBackGrad[0];
    grads[1][1] <== bottomRightBackGrad[1];
    grads[1][2] <== bottomRightBackGrad[2];
    grads[2][0] <== topLeftBackGrad[0];
    grads[2][1] <== topLeftBackGrad[1];
    grads[2][2] <== topLeftBackGrad[2];
    grads[3][0] <== topRightBackGrad[0];
    grads[3][1] <== topRightBackGrad[1];
    grads[3][2] <== topRightBackGrad[2];
    grads[4][0] <== bottomLeftFrontGrad[0];
    grads[4][1] <== bottomLeftFrontGrad[1];
    grads[4][2] <== bottomLeftFrontGrad[2];
    grads[5][0] <== bottomRightFrontGrad[0];
    grads[5][1] <== bottomRightFrontGrad[1];
    grads[5][2] <== bottomRightFrontGrad[2];
    grads[6][0] <== topLeftFrontGrad[0];
    grads[6][1] <== topLeftFrontGrad[1];
    grads[6][2] <== topLeftFrontGrad[2];
    grads[7][0] <== topRightFrontGrad[0];
    grads[7][1] <== topRightFrontGrad[1];
    grads[7][2] <== topRightFrontGrad[2];

    // signal bottomLeftCoords[2];
    // bottomLeftCoords[0] <== p[0] - xmodulo.remainder;
    // bottomLeftCoords[1] <== p[1] - ymodulo.remainder;

    // signal bottomRightCoords[2];
    // bottomRightCoords[0] <== bottomLeftCoords[0] + scale;
    // bottomRightCoords[1] <== bottomLeftCoords[1];

    // signal topLeftCoords[2];
    // topLeftCoords[0] <== bottomLeftCoords[0];
    // topLeftCoords[1] <== bottomLeftCoords[1] + scale;

    // signal topRightCoords[2];
    // topRightCoords[0] <== bottomLeftCoords[0] + scale;
    // topRightCoords[1] <== bottomLeftCoords[1] + scale;

    // component bottomLeftRandGrad = RandomGradientAt(DENOMINATOR);
    // bottomLeftRandGrad.in[0] <== bottomLeftCoords[0];
    // bottomLeftRandGrad.in[1] <== bottomLeftCoords[1];
    // bottomLeftRandGrad.scale <== scale;
    // bottomLeftRandGrad.KEY <== KEY;
    // signal bottomLeftGrad[2];
    // bottomLeftGrad[0] <== bottomLeftRandGrad.out[0];
    // bottomLeftGrad[1] <== bottomLeftRandGrad.out[1];

    // component bottomRightRandGrad = RandomGradientAt(DENOMINATOR);
    // bottomRightRandGrad.in[0] <== bottomRightCoords[0];
    // bottomRightRandGrad.in[1] <== bottomRightCoords[1];
    // bottomRightRandGrad.scale <== scale;
    // bottomRightRandGrad.KEY <== KEY;
    // signal bottomRightGrad[2];
    // bottomRightGrad[0] <== bottomRightRandGrad.out[0];
    // bottomRightGrad[1] <== bottomRightRandGrad.out[1];

    // component topLeftRandGrad = RandomGradientAt(DENOMINATOR);
    // topLeftRandGrad.in[0] <== topLeftCoords[0];
    // topLeftRandGrad.in[1] <== topLeftCoords[1];
    // topLeftRandGrad.scale <== scale;
    // topLeftRandGrad.KEY <== KEY;
    // signal topLeftGrad[2];
    // topLeftGrad[0] <== topLeftRandGrad.out[0];
    // topLeftGrad[1] <== topLeftRandGrad.out[1];

    // component topRightRandGrad = RandomGradientAt(DENOMINATOR);
    // topRightRandGrad.in[0] <== topRightCoords[0];
    // topRightRandGrad.in[1] <== topRightCoords[1];
    // topRightRandGrad.scale <== scale;
    // topRightRandGrad.KEY <== KEY;
    // signal topRightGrad[2];
    // topRightGrad[0] <== topRightRandGrad.out[0];
    // topRightGrad[1] <== topRightRandGrad.out[1];

    // signal output grads[4][2];
    // signal output coords[4][2];

    // // INTS
    // coords[0][0] <== bottomLeftCoords[0];
    // coords[0][1] <== bottomLeftCoords[1];
    // coords[1][0] <== bottomRightCoords[0];
    // coords[1][1] <== bottomRightCoords[1];
    // coords[2][0] <== topLeftCoords[0];
    // coords[2][1] <== topLeftCoords[1];
    // coords[3][0] <== topRightCoords[0];
    // coords[3][1] <== topRightCoords[1];


    // // FRACTIONS
    // grads[0][0] <== bottomLeftGrad[0];
    // grads[0][1] <== bottomLeftGrad[1];
    // grads[1][0] <== bottomRightGrad[0];
    // grads[1][1] <== bottomRightGrad[1];
    // grads[2][0] <== topLeftGrad[0];
    // grads[2][1] <== topLeftGrad[1];
    // grads[3][0] <== topRightGrad[0];
    // grads[3][1] <== topRightGrad[1];
}

// @0xSage: consolidated template for Circom2 compatibility
// https://github.com/0xSage/nightmarket/blob/fc4e5264436c75d37940fead3f47d650927a9120/circuits/list/Perlin.circom#L254-L283
// In order: BL, BR, TL, TR
// input: corner is FRAC NUMERATORS of scale x scale square, scaled down to unit square
// p is FRAC NUMERATORS of a point inside a scale x scale that was scaled down to unit sqrt
// output: FRAC NUMERATOR of weight of the gradient at this corner for this point
template GetWeight(DENOMINATOR, WHICHCORNER) {
    signal input corner[3];
    signal input p[3];

    signal diff[3];

    if (WHICHCORNER == 0) {
        diff[0] <== p[0] - corner[0];
        diff[1] <== p[1] - corner[1];
        diff[2] <== p[2] - corner[2];
    } else if (WHICHCORNER == 1) {
        diff[0] <== corner[0] - p[0];
        diff[1] <== p[1] - corner[1];
        diff[2] <== p[2] - corner[2];
    } else if (WHICHCORNER == 2) {
        diff[0] <== p[0] - corner[0];
        diff[1] <== corner[1] - p[1];
        diff[2] <== p[2] - corner[2];
    } else if (WHICHCORNER == 3) {
        diff[0] <== corner[0] - p[0];
        diff[1] <== corner[1] - p[1];
        diff[2] <== p[2] - corner[2];
    } else if (WHICHCORNER == 4) {
        diff[0] <== p[0] - corner[0];
        diff[1] <== p[1] - corner[1];
        diff[2] <== corner[2] - p[2];
    } else if (WHICHCORNER == 5) {
        diff[0] <== corner[0] - p[0];
        diff[1] <== p[1] - corner[1];
        diff[2] <== corner[2] - p[2];
    } else if (WHICHCORNER == 6) {
        diff[0] <== p[0] - corner[0];
        diff[1] <== corner[1] - p[1];
        diff[2] <== corner[2] - p[2];
    } else if (WHICHCORNER == 7) {
        diff[0] <== corner[0] - p[0];
        diff[1] <== corner[1] - p[1];
        diff[2] <== corner[2] - p[2];
    }

    signal factor[3];
    factor[0] <== DENOMINATOR - diff[0];
    factor[1] <== DENOMINATOR - diff[1];
    factor[2] <== DENOMINATOR - diff[2];

    signal intermediate;
    signal nominator;
    intermediate <== factor[0] * factor[1];
    nominator <== intermediate * factor[2];
    signal output out;
    out <-- nominator / DENOMINATOR;
    nominator === out * DENOMINATOR;
}

// dot product of two vector NUMERATORS
template Dot(DENOMINATOR) {
    signal input a[3]; // Updated to 3D
    signal input b[3]; // Updated to 3D
    signal prod[3]; // Updated to 3D
    signal sum;
    signal output out;

    prod[0] <== a[0] * b[0];
    prod[1] <== a[1] * b[1];
    prod[2] <== a[2] * b[2]; // Added for 3D

    sum <== prod[0] + prod[1] + prod[2]; // Updated for 3D
    out <-- sum / DENOMINATOR;
    sum === out * DENOMINATOR;
}

// input: 4 gradient unit vectors (NUMERATORS)
// corner coords of a scale x scale square (ints)
// point inside (int world coords)
template PerlinValue(DENOMINATOR) {
    signal input grads[8][3];
    signal input coords[8][3];
    signal input scale;
    signal input p[3];

    component getWeights[8];
    for (var i = 0; i < 8; i++) {
        getWeights[i] = GetWeight(DENOMINATOR, i);
    }

    signal distVec[8][3];
    signal scaledDistVec[8][3];

    component dots[8];

    signal retNominator[8];
    signal ret[8];
    signal output out;

    for (var i = 0; i < 8; i++) {
        distVec[i][0] <== p[0] - coords[i][0];
        distVec[i][1] <== p[1] - coords[i][1];
        distVec[i][2] <== p[2] - coords[i][2];

        getWeights[i].corner[0] <-- coords[i][0] / scale;
        getWeights[i].corner[1] <-- coords[i][1] / scale;
        getWeights[i].corner[2] <-- coords[i][2] / scale;

        getWeights[i].p[0] <-- p[0] / scale;
        getWeights[i].p[1] <-- p[1] / scale;
        getWeights[i].p[2] <-- p[2] / scale;

        scaledDistVec[i][0] <-- distVec[i][0] / scale;
        scaledDistVec[i][1] <-- distVec[i][1] / scale;
        scaledDistVec[i][2] <-- distVec[i][2] / scale;

        dots[i] = Dot(DENOMINATOR);
        dots[i].a[0] <== grads[i][0];
        dots[i].a[1] <== grads[i][1];
        dots[i].a[2] <== grads[i][2];
        dots[i].b[0] <== scaledDistVec[i][0];
        dots[i].b[1] <== scaledDistVec[i][1];
        dots[i].b[2] <== scaledDistVec[i][2];

        retNominator[i] <== dots[i].out * getWeights[i].out;
        ret[i] <-- retNominator[i] / DENOMINATOR;
        retNominator[i] === DENOMINATOR * ret[i];
    }

    out <== ret[0] + ret[1] + ret[2] + ret[3] + ret[4] + ret[5] + ret[6] + ret[7];
}

// template SingleScalePerlin(scale_bits, DENOMINATOR, SQRT_P) {
//     signal input p[2];
//     signal input KEY;
//     signal input SCALE;
//     signal output out;
//     component cornersAndGrads = GetCornersAndGradVectors(scale_bits, DENOMINATOR, SQRT_P);
//     component perlinValue = PerlinValue(DENOMINATOR);
//     cornersAndGrads.scale <== SCALE;
//     cornersAndGrads.p[0] <== p[0];
//     cornersAndGrads.p[1] <== p[1];
//     cornersAndGrads.KEY <== KEY;
//     perlinValue.scale <== SCALE;
//     perlinValue.p[0] <== DENOMINATOR * p[0];
//     perlinValue.p[1] <== DENOMINATOR * p[1];

//     for (var i = 0; i < 4; i++) {
//         perlinValue.coords[i][0] <== DENOMINATOR * cornersAndGrads.coords[i][0];
//         perlinValue.coords[i][1] <== DENOMINATOR * cornersAndGrads.coords[i][1];
//         perlinValue.grads[i][0] <== cornersAndGrads.grads[i][0];
//         perlinValue.grads[i][1] <== cornersAndGrads.grads[i][1];
//     }

//     out <== perlinValue.out;
// }

// template MultiScalePerlin() {
//     var DENOMINATOR = 1125899906842624000; // good for length scales up to 16384. 2^50 * 1000
//     var DENOMINATOR_BITS = 61;
//     var SQRT_P = 1000000000000000000000000000000000000;

//     signal input p[2];
//     signal input KEY;
//     signal input SCALE; // power of 2 at most 16384 so that DENOMINATOR works
//     signal input xMirror; // 1 is true, 0 is false
//     signal input yMirror; // 1 is true, 0 is false
//     signal output out;
//     component perlins[3];

//     xMirror * (xMirror - 1) === 0;
//     yMirror * (yMirror - 1) === 0;

//     component rp = MultiRangeProof(2, 35);
//     rp.in[0] <== p[0];
//     rp.in[1] <== p[1];
//     rp.max_abs_value <== 2 ** 31;

//     component xIsNegative = IsNegative();
//     component yIsNegative = IsNegative();
//     xIsNegative.in <== p[0];
//     yIsNegative.in <== p[1];

//     // Make scale_bits a few bits bigger so we have a buffer
//     perlins[0] = SingleScalePerlin(16, DENOMINATOR, SQRT_P);
//     perlins[1] = SingleScalePerlin(16, DENOMINATOR, SQRT_P);
//     perlins[2] = SingleScalePerlin(16, DENOMINATOR, SQRT_P);

//     // add perlins[0], perlins[1], perlins[2], and perlins[0] (again)
//     component adder = CalculateTotal(4);
//     signal xSignShouldFlip[3];
//     signal ySignShouldFlip[3];
//     for (var i = 0; i < 3; i++) {
//         xSignShouldFlip[i] <== xIsNegative.out * yMirror; // should flip sign of x coord (p[0]) if yMirror is true (i.e. flip along vertical axis) and p[0] is negative
//         ySignShouldFlip[i] <== yIsNegative.out * xMirror; // should flip sign of y coord (p[1]) if xMirror is true (i.e. flip along horizontal axis) and p[1] is negative
//         perlins[i].p[0] <== p[0] * (-2 * xSignShouldFlip[i] + 1);
//         perlins[i].p[1] <== p[1] * (-2 * ySignShouldFlip[i] + 1);
//         perlins[i].KEY <== KEY;
//         perlins[i].SCALE <== SCALE * 2 ** i;
//         adder.in[i] <== perlins[i].out;
//     }
//     adder.in[3] <== perlins[0].out;

//     signal outDividedByCount;
//     outDividedByCount <-- adder.out / 4;
//     adder.out === 4 * outDividedByCount;

//     // outDividedByCount is between [-DENOMINATOR*sqrt(2)/2, DENOMINATOR*sqrt(2)/2]
//     component divBy16 = Modulo(DENOMINATOR_BITS, SQRT_P);
//     divBy16.dividend <== outDividedByCount * 16;
//     divBy16.divisor <== DENOMINATOR;
//     out <== divBy16.quotient + 16;
// }

// // component main = MultiScalePerlin(3); // if you change this n, you also need to recompute DENOMINATOR with JS.

template SingleScalePerlin(scale_bits, DENOMINATOR, SQRT_P) {
    signal input p[3];
    signal input KEY;
    signal input SCALE;
    signal output out;
    component cornersAndGrads = GetCornersAndGradVectors(scale_bits, DENOMINATOR, SQRT_P);
    component perlinValue = PerlinValue(DENOMINATOR);
    cornersAndGrads.scale <== SCALE;
    cornersAndGrads.p[0] <== p[0];
    cornersAndGrads.p[1] <== p[1];
    cornersAndGrads.p[2] <== p[2];
    cornersAndGrads.KEY <== KEY;
    perlinValue.scale <== SCALE;
    perlinValue.p[0] <== DENOMINATOR * p[0];
    perlinValue.p[1] <== DENOMINATOR * p[1];
    perlinValue.p[2] <== DENOMINATOR * p[2];

    for (var i = 0; i < 8; i++) {
        perlinValue.coords[i][0] <== DENOMINATOR * cornersAndGrads.coords[i][0];
        perlinValue.coords[i][1] <== DENOMINATOR * cornersAndGrads.coords[i][1];
        perlinValue.coords[i][2] <== DENOMINATOR * cornersAndGrads.coords[i][2];
        perlinValue.grads[i][0] <== cornersAndGrads.grads[i][0];
        perlinValue.grads[i][1] <== cornersAndGrads.grads[i][1];
        perlinValue.grads[i][2] <== cornersAndGrads.grads[i][2];
    }

    out <== perlinValue.out;
}

template MultiScalePerlin() {
    var DENOMINATOR = 1125899906842624000; // good for length scales up to 16384. 2^50 * 1000
    var DENOMINATOR_BITS = 61;
    var SQRT_P = 1000000000000000000000000000000000000;

    signal input p[3];
    signal input KEY;
    signal input SCALE; // power of 2 at most 16384 so that DENOMINATOR works
    signal input xMirror; // 1 is true, 0 is false
    signal input yMirror; // 1 is true, 0 is false
    signal input zMirror; // 1 is true, 0 is false
    signal output out;
    component perlins[3];

    xMirror * (xMirror - 1) === 0;
    yMirror * (yMirror - 1) === 0;
    zMirror * (zMirror - 1) === 0;

    component rp = MultiRangeProof(3, 35);
    rp.in[0] <== p[0];
    rp.in[1] <== p[1];
    rp.in[2] <== p[2];
    rp.max_abs_value <== 2 ** 31;

    component xIsNegative = IsNegative();
    component yIsNegative = IsNegative();
    component zIsNegative = IsNegative();
    xIsNegative.in <== p[0];
    yIsNegative.in <== p[1];
    zIsNegative.in <== p[2];

    perlins[0] = SingleScalePerlin(16, DENOMINATOR, SQRT_P);
    perlins[1] = SingleScalePerlin(16, DENOMINATOR, SQRT_P);
    perlins[2] = SingleScalePerlin(16, DENOMINATOR, SQRT_P);

    signal xSignShouldFlip[3];
    signal ySignShouldFlip[3];
    signal zSignShouldFlip[3];
    for (var i = 0; i < 3; i++) {
        xSignShouldFlip[i] <== xIsNegative.out * yMirror; // Flip sign of x coord if yMirror is true and p[0] is negative
        ySignShouldFlip[i] <== yIsNegative.out * xMirror; // Flip sign of y coord if xMirror is true and p[1] is negative
        zSignShouldFlip[i] <== zIsNegative.out * zMirror; // Flip sign of z coord if zMirror is true and p[2] is negative
        perlins[i].p[0] <== p[0] * (-2 * xSignShouldFlip[i] + 1);
                perlins[i].p[1] <== p[1] * (-2 * ySignShouldFlip[i] + 1);
        perlins[i].p[2] <== p[2] * (-2 * zSignShouldFlip[i] + 1);
        perlins[i].KEY <== KEY;
        perlins[i].SCALE <== SCALE * 2 ** i;
    }

    component adder = CalculateTotal(4);
    for (var i = 0; i < 3; i++) {
        adder.in[i] <== perlins[i].out;
    }
    adder.in[3] <== perlins[0].out; // Reuse the first scale for additional detail or adjust as needed

    signal outDividedByCount;
    outDividedByCount <-- adder.out / 4;
    adder.out === 4 * outDividedByCount;

    component divBy16 = Modulo(DENOMINATOR_BITS, SQRT_P);
    divBy16.dividend <== outDividedByCount * 16;
    divBy16.divisor <== DENOMINATOR;
    out <== divBy16.quotient + 16; // Adjust final output scaling as necessary
}
