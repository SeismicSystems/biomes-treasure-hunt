import dotenv from "dotenv";
import { poseidon1 } from "poseidon-lite";
import { writeFileSync } from "fs";
import { sampleBlind } from "./utils/utils";

dotenv.config({ path: "../../.env" });

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
