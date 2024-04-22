import dotenv from "dotenv";
import { randomBytes } from "crypto";
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

    const seed = sampleBlind().toString();
    const seedData = JSON.stringify({ seed });
    writeFileSync(seedFilePath, seedData);

    console.log(`Seed generated and saved to ${seedFilePath}`);
}

init();
