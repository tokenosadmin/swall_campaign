
#[allow(unused_use)]
module swall_campaign::protocol {
    use sui::package;
    use sui::tx_context::{sender};
    use sui::event;
    use sui::clock::{Self, Clock};

    public struct PROTOCOL has drop {}

    public struct AdminCap has key, store {
        id: UID
    }

    public struct UpdateFeeCap has key, store {
        id: UID,
        expires_at: u64,
    }

    public struct CampaignFeeCap has key, store {
        id: UID
    }

     public struct CampaignProtocolFeeUpdated has copy, drop {
        old_protocol_fee_percent: u64,
        old_protocol_fee_wallet: address,
        new_protocol_fee_percent: u64,
        new_protocol_fee_wallet: address,
        timestamp_ms: u64,
    }

    public struct CampaignProtocolFee has key, store {
        id: UID,
        protocol_fee_percent: u64,
        protocol_fee_wallet: address,
    }
    //const ONE_MINITE: u64 = 60000;
    const ONE_DAY: u64 = 86400000;
    // const THREE_DAYS: u64 = 259200000;
    // const FIVE_DAYS: u64 = 432000000;
    // const TEN_DAYS: u64 = 864000000;
    //const THIRTY_DAYS: u64 = 2592000000;


    const UPDATE_CAP_EXPIRED: u64 = 0;
    // const FEE_TOO_SMALL: u64 = 1;

    fun init(_otw: PROTOCOL, ctx: &mut TxContext) {
        // Claim the `Publisher` for the package!
        // let publisher = package::claim(otw, ctx);
        // transfer::public_transfer(publisher, sender(ctx));
        let admin = AdminCap {
            id: object::new(ctx),
        };
        //debug::print(&global_profiles);
        transfer::public_transfer(admin, sender(ctx));

        let campaign_protocol_fee = CampaignProtocolFee {
            id: object::new(ctx),
            protocol_fee_percent: 6,
            protocol_fee_wallet: sender(ctx),
        };
        transfer::share_object(campaign_protocol_fee);
    }

    public fun authorize(_: &AdminCap, user: address, ctx: &mut TxContext, clock: &Clock) {
        let current_ms = clock::timestamp_ms(clock);
        let feeCap = UpdateFeeCap {
            id: object::new(ctx),
            expires_at: current_ms + ONE_DAY
        };
        //debug::print(&global_profiles);
        transfer::public_transfer(feeCap, user);
    }

    public fun update_campaign_protocol_fee(cap: &UpdateFeeCap, cpf: &mut CampaignProtocolFee,
        protocol_fee_percent: u64, protocol_fee_wallet: address,
        clock: &Clock,
    ) {
        let current = clock::timestamp_ms(clock);
        assert!(cap.expires_at > current, UPDATE_CAP_EXPIRED);
        cpf.protocol_fee_percent = protocol_fee_percent;
        cpf.protocol_fee_wallet = protocol_fee_wallet;
        event::emit(CampaignProtocolFeeUpdated {
                old_protocol_fee_percent: cpf.protocol_fee_percent,
                old_protocol_fee_wallet: cpf.protocol_fee_wallet,
                new_protocol_fee_percent: protocol_fee_percent,
                new_protocol_fee_wallet: protocol_fee_wallet,
                timestamp_ms: clock::timestamp_ms(clock),
            }
        );
    }

    public fun get_campaign_protocol_fee_percent(cpf: &CampaignProtocolFee): u64 {
        cpf.protocol_fee_percent
    }

    public fun get_campaign_protocol_fee_wallet(cpf: &CampaignProtocolFee): address {
        cpf.protocol_fee_wallet
    }


    #[test_only]
    public fun init_for_testing(otw: PROTOCOL, ctx: &mut TxContext) {
        init(otw, ctx);
    }

    #[test_only]
    public fun create_campaign_protocol_fee(ctx: &mut TxContext) {
        let campaign_protocol_fee = CampaignProtocolFee {
            id: object::new(ctx),
            protocol_fee_percent: 6,
            protocol_fee_wallet: sender(ctx),
        };
        transfer::share_object(campaign_protocol_fee);
    }



}