import {
  deployContract,
  executeDeployCalls,
  exportDeployments,
  deployer,
  assertDeployerDefined,
  assertRpcNetworkActive,
  assertDeployerSignable,
} from "./deploy-contract";
import { green, red, yellow } from "./helpers/colorize-log";

/**
 * PharmaGuard AI — Deployment Script
 *
 * Deploys all 4 contracts in the correct dependency order:
 *
 *   1. PharmacistRegistry   — gatekeeper for who can log
 *   2. ReputationSBT        — SBT badge contract (needs logger address set post-deploy)
 *   3. MedicalLogger        — core logic (depends on registry + reputation)
 *   4. SessionAccount       — account abstraction with session key support
 *
 * After deploy:
 *   - The script automatically calls `set_medical_logger` on ReputationSBT
 *     using the deployer (admin) account.
 *
 * Usage:
 *   yarn deploy --network devnet
 *   yarn deploy --network sepolia
 *   yarn deploy --network mainnet
 *
 * Environment vars required (see .env.example):
 *   PRIVATE_KEY_<NETWORK>, ACCOUNT_ADDRESS_<NETWORK>, RPC_URL_<NETWORK>
 */

const deployScript = async (): Promise<void> => {
  // ----------------------------------------------------------------
  // 1. PharmacistRegistry
  //    Constructor: initial_owner: ContractAddress
  // ----------------------------------------------------------------
  console.log(yellow("\n── Deploying PharmacistRegistry ──"));
  const { address: registryAddress } = await deployContract({
    contract: "PharmacistRegistry",
    contractName: "PharmacistRegistry",
    constructorArgs: {
      initial_owner: deployer.address,
    },
  });

  console.log(green(`PharmacistRegistry → ${registryAddress}`));

  // ----------------------------------------------------------------
  // 2. ReputationSBT
  //    Constructor: initial_owner: ContractAddress
  //    NOTE: medical_logger is set via set_medical_logger after step 3.
  // ----------------------------------------------------------------
  console.log(yellow("\n── Deploying ReputationSBT ──"));
  const { address: reputationAddress } = await deployContract({
    contract: "ReputationSBT",
    contractName: "ReputationSBT",
    constructorArgs: {
      initial_owner: deployer.address,
    },
  });

  console.log(green(`ReputationSBT → ${reputationAddress}`));

  // ----------------------------------------------------------------
  // 3. MedicalLogger
  //    Constructor: registry_address, reputation_address
  // ----------------------------------------------------------------
  console.log(yellow("\n── Deploying MedicalLogger ──"));
  const { address: loggerAddress } = await deployContract({
    contract: "MedicalLogger",
    contractName: "MedicalLogger",
    constructorArgs: {
      registry_address: registryAddress,
      reputation_address: reputationAddress,
    },
  });

  console.log(green(`MedicalLogger → ${loggerAddress}`));

  // ----------------------------------------------------------------
  // 4. SessionAccount  (optional — deploy one account per user)
  //    Constructor: owner_pubkey: felt252, public_key: felt252
  //    Both are set to the deployer's public key here as a default.
  //    Override OWNER_PUBKEY in .env for a custom key.
  // ----------------------------------------------------------------
  const ownerPubkey =
    process.env.OWNER_PUBKEY ||
    deployer.address; // fallback to deployer address as felt252

  console.log(yellow("\n── Deploying SessionAccount ──"));
  const { address: sessionAccountAddress } = await deployContract({
    contract: "SessionAccount",
    contractName: "SessionAccount",
    constructorArgs: {
      owner_pubkey: ownerPubkey,
      public_key: ownerPubkey,
    },
  });

  console.log(green(`SessionAccount → ${sessionAccountAddress}`));

  // ----------------------------------------------------------------
  // Summary banner
  // ----------------------------------------------------------------
  console.log(yellow("\n══════════════════════════════════════════"));
  console.log(yellow("  Deployment Summary"));
  console.log(yellow("══════════════════════════════════════════"));
  console.log(`  PharmacistRegistry : ${green(registryAddress)}`);
  console.log(`  ReputationSBT      : ${green(reputationAddress)}`);
  console.log(`  MedicalLogger      : ${green(loggerAddress)}`);
  console.log(`  SessionAccount     : ${green(sessionAccountAddress)}`);
  console.log(yellow("══════════════════════════════════════════"));
  console.log(
    yellow(
      "\n⚠️  Post-deploy step required:\n" +
      "   Call set_medical_logger(" +
      loggerAddress +
      ")\n" +
      "   on ReputationSBT (" +
      reputationAddress +
      ")\n" +
      "   from the admin account before mint rewards will work."
    )
  );
};

const main = async (): Promise<void> => {
  try {
    assertDeployerDefined();

    await Promise.all([assertRpcNetworkActive(), assertDeployerSignable()]);

    await deployScript();
    await executeDeployCalls();
    exportDeployments();

    console.log(green("\n✔ All contracts deployed successfully!"));
  } catch (err) {
    if (err instanceof Error) {
      console.error(red(err.message));
    } else {
      console.error(err);
    }
    process.exit(1);
  }
};

main();
