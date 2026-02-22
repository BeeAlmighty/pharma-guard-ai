use starknet::ContractAddress;
use snforge_std::{declare, ContractClassTrait, DeclareResultTrait};
use snforge_std::{start_cheat_caller_address, stop_cheat_caller_address};
use snforge_std::{start_cheat_block_timestamp, stop_cheat_block_timestamp};
use snforge_std::{start_cheat_signature, stop_cheat_signature};
use starknet::account::Call;
use starknet::VALIDATED;

use contracts::pharmacistRegistry::{
    IPharmacistRegistryDispatcher,
    IPharmacistRegistryDispatcherTrait
};
use contracts::reputationSBT::{
    IReputationSBTDispatcher,
    IReputationSBTDispatcherTrait
};
use contracts::medicalLogger::{
    IMedicalLoggerDispatcher,
    IMedicalLoggerDispatcherTrait
};
use contracts::sessionAccount::{
    ISessionAccountDispatcher,
    ISessionAccountDispatcherTrait
};

// ---------------------------------------------------------------- //
//                          HELPERS                                 //
// ---------------------------------------------------------------- //

fn contract_address_from_int(num: u128) -> ContractAddress {
    let felt: felt252 = num.into();
    felt.try_into().unwrap()
}

fn deploy_registry(owner: ContractAddress) -> (IPharmacistRegistryDispatcher, ContractAddress) {
    let contract = declare("PharmacistRegistry").unwrap();
    let mut calldata = array![];
    owner.serialize(ref calldata);
    let (addr, _) = contract.contract_class().deploy(@calldata).unwrap();
    (IPharmacistRegistryDispatcher { contract_address: addr }, addr)
}

fn deploy_reputation(owner: ContractAddress) -> (IReputationSBTDispatcher, ContractAddress) {
    let contract = declare("ReputationSBT").unwrap();
    let mut calldata = array![];
    owner.serialize(ref calldata);
    let (addr, _) = contract.contract_class().deploy(@calldata).unwrap();
    (IReputationSBTDispatcher { contract_address: addr }, addr)
}

fn deploy_logger(
    registry: ContractAddress,
    reputation: ContractAddress
) -> (IMedicalLoggerDispatcher, ContractAddress) {
    let contract = declare("MedicalLogger").unwrap();
    let mut calldata = array![];
    registry.serialize(ref calldata);
    reputation.serialize(ref calldata);
    let (addr, _) = contract.contract_class().deploy(@calldata).unwrap();
    (IMedicalLoggerDispatcher { contract_address: addr }, addr)
}

fn deploy_session_account(pubkey: felt252) -> (ISessionAccountDispatcher, ContractAddress) {
    let contract = declare("SessionAccount").unwrap();
    let mut calldata = array![];
    pubkey.serialize(ref calldata);
    pubkey.serialize(ref calldata); // owner_pubkey & public_key
    let (addr, _) = contract.contract_class().deploy(@calldata).unwrap();
    (ISessionAccountDispatcher { contract_address: addr }, addr)
}

/// Full setup: deploys all 4 contracts and wires them together.
/// owner pubkey = 999 for SessionAccount
fn setup_all() -> (
    IMedicalLoggerDispatcher,
    IPharmacistRegistryDispatcher,
    IReputationSBTDispatcher,
    ISessionAccountDispatcher,
    ContractAddress, // admin
    ContractAddress  // session account address (acts as pharmacist)
) {
    let admin = contract_address_from_int(1);
    let (registry, registry_addr) = deploy_registry(admin);
    let (reputation, reputation_addr) = deploy_reputation(admin);
    let (logger, logger_addr) = deploy_logger(registry_addr, reputation_addr);
    let (account, account_addr) = deploy_session_account(999);

    // Wire: set MedicalLogger in ReputationSBT
    start_cheat_caller_address(reputation_addr, admin);
    reputation.set_medical_logger(logger_addr);
    stop_cheat_caller_address(reputation_addr);

    // Wire: register SessionAccount address as pharmacist
    start_cheat_caller_address(registry_addr, admin);
    registry.add_pharmacist(account_addr);
    stop_cheat_caller_address(registry_addr);

    // Non-zero timestamp for MedicalLogger
    start_cheat_block_timestamp(logger_addr, 1000);

    (logger, registry, reputation, account, admin, account_addr)
}

// ---------------------------------------------------------------- //
//          GROUP 1: Full Pharmacist Lifecycle Flow                 //
// ---------------------------------------------------------------- //

#[test]
fn test_full_lifecycle_low_risk_log() {
    let (logger, _, reputation, _, _, account_addr) = setup_all();

    start_cheat_caller_address(logger.contract_address, account_addr);
    logger.log_safety_check(0xA01, 1_u8);
    stop_cheat_caller_address(logger.contract_address);

    let entry = logger.get_log(0xA01);
    assert(entry.pharmacist == account_addr, 'wrong pharmacist');
    assert(entry.risk_level == 1_u8, 'wrong risk level');
    assert(!entry.blocked, 'should not be blocked');

    let score = reputation.reputation_score(account_addr);
    assert(score == 0_u256, 'no badge for low risk');
}

#[test]
fn test_full_lifecycle_high_risk_block() {
    let (logger, _, reputation, _, _, account_addr) = setup_all();

    start_cheat_caller_address(logger.contract_address, account_addr);
    logger.log_safety_check(0xB01, 3_u8);
    logger.confirm_block(0xB01);
    stop_cheat_caller_address(logger.contract_address);

    let entry = logger.get_log(0xB01);
    assert(entry.blocked, 'should be blocked');

    let score = reputation.reputation_score(account_addr);
    assert(score == 1_u256, 'should have 1 badge');
}

#[test]
fn test_full_lifecycle_override() {
    let (logger, _, reputation, _, _, account_addr) = setup_all();

    start_cheat_caller_address(logger.contract_address, account_addr);
    logger.log_safety_check(0xC01, 2_u8);
    logger.override_warning(0xC01, 0xDEAD);
    stop_cheat_caller_address(logger.contract_address);

    let entry = logger.get_log(0xC01);
    assert(entry.overridden, 'should be overridden');
    assert(!entry.blocked, 'no block on override');

    let score = reputation.reputation_score(account_addr);
    assert(score == 0_u256, 'no badge for override');
}

#[test]
fn test_full_lifecycle_reputation_grows() {
    let (logger, _, reputation, _, _, account_addr) = setup_all();

    start_cheat_caller_address(logger.contract_address, account_addr);
    logger.log_safety_check(0xD01, 3_u8);
    logger.confirm_block(0xD01);
    logger.log_safety_check(0xD02, 3_u8);
    logger.confirm_block(0xD02);
    logger.log_safety_check(0xD03, 3_u8);
    logger.confirm_block(0xD03);
    stop_cheat_caller_address(logger.contract_address);

    let score = reputation.reputation_score(account_addr);
    assert(score == 3_u256, 'reputation should be 3');
}

// ---------------------------------------------------------------- //
//          GROUP 2: Cross-Contract Authorization                   //
// ---------------------------------------------------------------- //

#[test]
#[should_panic(expected: ('NOT_PHARMACIST',))]
fn test_removed_pharmacist_cannot_log() {
    let (logger, registry, _, _, admin, account_addr) = setup_all();

    // Log once successfully
    start_cheat_caller_address(logger.contract_address, account_addr);
    logger.log_safety_check(0xE01, 1_u8);
    stop_cheat_caller_address(logger.contract_address);

    // Remove from registry
    start_cheat_caller_address(registry.contract_address, admin);
    registry.remove_pharmacist(account_addr);
    stop_cheat_caller_address(registry.contract_address);

    // Try to log again — should panic
    start_cheat_caller_address(logger.contract_address, account_addr);
    logger.log_safety_check(0xE02, 1_u8);
    stop_cheat_caller_address(logger.contract_address);
}

#[test]
#[should_panic(expected: ('NOT_PHARMACIST',))]
fn test_unregistered_account_cannot_log() {
    let (logger, _, _, _, _, _) = setup_all();
    let rando = contract_address_from_int(9999);

    start_cheat_caller_address(logger.contract_address, rando);
    logger.log_safety_check(0xF01, 1_u8);
    stop_cheat_caller_address(logger.contract_address);
}

#[test]
#[should_panic(expected: ('NOT_AUTHORIZED',))]
fn test_only_logger_can_mint_badge() {
    let (_, _, reputation, _, _, account_addr) = setup_all();

    start_cheat_caller_address(reputation.contract_address, account_addr);
    reputation.mint_lifesaver_badge(account_addr);
    stop_cheat_caller_address(reputation.contract_address);
}

#[test]
#[should_panic(expected: ('NOT_AUTHORIZED',))]
fn test_old_logger_cannot_mint() {
    let (old_logger, _, reputation, _, admin, account_addr) = setup_all();
    let new_logger_addr = contract_address_from_int(42);

    // Point reputation to a new logger
    start_cheat_caller_address(reputation.contract_address, admin);
    reputation.set_medical_logger(new_logger_addr);
    stop_cheat_caller_address(reputation.contract_address);

    // Old logger tries to mint — should fail
    start_cheat_caller_address(reputation.contract_address, old_logger.contract_address);
    reputation.mint_lifesaver_badge(account_addr);
    stop_cheat_caller_address(reputation.contract_address);
}

// ---------------------------------------------------------------- //
//          GROUP 3: SessionAccount + MedicalLogger                 //
// ---------------------------------------------------------------- //

#[test]
fn test_session_account_validates_before_log() {
    let (logger, _, _, account, _, account_addr) = setup_all();
    let session_key: felt252 = 0xAA01;
    let expires_at: u64 = 5000;

    // Authorize a session targeting MedicalLogger
    start_cheat_signature(account.contract_address, array![999].span());
    account.authorize_session(session_key, expires_at, logger.contract_address);
    stop_cheat_signature(account.contract_address);

    // Validate session for a MedicalLogger call
    start_cheat_block_timestamp(account.contract_address, 2000);
    let call = Call { to: logger.contract_address, selector: 0x1, calldata: array![].span() };
    let result = account.validate_session(session_key, array![call]);
    assert(result == VALIDATED, 'should be VALIDATED');
    stop_cheat_block_timestamp(account.contract_address);

    // Perform the actual log as the account
    start_cheat_caller_address(logger.contract_address, account_addr);
    logger.log_safety_check(0xAA11, 1_u8);
    stop_cheat_caller_address(logger.contract_address);

    let entry = logger.get_log(0xAA11);
    assert(entry.pharmacist == account_addr, 'wrong pharmacist');
}

#[test]
fn test_expired_session_rejected() {
    let (logger, _, _, account, _, _) = setup_all();
    let session_key: felt252 = 0xAA02;
    let expires_at: u64 = 1000;

    start_cheat_signature(account.contract_address, array![999].span());
    account.authorize_session(session_key, expires_at, logger.contract_address);
    stop_cheat_signature(account.contract_address);

    // Time past expiry
    start_cheat_block_timestamp(account.contract_address, 2000);
    let call = Call { to: logger.contract_address, selector: 0x1, calldata: array![].span() };
    let result = account.validate_session(session_key, array![call]);
    assert(result == 'SESSION_EXPIRED', 'should be SESSION_EXPIRED');
    stop_cheat_block_timestamp(account.contract_address);
}

#[test]
fn test_revoked_session_rejected() {
    let (logger, _, _, account, _, _) = setup_all();
    let session_key: felt252 = 0xAA03;

    start_cheat_signature(account.contract_address, array![999].span());
    account.authorize_session(session_key, 9999, logger.contract_address);
    account.revoke_session(session_key);
    stop_cheat_signature(account.contract_address);

    start_cheat_block_timestamp(account.contract_address, 500);
    let call = Call { to: logger.contract_address, selector: 0x1, calldata: array![].span() };
    let result = account.validate_session(session_key, array![call]);
    assert(result == 'INVALID_SESSION', 'should be INVALID_SESSION');
    stop_cheat_block_timestamp(account.contract_address);
}

#[test]
fn test_wrong_target_session_rejected() {
    let (logger, _, _, account, _, _) = setup_all();
    let session_key: felt252 = 0xAA04;
    let wrong_target = contract_address_from_int(7777);

    start_cheat_signature(account.contract_address, array![999].span());
    account.authorize_session(session_key, 9999, logger.contract_address);
    stop_cheat_signature(account.contract_address);

    start_cheat_block_timestamp(account.contract_address, 500);
    let call = Call { to: wrong_target, selector: 0x1, calldata: array![].span() };
    let result = account.validate_session(session_key, array![call]);
    assert(result == 'INVALID_TARGET', 'should be INVALID_TARGET');
    stop_cheat_block_timestamp(account.contract_address);
}

// ---------------------------------------------------------------- //
//          GROUP 4: Edge Cases                                     //
// ---------------------------------------------------------------- //

#[test]
fn test_ownership_transfer_then_add_pharmacist() {
    let (logger, registry, _, _, admin, _) = setup_all();
    let new_admin = contract_address_from_int(2);
    let new_pharmacist = contract_address_from_int(500);

    // Transfer registry ownership
    start_cheat_caller_address(registry.contract_address, admin);
    registry.transfer_ownership(new_admin);
    stop_cheat_caller_address(registry.contract_address);

    // New admin adds a pharmacist
    start_cheat_caller_address(registry.contract_address, new_admin);
    registry.add_pharmacist(new_pharmacist);
    stop_cheat_caller_address(registry.contract_address);

    assert(registry.is_pharmacist(new_pharmacist), 'should be pharmacist');

    // New pharmacist can log
    start_cheat_caller_address(logger.contract_address, new_pharmacist);
    logger.log_safety_check(0x1001, 1_u8);
    stop_cheat_caller_address(logger.contract_address);

    let entry = logger.get_log(0x1001);
    assert(entry.pharmacist == new_pharmacist, 'wrong pharmacist');
}

#[test]
fn test_multiple_accounts_independent_reputation() {
    let admin = contract_address_from_int(1);
    let (registry, registry_addr) = deploy_registry(admin);
    let (reputation, reputation_addr) = deploy_reputation(admin);
    let (logger, logger_addr) = deploy_logger(registry_addr, reputation_addr);

    let (_account1, account1_addr) = deploy_session_account(111);
    let (_account2, account2_addr) = deploy_session_account(222);

    // Wire contracts
    start_cheat_caller_address(reputation_addr, admin);
    reputation.set_medical_logger(logger_addr);
    stop_cheat_caller_address(reputation_addr);

    // Register both accounts as pharmacists
    start_cheat_caller_address(registry_addr, admin);
    registry.add_pharmacist(account1_addr);
    registry.add_pharmacist(account2_addr);
    stop_cheat_caller_address(registry_addr);

    start_cheat_block_timestamp(logger_addr, 1000);

    // Account1 blocks
    start_cheat_caller_address(logger_addr, account1_addr);
    logger.log_safety_check(0x2001, 3_u8);
    logger.confirm_block(0x2001);
    stop_cheat_caller_address(logger_addr);

    // Account2 blocks
    start_cheat_caller_address(logger_addr, account2_addr);
    logger.log_safety_check(0x2002, 3_u8);
    logger.confirm_block(0x2002);
    stop_cheat_caller_address(logger_addr);

    let score1 = reputation.reputation_score(account1_addr);
    let score2 = reputation.reputation_score(account2_addr);
    assert(score1 == 1_u256, 'account1 should have 1 badge');
    assert(score2 == 1_u256, 'account2 should have 1 badge');
}

#[test]
fn test_reputation_accumulates_correctly() {
    let (logger, _, reputation, _, _, account_addr) = setup_all();

    start_cheat_caller_address(logger.contract_address, account_addr);
    logger.log_safety_check(0x3001, 3_u8);
    logger.confirm_block(0x3001);
    logger.log_safety_check(0x3002, 3_u8);
    logger.confirm_block(0x3002);
    logger.log_safety_check(0x3003, 3_u8);
    logger.confirm_block(0x3003);
    logger.log_safety_check(0x3004, 3_u8);
    logger.confirm_block(0x3004);
    logger.log_safety_check(0x3005, 3_u8);
    logger.confirm_block(0x3005);
    stop_cheat_caller_address(logger.contract_address);

    let score = reputation.reputation_score(account_addr);
    assert(score == 5_u256, 'should have 5 badges');
}
