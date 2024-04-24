import dotenv from "dotenv";
import { TreasureHuntStore } from "./game/store";
import network from "./utils/network";
import { CircuitInputs, VoxelArea, VoxelPosition } from "./game/types";
import { proveCircuit } from "./utils/prover";
import { handleAsync } from "./utils/utils";
import { Address } from "viem";
import { abi as gameAbi } from "../biomes-scaffold/packages/hardhat/deployments/biomesTestnet/Game.json";

dotenv.config({ path: "../../.env" });

const SEED_FILE_PATH = process.env.SEED_FILE_PATH;
if (!SEED_FILE_PATH) {
    throw new Error("SEED_FILE_PATH environment variable not set");
}

const CORNERS = {
    x: parseInt(process.env.CORNER_X || "0", 10),
    y: parseInt(process.env.CORNER_Y || "0", 10),
    z: parseInt(process.env.CORNER_Z || "0", 10),
};

const BOUNDS = {
    x: parseInt(process.env.BOUNDS_X || "0", 10),
    y: parseInt(process.env.BOUNDS_Y || "0", 10),
    z: parseInt(process.env.BOUNDS_Z || "0", 10),
};

let store: TreasureHuntStore;

const setup = async () => {
    store = new TreasureHuntStore(SEED_FILE_PATH);
};

const onNewExtensionContract = (contractAddress: Address) => {
    network.publicClient.watchEvent({
        address: contractAddress,
        event: network.events.mineEvent,
        onLogs: async (logs) => {
            for (let log of logs) {
                let { player, x, y, z, sizeX, sizeY, sizeZ, gameStartBlock } = log["args"];
                if (
                    x === undefined ||
                    y === undefined ||
                    z === undefined ||
                    sizeX === undefined ||
                    sizeY === undefined ||
                    sizeZ === undefined ||
                    gameStartBlock === undefined
                ) {
                    console.error("== Missing arguments", log["args"]);
                    continue;
                }
                await onMineEvent(
                    contractAddress,
                    player as Address,
                    { x, y, z },
                    { sizeX, sizeY, sizeZ },
                    gameStartBlock.toString(),
                );
            }
        },
    });
};

const onMineEvent = async (
    contractAddress: Address,
    player: Address,
    position: VoxelPosition,
    size: VoxelArea,
    gameStartBlock: string
) => {
    const { x, y, z } = position;
    const { sizeX, sizeY, sizeZ } = size;
    const inputs: CircuitInputs = {
        x: x.toString(),
        y: y.toString(),
        z: z.toString(),
        sizeX: sizeX.toString(),
        sizeY: sizeY.toString(),
        sizeZ: sizeZ.toString(),
        seed: store.seed,
        seedCommitment: store.seedCommitment,
        gameStartBlock,
    };

    let [proofRes, proofGenErr] = await handleAsync(proveCircuit(inputs));
    if (proofRes === null || proofGenErr) {
        console.error("== Error proving circuit", proofGenErr);
        return;
    }
    const { proof, publicSignals } = proofRes;

    const { request } = await network.publicClient.simulateContract({
        address: contractAddress,
        abi: gameAbi,
        functionName: "SeismicCall",
        args: [player, { x, y, z }, proof, publicSignals],
    });
    let [tx, contractCallErr] = await handleAsync(
        network.walletClient.writeContract(request)
    );
    if (tx === null || contractCallErr) {
        console.error("Error calling SeismicCall()", contractCallErr);
        console.error("Function inputs: ", {
            player,
            position: { x, y, z },
            proof,
            publicSignals,
        });
        return;
    }

    console.log(
        `== Player ${player} mined at (${x}, ${y}, ${z}), received ${publicSignals[0]} points`
    );
};

const run = async () => {
    await setup();

    network.publicClient.watchEvent({
        event: network.events.newExtensionEvent,
        onLogs: async (logs) => {
            for (let log of logs) {
                let { contractAddress } = log["args"];
                console.log("== New extension contract", contractAddress);
                onNewExtensionContract(contractAddress as Address);
            }
        },
    });

    console.log(
        `== Seismic client listening to hooks contract at ${network.contract.address}`
    );
};

run();
