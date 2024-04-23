import dotenv from "dotenv";
import { randomBytes } from "crypto";
import { poseidon1 } from "poseidon-lite";
import { writeFileSync } from "fs";

dotenv.config({ path: "../../.env" });

const sampleBlind = (): bigint => {
    return BigInt(`0x${randomBytes(32).toString("hex")}`);
}

const init = () => {
    const seedFilePath = process.env.SEED_FILE_PATH;
    if (!seedFilePath) {
        throw new Error("SEED_FILE_PATH environment variable not set");
    }

    const seed = sampleBlind();
    const seedCommitment = poseidon1([seed]).toString();
    const seedData = JSON.stringify({ seed: seed.toString(), seedCommitment });
    writeFileSync(seedFilePath, seedData);

    console.log(`Seed and seed commitment generated and saved to ${seedFilePath}`);
}

init();
