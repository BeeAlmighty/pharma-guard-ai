
use starknet::ContractAddress;
use starknet::get_caller_address;
use starknet::syscalls::get_block_timestamp;
use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};

#[starknet::interface]
trait IPharmacistRegistry<TContractState> {
    fn is_pharmacist(self: @TContractState, user: ContractAddress) -> bool;
}

#[starknet::interface]
trait IReputationSBT<TContractState> {
    fn mint_lifesaver_badge(ref self: TContractState, to: ContractAddress);
}

#[starknet::contract]
mod MedicalLogger {

    use super::*;

    // =========================
    // ======== STORAGE ========
    // =========================

    #[storage]
    struct Storage {
        registry: ContractAddress,
        reputation: ContractAddress,
        logs: LegacyMap<felt252, LogEntry>,
    }

    #[derive(Drop, Serde, Copy)]
    struct LogEntry {
        pharmacist: ContractAddress,
        risk_level: u8,
        overridden: bool,
        timestamp: u64,
        blocked: bool,
    }

    // =========================
    // ========= EVENTS ========
    // =========================

    #[event]
    fn SafetyLogged(
        commitment: felt252,
        pharmacist: ContractAddress,
        risk_level: u8,
        timestamp: u64
    );

    #[event]
    fn OverrideUsed(
        commitment: felt252,
        pharmacist: ContractAddress,
        reason_hash: felt252,
        timestamp: u64
    );

    #[event]
    fn HighRiskBlocked(
        commitment: felt252,
        pharmacist: ContractAddress,
        timestamp: u64
    );

    // =========================
    // ===== CONSTRUCTOR =======
    // =========================

    #[constructor]
    fn constructor(
        ref self: ContractState,
        registry_address: ContractAddress,
        reputation_address: ContractAddress
    ) {
        self.registry.write(registry_address);
        self.reputation.write(reputation_address);
    }

    // =========================
    // ===== VIEW FUNCTIONS ====
    // =========================

    #[external(v0)]
    fn get_log(
        self: @ContractState,
        commitment: felt252
    ) -> LogEntry {
        self.logs.read(commitment)
    }

    // =========================
    // ===== CORE LOGIC ========
    // =========================

    #[external(v0)]
    fn log_safety_check(
        ref self: ContractState,
        commitment: felt252,
        risk_level: u8
    ) {
        self._only_pharmacist();

        let existing = self.logs.read(commitment);
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

        self.logs.write(commitment, entry);

        self.emit(SafetyLogged {
            commitment,
            pharmacist: caller,
            risk_level,
            timestamp
        });
    }

    #[external(v0)]
    fn override_warning(
        ref self: ContractState,
        commitment: felt252,
        reason_hash: felt252
    ) {
        self._only_pharmacist();

        let mut entry = self.logs.read(commitment);
        assert(entry.timestamp != 0_u64, 'NOT_FOUND');
        assert(!entry.overridden, 'ALREADY_OVERRIDDEN');

        entry.overridden = true;
        self.logs.write(commitment, entry);

        let caller = get_caller_address();
        let timestamp = get_block_timestamp();

        self.emit(OverrideUsed {
            commitment,
            pharmacist: caller,
            reason_hash,
            timestamp
        });
    }

    #[external(v0)]
    fn confirm_block(
        ref self: ContractState,
        commitment: felt252
    ) {
        self._only_pharmacist();

        let mut entry = self.logs.read(commitment);
        assert(entry.timestamp != 0_u64, 'NOT_FOUND');
        assert(!entry.blocked, 'ALREADY_BLOCKED');

        // Only allow reward if risk was high (example threshold = 2)
        assert(entry.risk_level >= 2_u8, 'NOT_HIGH_RISK');

        entry.blocked = true;
        self.logs.write(commitment, entry);

        let caller = get_caller_address();
        let timestamp = get_block_timestamp();

        // Call Reputation contract
        let reputation_address = self.reputation.read();
        let mut reputation = IReputationSBTDispatcher {
            contract_address: reputation_address
        };
        reputation.mint_lifesaver_badge(caller);

        self.emit(HighRiskBlocked {
            commitment,
            pharmacist: caller,
            timestamp
        });
    }

    // =========================
    // ===== INTERNAL LOGIC ====
    // =========================

    fn _only_pharmacist(self: @ContractState) {
        let caller = get_caller_address();
        let registry_address = self.registry.read();

        let registry = IPharmacistRegistryDispatcher {
            contract_address: registry_address
        };

        let is_allowed = registry.is_pharmacist(caller);
        assert(is_allowed, 'NOT_PHARMACIST');
    }
}
