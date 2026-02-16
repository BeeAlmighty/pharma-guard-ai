
use starknet::ContractAddress;
use starknet::get_caller_address;
use starknet::syscalls::{get_block_timestamp};
use starknet::account::AccountContract;
use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
use starknet::info::get_tx_info;

#[starknet::contract]
mod SessionAccount {

    use super::*;

    // =========================
    // ========= STORAGE =======
    // =========================

    #[storage]
    struct Storage {
        owner: felt252,
        sessions: LegacyMap<felt252, SessionData>,
    }

    #[derive(Drop, Serde, Copy)]
    struct SessionData {
        expires_at: u64,
        allowed_target: ContractAddress,
        active: bool,
    }

    // =========================
    // ========= EVENTS ========
    // =========================

    #[event]
    fn SessionAuthorized(
        session_key: felt252,
        expires_at: u64,
        allowed_target: ContractAddress
    );

    #[event]
    fn SessionRevoked(
        session_key: felt252
    );

    // =========================
    // ===== CONSTRUCTOR =======
    // =========================

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner_pubkey: felt252
    ) {
        self.owner.write(owner_pubkey);
    }

    // =========================
    // ===== SESSION MGMT ======
    // =========================

    #[external(v0)]
    fn authorize_session(
        ref self: ContractState,
        session_key: felt252,
        expires_at: u64,
        allowed_target: ContractAddress
    ) {
        self._only_owner();

        let session = SessionData {
            expires_at,
            allowed_target,
            active: true
        };

        self.sessions.write(session_key, session);

        self.emit(SessionAuthorized {
            session_key,
            expires_at,
            allowed_target
        });
    }

    #[external(v0)]
    fn revoke_session(
        ref self: ContractState,
        session_key: felt252
    ) {
        self._only_owner();

        let mut session = self.sessions.read(session_key);
        session.active = false;
        self.sessions.write(session_key, session);

        self.emit(SessionRevoked { session_key });
    }

    // =========================
    // ===== ACCOUNT LOGIC =====
    // =========================

    #[external(v0)]
    fn __validate__(
        self: @ContractState,
        calls: Array<starknet::Call>
    ) -> felt252 {

        let tx_info = get_tx_info().unbox();
        let signer = tx_info.signature[0];

        let owner_key = self.owner.read();

        if signer == owner_key {
            return 0;
        }

        let session = self.sessions.read(signer);

        assert(session.active, 'INVALID_SESSION');

        let now = get_block_timestamp();
        assert(now <= session.expires_at, 'SESSION_EXPIRED');

        // Optional: restrict target
        let first_call = calls.at(0);
        assert(first_call.to == session.allowed_target, 'INVALID_TARGET');

        0
    }

    #[external(v0)]
    fn __execute__(
        ref self: ContractState,
        calls: Array<starknet::Call>
    ) -> Array<felt252> {
        starknet::execute(calls)
    }

    // =========================
    // ===== INTERNAL LOGIC ====
    // =========================

    fn _only_owner(self: @ContractState) {
        let tx_info = get_tx_info().unbox();
        let signer = tx_info.signature[0];
        let owner_key = self.owner.read();
        assert(signer == owner_key, 'NOT_OWNER');
    }
}
