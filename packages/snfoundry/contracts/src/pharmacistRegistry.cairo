use starknet::ContractAddress;

#[starknet::interface]
pub trait IPharmacistRegistry<TContractState> {
    fn is_pharmacist(self: @TContractState, user: ContractAddress) -> bool;
    fn add_pharmacist(ref self: TContractState, user: ContractAddress);
    fn remove_pharmacist(ref self: TContractState, user: ContractAddress);
    fn transfer_ownership(ref self: TContractState, new_owner: ContractAddress);
    fn get_owner(self: @TContractState) -> ContractAddress;
}

#[starknet::contract]
pub mod PharmacistRegistry {
    use starknet::ContractAddress;
    use starknet::get_caller_address;
    
    // Import ALL needed storage traits
    use starknet::storage::{
        StoragePointerReadAccess,    // For owner (simple variable)
        StoragePointerWriteAccess,   // For owner
        StorageMapReadAccess,        // For pharmacists map
        StorageMapWriteAccess,       // For pharmacists map
        Map,
    };

    #[storage]
    struct Storage {
        owner: ContractAddress,
        pharmacists: Map<ContractAddress, bool>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        OwnershipTransferred: OwnershipTransferred,
        PharmacistAdded: PharmacistAdded,
        PharmacistRemoved: PharmacistRemoved,
    }

    #[derive(Drop, starknet::Event)]
    struct OwnershipTransferred {
        #[key]
        previous_owner: ContractAddress,
        #[key]
        new_owner: ContractAddress
    }

    #[derive(Drop, starknet::Event)]
    struct PharmacistAdded {
        #[key]
        pharmacist: ContractAddress,
        added_by: ContractAddress
    }

    #[derive(Drop, starknet::Event)]
    struct PharmacistRemoved {
        #[key]
        pharmacist: ContractAddress,
        removed_by: ContractAddress
    }

    #[constructor]
    fn constructor(ref self: ContractState, initial_owner: ContractAddress) {
        // Simple variable - uses StoragePointerWriteAccess
        self.owner.write(initial_owner);
    }

    #[abi(embed_v0)]
    impl PharmacistRegistryImpl of super::IPharmacistRegistry<ContractState> {
        fn is_pharmacist(self: @ContractState, user: ContractAddress) -> bool {
            // Map in read-only context - uses StorageMapReadAccess
            self.pharmacists.read(user)
        }

        fn get_owner(self: @ContractState) -> ContractAddress {
            // Simple variable in read-only context - uses StoragePointerReadAccess
            self.owner.read()
        }

        fn add_pharmacist(ref self: ContractState, user: ContractAddress) {
            self._only_owner();
            
            // Map read - uses StorageMapReadAccess
            let exists = self.pharmacists.read(user);
            assert(!exists, 'ALREADY_REGISTERED');
            
            // Map write - uses StorageMapWriteAccess
            self.pharmacists.write(user, true);
            
            self.emit(PharmacistAdded { pharmacist: user, added_by: get_caller_address() });
        }

        fn remove_pharmacist(ref self: ContractState, user: ContractAddress) {
            self._only_owner();
            
            // Map read - uses StorageMapReadAccess
            let exists = self.pharmacists.read(user);
            assert(exists, 'NOT_REGISTERED');
            
            // Map write - uses StorageMapWriteAccess
            self.pharmacists.write(user, false);
            
            self.emit(PharmacistRemoved { pharmacist: user, removed_by: get_caller_address() });
        }

        fn transfer_ownership(ref self: ContractState, new_owner: ContractAddress) {
            self._only_owner();
            
            // Simple variable read/write - uses StoragePointerReadAccess/WriteAccess
            let previous_owner = self.owner.read();
            self.owner.write(new_owner);
            
            self.emit(OwnershipTransferred { previous_owner, new_owner });
        }
    }

    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        fn _only_owner(self: @ContractState) {
            let caller = get_caller_address();
            let owner = self.owner.read();  // Simple variable read
            assert(caller == owner, 'NOT_OWNER');
        }
    }
}