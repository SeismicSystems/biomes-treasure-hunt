#! /bin/bash

PTAU_URL=https://storage.googleapis.com/zkevm/ptau/powersOfTau28_hez_final_17.ptau
PTAU_FILE=powersOfTau28_hez_final_17.ptau

if [ ! -f artifacts/$PTAU_FILE ]; then
    mkdir -p artifacts
    curl -o artifacts/$PTAU_FILE $PTAU_URL
    echo " == Installed dev ptau file: $PTAU_FILE"
else
    echo " == Dev ptau file already installed, proceeding..."
fi

# Compile circuit
yarn run circom2 circuit.circom --r1cs --wasm

# Generate proving key
yarn run snarkjs groth16 setup circuit.r1cs \
                               artifacts/$PTAU_FILE \
                               circuit.zkey

# Generate verifying key
yarn run snarkjs zkey export verificationkey circuit.zkey \
                                             circuit.vkey.json

# Compute witness, used as smoke test for circuit
node circuit_js/generate_witness.js \
     circuit_js/circuit.wasm \
     circuit.smoke.json \
     circuit.wtns
rm -rf circuit.wtns

# Export solidity verifier
yarn run snarkjs zkey export solidityverifier circuit.zkey \
                                              CircuitVerifier.sol
sed -i -e 's/0.6.11;/0.8.13;/g' CircuitVerifier.sol
rm -rf CircuitVerifier.sol-e

# # Save proving key and witness generation script
# mkdir -p circuit/build
# mv circuit_js/circuit.wasm circuit.zkey circuit/build

# # Clean up
mkdir -p build
mv circuit_js/circuit.wasm circuit.zkey circuit.vkey.json build/
mv CircuitVerifier.sol ../biomes-scaffold/packages/hardhat/contracts/
rm -r circuit_js/ circuit.r1cs
