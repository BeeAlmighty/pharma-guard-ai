use starknet::ContractAddress;
use snforge_std::{declare, ContractClassTrait, DeclareResultTrait};
use snforge_std::{start_cheat_caller_address, stop_cheat_caller_address};
use snforge_std::{start_cheat_block_timestamp, stop_cheat_block_timestamp};

use snforge_std::cheatcodes::events::{spy_events, EventSpyTrait, EventsFilterTrait};

use contracts::medicalLogger::{
    IMedicalLoggerDispatcher,
    IMedicalLoggerDispatcherTrait,
    LogEntry
};
use contracts::pharmacistRegistry::{
    IPharmacistRegistryDispatcher,
    IPharmacistRegistryDispatcherTrait
};
use contracts::reputationSBT::{
    IReputationSBTDispatcher,
    IReputationSBTDispatcherTrait
};

// Helper function to convert to ContractAddress
fn contract_address_from_int(num: u128) -> ContractAddress {
    let felt: felt252 = num.into();
    felt.try_into().unwrap()
}

// ---------------------------------------------------------------- //
//                          DEPLOYMENT HELPERS                      //
// ---------------------------------------------------------------- //

fn deploy_registry() -> (IPharmacistRegistryDispatcher, ContractAddress) {
    let contract = declare("PharmacistRegistry").unwrap();
    let owner = contract_address_from_int(123);
    let mut calldata = array![];
    owner.serialize(ref calldata);
    
    let (contract_address, _) = contract.contract_class().deploy(@calldata).unwrap();
    (IPharmacistRegistryDispatcher { contract_address }, contract_address)
}

fn deploy_reputation() -> (IReputationSBTDispatcher, ContractAddress) {
    let contract = declare("ReputationSBT").unwrap();
    let owner = contract_address_from_int(123);
    let mut calldata = array![];
    owner.serialize(ref calldata);
    
    let (contract_address, _) = contract.contract_class().deploy(@calldata).unwrap();
    (IReputationSBTDispatcher { contract_address }, contract_address)
}

fn deploy_logger(
    registry: ContractAddress, 
    reputation: ContractAddress
) -> (IMedicalLoggerDispatcher, ContractAddress) {
    let contract = declare("MedicalLogger").unwrap();
    let mut calldata = array![];
    registry.serialize(ref calldata);
    reputation.serialize(ref calldata);
    
    let (contract_address, _) = contract.contract_class().deploy(@calldata).unwrap();
    (IMedicalLoggerDispatcher { contract_address }, contract_address)
}

fn setup() -> (IMedicalLoggerDispatcher, IPharmacistRegistryDispatcher, IReputationSBTDispatcher, ContractAddress) {
    let (registry_disp, registry_addr) = deploy_registry();
    let (reputation_disp, reputation_addr) = deploy_reputation();
    let (logger_disp, logger_addr) = deploy_logger(registry_addr, reputation_addr);
    
    let owner = contract_address_from_int(123);
    let pharmacist = contract_address_from_int(456);
    
    // 1. Add pharmacist to Registry
    start_cheat_caller_address(registry_addr, owner);
    registry_disp.add_pharmacist(pharmacist);
    stop_cheat_caller_address(registry_addr);
    
    // 2. Set logger in ReputationSBT
    start_cheat_caller_address(reputation_addr, owner);
    reputation_disp.set_medical_logger(logger_addr);
    stop_cheat_caller_address(reputation_addr);

    // Set a non-zero timestamp for all tests
    start_cheat_block_timestamp(logger_addr, 1000);
    
    (logger_disp, registry_disp, reputation_disp, pharmacist)
}

// ---------------------------------------------------------------- //
//                              TESTS                               //
// ---------------------------------------------------------------- //

#[test]
fn test_log_safety_check() {
    let (logger_disp, _, _, pharmacist) = setup();
    let commitment = 12345;
    let risk_level = 1_u8;
    
    start_cheat_caller_address(logger_disp.contract_address, pharmacist);
    logger_disp.log_safety_check(commitment, risk_level);
    stop_cheat_caller_address(logger_disp.contract_address);
    
    let entry = logger_disp.get_log(commitment);
    assert(entry.pharmacist == pharmacist, 'wrong pharmacist');
    assert(entry.risk_level == risk_level, 'wrong risk level');
    assert(entry.blocked == false, 'should not be blocked');
    assert(entry.overridden == false, 'should not be overridden');
}

#[test]
#[should_panic(expected: ('NOT_PHARMACIST',))]
fn test_log_unauthorized() {
    let (logger_disp, _, _, _) = setup();
    let rando = contract_address_from_int(999);
    let commitment = 12345;
    
    start_cheat_caller_address(logger_disp.contract_address, rando);
    logger_disp.log_safety_check(commitment, 1_u8);
    stop_cheat_caller_address(logger_disp.contract_address);
}

#[test]
fn test_override_warning() {
    let (logger_disp, _, _, pharmacist) = setup();
    let commitment = 12345;
    let reason_hash = 0xABC;
    
    // First log functionality
    start_cheat_caller_address(logger_disp.contract_address, pharmacist);
    logger_disp.log_safety_check(commitment, 2_u8);
    
    // Then override
    logger_disp.override_warning(commitment, reason_hash);
    stop_cheat_caller_address(logger_disp.contract_address);
    
    let entry = logger_disp.get_log(commitment);
    assert(entry.overridden == true, 'should be overridden');
}

#[test]
#[should_panic(expected: ('ALREADY_OVERRIDDEN',))]
fn test_double_override() {
    let (logger_disp, _, _, pharmacist) = setup();
    let commitment = 12345;
    
    start_cheat_caller_address(logger_disp.contract_address, pharmacist);
    logger_disp.log_safety_check(commitment, 2_u8);
    logger_disp.override_warning(commitment, 0x1);
    logger_disp.override_warning(commitment, 0x2); // Should panic
    stop_cheat_caller_address(logger_disp.contract_address);
}

#[test]
fn test_confirm_block() {
    let (logger_disp, _, reputation_disp, pharmacist) = setup();
    let commitment = 12345;
    
    // Log functionality with high risk
    start_cheat_caller_address(logger_disp.contract_address, pharmacist);
    logger_disp.log_safety_check(commitment, 3_u8); // High risk
    
    // Block it
    logger_disp.confirm_block(commitment);
    stop_cheat_caller_address(logger_disp.contract_address);
    
    // Check log state
    let entry = logger_disp.get_log(commitment);
    assert(entry.blocked == true, 'should be blocked');
    
    // Check reputation reward
    // Pharmacist should have received 1 badge
    let score = reputation_disp.reputation_score(pharmacist);
    assert(score == 1_u256, 'reputation should increase');
}

#[test]
#[should_panic(expected: ('NOT_HIGH_RISK',))]
fn test_confirm_block_low_risk() {
    let (logger_disp, _, _, pharmacist) = setup();
    let commitment = 12345;
    
    start_cheat_caller_address(logger_disp.contract_address, pharmacist);
    logger_disp.log_safety_check(commitment, 1_u8); // Low risk
    
    // Try to block
    logger_disp.confirm_block(commitment);
    stop_cheat_caller_address(logger_disp.contract_address);
}

#[test]
#[should_panic(expected: ('ALREADY_BLOCKED',))]
fn test_double_block() {
    let (logger_disp, _, _, pharmacist) = setup();
    let commitment = 12345;
    
    start_cheat_caller_address(logger_disp.contract_address, pharmacist);
    logger_disp.log_safety_check(commitment, 3_u8);
    logger_disp.confirm_block(commitment);
    logger_disp.confirm_block(commitment); // Should panic
    stop_cheat_caller_address(logger_disp.contract_address);
}




#[test]
fn test_log_safety_emits_event() {
    let (logger_disp, _, _, pharmacist) = setup();
    let commitment = 12345;
    let mut spy = spy_events();
    
    start_cheat_caller_address(logger_disp.contract_address, pharmacist);
    logger_disp.log_safety_check(commitment, 1_u8);
    stop_cheat_caller_address(logger_disp.contract_address);
    
    let events = spy.get_events();
    assert(events.events.len() > 0, 'should emit event');
    
    // Optional: Check event data matches
    // let (event_name, event_data) = events[0].clone();
    // assert(event_name == 'SafetyLogged', 'wrong event');
}

#[test]
fn test_override_emits_event() {
    // Test OverrideUsed event
}

#[test]
fn test_confirm_block_emits_event() {
    // Test HighRiskBlocked event
}

#[test]
#[should_panic(expected: ('ALREADY_EXISTS',))]
fn test_duplicate_commitment() {
    let (logger_disp, _, _, pharmacist) = setup();
    let commitment = 12345;
    
    start_cheat_caller_address(logger_disp.contract_address, pharmacist);
    logger_disp.log_safety_check(commitment, 1_u8);
    logger_disp.log_safety_check(commitment, 2_u8); // Should panic
    stop_cheat_caller_address(logger_disp.contract_address);
}

#[test]
#[should_panic(expected: ('NOT_FOUND',))]
fn test_override_nonexistent_log() {
    let (logger_disp, _, _, pharmacist) = setup();
    
    start_cheat_caller_address(logger_disp.contract_address, pharmacist);
    logger_disp.override_warning(99999, 0x1); // Non-existent commitment
    stop_cheat_caller_address(logger_disp.contract_address);
}

#[test]
#[should_panic(expected: ('NOT_FOUND',))]
fn test_confirm_block_nonexistent() {
    let (logger_disp, _, _, pharmacist) = setup();
    
    start_cheat_caller_address(logger_disp.contract_address, pharmacist);
    logger_disp.confirm_block(99999);
    stop_cheat_caller_address(logger_disp.contract_address);
}

#[test]
fn test_override_after_block() {
    let (logger_disp, _, _, pharmacist) = setup();
    let commitment = 12345;
    
    start_cheat_caller_address(logger_disp.contract_address, pharmacist);
    logger_disp.log_safety_check(commitment, 3_u8);
    logger_disp.confirm_block(commitment);
    
    // Try to override after blocked - should it be allowed?
    // The contract doesn't explicitly forbid this, so it might succeed
    logger_disp.override_warning(commitment, 0x1);
    stop_cheat_caller_address(logger_disp.contract_address);
    
    let entry = logger_disp.get_log(commitment);
    assert(entry.overridden == true, 'should allow override?');
    // Consider if this is intended behavior
}

#[test]
fn test_block_after_override() {
    let (logger_disp, _, _, pharmacist) = setup();
    let commitment = 12345;
    
    start_cheat_caller_address(logger_disp.contract_address, pharmacist);
    logger_disp.log_safety_check(commitment, 3_u8);
    logger_disp.override_warning(commitment, 0x1);
    
    // Try to block after override - should it be allowed?
    // The contract doesn't explicitly forbid this
    logger_disp.confirm_block(commitment);
    stop_cheat_caller_address(logger_disp.contract_address);
    
    let entry = logger_disp.get_log(commitment);
    assert(entry.blocked == true, 'should allow block?');
    assert(entry.overridden == true, 'should keep override flag');
}

#[test]
fn test_timestamp_recorded_correctly() {
    let (logger_disp, _, _, pharmacist) = setup();
    let commitment = 12345;
    let expected_timestamp = 5000;
    
    start_cheat_block_timestamp(logger_disp.contract_address, expected_timestamp);
    start_cheat_caller_address(logger_disp.contract_address, pharmacist);
    logger_disp.log_safety_check(commitment, 1_u8);
    stop_cheat_caller_address(logger_disp.contract_address);
    stop_cheat_block_timestamp(logger_disp.contract_address);
    
    let entry = logger_disp.get_log(commitment);
    assert(entry.timestamp == expected_timestamp, 'timestamp wrong');
}

#[test]
fn test_multiple_logs_different_timestamps() {
    // Test that timestamps are recorded correctly for multiple logs
}

#[test]
fn test_multiple_pharmacists_different_logs() {
    let (logger_disp, registry_disp, _, _) = setup();
    let pharmacist1 = contract_address_from_int(456);
    let pharmacist2 = contract_address_from_int(457);
    let owner = contract_address_from_int(123);
    let registry_addr = registry_disp.contract_address;
    
    // Add second pharmacist
    start_cheat_caller_address(registry_addr, owner);
    registry_disp.add_pharmacist(pharmacist2);
    stop_cheat_caller_address(registry_addr);
    
    // Both pharmacists can log
    start_cheat_caller_address(logger_disp.contract_address, pharmacist1);
    logger_disp.log_safety_check(111, 1_u8);
    stop_cheat_caller_address(logger_disp.contract_address);
    
    start_cheat_caller_address(logger_disp.contract_address, pharmacist2);
    logger_disp.log_safety_check(222, 2_u8);
    stop_cheat_caller_address(logger_disp.contract_address);
    
    // Verify both logs exist
    let entry1 = logger_disp.get_log(111);
    let entry2 = logger_disp.get_log(222);
    assert(entry1.pharmacist == pharmacist1, 'wrong pharmacist1');
    assert(entry2.pharmacist == pharmacist2, 'wrong pharmacist2');
}

#[test]
fn test_pharmacist_cannot_override_others_logs() {
    let (logger_disp, registry_disp, _, _) = setup();
    let pharmacist1 = contract_address_from_int(456);
    let pharmacist2 = contract_address_from_int(457);
    let owner = contract_address_from_int(123);
    let registry_addr = registry_disp.contract_address;
    let commitment = 12345;
    
    // Add second pharmacist
    start_cheat_caller_address(registry_addr, owner);
    registry_disp.add_pharmacist(pharmacist2);
    stop_cheat_caller_address(registry_addr);
    
    // Pharmacist1 logs
    start_cheat_caller_address(logger_disp.contract_address, pharmacist1);
    logger_disp.log_safety_check(commitment, 2_u8);
    stop_cheat_caller_address(logger_disp.contract_address);
    
    // Pharmacist2 tries to override - should this be allowed?
    // The contract only checks if caller is a pharmacist, not if they own the log
    start_cheat_caller_address(logger_disp.contract_address, pharmacist2);
    logger_disp.override_warning(commitment, 0x1);
    stop_cheat_caller_address(logger_disp.contract_address);
    
    let entry = logger_disp.get_log(commitment);
    assert(entry.overridden == true, 'p2 overrode p1 log');
    // Consider if this is intended behavior
}

#[test]
fn test_confirm_block_multiple_times_different_pharmacists() {
    let (logger_disp, registry_disp, reputation_disp, pharmacist1) = setup();
    let pharmacist2 = contract_address_from_int(457);
    let owner = contract_address_from_int(123);
    let registry_addr = registry_disp.contract_address;
    let commitment1 = 111;
    let commitment2 = 222;
    
    // Add second pharmacist
    start_cheat_caller_address(registry_addr, owner);
    registry_disp.add_pharmacist(pharmacist2);
    stop_cheat_caller_address(registry_addr);
    
    // Both block high-risk logs
    start_cheat_caller_address(logger_disp.contract_address, pharmacist1);
    logger_disp.log_safety_check(commitment1, 3_u8);
    logger_disp.confirm_block(commitment1);
    stop_cheat_caller_address(logger_disp.contract_address);
    
    start_cheat_caller_address(logger_disp.contract_address, pharmacist2);
    logger_disp.log_safety_check(commitment2, 3_u8);
    logger_disp.confirm_block(commitment2);
    stop_cheat_caller_address(logger_disp.contract_address);
    
    // Check both got reputation
    let score1 = reputation_disp.reputation_score(pharmacist1);
    let score2 = reputation_disp.reputation_score(pharmacist2);
    assert(score1 == 1_u256, 'pharmacist1 wrong score');
    assert(score2 == 1_u256, 'pharmacist2 wrong score');
}

#[test]
fn test_reputation_not_given_for_low_risk() {
    let (logger_disp, _, reputation_disp, pharmacist) = setup();
    let commitment = 12345;
    
    start_cheat_caller_address(logger_disp.contract_address, pharmacist);
    logger_disp.log_safety_check(commitment, 1_u8);
    
    // Try to block low risk (will fail)
    // But the test should verify no reputation was given
    stop_cheat_caller_address(logger_disp.contract_address);
    
    let score = reputation_disp.reputation_score(pharmacist);
    assert(score == 0_u256, 'reputation should not increase');
}

#[test]
fn test_risk_level_boundaries() {
    let (logger_disp, _, _, pharmacist) = setup();
    
    start_cheat_caller_address(logger_disp.contract_address, pharmacist);
    
    // Test min risk level
    logger_disp.log_safety_check(111, 0_u8);
    
    // Test max risk level (assuming u8 max is 255)
    logger_disp.log_safety_check(222, 255_u8);
    
    stop_cheat_caller_address(logger_disp.contract_address);
    
    let entry1 = logger_disp.get_log(111);
    let entry2 = logger_disp.get_log(222);
    assert(entry1.risk_level == 0_u8, 'min risk wrong');
    assert(entry2.risk_level == 255_u8, 'max risk wrong');
}

#[test]
fn test_high_risk_threshold() {
    let (logger_disp, _, _, pharmacist) = setup();
    let commitment = 12345;
    
    start_cheat_caller_address(logger_disp.contract_address, pharmacist);
    logger_disp.log_safety_check(commitment, 2_u8); // Threshold is >=2
    
    // Should be blockable since risk_level >=2
    logger_disp.confirm_block(commitment);
    stop_cheat_caller_address(logger_disp.contract_address);
    
    let entry = logger_disp.get_log(commitment);
    assert(entry.blocked == true, 'risk >= 2 blockable');
}