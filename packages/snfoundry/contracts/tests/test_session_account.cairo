use starknet::ContractAddress;
use snforge_std::{declare, ContractClassTrait, DeclareResultTrait};
use snforge_std::{start_cheat_signature, stop_cheat_signature};
use snforge_std::{start_cheat_block_timestamp, stop_cheat_block_timestamp};
use snforge_std::cheatcodes::events::{spy_events, EventSpyTrait};
use starknet::account::Call;
use starknet::VALIDATED;

use contracts::sessionAccount::{
    ISessionAccountDispatcher,
    ISessionAccountDispatcherTrait
};

// Helper function to convert to ContractAddress
fn contract_address_from_int(num: u128) -> ContractAddress {
    let felt: felt252 = num.into();
    felt.try_into().unwrap()
}

// ---------------------------------------------------------------- //
//                          DEPLOYMENT HELPERS                      //
// ---------------------------------------------------------------- //

fn deploy_account() -> (ISessionAccountDispatcher, ContractAddress, felt252) {
    let contract = declare("SessionAccount").unwrap();
    let owner_pubkey: felt252 = 123;
    let public_key: felt252 = 123; // Account public key
    let mut calldata = array![];
    owner_pubkey.serialize(ref calldata);
    public_key.serialize(ref calldata);
    
    let (contract_address, _) = contract.contract_class().deploy(@calldata).unwrap();
    (ISessionAccountDispatcher { contract_address }, contract_address, owner_pubkey)
}

// ---------------------------------------------------------------- //
//                              TESTS                               //
// ---------------------------------------------------------------- //

#[test]
fn test_deploy_owner_set() {
    let (account, _, owner_key) = deploy_account();
    assert(account.get_owner() == owner_key, 'wrong owner');
}

#[test]
fn test_authorize_session() {
    let (account, account_addr, owner_key) = deploy_account();
    let session_key: felt252 = 999;
    let expires_at: u64 = 1000;
    let allowed_target = contract_address_from_int(888);
    
    // Cheat signature to mimic owner
    start_cheat_signature(account_addr, array![owner_key].span());
    
    account.authorize_session(session_key, expires_at, allowed_target);
    
    stop_cheat_signature(account_addr);
    
    // Since we can't read storage directly via interface, we rely on no panic
    // and ideally check events
}

#[test]
fn test_authorize_session_emits_event() {
    let (account, account_addr, owner_key) = deploy_account();
    let session_key: felt252 = 999;
    let expires_at: u64 = 1000;
    let allowed_target = contract_address_from_int(888);
    let mut spy = spy_events();
    
    start_cheat_signature(account_addr, array![owner_key].span());
    account.authorize_session(session_key, expires_at, allowed_target);
    stop_cheat_signature(account_addr);
    
    let events = spy.get_events();
    assert(events.events.len() > 0, 'should emit event');
}

#[test]
#[should_panic(expected: ('NOT_OWNER',))]
fn test_authorize_session_unauthorized() {
    let (account, account_addr, _) = deploy_account();
    let session_key: felt252 = 999;
    
    // Wrong signature
    let bad_key: felt252 = 666;
    start_cheat_signature(account_addr, array![bad_key].span());
    
    account.authorize_session(session_key, 1000, contract_address_from_int(888));
    
    stop_cheat_signature(account_addr);
}

#[test]
fn test_revoke_session() {
    let (account, account_addr, owner_key) = deploy_account();
    let session_key: felt252 = 999;
    
    // Authorize first
    start_cheat_signature(account_addr, array![owner_key].span());
    account.authorize_session(session_key, 1000, contract_address_from_int(888));
    
    // Revoke
    account.revoke_session(session_key);
    stop_cheat_signature(account_addr);
}

#[test]
fn test_revoke_session_emits_event() {
    let (account, account_addr, owner_key) = deploy_account();
    let session_key: felt252 = 999;
    let mut spy = spy_events();
    
    start_cheat_signature(account_addr, array![owner_key].span());
    account.authorize_session(session_key, 1000, contract_address_from_int(888));
    account.revoke_session(session_key);
    stop_cheat_signature(account_addr);
    
    let events = spy.get_events();
    // Should have authorized and revoked events (at least 2 events total, maybe more from inner components)
    assert(events.events.len() >= 2, 'should emit events');
}

#[test]
fn test_get_session() {
    let (account, account_addr, owner_key) = deploy_account();
    let session_key: felt252 = 999;
    let expires_at: u64 = 1000;
    let allowed_target = contract_address_from_int(888);
    
    start_cheat_signature(account_addr, array![owner_key].span());
    account.authorize_session(session_key, expires_at, allowed_target);
    stop_cheat_signature(account_addr);
    
    let session = account.get_session(session_key);
    assert(session.expires_at == expires_at, 'wrong expiry');
    assert(session.allowed_target == allowed_target, 'wrong target');
    assert(session.active == true, 'should be active');
}

#[test]
fn test_is_session_active() {
    let (account, account_addr, owner_key) = deploy_account();
    let session_key: felt252 = 999;
    let expires_at: u64 = 1000;
    
    start_cheat_signature(account_addr, array![owner_key].span());
    account.authorize_session(session_key, expires_at, contract_address_from_int(888));
    stop_cheat_signature(account_addr);
    
    // Active case
    start_cheat_block_timestamp(account_addr, 500);
    assert(account.is_session_active(session_key), 'should be active');
    
    // Expired case
    start_cheat_block_timestamp(account_addr, 1001);
    assert(!account.is_session_active(session_key), 'should be expired');
    stop_cheat_block_timestamp(account_addr);
    
    // Revoked case
    start_cheat_signature(account_addr, array![owner_key].span());
    account.revoke_session(session_key);
    stop_cheat_signature(account_addr);
    
    start_cheat_block_timestamp(account_addr, 500);
    assert(!account.is_session_active(session_key), 'should be inactive(revoked)');
    stop_cheat_block_timestamp(account_addr);
}

#[test]
fn test_get_all_sessions() {
    let (account, account_addr, owner_key) = deploy_account();
    let session1: felt252 = 111;
    let session2: felt252 = 222;
    
    start_cheat_signature(account_addr, array![owner_key].span());
    account.authorize_session(session1, 1000, contract_address_from_int(888));
    account.authorize_session(session2, 2000, contract_address_from_int(999));
    stop_cheat_signature(account_addr);
    
    let sessions = account.get_all_sessions();
    assert(sessions.len() == 2, 'wrong count');
    assert(*sessions.at(0) == session1, 'wrong session1');
    assert(*sessions.at(1) == session2, 'wrong session2');
}

#[test]
fn test_duplicate_authorization() {
    let (account, account_addr, owner_key) = deploy_account();
    let session_key: felt252 = 999;
    
    start_cheat_signature(account_addr, array![owner_key].span());
    account.authorize_session(session_key, 1000, contract_address_from_int(888));
    
    // Update existing session (should work and overwrite)
    account.authorize_session(session_key, 2000, contract_address_from_int(777));
    stop_cheat_signature(account_addr);
    
    let session = account.get_session(session_key);
    assert(session.expires_at == 2000, 'should update expiry');
    assert(session.allowed_target == contract_address_from_int(777), 'should update target');
}

#[test]
fn test_double_revocation() {
    let (account, account_addr, owner_key) = deploy_account();
    let session_key: felt252 = 999;
    
    start_cheat_signature(account_addr, array![owner_key].span());
    account.authorize_session(session_key, 1000, contract_address_from_int(888));
    
    account.revoke_session(session_key);
    account.revoke_session(session_key); // Should not panic
    stop_cheat_signature(account_addr);
    
    assert(!account.is_session_active(session_key), 'should be inactive');
}

#[test]
fn test_revoke_non_existent() {
    let (account, account_addr, owner_key) = deploy_account();
    let session_key: felt252 = 999; // Never authorized
    
    start_cheat_signature(account_addr, array![owner_key].span());
    account.revoke_session(session_key); // Should not panic
    stop_cheat_signature(account_addr);
}

#[test]
fn test_validate_session_integration() {
    let (account, account_addr, owner_key) = deploy_account();
    let session_key: felt252 = 999;
    let expires_at: u64 = 1000;
    let allowed_target = contract_address_from_int(888);
    
    // Authorize
    start_cheat_signature(account_addr, array![owner_key].span());
    account.authorize_session(session_key, expires_at, allowed_target);
    stop_cheat_signature(account_addr);
    
    let call = Call {
        to: allowed_target,
        selector: 0x123,
        calldata: array![].span()
    };
    let calls = array![call];
    
    // 1. Valid session
    start_cheat_block_timestamp(account_addr, 500);
    let ret = account.validate_session(session_key, calls.clone());
    assert(ret == VALIDATED, 'should validate');
    
    // 2. Expired session
    start_cheat_block_timestamp(account_addr, 1001);
    let ret = account.validate_session(session_key, calls.clone());
    assert(ret == 'SESSION_EXPIRED', 'should be expired');
    stop_cheat_block_timestamp(account_addr); // Reset time
    
    // 3. Invalid Target
    start_cheat_block_timestamp(account_addr, 500);
    let bad_call = Call {
        to: contract_address_from_int(999), 
        selector: 0x123,
        calldata: array![].span()
    };
    let bad_calls = array![bad_call];
    let ret = account.validate_session(session_key, bad_calls);
    assert(ret == 'INVALID_TARGET', 'should invalid target');
    
    // 4. Revoked Session (Internal state check)
    start_cheat_signature(account_addr, array![owner_key].span());
    account.revoke_session(session_key);
    stop_cheat_signature(account_addr);
    
    let ret = account.validate_session(session_key, calls);
    assert(ret == 'INVALID_SESSION', 'should be invalid');
}
