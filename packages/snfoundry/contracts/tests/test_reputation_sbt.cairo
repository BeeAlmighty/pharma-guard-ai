use starknet::ContractAddress;
use snforge_std::{declare, ContractClassTrait, DeclareResultTrait};
use snforge_std::{start_cheat_caller_address, stop_cheat_caller_address};
use snforge_std::cheatcodes::events::spy_events;
use snforge_std::cheatcodes::events::{EventSpyTrait};

// In integration tests, use contracts:: to import from your contract
use contracts::reputationSBT::{
    IReputationSBTDispatcher,
    IReputationSBTDispatcherTrait
};

// Helper function to convert to ContractAddress
fn contract_address_from_int(num: u128) -> ContractAddress {
    let felt: felt252 = num.into();
    felt.try_into().unwrap()
}

fn deploy_contract() -> (IReputationSBTDispatcher, ContractAddress) {
    // declare returns a Result, so we need to unwrap it first
    let contract = declare("ReputationSBT").unwrap();
    let initial_owner = contract_address_from_int(123);
    let mut calldata = array![];
    initial_owner.serialize(ref calldata);
    
    // deploy is called on the ContractClass - we need ContractClassTrait in scope
    let (contract_address, _) = contract.contract_class().deploy(@calldata).unwrap();
    (IReputationSBTDispatcher { contract_address }, contract_address)
}

fn deploy_with_logger() -> (IReputationSBTDispatcher, ContractAddress, ContractAddress) {
    let (dispatcher, contract_address) = deploy_contract();
    let logger = contract_address_from_int(456);
    let owner = contract_address_from_int(123);
    
    start_cheat_caller_address(contract_address, owner);
    dispatcher.set_medical_logger(logger);
    stop_cheat_caller_address(contract_address);
    
    (dispatcher, contract_address, logger)
}

#[test]
fn test_constructor() {
    let (dispatcher, _) = deploy_contract();
    
    let score = dispatcher.reputation_score(contract_address_from_int(1));
    assert(score == 0_u256, 'initial score should be 0');
}

#[test]
fn test_mint_lifesaver_badge() {
    let (dispatcher, contract_address, logger) = deploy_with_logger();
    let user = contract_address_from_int(789);
    
    start_cheat_caller_address(contract_address, logger);
    dispatcher.mint_lifesaver_badge(user);
    stop_cheat_caller_address(contract_address);
    
    assert(dispatcher.owner_of(1_u256) == user, 'wrong owner');
    assert(dispatcher.reputation_score(user) == 1_u256, 'wrong score');
}

#[test]
#[should_panic(expected: ('NOT_AUTHORIZED',))]
fn test_mint_unauthorized() {
    let (dispatcher, contract_address, _) = deploy_with_logger();
    let user = contract_address_from_int(789);
    let attacker = contract_address_from_int(999);
    
    start_cheat_caller_address(contract_address, attacker);
    dispatcher.mint_lifesaver_badge(user);
    stop_cheat_caller_address(contract_address);
}

#[test]
fn test_mint_multiple_badges() {
    let (dispatcher, contract_address, logger) = deploy_with_logger();
    let user1 = contract_address_from_int(789);
    let user2 = contract_address_from_int(790);
    
    start_cheat_caller_address(contract_address, logger);
    
    dispatcher.mint_lifesaver_badge(user1);
    dispatcher.mint_lifesaver_badge(user1);
    dispatcher.mint_lifesaver_badge(user2);
    
    stop_cheat_caller_address(contract_address);
    
    assert(dispatcher.reputation_score(user1) == 2_u256, 'user1 should have 2');
    assert(dispatcher.reputation_score(user2) == 1_u256, 'user2 should have 1');
    assert(dispatcher.owner_of(1_u256) == user1, 'token1 wrong owner');
    assert(dispatcher.owner_of(2_u256) == user1, 'token2 wrong owner');
    assert(dispatcher.owner_of(3_u256) == user2, 'token3 wrong owner');
}

#[test]
fn test_reputation_score() {
    let (dispatcher, contract_address, logger) = deploy_with_logger();
    let user = contract_address_from_int(789);
    let non_user = contract_address_from_int(790);
    
    // Initial score should be 0
    assert(dispatcher.reputation_score(user) == 0_u256, 'initial score wrong');
    assert(dispatcher.reputation_score(non_user) == 0_u256, 'initial score wrong');
    
    // Mint a badge
    start_cheat_caller_address(contract_address, logger);
    dispatcher.mint_lifesaver_badge(user);
    stop_cheat_caller_address(contract_address);
    
    // Check updated score
    assert(dispatcher.reputation_score(user) == 1_u256, 'score should be 1');
    assert(dispatcher.reputation_score(non_user) == 0_u256, 'non-user score should be 0');
}

#[test]
fn test_owner_of() {
    let (dispatcher, contract_address, logger) = deploy_with_logger();
    let user = contract_address_from_int(789);
    
    start_cheat_caller_address(contract_address, logger);
    dispatcher.mint_lifesaver_badge(user);
    stop_cheat_caller_address(contract_address);
    
    assert(dispatcher.owner_of(1_u256) == user, 'wrong owner');
}

#[test]
#[should_panic(expected: ('INVALID_TOKEN',))]
fn test_owner_of_nonexistent_token() {
    let (dispatcher, _, _) = deploy_with_logger();
    
    // Try to get owner of non-existent token
    dispatcher.owner_of(999_u256);
}

#[test]
fn test_set_medical_logger() {
    let (dispatcher, contract_address, _initial_logger) = deploy_with_logger();
    let new_logger = contract_address_from_int(999);
    let owner = contract_address_from_int(123);
    
    // Set new logger as owner
    start_cheat_caller_address(contract_address, owner);
    dispatcher.set_medical_logger(new_logger);
    stop_cheat_caller_address(contract_address);
    
    // Verify new logger can mint
    start_cheat_caller_address(contract_address, new_logger);
    let user = contract_address_from_int(789);
    dispatcher.mint_lifesaver_badge(user);
    stop_cheat_caller_address(contract_address);
    
    assert(dispatcher.owner_of(1_u256) == user, 'mint with new logger failed');
}

#[test]
#[should_panic(expected: ('NOT_OWNER',))]
fn test_set_medical_logger_unauthorized() {
    let (dispatcher, contract_address, _) = deploy_with_logger();
    let attacker = contract_address_from_int(999);
    let new_logger = contract_address_from_int(888);
    
    // Try to set logger as non-owner
    start_cheat_caller_address(contract_address, attacker);
    dispatcher.set_medical_logger(new_logger);
    stop_cheat_caller_address(contract_address);
}

#[test]
fn test_transfer_ownership() {
    let (dispatcher, contract_address, _logger) = deploy_with_logger();
    let new_owner = contract_address_from_int(999);
    let owner = contract_address_from_int(123);
    
    // Transfer ownership
    start_cheat_caller_address(contract_address, owner);
    dispatcher.transfer_ownership(new_owner);
    stop_cheat_caller_address(contract_address);
    
    // New owner should be able to set logger
    let new_logger = contract_address_from_int(777);
    start_cheat_caller_address(contract_address, new_owner);
    dispatcher.set_medical_logger(new_logger);
    stop_cheat_caller_address(contract_address);
    
    // New logger should be able to mint
    start_cheat_caller_address(contract_address, new_logger);
    let user = contract_address_from_int(555);
    dispatcher.mint_lifesaver_badge(user);
    stop_cheat_caller_address(contract_address);
    
    assert(dispatcher.owner_of(1_u256) == user, 'mint after owner transfer fail');
}

#[test]
#[should_panic(expected: ('NOT_OWNER',))]
fn test_transfer_ownership_unauthorized() {
    let (dispatcher, contract_address, _) = deploy_with_logger();
    let attacker = contract_address_from_int(999);
    let new_owner = contract_address_from_int(888);
    
    // Try to transfer ownership as non-owner
    start_cheat_caller_address(contract_address, attacker);
    dispatcher.transfer_ownership(new_owner);
    stop_cheat_caller_address(contract_address);
}

#[test]
fn test_medical_logger_privileges() {
    let (dispatcher, contract_address, logger) = deploy_with_logger();
    let user = contract_address_from_int(777);
    
    start_cheat_caller_address(contract_address, logger);
    
    // Medical logger can mint
    dispatcher.mint_lifesaver_badge(user);
    
    stop_cheat_caller_address(contract_address);
    
    assert(dispatcher.owner_of(1_u256) == user, 'logger should be able to mint');
}

#[test]
fn test_multiple_loggers() {
    let (dispatcher, contract_address, _initial_logger) = deploy_with_logger();
    let user = contract_address_from_int(777);
    let owner = contract_address_from_int(123);
    
    // Set new logger
    let logger2 = contract_address_from_int(888);
    start_cheat_caller_address(contract_address, owner);
    dispatcher.set_medical_logger(logger2);
    stop_cheat_caller_address(contract_address);
    
    // New logger should work
    start_cheat_caller_address(contract_address, logger2);
    dispatcher.mint_lifesaver_badge(user);
    stop_cheat_caller_address(contract_address);
    
    assert(dispatcher.owner_of(1_u256) == user, 'new logger mint failed');
}
// new tests
#[test]
fn test_mint_emits_event() {
    let (dispatcher, contract_address, logger) = deploy_with_logger();
    let user = contract_address_from_int(789);
    let mut spy = spy_events();
    
    start_cheat_caller_address(contract_address, logger);
    dispatcher.mint_lifesaver_badge(user);
    stop_cheat_caller_address(contract_address);
    
    let events = spy.get_events();
    assert(events.events.len() > 0, 'should emit event');
}

#[test]
#[should_panic(expected: ('NOT_AUTHORIZED',))]
fn test_previous_logger_cannot_mint() {
    let (dispatcher, contract_address, initial_logger) = deploy_with_logger();
    let new_logger = contract_address_from_int(999);
    let owner = contract_address_from_int(123);
    let user = contract_address_from_int(777);
    
    // Change logger
    start_cheat_caller_address(contract_address, owner);
    dispatcher.set_medical_logger(new_logger);
    stop_cheat_caller_address(contract_address);
    
    // Old logger tries to mint
    start_cheat_caller_address(contract_address, initial_logger);
    dispatcher.mint_lifesaver_badge(user); // Should panic
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('INVALID_TOKEN',))]
fn test_owner_of_burned_token() {
    let (dispatcher, contract_address, logger) = deploy_with_logger();
    let user = contract_address_from_int(789);
    
    start_cheat_caller_address(contract_address, logger);
    dispatcher.mint_lifesaver_badge(user);
    // If you add a burn function later, test it
    stop_cheat_caller_address(contract_address);
    
    // For now, test non-existent token
    dispatcher.owner_of(999_u256);
}