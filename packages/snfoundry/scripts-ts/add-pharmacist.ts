import { networks } from "./helpers/networks";
import { green, red, yellow } from "./helpers/colorize-log";
import yargs from "yargs";
import fs from "fs";
import path from "path";
import { CallData } from "starknet";

/**
 * add-pharmacist.ts
 *
 * Adds a wallet address to the PharmacistRegistry.
 * Must be called by the admin (deployer) account.
 *
 * Usage:
 *   yarn ts-node scripts-ts/add-pharmacist.ts --network sepolia --address <WALLET_ADDRESS>
 */

const argv = yargs(process.argv.slice(2))
    .option("network", {
        type: "string",
        description: "Specify the network",
        demandOption: true,
    })
    .option("address", {
        type: "string",
        description: "The wallet address to add as a pharmacist",
        demandOption: true,
    })
    .parseSync() as { network: string; address: string;[x: string]: unknown; _: (string | number)[]; $0: string };

const networkName = argv.network;
const walletAddress = argv.address;
const { provider, deployer } = networks[networkName];

const loadDeployments = () => {
    const filePath = path.resolve(
        __dirname,
        `../deployments/${networkName}_latest.json`
    );
    if (!fs.existsSync(filePath)) {
        throw new Error(
            `No deployment file found at ${filePath}.\n` +
            `Run 'yarn deploy --network ${networkName}' first.`
        );
    }
    return JSON.parse(fs.readFileSync(filePath, "utf8"));
};

const main = async (): Promise<void> => {
    console.log(yellow(`\nRegistering Pharmacist on ${networkName}`));

    const deployments = loadDeployments();
    const registryAddress = deployments["PharmacistRegistry"]?.address;

    if (!registryAddress) throw new Error("PharmacistRegistry address not found in deployments.");

    console.log(`  Registry Address : ${registryAddress}`);
    console.log(`  Adding Wallet    : ${walletAddress}`);

    const { transaction_hash } = await deployer.execute([
        {
            contractAddress: registryAddress,
            entrypoint: "add_pharmacist",
            calldata: CallData.compile({ user: walletAddress }),
        },
    ]);

    console.log(green(`✔ add_pharmacist called. Tx: ${transaction_hash}`));

    if (networkName !== "devnet") {
        console.log(yellow("Waiting for confirmation..."));
        await provider.waitForTransaction(transaction_hash);
        console.log(green("✔ Confirmed!"));
    }

    console.log(green(`\n✔ Wallet ${walletAddress} is now a registered pharmacist!`));
};

main().catch((err) => {
    console.error(red(err instanceof Error ? err.message : String(err)));
    process.exit(1);
});
