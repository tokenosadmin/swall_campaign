#[allow(unused_use)]
#[lint_allow(self_transfer)]
module swall_campaign::campaign {
    use sui::sui::SUI;
    use sui::coin::{Self, Coin, CoinMetadata};
    use sui::object_table::{Self, ObjectTable};
    use sui::balance::{Self, Balance};
    use std::string::{Self, String};
    use sui::clock::{Self, Clock};
    use swall_campaign::campaign_oracle::{Self, CampaignOracle};
    use swall_campaign::protocol::{Self, CampaignProtocolFee};
    use std::type_name::{Self, TypeName};
    use std::ascii::{Self};
    use std::debug;
    use sui::event;
    use sui::package;
    use std::hash;
    use sui::ecvrf;
    use sui::tx_context::{sender};
    use sui::table_vec::{Self, TableVec};
    use sui::linked_table::{Self, LinkedTable};
    const INSUFFICIENT_FUND: u64 = 1;
    const REFERRAL_EXISTS: u64 = 2;
    const CLAIM_EXISTS: u64 = 3;
    const CAMPAIGN_ENDED: u64 = 4;
    const CAMPAIGN_FULLY_CLAIMED: u64 = 5;
    const NOT_VERIFIED: u64 = 6;
    //const INVALID_END_DATE: u64 = 7;
    const REFERRAL_NOT_FOUND: u64 = 9;

    public struct CampaignAdminCap has key {
        id: UID,
        admin: address,
    }

    public struct CampaignTopUpKey has store, copy, drop{
        sender: address,
        timestamp_ms: u64,
    }   

    public struct Campaign<phantom T> has key {
        id: UID,
        owner: address,
        campaign_post_id: ID,
        balance_token_mist: Balance<T>,
        budget_token_mist_value: u64,
        budget_usd: u64,
        claimed_budget_token_mist_value: u64,
        no_of_target_referees: u64,
        no_of_claimed_referees: u64,
        no_of_referrals: u64,
        referrals: ObjectTable<address, ReferralMetadata>,
        claimers: ObjectTable<address, ClaimMetadata>,
        top_ups: LinkedTable<CampaignTopUpKey, CampaignTopUp>,
        no_of_locked_claimers: u64,
        locked_claimers: ObjectTable<address, LockedClaim>,
        campaign_end_date: u64,
        campaign_start_date: u64,
        campaign_owner_reward_percentage: u64,
        campaign_referral_reward_percentage: u64,
        campaign_referee_reward_percentage: u64,
        token_mist_value_per_claim: u64,
    }

    public struct CampaignPost has key {
        id: UID,
        campaign_name: String,
        post_id: String,
        channel_id: String,
        ad_banner: String,
        cta_header: String,
        cta_description: String,
        cta_action: String,
        destination_url: String,
    }

    public struct CampaignTopUp has key, store {
        id: UID,
        campaign_id: ID,
        top_up_token_mist_value: u64,
        remaining_balance_token_mist_value: u64,
        token_mist_value_per_claim: u64,
        no_of_target_referees: u64,
        sender: address,
        timestamp_ms: u64
    }

    public struct CampaignToppedUp has copy, drop {
        id: ID,
        campaign_id: ID,
        timestamp_ms: u64,
        top_up_token_mist_value: u64,
        token_mist_value_per_claim: u64,
        no_of_target_referees: u64,
        sender: address,
    }

    public struct CampaignCreated has copy, drop {
        campaign_post_id: ID,
        timestamp_ms: u64,
        campaign_id: ID,
        budget_token_mist_value: u64,
        budget_usd: u64,
        campaign_end_date: u64,
        campaign_start_date: u64,
        owner: address,
        payment_token_type: String,
    }

    public struct Referral has key, store {
        id: UID,
        campaign_id: ID,
        referrer: address,
        link: String,
        timestamp_ms: u64
    }

    public struct ReferralMetadata has key, store {
        id: UID,
        referral_id: ID,
        campaign_id: ID,
        referrer: address,
        link: String,
        timestamp_ms: u64
    }

    public struct ReferralCreated has copy, drop {
        referral_id: ID,
        campaign_id: ID,
        referrer: address,
        link: String,
        timestamp_ms: u64
    }

    public struct Claim has key, store {
        id: UID,
        campaign_id: ID,
        referee_address: address,
        referee_amount_token_mist_value: u64,
        referral_address: address,
        referral_amount_token_mist_value: u64,
        campaign_owner_address: address,
        campaign_owner_amount_token_mist_value: u64,
        token_mist_value_per_claim: u64,
        timestamp_ms: u64
    }  

    public struct ClaimMetadata has key, store {
        id: UID,
        claim_id: ID,
        campaign_id: ID,
        claimer_address: address,
        timestamp_ms: u64
    }

    public struct LockedClaim has key, store {
        id: UID,
        campaign_id: ID,
        campaign_owner: address,
        campaign_owner_reward_token_mist: u64,
        referral: address,
        referral_reward_token_mist: u64,
        claimer: address,
        claimer_reward_token_mist: u64,
        total_amount_token_mist: u64,
        timestamp_ms: u64
    }

    public struct ClaimCreated has copy, drop {
        claim_id: ID,
        campaign_id: ID,
        campaign_owner_address: address,
        campaign_owner_amount_token_mist_value: u64,
        referee_address: address,
        referee_amount_token_mist_value: u64,
        referral_address: address,
        referral_amount_token_mist_value: u64,
        token_mist_value_per_claim: u64,
        campaign_end_date: u64,
        timestamp_ms: u64
    }

    public struct LockedClaimCreated has copy, drop {
        locked_claim_id: ID,
        campaign_id: ID,
        campaign_owner: address,
        campaign_owner_reward_token_mist: u64,
        referral: address,
        referral_reward_token_mist: u64,
        claimer: address,
        claimer_reward_token_mist: u64,
        total_amount_token_mist: u64,
        timestamp_ms: u64
    }

    public struct ClaimUnlocked has copy, drop {
        locked_claim_id: ID,
        claim_id: ID,
        campaign_id: ID,
        claimer: address,
        amount_claimed_token_mist: u64,
        timestamp_ms: u64
    }


    public struct CampaignBalanceWithdrawn has copy, drop {
        campaign_id: ID,
        withdraw_timestamp_ms: u64,
        top_up_timestamp_ms: u64,
        sender: address,
    }

    // public struct CampaignExtended has copy, drop {
    //     campaign_id: ID,
    //     old_end_date: u64,
    //     new_end_date: u64,
    //     timestamp_ms: u64,
    //     sender: address,
    // }

    public struct CampaignEnded has copy, drop {
        campaign_id: ID,
        timestamp_ms: u64,
        sender: address,
    }
    
    public struct CAMPAIGN has drop {}

    fun init(otw: CAMPAIGN, ctx: &mut TxContext) {
        // Claim the `Publisher` for the package!
        let publisher = package::claim(otw, ctx);
        transfer::public_transfer(publisher, sender(ctx));
        let campaign_admin_cap = CampaignAdminCap {
            id: object::new(ctx),
            admin: sender(ctx),
        };
        transfer::transfer(campaign_admin_cap, sender(ctx));
    }


    public entry fun create_campaign<T> ( 
        name: vector<u8>,
        post_id: vector<u8>,
        channel_id: vector<u8>,
        ad_banner: vector<u8>,
        cta_header: vector<u8>,
        cta_description: vector<u8>,
        cta_action: vector<u8>,
        destination_url: vector<u8>,
        mut payment_token_mist: Coin<T>, 
        metadata: &CoinMetadata<T>,
        campaign_owner_reward_percentage: u64,
        campaign_referral_reward_percentage: u64,
        campaign_end_date: u64,
        campaign_start_date: u64,
        no_of_target_referees: u64,
        campaign_protocol_fee: &CampaignProtocolFee,
        budget_usd: u64,
        campaign_oracle: &CampaignOracle,
        link: vector<u8>,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let id = object::new(ctx);
        let inner_id = object::uid_to_inner(&id);
        let campaign_id = object::new(ctx);
        let inner_campaign_id = object::uid_to_inner(&campaign_id);

        let multiplier: u256 = get_multiplier<T>(metadata) as u256;
        let type_name = get_type_name<T>();
        let budget_usd_integer_value = budget_usd as u256 * 10000;
        debug::print(&budget_usd_integer_value);
        let campaign_protocol_fee_usd_ineger_value = get_campaign_protocol_fee(campaign_protocol_fee, budget_usd, no_of_target_referees);
        debug::print(&campaign_protocol_fee_usd_ineger_value);
        let total_fee_usd_integer_value = campaign_protocol_fee_usd_ineger_value + budget_usd_integer_value;
        let token_price_usd_mist = campaign_oracle::get_price(campaign_oracle, type_name ) as u256;
        let total_fee_token_mist = total_fee_usd_integer_value * multiplier * multiplier / (token_price_usd_mist * 10000);
        let payment_token_mist_value = coin::value(&payment_token_mist) as u256;
       // debug::print(&payment_token_mist_value);
        debug::print(&total_fee_token_mist);
        assert!(payment_token_mist_value >= total_fee_token_mist, INSUFFICIENT_FUND);

        let campaign_protocol_fee_token_mist = (campaign_protocol_fee_usd_ineger_value * multiplier * multiplier / (token_price_usd_mist * 10000)) as u64;
        let campaign_protocol_fee_wallet = protocol::get_campaign_protocol_fee_wallet(campaign_protocol_fee);
        let campaign_protocol_fee_coin = coin::split(&mut payment_token_mist, campaign_protocol_fee_token_mist, ctx);
        transfer::public_transfer(campaign_protocol_fee_coin, campaign_protocol_fee_wallet);
        
        let budget_token_mist_value = (budget_usd_integer_value * multiplier * multiplier / (token_price_usd_mist * 10000)) as u64;
        let budget_coin = coin::split(&mut payment_token_mist, budget_token_mist_value, ctx);
        let budget_token_mist = coin::into_balance(budget_coin);
        //let budget_token_mist_value = balance::value(&budget_token_mist);
        let token_mist_value_per_claim = budget_token_mist_value / no_of_target_referees;
        debug::print(&budget_token_mist_value);

        let campaign_post = CampaignPost {
            id: id,
            campaign_name: string::utf8(name),
            post_id: string::utf8(post_id),
            channel_id: string::utf8(channel_id),
            ad_banner: string::utf8(ad_banner),
            cta_header: string::utf8(cta_header),
            cta_description: string::utf8(cta_description),
            cta_action: string::utf8(cta_action),
            destination_url: string::utf8(destination_url),
        };

        let mut campaign = Campaign<T> {
            id: campaign_id,
            owner: sender(ctx),
            campaign_post_id: inner_id,
            balance_token_mist: budget_token_mist,
            budget_token_mist_value: budget_token_mist_value,
            budget_usd: budget_usd,
            claimed_budget_token_mist_value: 0,
            no_of_target_referees: no_of_target_referees,
            no_of_claimed_referees: 0,
            no_of_referrals: 0,
            top_ups: linked_table::new(ctx),
            referrals: object_table::new(ctx),
            claimers: object_table::new(ctx),
            no_of_locked_claimers: 0,
            locked_claimers: object_table::new(ctx),
            campaign_end_date: campaign_end_date,
            campaign_start_date: campaign_start_date,
            campaign_owner_reward_percentage: campaign_owner_reward_percentage,
            campaign_referral_reward_percentage: campaign_referral_reward_percentage,
            campaign_referee_reward_percentage: 100 - campaign_owner_reward_percentage - campaign_referral_reward_percentage,
            token_mist_value_per_claim: token_mist_value_per_claim,
        };
        event::emit(CampaignCreated {
            campaign_id: inner_campaign_id,
            timestamp_ms: clock::timestamp_ms(clock),
            campaign_post_id: inner_id,
            budget_token_mist_value: budget_token_mist_value,
            budget_usd: budget_usd,
            campaign_end_date: campaign_end_date,
            campaign_start_date: campaign_start_date,
            owner: sender(ctx),
            payment_token_type: type_name,
        });
        let referral_id = object::new(ctx);
        let inner_referral_id = object::uid_to_inner(&referral_id);
        let referral = Referral {
            id: referral_id,
            campaign_id: object::uid_to_inner(&campaign.id),
            referrer: sender(ctx),
            link: string::utf8(link),
            timestamp_ms: clock::timestamp_ms(clock),
        };
        let referral_metadata = ReferralMetadata {
            id: object::new(ctx),
            referral_id: inner_referral_id,
            campaign_id: object::uid_to_inner(&campaign.id),
            referrer: sender(ctx),
            link: string::utf8(link),
            timestamp_ms: clock::timestamp_ms(clock),
        };
        event::emit(ReferralCreated {
            referral_id: inner_referral_id,
            campaign_id: object::uid_to_inner(&campaign.id),
            referrer: sender(ctx),
            link: string::utf8(link),
            timestamp_ms: clock::timestamp_ms(clock),
        });
        transfer::public_transfer(referral, sender(ctx));
        object_table::add(&mut campaign.referrals, sender(ctx), referral_metadata);
        campaign.no_of_referrals = campaign.no_of_referrals + 1;

        let campaign_top_up_id = object::new(ctx);
        let campaign_top_up_inner_id = object::uid_to_inner(&campaign_top_up_id);
        let campaign_top_up = CampaignTopUp {
            id: campaign_top_up_id,
            campaign_id: object::uid_to_inner(&campaign.id),
            top_up_token_mist_value: budget_token_mist_value,
            remaining_balance_token_mist_value: budget_token_mist_value,
            token_mist_value_per_claim: token_mist_value_per_claim,
            no_of_target_referees: no_of_target_referees,
            sender: sender(ctx),
            timestamp_ms: clock::timestamp_ms(clock),
        };      
        //table_vec::push_back(&mut campaign.top_ups, campaign_top_up);
        let key = CampaignTopUpKey {
            sender: sender(ctx),
            timestamp_ms: clock::timestamp_ms(clock)
        };
        
        linked_table::push_front(&mut campaign.top_ups, key, campaign_top_up);
        event::emit(CampaignToppedUp {
            id: campaign_top_up_inner_id,
            campaign_id: inner_campaign_id,
            timestamp_ms: clock::timestamp_ms(clock),
            top_up_token_mist_value: budget_token_mist_value,
            token_mist_value_per_claim: token_mist_value_per_claim,
            no_of_target_referees: no_of_target_referees,
            sender: sender(ctx),
        });
        transfer::transfer(campaign_post, sender(ctx));
        transfer::public_transfer(payment_token_mist, sender(ctx));
        transfer::share_object(campaign);
    }

    fun get_campaign_protocol_fee(campaign_protocol_fee: &CampaignProtocolFee, budget_usd: u64, number_of_target_referees: u64) : u256 {
        let campaign_protocol_fee_percent = protocol::get_campaign_protocol_fee_percent(campaign_protocol_fee) as u256;
        let budget_usd_integer_value = budget_usd as u256 * 10000;
        let mut campaign_protocol_fee_usd_ineger_value = budget_usd_integer_value * campaign_protocol_fee_percent / 100;
        // minimum campaign protocol fee is (number of claim txs + number of refer txs) * gas fee * 10000
        let minimum_campaign_protocol_fee_usd_integer_value = ((number_of_target_referees + number_of_target_referees) * 2) as u256;
        if (campaign_protocol_fee_usd_ineger_value < minimum_campaign_protocol_fee_usd_integer_value) {
            campaign_protocol_fee_usd_ineger_value = minimum_campaign_protocol_fee_usd_integer_value;
        };
        let reuslt = campaign_protocol_fee_usd_ineger_value;       
        reuslt
    }


    public entry fun add_referral<T>(
        campaign: &mut Campaign<T>,
        clock: &Clock,
        link: vector<u8>,
        ctx: &mut TxContext
    ) {
        let referralExists = object_table::contains(&campaign.referrals, sender(ctx));
        assert!(!referralExists, REFERRAL_EXISTS);
        let referral_id = object::new(ctx);
        let inner_referral_id = object::uid_to_inner(&referral_id);
        let referral = Referral {
            id: referral_id,
            campaign_id: object::uid_to_inner(&campaign.id),
            referrer: sender(ctx),
            link: string::utf8(link),
            timestamp_ms: clock::timestamp_ms(clock),
        };
        let referral_metadata = ReferralMetadata {
            id: object::new(ctx),
            referral_id: inner_referral_id,
            campaign_id: object::uid_to_inner(&campaign.id),
            referrer: sender(ctx),
            link: string::utf8(link),
            timestamp_ms: clock::timestamp_ms(clock),
        };
        event::emit(ReferralCreated {
            referral_id: inner_referral_id,
            campaign_id: object::uid_to_inner(&campaign.id),
            referrer: sender(ctx),
            link: string::utf8(link),
            timestamp_ms: clock::timestamp_ms(clock),
        });
        transfer::public_transfer(referral, sender(ctx));
        object_table::add(&mut campaign.referrals, sender(ctx), referral_metadata);
        campaign.no_of_referrals = campaign.no_of_referrals + 1;
    }


    public fun claim<T>(
        output: vector<u8>, input: vector<u8>, public_key: vector<u8>, proof: vector<u8>, 
        referral: address, campaign: &mut Campaign<T>, clock: &Clock, ctx: &mut TxContext
    ) {
        let is_verified: bool = ecvrf::ecvrf_verify(&output, &input, &public_key, &proof);
        assert!(is_verified, NOT_VERIFIED);
        // check if claimer has not claimed yet
        let claimExists = object_table::contains(&campaign.claimers, sender(ctx));
        assert!(!claimExists, CLAIM_EXISTS);
        // check if campaign is active
        let campaign_end_date = campaign.campaign_end_date;
        let current_time = clock::timestamp_ms(clock);
        assert!(current_time <= campaign_end_date, CAMPAIGN_ENDED);
        // check if campaign has enough budget
        assert!(campaign.no_of_target_referees >= campaign.no_of_claimed_referees, CAMPAIGN_FULLY_CLAIMED);
        let budget_token_mist_value = campaign.budget_token_mist_value;
        let token_mist_value_per_claim = budget_token_mist_value / campaign.no_of_target_referees;

        let referral_exists = object_table::contains(&campaign.referrals, referral);
        assert!(referral_exists, REFERRAL_NOT_FOUND);

        debug::print(&token_mist_value_per_claim);
        let campaign_owner_reward_percentage = campaign.campaign_owner_reward_percentage;
        let campaign_referral_reward_percentage = campaign.campaign_referral_reward_percentage;

        let token_mist_value_claimed_campaign_owner = token_mist_value_per_claim * campaign_owner_reward_percentage / 100;
        let token_mist_value_claimed_campaign_referral = token_mist_value_per_claim * campaign_referral_reward_percentage / 100;
        let token_mist_value_claimed_campaign_referee = token_mist_value_per_claim * (100 - campaign_owner_reward_percentage - campaign_referral_reward_percentage) / 100;

        let balance_claimed_campaign_owner = balance::split(&mut campaign.balance_token_mist, token_mist_value_claimed_campaign_owner);
        //debug::print(&balance_claimed_campaign_owner);
        let amount_claimed_campaign_owner = coin::from_balance(balance_claimed_campaign_owner, ctx);
        let balance_claimed_campaign_referral = balance::split(&mut campaign.balance_token_mist, token_mist_value_claimed_campaign_referral);
        //debug::print(&balance_claimed_campaign_referral);
        let amount_claimed_campaign_referral = coin::from_balance(balance_claimed_campaign_referral, ctx);
        let balance_claimed_campaign_referee = balance::split(&mut campaign.balance_token_mist, token_mist_value_claimed_campaign_referee);
       // debug::print(&balance_claimed_campaign_referee);
        let amount_claimed_campaign_referee = coin::from_balance(balance_claimed_campaign_referee, ctx);

        // update claimed budget
        campaign.claimed_budget_token_mist_value = campaign.claimed_budget_token_mist_value 
        + token_mist_value_claimed_campaign_owner 
        + token_mist_value_claimed_campaign_referral 
        + token_mist_value_claimed_campaign_referee;
        
        transfer::public_transfer(amount_claimed_campaign_owner, campaign.owner);
        transfer::public_transfer(amount_claimed_campaign_referral, referral);
        transfer::public_transfer(amount_claimed_campaign_referee, sender(ctx));

        let claim_id = object::new(ctx);
        let inner_claim_id = object::uid_to_inner(&claim_id);
        let claim = Claim {
            id: claim_id,
            campaign_id: object::uid_to_inner(&campaign.id),
            campaign_owner_address: campaign.owner,
            campaign_owner_amount_token_mist_value: token_mist_value_claimed_campaign_owner,
            referee_address: sender(ctx),
            referee_amount_token_mist_value: token_mist_value_claimed_campaign_referee,
            referral_address: referral,
            referral_amount_token_mist_value: token_mist_value_claimed_campaign_referral,
            token_mist_value_per_claim: token_mist_value_per_claim,
            timestamp_ms: clock::timestamp_ms(clock),
        };
        let claim_metadata = ClaimMetadata {
            id: object::new(ctx),
            claim_id: inner_claim_id,
            campaign_id: object::uid_to_inner(&campaign.id),
            claimer_address: sender(ctx),
            timestamp_ms: clock::timestamp_ms(clock),
        };
        event::emit(ClaimCreated {
            claim_id: inner_claim_id,
            campaign_id: object::uid_to_inner(&campaign.id),
            campaign_owner_address: campaign.owner,
            campaign_owner_amount_token_mist_value: token_mist_value_claimed_campaign_owner,
            referee_address: sender(ctx),
            referee_amount_token_mist_value: token_mist_value_claimed_campaign_referee,
            referral_address: referral,
            referral_amount_token_mist_value: token_mist_value_claimed_campaign_referral,
            token_mist_value_per_claim: token_mist_value_per_claim,
            campaign_end_date: campaign.campaign_end_date,
            timestamp_ms: clock::timestamp_ms(clock),
        });
        transfer::public_transfer(claim, sender(ctx));
        object_table::add(&mut campaign.claimers, sender(ctx), claim_metadata);
        campaign.no_of_claimed_referees = campaign.no_of_claimed_referees + 1;

        update_top_up(campaign, token_mist_value_per_claim);
    }

    public entry fun claim_locked<T>(
        output: vector<u8>, input: vector<u8>, public_key: vector<u8>, proof: vector<u8>, 
        referral: address, campaign: &mut Campaign<T>, clock: &Clock, ctx: &mut TxContext
    ) {
        let is_verified: bool = ecvrf::ecvrf_verify(&output, &input, &public_key, &proof);
        assert!(is_verified, NOT_VERIFIED);
        // check if claimer has not claimed yet
        let claimExists = object_table::contains(&campaign.claimers, sender(ctx));
        assert!(!claimExists, CLAIM_EXISTS);
        // check if campaign is active
        let campaign_end_date = campaign.campaign_end_date;
        let current_time = clock::timestamp_ms(clock);
        assert!(current_time <= campaign_end_date, CAMPAIGN_ENDED);
        // check if campaign has enough budget
        assert!(campaign.no_of_target_referees >= campaign.no_of_claimed_referees, CAMPAIGN_FULLY_CLAIMED);
        //let budget_token_mist_value = balance::value(&campaign.budget_token_mist);
        let token_mist_value_per_claim = campaign.budget_token_mist_value / campaign.no_of_target_referees;
        let campaign_owner_reward_percentage = campaign.campaign_owner_reward_percentage;
        let campaign_referral_reward_percentage = campaign.campaign_referral_reward_percentage;
        let campaign_referee_reward_percentage = 100 - campaign_owner_reward_percentage - campaign_referral_reward_percentage;

        let token_mist_value_claimed_campaign_owner = token_mist_value_per_claim * campaign_owner_reward_percentage / 100;
        let token_mist_value_claimed_campaign_referral = token_mist_value_per_claim * campaign_referral_reward_percentage / 100;
        let token_mist_value_claimed_campaign_referee = token_mist_value_per_claim * campaign_referee_reward_percentage / 100;

        // increate locked claimers
        let locked_claim_id = object::new(ctx);
        let inner_locked_claim_id = object::uid_to_inner(&locked_claim_id);
        let locked_claim = LockedClaim {
            id: locked_claim_id,
            campaign_id: object::uid_to_inner(&campaign.id),
            campaign_owner: campaign.owner,
            campaign_owner_reward_token_mist: token_mist_value_claimed_campaign_owner,
            referral: referral,
            referral_reward_token_mist: token_mist_value_claimed_campaign_referral,
            claimer: sender(ctx),
            claimer_reward_token_mist: token_mist_value_claimed_campaign_referee,
            total_amount_token_mist: token_mist_value_per_claim,
            timestamp_ms: clock::timestamp_ms(clock),
        };
        event::emit(LockedClaimCreated {
            locked_claim_id: inner_locked_claim_id,
            campaign_id: object::uid_to_inner(&campaign.id),
            campaign_owner: campaign.owner,
            campaign_owner_reward_token_mist: token_mist_value_claimed_campaign_owner,
            referral: referral,
            referral_reward_token_mist: token_mist_value_claimed_campaign_referral,
            claimer: sender(ctx),
            claimer_reward_token_mist: token_mist_value_claimed_campaign_referee,
            total_amount_token_mist: token_mist_value_per_claim,
            timestamp_ms: clock::timestamp_ms(clock),
        });
        object_table::add(&mut campaign.locked_claimers, sender(ctx), locked_claim);
        campaign.no_of_locked_claimers = campaign.no_of_locked_claimers + 1;
    }

    public entry fun unlock_claim_by_admin<T>(
        _: &CampaignAdminCap,
        locked_claimer: address,
        campaign: &mut Campaign<T>,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        // get locked claim
        let locked_claim = object_table::borrow(&campaign.locked_claimers, locked_claimer);
        
        let claim = Claim {
            id: object::new(ctx),
            campaign_id: object::uid_to_inner(&campaign.id),
            campaign_owner_address: campaign.owner,
            campaign_owner_amount_token_mist_value: locked_claim.campaign_owner_reward_token_mist,
            referee_address: locked_claim.claimer,
            referee_amount_token_mist_value: locked_claim.claimer_reward_token_mist,
            referral_address: locked_claim.referral,
            referral_amount_token_mist_value: locked_claim.referral_reward_token_mist,
            token_mist_value_per_claim: locked_claim.total_amount_token_mist,
            timestamp_ms: clock::timestamp_ms(clock),
        };
        let token_mist_value_per_claim = locked_claim.total_amount_token_mist;
        // split campaign owner reward from budget
        let campaign_owner_reward_token_mist = balance::split(&mut campaign.balance_token_mist, locked_claim.campaign_owner_reward_token_mist);
        let campaign_owner_reward_coin = coin::from_balance(campaign_owner_reward_token_mist, ctx);
        // transfer campaign owner reward to campaign owner
        transfer::public_transfer(campaign_owner_reward_coin, campaign.owner);

        // split referral reward from budget
        let referral_reward_token_mist = balance::split(&mut campaign.balance_token_mist, locked_claim.referral_reward_token_mist);
        let referral_reward_coin = coin::from_balance(referral_reward_token_mist, ctx);
        // transfer referral reward to referral
        transfer::public_transfer(referral_reward_coin, locked_claim.referral);

        // split claimer reward from budget
        let claimer_reward_token_mist = balance::split(&mut campaign.balance_token_mist, locked_claim.claimer_reward_token_mist);
        let claimer_reward_coin = coin::from_balance(claimer_reward_token_mist, ctx);
        // transfer claimer reward to claimer
        transfer::public_transfer(claimer_reward_coin, locked_claim.claimer);

        // unlock claim
        let locked_claim = object_table::remove(&mut campaign.locked_claimers, locked_claimer);
        let claimer_reward_token_mist_value = locked_claim.claimer_reward_token_mist;
        event::emit(ClaimUnlocked {
            locked_claim_id: object::uid_to_inner(&locked_claim.id),
            claim_id: object::uid_to_inner(&claim.id),
            campaign_id: object::uid_to_inner(&campaign.id),
            claimer: locked_claimer,
            amount_claimed_token_mist: claimer_reward_token_mist_value,
            timestamp_ms: clock::timestamp_ms(clock),
        });
        let LockedClaim {
            id,
            campaign_id: _,
            campaign_owner: _,
            campaign_owner_reward_token_mist: _,
            referral: _,
            referral_reward_token_mist: _,
            claimer: _,
            claimer_reward_token_mist: _,
            timestamp_ms: _,
            total_amount_token_mist: _,
        } = locked_claim;
        // Delete the object's UID to fully clean up
        object::delete(id);

        let claim_metadata = ClaimMetadata {
            id: object::new(ctx),
            claim_id: object::uid_to_inner(&claim.id),
            campaign_id: object::uid_to_inner(&campaign.id),
            claimer_address: sender(ctx),
            timestamp_ms: clock::timestamp_ms(clock),
        };
        transfer::public_transfer(claim, sender(ctx));
        object_table::add(&mut campaign.claimers, sender(ctx), claim_metadata);
        campaign.no_of_claimed_referees = campaign.no_of_claimed_referees + 1;

        update_top_up(campaign, token_mist_value_per_claim);
    }

    public entry fun top_up_campaign<T>(
        campaign: &mut Campaign<T>,
        mut top_up_amount_token_mist: Coin<T>,
        no_of_target_referees: u64,
        token_mist_value_per_claim: u64,
        campaign_protocol_fee: &CampaignProtocolFee,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let campain_amount_token_mist_value = no_of_target_referees * token_mist_value_per_claim;
        let campaign_protocol_fee_percent = protocol::get_campaign_protocol_fee_percent(campaign_protocol_fee);
        let campaign_protocol_fee_token_mist = campain_amount_token_mist_value * campaign_protocol_fee_percent / 100;
        let total_amount_token_mist_value = campain_amount_token_mist_value + campaign_protocol_fee_token_mist;
        let top_up_amount_token_mist_value = coin::value(&top_up_amount_token_mist);
        assert!(total_amount_token_mist_value <= top_up_amount_token_mist_value, INSUFFICIENT_FUND);

        let campaign_protocol_fee_wallet = protocol::get_campaign_protocol_fee_wallet(campaign_protocol_fee);
        let campaign_protocol_fee_coin = coin::split(&mut top_up_amount_token_mist, campaign_protocol_fee_token_mist, ctx);
        transfer::public_transfer(campaign_protocol_fee_coin, campaign_protocol_fee_wallet);

        // let total_fee_token_mist = total_fee_usd * multiplier * multiplier / token_price_usd_mist;
        // assert!(top_up_amount_token_mist_value >= total_fee_token_mist, INSUFFICIENT_FUND);
        
        // let campaign_protocol_fee_token_mist = campaign_protocol_fee_usd * multiplier * multiplier / token_price_usd_mist;
        // let campaign_protocol_fee_wallet = protocol::get_campaign_protocol_fee_wallet(campaign_protocol_fee);
        // let campaign_protocol_fee_coin = coin::split(&mut top_up_amount_token_mist, campaign_protocol_fee_token_mist, ctx);
        // transfer::public_transfer(campaign_protocol_fee_coin, campaign_protocol_fee_wallet);
        let top_up_amount_token_mist_coin = coin::split(&mut top_up_amount_token_mist, campain_amount_token_mist_value, ctx);
        let cmpaign_amount_token_mist = coin::into_balance(top_up_amount_token_mist_coin);
        balance::join(&mut campaign.balance_token_mist, cmpaign_amount_token_mist);
        campaign.no_of_target_referees = campaign.no_of_target_referees + no_of_target_referees;

        let top_up_id = object::new(ctx);
        let inner_top_up_id = object::uid_to_inner(&top_up_id);
        let top_up_key = CampaignTopUpKey {
            sender: sender(ctx),
            timestamp_ms: clock::timestamp_ms(clock),
        };

        let top_up = CampaignTopUp {
            id: top_up_id,
            campaign_id: object::uid_to_inner(&campaign.id),
            top_up_token_mist_value: campain_amount_token_mist_value,
            remaining_balance_token_mist_value: campain_amount_token_mist_value,
            sender: sender(ctx),
            timestamp_ms: clock::timestamp_ms(clock),
            no_of_target_referees: no_of_target_referees,
            token_mist_value_per_claim: token_mist_value_per_claim,
        };
        linked_table::push_front(&mut campaign.top_ups, top_up_key, top_up);
        event::emit(CampaignToppedUp {
            id: inner_top_up_id,
            campaign_id: object::uid_to_inner(&campaign.id),
            timestamp_ms: clock::timestamp_ms(clock),
            top_up_token_mist_value: campain_amount_token_mist_value,
            sender: sender(ctx),
            no_of_target_referees: no_of_target_referees,
            token_mist_value_per_claim: token_mist_value_per_claim,
        });
        transfer::public_transfer(top_up_amount_token_mist, sender(ctx));
    }

    public entry fun withdraw_balance_by_admin<T>(
        _: &CampaignAdminCap,
        campaign: &mut Campaign<T>,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        // make sure locked claimer is sender
        let len = campaign.top_ups.length();
        let mut top_up_timestamp_ms: u64 = 0;
        let mut i = 0;
        while (i < len) {
            let (_, top_up) = linked_table::pop_front<CampaignTopUpKey, CampaignTopUp>(&mut campaign.top_ups);
            top_up_timestamp_ms = top_up.timestamp_ms;
            let withdrawn_balance = balance::split(&mut campaign.balance_token_mist, top_up.remaining_balance_token_mist_value);
            transfer::public_transfer(coin::from_balance(withdrawn_balance, ctx), top_up.sender);
            let CampaignTopUp {
                id,
                campaign_id: _,
                top_up_token_mist_value: _,
                remaining_balance_token_mist_value: _,
                sender: _,
                timestamp_ms: _,
                no_of_target_referees: _,
                token_mist_value_per_claim: _,
            } = top_up;
            object::delete(id);
            i = i + 1;
        };
        event::emit(CampaignBalanceWithdrawn {
            campaign_id: object::uid_to_inner(&campaign.id),
            withdraw_timestamp_ms: clock::timestamp_ms(clock),
            top_up_timestamp_ms: top_up_timestamp_ms,
            sender: sender(ctx),
        });
    }

    fun new_campaign_top_up_key(sender: address, timestamp_ms: u64): CampaignTopUpKey {
        CampaignTopUpKey {sender: sender, timestamp_ms: timestamp_ms}
    }

    public entry fun withdraw_balance_by_sender<T>(
        campaign: &mut Campaign<T>,
        timestamp_ms: vector<u64>,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        let len = timestamp_ms.length();
        let mut i = 0;
        while (i < len) {
            let top_up_timestamp_ms = timestamp_ms[i];
            let key: CampaignTopUpKey = new_campaign_top_up_key(sender(ctx), timestamp_ms[i]);
            //let key: CampaignTopUpKey = {sender: sender(ctx), timestamp_ms: timestamp_ms[i]};
            let _top_up = linked_table::remove<CampaignTopUpKey, CampaignTopUp>(&mut campaign.top_ups, key);
            let withdrawn_balance = balance::split(&mut campaign.balance_token_mist, _top_up.remaining_balance_token_mist_value);
            transfer::public_transfer(coin::from_balance(withdrawn_balance, ctx), _top_up.sender);
            let CampaignTopUp {
                id,
                campaign_id: _,
                top_up_token_mist_value: _,
                remaining_balance_token_mist_value: _,
                sender: _,
                timestamp_ms: _,
                no_of_target_referees: _,
                token_mist_value_per_claim: _,
            } = _top_up;
            object::delete(id);
            i = i + 1;
            event::emit(CampaignBalanceWithdrawn {
                campaign_id: object::uid_to_inner(&campaign.id),
                withdraw_timestamp_ms: clock::timestamp_ms(clock),
                top_up_timestamp_ms: top_up_timestamp_ms,
                sender: sender(ctx)
            });
        };
        
         
    }

    // public entry fun extend_campaign<T>(
    //     _: &CampaignPost,
    //     campaign: &mut Campaign<T>,
    //     new_end_date: u64,
    //     clock: &Clock,
    //     ctx: &mut TxContext,
    // ) {
    //     assert!(new_end_date > campaign.campaign_end_date, INVALID_END_DATE);
    //     campaign.campaign_end_date = new_end_date;  
    //     event::emit(CampaignExtended {
    //         campaign_id: object::uid_to_inner(&campaign.id),
    //         old_end_date: campaign.campaign_end_date,
    //         new_end_date: new_end_date,
    //         timestamp_ms: clock::timestamp_ms(clock),
    //         sender: sender(ctx)
    //     });
    // }

    public entry fun end_campaign<T>(
        _: &CampaignPost,
        campaign: &mut Campaign<T>,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        campaign.campaign_end_date = clock::timestamp_ms(clock);
        event::emit(CampaignEnded {
            campaign_id: object::uid_to_inner(&campaign.id),
            timestamp_ms: clock::timestamp_ms(clock),
            sender: sender(ctx),
        });
    }

    public fun update_top_up<T>(campaign: &mut Campaign<T>, token_mist_value_per_claim: u64) {
        let (first_top_up_key, mut first_top_up) = linked_table::pop_front<CampaignTopUpKey, CampaignTopUp>(&mut campaign.top_ups);
        let remaining_token_mist_value = first_top_up.top_up_token_mist_value - token_mist_value_per_claim;
        if (remaining_token_mist_value >=  token_mist_value_per_claim) {
            first_top_up.remaining_balance_token_mist_value = remaining_token_mist_value;
            linked_table::push_front(&mut campaign.top_ups, first_top_up_key, first_top_up);
        } else {
            let CampaignTopUp {
                id,
                campaign_id: _,
                top_up_token_mist_value: _,
                remaining_balance_token_mist_value: _,
                sender: _,
                timestamp_ms: _,
                token_mist_value_per_claim: _,
                no_of_target_referees: _,
            } = first_top_up;
            object::delete(id);
        }
    }

    // public fun update_top_ups<T>(campaign: &mut Campaign<T>, token_mist_value_per_claim: u64) {
    //     let mut remaining_token_mist_value_per_claim = token_mist_value_per_claim;
    //     while (remaining_token_mist_value_per_claim > 0) {
    //         let (_, updated_token_mist_value_per_claim) = update_top_up_once(campaign, remaining_token_mist_value_per_claim);
    //         remaining_token_mist_value_per_claim = updated_token_mist_value_per_claim;
    //     };
    // }

    // public fun update_top_up_once<T>(campaign: &mut Campaign<T>, token_mist_value_per_claim: u64): (u64, u64) {
    //     let (first_top_up_key, mut first_top_up) = linked_table::pop_front<CampaignTopUpKey, CampaignTopUp>(&mut campaign.top_ups);
    //     let mut remaining_token_mist_value_per_claim = token_mist_value_per_claim;
    //     let remaining_token_mist_value = first_top_up.remaining_balance_token_mist_value;
    //     if (remaining_token_mist_value > remaining_token_mist_value_per_claim) {
    //         first_top_up.remaining_balance_token_mist_value = remaining_token_mist_value - remaining_token_mist_value_per_claim;
    //         linked_table::push_front(&mut campaign.top_ups, first_top_up_key, first_top_up);
    //         remaining_token_mist_value_per_claim = 0;
    //     } else {
    //         let CampaignTopUp {
    //             id,
    //             campaign_id: _,
    //             top_up_token_mist: _,
    //             remaining_balance_token_mist_value: _,
    //             sender: _,
    //             timestamp_ms: _,
    //         } = first_top_up;
    //         object::delete(id);
    //         remaining_token_mist_value_per_claim = remaining_token_mist_value_per_claim - remaining_token_mist_value;
    //     };

    //     (remaining_token_mist_value, remaining_token_mist_value_per_claim)
    // }

    public fun get_multiplier<T>(metadata: &CoinMetadata<T>): u64 {
        let decimals = coin::get_decimals(metadata);
        let mut i: u8 = 0;
        let mut multiplier = 1;       
        while (i < decimals) { 
            multiplier = multiplier * 10;
            i = i + 1;
        };
        multiplier
    }


    public fun get_type_name<T>(): String {
        let type_name: TypeName = type_name::get<T>();
        let typeBytes = ascii::into_bytes(type_name.into_string());
        let str = string::utf8(typeBytes);
        str
    }   

    #[test_only]
    public fun init_for_testing(otw: CAMPAIGN, ctx: &mut TxContext) {
        init(otw, ctx);
    }
}

