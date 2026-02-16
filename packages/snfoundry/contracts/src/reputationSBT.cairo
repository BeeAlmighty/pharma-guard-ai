
use starknet::ContractAddress;
use starknet::get_caller_address;
use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};

#[starknet::interface]
trait IReputationSBT<TContractState> {
    fn mint_lifesaver_badge(ref self: TContractState, to: ContractAddress);
    fn reputation_score(self: @TContractState, user: ContractAddress) -> u256;
    fn owner_of(self: @TContractState, token_id: u256) -> ContractAddress;
}

#[starknet::contract]
mod ReputationSBT {

    use super::*;

    // =========================
    // ========= STORAGE =======
    // =========================

    #[storage]
    struct Storage {
        owner: ContractAddress,
        medical_logger: ContractAddress,
        balances: LegacyMap<ContractAddress, u256>,
        token_owner: LegacyMap<u256, ContractAddress>,
        next_token_id: u256,
    }

    // =========================
    // ========= EVENTS ========
    // =========================

    #[event]
    fn OwnershipTransferred(
        previous_owner: ContractAddress,
        new_owner: ContractAddress
    );

    #[event]
    fn MedicalLoggerUpdated(
        new_logger: ContractAddress
    );

    #[event]
    fn LifesaverBadgeMinted(
        to: ContractAddress,
        token_id: u256
    );

    // =========================
    // ===== CONSTRUCTOR =======
    // =========================

    #[constructor]
    fn constructor(
        ref self: ContractState,
        initial_owner: ContractAddress
    ) {
        self.owner.write(initial_owner);
        self.next_token_id.write(1_u256);
    }

    // =========================
    // ===== VIEW FUNCTIONS ====
    // =========================

    #[external(v0)]
    fn reputation_score(
        self: @ContractState,
        user: ContractAddress
    ) -> u256 {
        self.balances.read(user)
    }

    #[external(v0)]
    fn owner_of(
        self: @ContractState,
        token_id: u256
    ) -> ContractAddress {
        let owner = self.token_owner.read(token_id);
        assert(owner != ContractAddress::from(0), 'INVALID_TOKEN');
        owner
    }

    // =========================
    // ===== CORE MINTING ======
    // =========================

    #[external(v0)]
    fn mint_lifesaver_badge(
        ref self: ContractState,
        to: ContractAddress
    ) {
        self._only_medical_logger();

        let token_id = self.next_token_id.read();

        self.token_owner.write(token_id, to);

        let current_balance = self.balances.read(to);
        self.balances.write(to, current_balance + 1_u256);

        self.next_token_id.write(token_id + 1_u256);

        self.emit(LifesaverBadgeMinted {
            to,
            token_id
        });
    }

    // =========================
    // ===== ADMIN FUNCTIONS ===
    // =========================

    #[external(v0)]
    fn set_medical_logger(
        ref self: ContractState,
        new_logger: ContractAddress
    ) {
        self._only_owner();
        self.medical_logger.write(new_logger);

        self.emit(MedicalLoggerUpdated {
            new_logger
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

    fn _only_medical_logger(self: @ContractState) {
        let caller = get_caller_address();
        let logger = self.medical_logger.read();
        assert(caller == logger, 'NOT_AUTHORIZED');
    }
}
