import dotenv from "dotenv";
import { TreasureHuntStore } from "./game/store";
import network from "./utils/network";
import { CircuitInputs, VoxelPosition } from "./game/types";
import { proveCircuit } from "./utils/prover";
import { handleAsync } from "./utils/utils";
import { Address } from "viem";

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
}

const onNewExtensionContract = (contractAddress: Address) => {
    network.publicClient.watchEvent({
        address: contractAddress,
        event: network.events.mineEvent,
        onLogs: async (logs) => {
            for (let log of logs) {
                let { player, x, y, z } = log["args"];
                if (x === undefined || y === undefined || z === undefined) {
                    continue;
                }
                onMineEvent(player as Address, { x, y, z });
            }
        }
    })
}

const onMineEvent = (player: Address, position: VoxelPosition) => {
    console.log("hehe", { player, position });
}

const run = async () => {
    await setup();

    network.publicClient.watchEvent({
        event: network.events.newExtensionEvent,
        onLogs: async (logs) => {
            for (let log of logs) {
                let { contractAddress } = log["args"];
                onNewExtensionContract(contractAddress as Address);
            }
        }
    });

    console.log(`== Seismic client listening to hooks contract at ${network.contract.address}`);
}

run();









const oldRun = () => {
    network.contract.watchEvent.MineEvent({
        onLogs: async (logs) => {
            for (let log of logs) {
                let { player, x, y, z } = log["args"];

                if (x < CORNERS.x || x > CORNERS.x + BOUNDS.x || y < CORNERS.y || y > CORNERS.y + BOUNDS.y || z < CORNERS.z || z > CORNERS.z + BOUNDS.z) {
                    console.log(`== Player ${player} tried to mine at (${x}, ${y}, ${z}), but it was out of bounds`);
                    continue;
                }

                const offsetCoord: VoxelPosition = {
                    x: x - CORNERS.x,
                    y: y - CORNERS.y,
                    z: z - CORNERS.z
                }

                if (store.isAlreadyMined(offsetCoord)) {
                    console.log(`== Player ${player} tried to mine at (${x}, ${y}, ${z}), but it was already mined`);
                    continue;
                }

                const inputs: CircuitInputs = {
                    x: offsetCoord.x.toString(),
                    y: offsetCoord.y.toString(),
                    z: offsetCoord.z.toString(),
                    seed: store.seed,
                    seedCommitment: store.seedCommitment
                }

                let [proofRes, proofGenErr] = await handleAsync(proveCircuit(inputs));
                if (proofRes === null || proofGenErr) {
                    console.error("== Error proving circuit", proofGenErr);
                    continue;
                }
                const { proof, publicSignals } = proofRes;

                store.addMinedPosition(offsetCoord);

                let [tx, contractCallErr] = await handleAsync(
                    network.contract.write.SeismicCall([
                        player,
                        { x, y, z },
                        proof,
                        publicSignals
                    ])
                );
                if (tx === null || contractCallErr) {
                    console.error("Error calling SeismicCall()", contractCallErr);
                    console.error("Function inputs: ", { player, position: { x, y, z }, proof, publicSignals })
                    continue;
                }

                console.log(`== Player ${player} mined at (${x}, ${y}, ${z}), received ${publicSignals[0]} points`);
            }
        }
    });
}