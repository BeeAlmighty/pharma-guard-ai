
use starknet::ContractAddress;
use starknet::get_caller_address;
use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
use starknet::class_hash::ClassHash;
use starknet::syscalls::get_block_timestamp;

#[starknet::interface]
trait IPharmacistRegistry<TContractState> {
    fn is_pharmacist(self: @TContractState, user: ContractAddress) -> bool;
    fn add_pharmacist(ref self: TContractState, user: ContractAddress);
    fn remove_pharmacist(ref self: TContractState, user: ContractAddress);
    fn transfer_ownership(ref self: TContractState, new_owner: ContractAddress);
    fn get_owner(self: @TContractState) -> ContractAddress;
}

#[starknet::contract]
mod PharmacistRegistry {

    use super::*;

    #[storage]
    struct Storage {
        owner: ContractAddress,
        pharmacists: LegacyMap<ContractAddress, bool>,
    }

    // =========================
    // ======== EVENTS =========
    // =========================

    #[event]
    fn OwnershipTransferred(
        previous_owner: ContractAddress,
        new_owner: ContractAddress
    );

    #[event]
    fn PharmacistAdded(
        pharmacist: ContractAddress,
        added_by: ContractAddress
    );

    #[event]
    fn PharmacistRemoved(
        pharmacist: ContractAddress,
        removed_by: ContractAddress
    );

    // =========================
    // ===== CONSTRUCTOR =======
    // =========================

    #[constructor]
    fn constructor(ref self: ContractState, initial_owner: ContractAddress) {
        self.owner.write(initial_owner);
    }

    // =========================
    // ===== VIEW FUNCTIONS ====
    // =========================

    #[external(v0)]
    fn is_pharmacist(
        self: @ContractState,
        user: ContractAddress
    ) -> bool {
        self.pharmacists.read(user)
    }

    #[external(v0)]
    fn get_owner(self: @ContractState) -> ContractAddress {
        self.owner.read()
    }

    // =========================
    // ==== STATE FUNCTIONS ====
    // =========================

    #[external(v0)]
    fn add_pharmacist(
        ref self: ContractState,
        user: ContractAddress
    ) {
        self._only_owner();

        let exists = self.pharmacists.read(user);
        assert(!exists, 'ALREADY_REGISTERED');

        self.pharmacists.write(user, true);

        let caller = get_caller_address();
        self.emit(PharmacistAdded {
            pharmacist: user,
            added_by: caller
        });
    }

    #[external(v0)]
    fn remove_pharmacist(
        ref self: ContractState,
        user: ContractAddress
    ) {
        self._only_owner();

        let exists = self.pharmacists.read(user);
        assert(exists, 'NOT_REGISTERED');

        self.pharmacists.write(user, false);

        let caller = get_caller_address();
        self.emit(PharmacistRemoved {
            pharmacist: user,
            removed_by: caller
        });
    }

    #[external(v0)]
    fn transfer_ownership(
        ref self: ContractState,
        new_owner: ContractAddress
    ) {
        self._only_owner();

        let previous_owner = self.owner.read();
        self.owner.write(new_owner);

        self.emit(OwnershipTransferred {
            previous_owner,
            new_owner
        });
    }

    // =========================
    // ===== INTERNAL LOGIC ====
    // =========================

    fn _only_owner(self: @ContractState) {
        let caller = get_caller_address();
        let owner = self.owner.read();
        assert(caller == owner, 'NOT_OWNER');
    }
}
