import dotenv from "dotenv"
import { webSocket, createPublicClient, createWalletClient, Address, getContract, parseAbi } from "viem";
import { privateKeyToAccount } from "viem/accounts";
import { abi, address, receipt } from "../../biomes-scaffold/packages/hardhat/deployments/biomesTestnet/Game.json";

dotenv.config({ path: "../../.env" });

const chain = {
    id: 1337,
    name: "Biomes Testnet",
    nativeCurrency: {
        decimals: 18,
        name: "Ether",
        symbol: "ETH",
    },
    rpcUrls: {
        default: {
            http: ["https://testnet.biomes.aw"],
            webSocket: ["wss://testnet.biomes.aw"],
        },
        public: {
            http: ["https://testnet.biomes.aw"],
            webSocket: ["wss://testnet.biomes.aw"],
        },
    },
};

const publicClient = createPublicClient({
    chain,
    transport: webSocket("wss://testnet.biomes.aw"),
    pollingInterval: 1000,
});

// TODO: pollingInterval
const account = privateKeyToAccount(process.env.PRIVATE_KEY as Address);
const walletClient = createWalletClient({
    chain,
    transport: webSocket("wss://testnet.biomes.aw"),
    account
});

const contract = getContract({
    abi,
    address: address as Address,
    client: {
        public: publicClient,
        wallet: walletClient,
    },
});

const network = {
    account,
    chain,
    publicClient,
    walletClient,
    contract,
    receipt,
};

export default network;