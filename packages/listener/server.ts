import dotenv from "dotenv";
import { TreasureHuntStore } from "./game/store";
import network from "./utils/network";

dotenv.config({ path: "../../.env" });

const SEED_FILE_PATH = process.env.SEED_FILE_PATH;
if (!SEED_FILE_PATH) {
    throw new Error("SEED_FILE_PATH environment variable not set");
}

const CORNERS = {
    x: parseInt(process.env.CORNER_X || '0', 10),
    y: parseInt(process.env.CORNER_Y || '0', 10),
    z: parseInt(process.env.CORNER_Z || '0', 10)
}

const BOUNDS = {
    x: parseInt(process.env.BOUNDS_X || '0', 10),
    y: parseInt(process.env.BOUNDS_Y || '0', 10),
    z: parseInt(process.env.BOUNDS_Z || '0', 10)
}

let store: TreasureHuntStore;

const setup = async () => {
    store = new TreasureHuntStore(SEED_FILE_PATH);
    
    // TODO: get sync to work
}

const run = async () => {
    await setup();

    network.contract.watchEvent.MineEvent({
        onLogs: async (logs) => {
            // TODO: fill in logic
            console.log(logs);
        }
    });

    console.log("== Seismic client listening to hooks contract");
}

run();
