import { readFileSync } from "fs";
import { poseidon1 } from "poseidon-lite";
import { VoxelPosition } from "./types";

export class TreasureHuntStore {

    seed: string;
    seedCommitment: string;

    // TODO: replace with DA
    minedPositions: Set<string>;

    constructor(seedFilePath: string) {
        this.minedPositions = new Set<string>();

        try {
            const data = readFileSync(seedFilePath, 'utf8');
            const parsedData = JSON.parse(data);
            this.seed = parsedData.seed;
            this.seedCommitment = poseidon1([this.seed]).toString();
        } catch (err) {
            console.error(`Error reading seed from file: ${err}`);
        }
    }

    addMinedPosition(position: VoxelPosition | string): void {
        const positionString = typeof position === 'string' ? position : JSON.stringify(position);
        this.minedPositions.add(positionString);
    }

    isAlreadyMined(position: VoxelPosition | string): boolean {
        const positionString = typeof position === 'string' ? position : JSON.stringify(position);
        return this.minedPositions.has(positionString);
    }
}
