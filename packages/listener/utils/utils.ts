import { randomBytes } from "crypto";

export async function handleAsync<T>(
    promise: Promise<T>
): Promise<[T, null] | [null, any]> {
    try {
        const data = await promise;
        return [data, null];
    } catch (error) {
        return [null, error];
    }
}

export function sampleBlind() {
    return BigInt(`0x${randomBytes(32).toString("hex")}`);
}
