use starknet::ContractAddress;

#[starknet::interface]
pub trait IReputationSBT<TContractState> {
    fn mint_lifesaver_badge(ref self: TContractState, to: ContractAddress);
    fn reputation_score(self: @TContractState, user: ContractAddress) -> u256;
    fn owner_of(self: @TContractState, token_id: u256) -> ContractAddress;
    fn set_medical_logger(ref self: TContractState, new_logger: ContractAddress);
    fn transfer_ownership(ref self: TContractState, new_owner: ContractAddress);
}

#[starknet::contract]
pub mod ReputationSBT {
    use starknet::ContractAddress;
    use starknet::get_caller_address;
    
    // Import the correct storage traits
    use starknet::storage::{
        StoragePointerReadAccess,    // For simple variables (owner, medical_logger, next_token_id)
        StoragePointerWriteAccess,   // For simple variables
        StorageMapReadAccess,        // For maps (balances, token_owner)
        StorageMapWriteAccess,       // For maps
        Map,
    };

    #[storage]
    struct Storage {
        owner: ContractAddress,
        medical_logger: ContractAddress,
        balances: Map<ContractAddress, u256>,
        token_owner: Map<u256, ContractAddress>,
        next_token_id: u256,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        OwnershipTransferred: OwnershipTransferred,
        MedicalLoggerUpdated: MedicalLoggerUpdated,
        LifesaverBadgeMinted: LifesaverBadgeMinted,
    }

    #[derive(Drop, starknet::Event)]
    struct OwnershipTransferred {
        #[key]
        previous_owner: ContractAddress,
        #[key]
        new_owner: ContractAddress
    }

    #[derive(Drop, starknet::Event)]
    struct MedicalLoggerUpdated {
        new_logger: ContractAddress
    }

    #[derive(Drop, starknet::Event)]
    struct LifesaverBadgeMinted {
        #[key]
        to: ContractAddress,
        token_id: u256
    }

    #[constructor]
    fn constructor(ref self: ContractState, initial_owner: ContractAddress) {
        // Simple variables use StoragePointerWriteAccess
        self.owner.write(initial_owner);
        self.next_token_id.write(1_u256);
    }

    #[abi(embed_v0)]
    impl ReputationSBTImpl of super::IReputationSBT<ContractState> {
        fn reputation_score(self: @ContractState, user: ContractAddress) -> u256 {
            // Maps use StorageMapReadAccess
            self.balances.read(user)
        }

        fn owner_of(self: @ContractState, token_id: u256) -> ContractAddress {
            let owner = self.token_owner.read(token_id);
            // Check against zero address using try_into
            assert(owner != 0.try_into().unwrap(), 'INVALID_TOKEN');
            owner
        }

        fn mint_lifesaver_badge(ref self: ContractState, to: ContractAddress) {
            self._only_medical_logger();

            let token_id = self.next_token_id.read();
            
            // Maps use StorageMapWriteAccess
            self.token_owner.write(token_id, to);

            let current_balance = self.balances.read(to);
            self.balances.write(to, current_balance + 1_u256);

            self.next_token_id.write(token_id + 1_u256);
            self.emit(LifesaverBadgeMinted { to, token_id });
        }

        fn set_medical_logger(ref self: ContractState, new_logger: ContractAddress) {
            self._only_owner();
            self.medical_logger.write(new_logger);
            self.emit(MedicalLoggerUpdated { new_logger });
        }

        fn transfer_ownership(ref self: ContractState, new_owner: ContractAddress) {
            self._only_owner();
            let previous_owner = self.owner.read();
            self.owner.write(new_owner);
            self.emit(OwnershipTransferred { previous_owner, new_owner });
        }
    }

    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        fn _only_owner(self: @ContractState) {
            let caller = get_caller_address();
            let owner = self.owner.read();
            assert(caller == owner, 'NOT_OWNER');
        }

        fn _only_medical_logger(self: @ContractState) {
            let caller = get_caller_address();
            let logger = self.medical_logger.read();
            assert(caller == logger, 'NOT_AUTHORIZED');
        }
    }
}