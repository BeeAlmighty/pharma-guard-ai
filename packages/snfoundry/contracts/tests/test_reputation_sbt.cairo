use starknet::ContractAddress;
use snforge_std::{ declare, ContractClassTrait, start_prank, stop_prank, spy_events, EventSpy, EventAssertions };
use contracts::reputationSBT::{ IReputationSBTDispatcher, IReputationSBTDispatcherTrait };

fn deploy_contract() -> (IReputationSBTDispatcher, ContractAddress) {
    let contract = declare("ReputationSBT");
    let initial_owner: ContractAddress = 123.try_into().unwrap();
    let mut calldata = array![];
    initial_owner.serialize(ref calldata);
    
    let contract_address = contract.deploy(@calldata).unwrap();
    (IReputationSBTDispatcher { contract_address }, contract_address)
}

fn deploy_with_logger() -> (IReputationSBTDispatcher, ContractAddress, ContractAddress) {
    let (dispatcher, contract_address) = deploy_contract();
    let logger: ContractAddress = 456.try_into().unwrap();
    
    // Set medical logger as owner
    start_prank(contract_address, 123.try_into().unwrap());
    dispatcher.set_medical_logger(logger);
    stop_prank(contract_address);
    
    (dispatcher, contract_address, logger)
}

#[test]
fn test_constructor() {
    let (_, contract_address) = deploy_contract();
    let dispatcher = IReputationSBTDispatcher { contract_address };
    let initial_owner: ContractAddress = 123.try_into().unwrap();
    
    // Check initial state - token 1 should not exist
    let result = core::panic::catch::<(), _>(|| {
        dispatcher.owner_of(1_u256);
    });
    assert(result.is_err(), 'token 1 should not exist');
}

#[test]
fn test_mint_lifesaver_badge() {
    let (dispatcher, contract_address, logger) = deploy_with_logger();
    let user: ContractAddress = 789.try_into().unwrap();
    
    // Mint as logger
    start_prank(contract_address, logger);
    dispatcher.mint_lifesaver_badge(user);
    stop_prank(contract_address);
    
    // Check token ownership
    assert(dispatcher.owner_of(1_u256) == user, 'wrong owner');
    
    // Check reputation score
    assert(dispatcher.reputation_score(user) == 1_u256, 'wrong score');
}

#[test]
#[should_panic(expected: ('NOT_AUTHORIZED',))]
fn test_mint_unauthorized() {
    let (dispatcher, contract_address, _) = deploy_with_logger();
    let user: ContractAddress = 789.try_into().unwrap();
    let attacker: ContractAddress = 999.try_into().unwrap();
    
    // Try to mint as non-logger
    start_prank(contract_address, attacker);
    dispatcher.mint_lifesaver_badge(user);
    stop_prank(contract_address);
}

#[test]
fn test_mint_multiple_badges() {
    let (dispatcher, contract_address, logger) = deploy_with_logger();
    let user1: ContractAddress = 789.try_into().unwrap();
    let user2: ContractAddress = 790.try_into().unwrap();
    
    start_prank(contract_address, logger);
    
    // Mint multiple badges to same user
    dispatcher.mint_lifesaver_badge(user1);
    dispatcher.mint_lifesaver_badge(user1);
    dispatcher.mint_lifesaver_badge(user2);
    
    stop_prank(contract_address);
    
    // Check scores
    assert(dispatcher.reputation_score(user1) == 2_u256, 'user1 should have 2');
    assert(dispatcher.reputation_score(user2) == 1_u256, 'user2 should have 1');
    
    // Check token IDs
    assert(dispatcher.owner_of(1_u256) == user1, 'token1 wrong owner');
    assert(dispatcher.owner_of(2_u256) == user1, 'token2 wrong owner');
    assert(dispatcher.owner_of(3_u256) == user2, 'token3 wrong owner');
}

#[test]
fn test_reputation_score() {
    let (dispatcher, contract_address, logger) = deploy_with_logger();
    let user: ContractAddress = 789.try_into().unwrap();
    let non_user: ContractAddress = 790.try_into().unwrap();
    
    // Initial score should be 0
    assert(dispatcher.reputation_score(user) == 0_u256, 'initial score wrong');
    assert(dispatcher.reputation_score(non_user) == 0_u256, 'initial score wrong');
    
    // Mint a badge
    start_prank(contract_address, logger);
    dispatcher.mint_lifesaver_badge(user);
    stop_prank(contract_address);
    
    // Check updated score
    assert(dispatcher.reputation_score(user) == 1_u256, 'score should be 1');
    assert(dispatcher.reputation_score(non_user) == 0_u256, 'non-user score should be 0');
}

#[test]
fn test_owner_of() {
    let (dispatcher, contract_address, logger) = deploy_with_logger();
    let user: ContractAddress = 789.try_into().unwrap();
    
    start_prank(contract_address, logger);
    dispatcher.mint_lifesaver_badge(user);
    stop_prank(contract_address);
    
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
    let (dispatcher, contract_address, initial_logger) = deploy_with_logger();
    let new_logger: ContractAddress = 999.try_into().unwrap();
    
    // Set new logger as owner
    start_prank(contract_address, 123.try_into().unwrap());
    dispatcher.set_medical_logger(new_logger);
    stop_prank(contract_address);
    
    // Try minting with old logger - should fail
    start_prank(contract_address, initial_logger);
    let user: ContractAddress = 789.try_into().unwrap();
    
    let result = core::panic::catch::<(), _>(|| {
        dispatcher.mint_lifesaver_badge(user);
    });
    assert(result.is_err(), 'old logger should not work');
    stop_prank(contract_address);
    
    // Mint with new logger - should succeed
    start_prank(contract_address, new_logger);
    dispatcher.mint_lifesaver_badge(user);
    stop_prank(contract_address);
    
    assert(dispatcher.owner_of(1_u256) == user, 'mint with new logger failed');
}

#[test]
#[should_panic(expected: ('NOT_OWNER',))]
fn test_set_medical_logger_unauthorized() {
    let (dispatcher, contract_address, _) = deploy_with_logger();
    let attacker: ContractAddress = 999.try_into().unwrap();
    let new_logger: ContractAddress = 888.try_into().unwrap();
    
    // Try to set logger as non-owner
    start_prank(contract_address, attacker);
    dispatcher.set_medical_logger(new_logger);
    stop_prank(contract_address);
}

#[test]
fn test_transfer_ownership() {
    let (dispatcher, contract_address, logger) = deploy_with_logger();
    let new_owner: ContractAddress = 999.try_into().unwrap();
    
    // Transfer ownership
    start_prank(contract_address, 123.try_into().unwrap());
    dispatcher.transfer_ownership(new_owner);
    stop_prank(contract_address);
    
    // Old owner should not be able to set logger
    start_prank(contract_address, 123.try_into().unwrap());
    let result = core::panic::catch::<(), _>(|| {
        dispatcher.set_medical_logger(456.try_into().unwrap());
    });
    assert(result.is_err(), 'old owner should not work');
    stop_prank(contract_address);
    
    // New owner should be able to set logger
    let new_logger: ContractAddress = 777.try_into().unwrap();
    start_prank(contract_address, new_owner);
    dispatcher.set_medical_logger(new_logger);
    stop_prank(contract_address);
    
    // New logger should be able to mint
    start_prank(contract_address, new_logger);
    let user: ContractAddress = 555.try_into().unwrap();
    dispatcher.mint_lifesaver_badge(user);
    stop_prank(contract_address);
    
    assert(dispatcher.owner_of(1_u256) == user, 'mint after ownership transfer failed');
}

#[test]
#[should_panic(expected: ('NOT_OWNER',))]
fn test_transfer_ownership_unauthorized() {
    let (dispatcher, contract_address, _) = deploy_with_logger();
    let attacker: ContractAddress = 999.try_into().unwrap();
    let new_owner: ContractAddress = 888.try_into().unwrap();
    
    // Try to transfer ownership as non-owner
    start_prank(contract_address, attacker);
    dispatcher.transfer_ownership(new_owner);
    stop_prank(contract_address);
}

#[test]
fn test_events() {
    let (dispatcher, contract_address, logger) = deploy_with_logger();
    
    // Test OwnershipTransferred event
    let mut spy = spy_events();
    start_prank(contract_address, 123.try_into().unwrap());
    let new_owner: ContractAddress = 999.try_into().unwrap();
    dispatcher.transfer_ownership(new_owner);
    stop_prank(contract_address);
    spy.assert_emitted(@array![
        (
            dispatcher.contract_address,
            'OwnershipTransferred',
            array![123, 999]
        )
    ]);
    
    // Test MedicalLoggerUpdated event
    let mut spy = spy_events();
    start_prank(contract_address, new_owner);
    let new_logger: ContractAddress = 888.try_into().unwrap();
    dispatcher.set_medical_logger(new_logger);
    stop_prank(contract_address);
    spy.assert_emitted(@array![
        (
            dispatcher.contract_address,
            'MedicalLoggerUpdated',
            array![888]
        )
    ]);
    
    // Test LifesaverBadgeMinted event
    let mut spy = spy_events();
    start_prank(contract_address, new_logger);
    let user: ContractAddress = 777.try_into().unwrap();
    dispatcher.mint_lifesaver_badge(user);
    stop_prank(contract_address);
    spy.assert_emitted(@array![
        (
            dispatcher.contract_address,
            'LifesaverBadgeMinted',
            array![777, 1]
        )
    ]);
}

#[test]
fn test_medical_logger_privileges() {
    let (dispatcher, contract_address, logger) = deploy_with_logger();
    let user: ContractAddress = 777.try_into().unwrap();
    
    start_prank(contract_address, logger);
    
    // Medical logger can mint
    dispatcher.mint_lifesaver_badge(user);
    
    // Medical logger cannot transfer ownership
    let result = core::panic::catch::<(), _>(|| {
        dispatcher.transfer_ownership(999.try_into().unwrap());
    });
    assert(result.is_err(), 'logger should not transfer ownership');
    
    // Medical logger cannot set new medical logger (only owner can)
    let result = core::panic::catch::<(), _>(|| {
        dispatcher.set_medical_logger(888.try_into().unwrap());
    });
    assert(result.is_err(), 'logger should not set new logger');
    
    stop_prank(contract_address);
}

#[test]
fn test_multiple_loggers() {
    let (dispatcher, contract_address, initial_logger) = deploy_with_logger();
    let user: ContractAddress = 777.try_into().unwrap();
    
    // Only one logger should exist at a time
    start_prank(contract_address, 123.try_into().unwrap());
    let logger2: ContractAddress = 888.try_into().unwrap();
    dispatcher.set_medical_logger(logger2);
    stop_prank(contract_address);
    
    // Initial logger should no longer work
    start_prank(contract_address, initial_logger);
    let result = core::panic::catch::<(), _>(|| {
        dispatcher.mint_lifesaver_badge(user);
    });
    assert(result.is_err(), 'old logger should not work');
    stop_prank(contract_address);
    
    // New logger should work
    start_prank(contract_address, logger2);
    dispatcher.mint_lifesaver_badge(user);
    stop_prank(contract_address);
    
    assert(dispatcher.owner_of(1_u256) == user, 'new logger mint failed');
}