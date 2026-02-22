use starknet::ContractAddress;
use snforge_std::{declare, ContractClassTrait, DeclareResultTrait};
use snforge_std::{start_cheat_caller_address, stop_cheat_caller_address};
use snforge_std::cheatcodes::events::{spy_events, EventSpyTrait};

use contracts::pharmacistRegistry::{
    IPharmacistRegistryDispatcher,
    IPharmacistRegistryDispatcherTrait
};

// Helper function to convert to ContractAddress
fn contract_address_from_int(num: u128) -> ContractAddress {
    let felt: felt252 = num.into();
    felt.try_into().unwrap()
}

// ---------------------------------------------------------------- //
//                          DEPLOYMENT HELPERS                      //
// ---------------------------------------------------------------- //

fn deploy_registry() -> (IPharmacistRegistryDispatcher, ContractAddress, ContractAddress) {
    let contract = declare("PharmacistRegistry").unwrap();
    let owner = contract_address_from_int(123);
    let mut calldata = array![];
    owner.serialize(ref calldata);
    
    let (contract_address, _) = contract.contract_class().deploy(@calldata).unwrap();
    (IPharmacistRegistryDispatcher { contract_address }, contract_address, owner)
}

// ---------------------------------------------------------------- //
//                              TESTS                               //
// ---------------------------------------------------------------- //

#[test]
fn test_deploy_owner_set() {
    let (registry, _, owner) = deploy_registry();
    assert(registry.get_owner() == owner, 'wrong owner');
}

#[test]
fn test_add_pharmacist() {
    let (registry, registry_addr, owner) = deploy_registry();
    let pharmacist = contract_address_from_int(456);
    
    start_cheat_caller_address(registry_addr, owner);
    registry.add_pharmacist(pharmacist);
    stop_cheat_caller_address(registry_addr);
    
    assert(registry.is_pharmacist(pharmacist), 'should be pharmacist');
}

#[test]
fn test_add_pharmacist_emits_event() {
    let (registry, registry_addr, owner) = deploy_registry();
    let pharmacist = contract_address_from_int(456);
    let mut spy = spy_events();
    
    start_cheat_caller_address(registry_addr, owner);
    registry.add_pharmacist(pharmacist);
    stop_cheat_caller_address(registry_addr);
    
    let events = spy.get_events();
    assert(events.events.len() > 0, 'should emit event');
}

#[test]
#[should_panic(expected: ('NOT_OWNER',))]
fn test_add_pharmacist_unauthorized() {
    let (registry, registry_addr, _) = deploy_registry();
    let rando = contract_address_from_int(999);
    let pharmacist = contract_address_from_int(456);
    
    start_cheat_caller_address(registry_addr, rando);
    registry.add_pharmacist(pharmacist);
    stop_cheat_caller_address(registry_addr);
}

#[test]
#[should_panic(expected: ('ALREADY_REGISTERED',))]
fn test_add_same_pharmacist_twice() {
    let (registry, registry_addr, owner) = deploy_registry();
    let pharmacist = contract_address_from_int(456);
    
    start_cheat_caller_address(registry_addr, owner);
    registry.add_pharmacist(pharmacist);
    registry.add_pharmacist(pharmacist); // Should panic
    stop_cheat_caller_address(registry_addr);
}

#[test]
fn test_remove_pharmacist() {
    let (registry, registry_addr, owner) = deploy_registry();
    let pharmacist = contract_address_from_int(456);
    
    start_cheat_caller_address(registry_addr, owner);
    registry.add_pharmacist(pharmacist);
    registry.remove_pharmacist(pharmacist);
    stop_cheat_caller_address(registry_addr);
    
    assert(!registry.is_pharmacist(pharmacist), 'should not be pharmacist');
}

#[test]
#[should_panic(expected: ('NOT_REGISTERED',))]
fn test_remove_nonexistent_pharmacist() {
    let (registry, registry_addr, owner) = deploy_registry();
    let pharmacist = contract_address_from_int(456);
    
    start_cheat_caller_address(registry_addr, owner);
    registry.remove_pharmacist(pharmacist); // Should panic
    stop_cheat_caller_address(registry_addr);
}

#[test]
#[should_panic(expected: ('NOT_OWNER',))]
fn test_remove_pharmacist_unauthorized() {
    let (registry, registry_addr, owner) = deploy_registry();
    let rando = contract_address_from_int(999);
    let pharmacist = contract_address_from_int(456);
    
    // Add first
    start_cheat_caller_address(registry_addr, owner);
    registry.add_pharmacist(pharmacist);
    stop_cheat_caller_address(registry_addr);
    
    // Rando tries to remove
    start_cheat_caller_address(registry_addr, rando);
    registry.remove_pharmacist(pharmacist);
    stop_cheat_caller_address(registry_addr);
}

#[test]
fn test_transfer_ownership() {
    let (registry, registry_addr, owner) = deploy_registry();
    let new_owner = contract_address_from_int(789);
    
    start_cheat_caller_address(registry_addr, owner);
    registry.transfer_ownership(new_owner);
    stop_cheat_caller_address(registry_addr);
    
    assert(registry.get_owner() == new_owner, 'wrong new owner');
}

#[test]
#[should_panic(expected: ('NOT_OWNER',))]
fn test_transfer_ownership_unauthorized() {
    let (registry, registry_addr, _) = deploy_registry();
    let rando = contract_address_from_int(999);
    let new_owner = contract_address_from_int(789);
    
    start_cheat_caller_address(registry_addr, rando);
    registry.transfer_ownership(new_owner);
    stop_cheat_caller_address(registry_addr);
}

#[test]
fn test_add_remove_add_cycle() {
    let (registry, registry_addr, owner) = deploy_registry();
    let pharmacist = contract_address_from_int(456);
    
    start_cheat_caller_address(registry_addr, owner);
    
    // 1. Add
    registry.add_pharmacist(pharmacist);
    assert(registry.is_pharmacist(pharmacist), 'should be pharmacist');
    
    // 2. Remove
    registry.remove_pharmacist(pharmacist);
    assert(!registry.is_pharmacist(pharmacist), 'should not be pharmacist');
    
    // 3. Add again
    registry.add_pharmacist(pharmacist);
    assert(registry.is_pharmacist(pharmacist), 'should be pharmacist again');
    
    stop_cheat_caller_address(registry_addr);
}

#[test]
fn test_post_transfer_permissions() {
    let (registry, registry_addr, owner) = deploy_registry();
    let new_owner = contract_address_from_int(789);
    let pharmacist = contract_address_from_int(456);
    
    start_cheat_caller_address(registry_addr, owner);
    registry.transfer_ownership(new_owner);
    stop_cheat_caller_address(registry_addr);
    
    // Old owner tries to add mock pharmacist
    start_cheat_caller_address(registry_addr, owner);
    // This should fail ideally, but we need #[should_panic] for test functions.
    // Since we can't switch expected panic mid-test easily, we just verify owner changed
    // and rely on internal logic that asserts caller == owner.
    // Instead, let's just assert the new owner can add.
    stop_cheat_caller_address(registry_addr);

    start_cheat_caller_address(registry_addr, new_owner);
    registry.add_pharmacist(pharmacist);
    stop_cheat_caller_address(registry_addr);
    
    assert(registry.is_pharmacist(pharmacist), 'new owner should add');
}

#[test]
#[should_panic(expected: ('NOT_OWNER',))]
fn test_old_owner_cannot_add() {
    let (registry, registry_addr, owner) = deploy_registry();
    let new_owner = contract_address_from_int(789);
    let pharmacist = contract_address_from_int(456);
    
    start_cheat_caller_address(registry_addr, owner);
    registry.transfer_ownership(new_owner);
    // Don't stop cheat yet, we want to simulate old owner
    
    registry.add_pharmacist(pharmacist); // Should panic
    stop_cheat_caller_address(registry_addr);
}

#[test]
#[should_panic(expected: ('INVALID_ADDRESS',))]
fn test_add_zero_address_pharmacist() {
    let (registry, registry_addr, owner) = deploy_registry();
    let zero_addr = contract_address_from_int(0);
    
    start_cheat_caller_address(registry_addr, owner);
    registry.add_pharmacist(zero_addr);
    stop_cheat_caller_address(registry_addr);
}

#[test]
#[should_panic(expected: ('INVALID_ADDRESS',))]
fn test_transfer_to_zero_address() {
    let (registry, registry_addr, owner) = deploy_registry();
    let zero_addr = contract_address_from_int(0);
    
    start_cheat_caller_address(registry_addr, owner);
    registry.transfer_ownership(zero_addr);
    stop_cheat_caller_address(registry_addr);
}
