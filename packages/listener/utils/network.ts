import dotenv from "dotenv"
import { webSocket, createPublicClient, createWalletClient, Address, getContract, parseAbiItem } from "viem";
import { privateKeyToAccount } from "viem/accounts";
import { abi } from "../../contracts/out/SeismicNotifier.sol/SeismicNotifier.json";
import { address } from "../../contracts/out/SeismicNotifier.sol/deployment.json";

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

const newExtensionEvent = parseAbiItem("event NewExtensionsContract(address indexed contractAddress)");
const mineEvent = parseAbiItem("event MineEvent(address player, int32 x, int32 y, int32 z, int32 sizeX, int32 sizeY, int32 sizeZ, uint256 gameStartBlock)");

const network = {
    account,
    chain,
    publicClient,
    walletClient,
    contract,
    events: {
        newExtensionEvent,
        mineEvent,
    }
};

export default network;
