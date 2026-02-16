use starknet::ContractAddress;
use crate::pharmacistRegistry::IPharmacistRegistryDispatcher;
use crate::pharmacistRegistry::IPharmacistRegistryDispatcherTrait;
use crate::reputationSBT::IReputationSBTDispatcher;
use crate::reputationSBT::IReputationSBTDispatcherTrait;

#[derive(Drop, Serde, Copy, starknet::Store)]
pub struct LogEntry {
    pub pharmacist: ContractAddress,
    pub risk_level: u8,
    pub overridden: bool,
    pub timestamp: u64,
    pub blocked: bool,
}

#[starknet::interface]
pub trait IMedicalLogger<TContractState> {
    fn log_safety_check(ref self: TContractState, commitment: felt252, risk_level: u8);
    fn override_warning(ref self: TContractState, commitment: felt252, reason_hash: felt252);
    fn confirm_block(ref self: TContractState, commitment: felt252);
    fn get_log(self: @TContractState, commitment: felt252) -> LogEntry;
}

#[starknet::contract]
pub mod MedicalLogger {
    use starknet::ContractAddress;
    use starknet::{get_caller_address, get_block_timestamp};
    
    use starknet::storage::{
        Map,
        StoragePathEntry,
        StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    
    use super::LogEntry;
    
    // IMPORTANT: Import both Dispatcher and DispatcherTrait
    use crate::pharmacistRegistry::IPharmacistRegistryDispatcher;
    use crate::pharmacistRegistry::IPharmacistRegistryDispatcherTrait;
    use crate::reputationSBT::IReputationSBTDispatcher;
    use crate::reputationSBT::IReputationSBTDispatcherTrait;

    #[storage]
    struct Storage {
        registry: ContractAddress,
        reputation: ContractAddress,
        logs: Map<felt252, LogEntry>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        SafetyLogged: SafetyLogged,
        OverrideUsed: OverrideUsed,
        HighRiskBlocked: HighRiskBlocked,
    }

    #[derive(Drop, starknet::Event)]
    struct SafetyLogged {
        #[key]
        commitment: felt252,
        pharmacist: ContractAddress,
        risk_level: u8,
        timestamp: u64
    }

    #[derive(Drop, starknet::Event)]
    struct OverrideUsed {
        #[key]
        commitment: felt252,
        pharmacist: ContractAddress,
        reason_hash: felt252,
        timestamp: u64
    }

    #[derive(Drop, starknet::Event)]
    struct HighRiskBlocked {
        #[key]
        commitment: felt252,
        pharmacist: ContractAddress,
        timestamp: u64
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        registry_address: ContractAddress,
        reputation_address: ContractAddress
    ) {
        self.registry.write(registry_address);
        self.reputation.write(reputation_address);
    }

    #[abi(embed_v0)]
    impl MedicalLoggerImpl of super::IMedicalLogger<ContractState> {
        fn get_log(self: @ContractState, commitment: felt252) -> LogEntry {
            self.logs.entry(commitment).read()
        }

        fn log_safety_check(
            ref self: ContractState,
            commitment: felt252,
            risk_level: u8
        ) {
            self._only_pharmacist();

            let existing = self.logs.entry(commitment).read();
            assert(existing.timestamp == 0_u64, 'ALREADY_EXISTS');

            let caller = get_caller_address();
            let timestamp = get_block_timestamp();

            let entry = LogEntry {
                pharmacist: caller,
                risk_level,
                overridden: false,
                timestamp,
                blocked: false,
            };

            self.logs.entry(commitment).write(entry);
            self.emit(SafetyLogged { commitment, pharmacist: caller, risk_level, timestamp });
        }

        fn override_warning(
            ref self: ContractState,
            commitment: felt252,
            reason_hash: felt252
        ) {
            self._only_pharmacist();

            let mut entry = self.logs.entry(commitment).read();
            assert(entry.timestamp != 0_u64, 'NOT_FOUND');
            assert(!entry.overridden, 'ALREADY_OVERRIDDEN');

            entry.overridden = true;
            self.logs.entry(commitment).write(entry);

            let caller = get_caller_address();
            let timestamp = get_block_timestamp();
            self.emit(OverrideUsed { commitment, pharmacist: caller, reason_hash, timestamp });
        }

        fn confirm_block(
            ref self: ContractState,
            commitment: felt252
        ) {
            self._only_pharmacist();

            let mut entry = self.logs.entry(commitment).read();
            assert(entry.timestamp != 0_u64, 'NOT_FOUND');
            assert(!entry.blocked, 'ALREADY_BLOCKED');
            assert(entry.risk_level >= 2_u8, 'NOT_HIGH_RISK');

            entry.blocked = true;
            self.logs.entry(commitment).write(entry);

            let caller = get_caller_address();
            let timestamp = get_block_timestamp();
            
            let reputation_address = self.reputation.read();
            
            // Now this works because we imported the trait
            IReputationSBTDispatcher { contract_address: reputation_address }
                .mint_lifesaver_badge(caller);

            self.emit(HighRiskBlocked { commitment, pharmacist: caller, timestamp });
        }
    }

    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        fn _only_pharmacist(self: @ContractState) {
            let caller = get_caller_address();
            let registry_address = self.registry.read();

            // Now this works because we imported the trait
            let is_allowed = IPharmacistRegistryDispatcher { contract_address: registry_address }
                .is_pharmacist(caller);
            
            assert(is_allowed, 'NOT_PHARMACIST');
        }
    }
}