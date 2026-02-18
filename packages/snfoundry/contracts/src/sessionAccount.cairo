use starknet::ContractAddress;
use starknet::account::Call;

#[derive(Drop, Serde, Copy, starknet::Store)]
pub struct SessionData {
    pub expires_at: u64,
    pub allowed_target: ContractAddress,
    pub active: bool,
}

#[starknet::interface]
pub trait ISessionAccount<TContractState> {
    fn authorize_session(ref self: TContractState, session_key: felt252, expires_at: u64, allowed_target: ContractAddress);
    fn revoke_session(ref self: TContractState, session_key: felt252);
    fn get_owner(self: @TContractState) -> felt252;
    fn get_session(self: @TContractState, session_key: felt252) -> SessionData;
    fn is_session_active(self: @TContractState, session_key: felt252) -> bool;
    fn get_all_sessions(self: @TContractState) -> Array<felt252>;
    fn validate_session(self: @TContractState, signer: felt252, calls: Array<Call>) -> felt252;
}

#[starknet::contract(account)]
pub mod SessionAccount {
    use starknet::ContractAddress;
    use starknet::{get_block_timestamp, get_tx_info, VALIDATED};
    use starknet::account::Call;
    use super::SessionData; // Import SessionData from super module
    
    // CORRECT imports from the docs [citation:2]
    use openzeppelin_account::AccountComponent;
    use openzeppelin_introspection::src5::SRC5Component;

    // Define components
    component!(path: AccountComponent, storage: account, event: AccountEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    // Account Mixin - provides all ISRC6 methods [citation:2]
    #[abi(embed_v0)]
    impl AccountMixinImpl = AccountComponent::AccountMixinImpl<ContractState>;
    impl AccountInternalImpl = AccountComponent::InternalImpl<ContractState>;
    
    // IMPORTANT: SRC5Impl is included but NOT embedded with #[abi(embed_v0)] [citation:2]
    // This prevents duplicate entry points
    impl SRC5InternalImpl = SRC5Component::InternalImpl<ContractState>;

    // Storage traits
    use starknet::storage::{
        StoragePointerReadAccess,
        StoragePointerWriteAccess,
        StorageMapReadAccess,
        StorageMapWriteAccess,
        Map,
        StoragePathEntry,
    };

    #[storage]
    struct Storage {
        owner: felt252,
        sessions: Map<felt252, SessionData>,
        // List storage for sessions
        session_keys: Map<u64, felt252>,
        session_count: u64,
        // Component storage [citation:2]
        #[substorage(v0)]
        account: AccountComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
    }

    // SessionData moved outside


    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        SessionAuthorized: SessionAuthorized,
        SessionRevoked: SessionRevoked,
        // Component events MUST be flattened [citation:2]
        #[flat]
        AccountEvent: AccountComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
    }

    #[derive(Drop, starknet::Event)]
    struct SessionAuthorized {
        #[key]
        session_key: felt252,
        expires_at: u64,
        allowed_target: ContractAddress
    }

    #[derive(Drop, starknet::Event)]
    struct SessionRevoked {
        #[key]
        session_key: felt252
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner_pubkey: felt252,
        public_key: felt252
    ) {
        self.owner.write(owner_pubkey);
        // AccountComponent initializer sets everything up [citation:2]
        self.account.initializer(public_key);
    }

    #[abi(embed_v0)]
    impl SessionAccountImpl of super::ISessionAccount<ContractState> {
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

            self.sessions.entry(session_key).write(session);
            
            // Add to list
            let count = self.session_count.read();
            self.session_keys.write(count, session_key);
            self.session_count.write(count + 1);

            self.emit(SessionAuthorized { session_key, expires_at, allowed_target });
        }

        fn revoke_session(ref self: ContractState, session_key: felt252) {
            self._only_owner();

            let mut session = self.sessions.entry(session_key).read();
            session.active = false;
            self.sessions.entry(session_key).write(session);

            self.emit(SessionRevoked { session_key });
        }

        fn get_owner(self: @ContractState) -> felt252 {
            self.owner.read()
        }

        fn get_session(self: @ContractState, session_key: felt252) -> SessionData {
            self.sessions.entry(session_key).read()
        }

        fn is_session_active(self: @ContractState, session_key: felt252) -> bool {
            let session = self.sessions.entry(session_key).read();
            let now = get_block_timestamp();
            session.active && now <= session.expires_at
        }

        fn get_all_sessions(self: @ContractState) -> Array<felt252> {
            let mut arr = array![];
            let count = self.session_count.read();
            let mut i = 0;
            loop {
                if i >= count { break; }
                arr.append(self.session_keys.read(i));
                i += 1;
            };
            arr
        }

        fn validate_session(self: @ContractState, signer: felt252, calls: Array<Call>) -> felt252 {
            self.validate_session_internal(signer, calls)
        }
    }

    // Custom validation for session keys
    #[generate_trait]
    impl CustomValidation of CustomValidationTrait {
        fn validate_session_internal(
            self: @ContractState,
            signer: felt252,
            calls: Array<Call>
        ) -> felt252 {
            let session = self.sessions.entry(signer).read();

            if !session.active {
                return 'INVALID_SESSION';
            }

            let now = get_block_timestamp();
            if now > session.expires_at {
                return 'SESSION_EXPIRED';
            }

            if calls.len() > 0 {
                let first_call = calls.at(0);
                if *first_call.to != session.allowed_target {
                    return 'INVALID_TARGET';
                }
            }

            VALIDATED
        }
    }

    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        fn _only_owner(self: @ContractState) {
            let tx_info = get_tx_info().unbox();
            let signature = tx_info.signature;
            
            if signature.len() < 1 {
                panic(array!['INVALID_SIG_LEN']);
            }
            
            let signer = *signature.at(0);
            let owner_key = self.owner.read();
            assert(signer == owner_key, 'NOT_OWNER');
        }
    }
}