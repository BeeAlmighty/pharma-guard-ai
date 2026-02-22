/**
 * deploy-wire.ts
 *
 * Post-deployment wiring script.
 * Reads deployed addresses from the deployment JSON and calls
 * `set_medical_logger` on ReputationSBT so that MedicalLogger
 * can mint reputation badges.
 *
 * Usage:
 *   yarn ts-node scripts-ts/deploy-wire.ts --network devnet
 *   yarn ts-node scripts-ts/deploy-wire.ts --network sepolia
 */

import fs from "fs";
import path from "path";
import { CallData } from "starknet";

import { networks } from "./helpers/networks";
import { green, red, yellow } from "./helpers/colorize-log";
import yargs from "yargs";

const argv = yargs(process.argv.slice(2))
    .option("network", {
        type: "string",
        description: "Specify the network",
        demandOption: true,
    })
    .parseSync() as { network: string;[x: string]: unknown; _: (string | number)[]; $0: string };

const networkName = argv.network;
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
    console.log(yellow(`\nPharmaGuard AI — Post-deploy wiring on ${networkName}`));

    // 1. Load deployed addresses
    const deployments = loadDeployments();

    const reputationAddress = deployments["ReputationSBT"]?.address;
    const loggerAddress = deployments["MedicalLogger"]?.address;

    if (!reputationAddress) throw new Error("ReputationSBT address not found in deployments.");
    if (!loggerAddress) throw new Error("MedicalLogger address not found in deployments.");

    console.log(`  ReputationSBT : ${reputationAddress}`);
    console.log(`  MedicalLogger : ${loggerAddress}`);

    // 2. Build and execute set_medical_logger directly (no Contract wrapper needed)
    console.log(yellow("\nCalling set_medical_logger..."));
    const { transaction_hash } = await deployer.execute([
        {
            contractAddress: reputationAddress,
            entrypoint: "set_medical_logger",
            calldata: CallData.compile({ medical_logger: loggerAddress }),
        },
    ]);
    console.log(green(`✔ set_medical_logger called. Tx: ${transaction_hash}`));

    if (networkName !== "devnet") {
        console.log(yellow("Waiting for confirmation..."));
        await provider.waitForTransaction(transaction_hash);
        console.log(green("✔ Confirmed!"));
    }

    console.log(green("\n✔ Wiring complete! MedicalLogger can now mint badges."));
};

main().catch((err) => {
    console.error(red(err instanceof Error ? err.message : String(err)));
    process.exit(1);
});
