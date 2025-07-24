/*
/// Module: swall_oracle
module swall_oracle::swall_oracle;
*/

/*
/// Module: oracle
module oracle::oracle;
*/
#[allow(unused_use)]
module swall_campaign::campaign_oracle {
    use std::string::{Self, String};
    use sui::coin::{Self, CoinMetadata};
    use sui::event;
    use std::type_name::{Self, TypeName};
    use std::ascii::{Self};
    use sui::tx_context::sender;
    use sui::object_table::{Self, ObjectTable};
    use sui::clock::{ Clock };
    /// Define a capability for the admin of the oracle.
    public struct CampaignOracleCap has key, store { id: UID }

    public struct CAMPAIGN_ORACLE has drop {}

    /// Define a struct for the SUI USD price oracle
    public struct PriceOracle has key, store {
        id: UID,
        /// The address of the oracle.
        creator: address,
        /// The name of the oracle.
        name: String,
        /// The description of the oracle.
        description: String,
        /// The current price of SUI in USD.
        token_price_mist: u64,
        /// The timestamp of the last update.
        last_update: u64,
    }

    public struct CampaignOracle has key, store {
        id: UID,
        oraceles: ObjectTable<String, PriceOracle>,
    }

    public struct PriceCreated has drop, copy {
        oracle_id: ID,
        type_name: String,
        creator: address,
        name: String,
        description: String,
        token_price_mist: u64,
        timestamp: u64,
    }

    public struct PriceUpdated has drop, copy {
        oracle_id: ID,
        type_name: String,
        old_price_mist: u64,
        new_price_mist: u64,
        timestamp: u64,
    }

    fun init(_campaign_oracle: CAMPAIGN_ORACLE, ctx: &mut TxContext) {
         // Claim ownership of the one-time witness and keep it

        let cap = CampaignOracleCap { id: object::new(ctx) }; // Create a new admin capability object
        let campaign_oracle = CampaignOracle {
            id: object::new(ctx),
            oraceles: object_table::new(ctx),
        };
        transfer::share_object(campaign_oracle);
        transfer::public_transfer(cap, ctx.sender()); // Transfer the admin capability to the sender.
    }

    public fun add_oracle<T>(
        _: &CampaignOracleCap,
        campaign_oracle: &mut CampaignOracle,
        metadata: &CoinMetadata<T>,
        token_price_mist: u64,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        let type_string = get_type_name<T>();
        let oracle = PriceOracle {
            id: object::new(ctx),
            creator: sender(ctx),
            name: coin::get_name(metadata),
            description: coin::get_description(metadata),
            token_price_mist: token_price_mist,
            last_update: clock.timestamp_ms(),
        };
        event::emit(PriceCreated {
            oracle_id: object::uid_to_inner(&oracle.id),
            type_name: type_string,
            creator: sender(ctx),
            name: coin::get_name(metadata),
            description: coin::get_description(metadata),
            token_price_mist: token_price_mist,
            timestamp: clock.timestamp_ms(),
        });
        object_table::add(&mut campaign_oracle.oraceles, type_string, oracle);
    }

        /// Update the SUI USD price
    public fun update_price(
        _: &CampaignOracleCap,
        campaign_oracle: &mut CampaignOracle,
        type_name: vector<u8>,
        new_price_mist: u64,
        clock: &Clock,
    ) {
        let type_string = string::utf8(type_name);
        let oracle = object_table::borrow_mut(&mut campaign_oracle.oraceles, type_string); 
        oracle.token_price_mist = new_price_mist;
        oracle.last_update = clock.timestamp_ms();
        event::emit(PriceUpdated {
            oracle_id: object::uid_to_inner(&oracle.id),
            type_name: type_string,
            old_price_mist: oracle.token_price_mist,
            new_price_mist: new_price_mist,
            timestamp: clock.timestamp_ms()
        });
    }

    public fun get_type_name<T>(): String {
        let type_name: TypeName = type_name::get<T>();
        let typeBytes = ascii::into_bytes(type_name.into_string());
        let str = string::utf8(typeBytes);
        str
    }   
    

    /// Get the current SUI USD price
    public fun get_price(campaign_oracle: &CampaignOracle, type_name: String): u64 {
        //let type_string = string::utf8(type_name);
        let oracle = object_table::borrow(&campaign_oracle.oraceles, type_name); 
        oracle.token_price_mist
    }

    /// Get the last update timestamp
    public fun get_last_update(campaign_oracle: &CampaignOracle, type_name: String): u64 {
        //let type_string = string::utf8(type_name);
        let oracle = object_table::borrow(&campaign_oracle.oraceles, type_name); 
        oracle.last_update
    }

    #[test_only]
    public fun fetch_campaign_oracle(ctx: &mut TxContext) {
        let cap = CampaignOracleCap { id: object::new(ctx) }; // Create a new admin capability object
        let campaign_oracle = CampaignOracle {
            id: object::new(ctx),
            oraceles: object_table::new(ctx),
        };
        transfer::share_object(campaign_oracle);
        transfer::public_transfer(cap, ctx.sender()); // Transfer the admin capability to the sender.
    }
}

