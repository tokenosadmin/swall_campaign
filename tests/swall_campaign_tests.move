/*
#[test_only]
module swall_campaign::swall_campaign_tests;
// uncomment this line to import the module
// use swall_campaign::swall_campaign;

const ENotImplemented: u64 = 0;
*/
#[test_only]
#[allow(unused_use)]
module swall_campaign::swall_campaign_tests {
    use sui::test_scenario::{Self as ts, Scenario};
    use sui::test_utils;
    use swall_campaign::campaign::{Self, Campaign, CAMPAIGN};
    use sui::sui::SUI;
    use sui::object_table;
    use sui::clock::{Self, Clock};
    use swall_campaign::protocol::{Self, CampaignProtocolFee};
    use swall_campaign::campaign_oracle::{Self, CampaignOracle, CampaignOracleCap};
    use sui::coin::{Self, CoinMetadata, TreasuryCap};
    use std::string::{Self, String};
    use std::debug;

    const ADMIN: address = @0xAD;
    const BOB: address = @0xB;

    const MINIMUM_FUND: u64 = 2000000000000000000;

    public struct SWALL_CAMPAIGN_TESTS has drop {}

    #[test_only]
    public fun setup_test_environment(scenario: &mut Scenario) {
        // Start admin transaction
        ts::next_tx(scenario, ADMIN);

       // let coin_type = MOCK_COIN {};
        // Create mock coin metadata
        let (treasury_cap, metadata) = coin::create_currency<SWALL_CAMPAIGN_TESTS>(
            SWALL_CAMPAIGN_TESTS{},
            9, // decimals
            b"MOCK",
            b"Mock Coin",
            b"Test coin",
            option::none(),
            ts::ctx(scenario)
        );
        // Initialize campaign oracle
        campaign_oracle::fetch_campaign_oracle(ts::ctx(scenario));
        // Initialize protocol fee
        protocol::create_campaign_protocol_fee(ts::ctx(scenario));
        // Create test clock
        //let clock = clock::create_for_testing(ts::ctx(scenario));
        // Get shared objects
        // let mut oracle = ts::take_shared<CampaignOracle>(scenario);
        // let oracleCap = ts::take_from_sender<CampaignOracleCap>(scenario);
        // //let protocol_fee = ts::take_shared<CampaignProtocolFee>(scenario);
        // campaign_oracle::add_oracle<SWALL_CAMPAIGN_TESTS>(
        //     &oracleCap, 
        //      &mut oracle,
        //     &metadata,
        //     1000000,
        //     &clock,
        //     ts::ctx(scenario)
        // );

        // // Clean up treasury cap
        transfer::public_transfer(treasury_cap, @0xAD);
        transfer::public_transfer(metadata, @0xAD);
        // ts::return_shared<CampaignOracle>(oracle);
        // ts::return_to_sender(scenario, oracleCap);
        // clock::destroy_for_testing(clock);
    }

    #[test]
    fun test_create() { 
        let mut ts = ts::begin(ADMIN);
        setup_test_environment(&mut ts);
        // {
        //     ts::next_tx(&mut ts, ADMIN);
        //     campaign::init_for_testing(
        //         test_utils::create_one_time_witness<CAMPAIGN>(), 
        //         ts::ctx(&mut ts)
        //     );
        //     campaign_oracle::fetch_campaign_oracle(ts::ctx(&mut ts));
        //     protocol::create_campaign_protocol_fee(ts::ctx(&mut ts));
        // };
        {
            ts::next_tx(&mut ts, ADMIN);
            let mut oracle = ts::take_shared<CampaignOracle>(&ts);
            let oracleCap = ts::take_from_sender<CampaignOracleCap>(&ts);
            let metadata = ts::take_from_sender<CoinMetadata<SWALL_CAMPAIGN_TESTS>>(&ts);
            let treasury_cap = ts::take_from_sender<TreasuryCap<SWALL_CAMPAIGN_TESTS>>(&ts);
            let clock = clock::create_for_testing(ts::ctx(&mut ts));
            //let protocol_fee = ts::take_shared<CampaignProtocolFee>(scenario);
                campaign_oracle::add_oracle<SWALL_CAMPAIGN_TESTS>(
                    &oracleCap, 
                    &mut oracle,
                    &metadata,
                    3141500000,
                    &clock,
                    ts::ctx(&mut ts)
                );

            // Clean up treasury cap
            transfer::public_transfer(treasury_cap, @0xAD);
            transfer::public_transfer(metadata, @0xAD);
            ts::return_shared<CampaignOracle>(oracle);
            ts::return_to_sender(&ts, oracleCap);
            clock::destroy_for_testing(clock);
        };
        {
            ts::next_tx(&mut ts, ADMIN);
            let coin = coin::mint_for_testing<SWALL_CAMPAIGN_TESTS>(MINIMUM_FUND, ts::ctx(&mut ts));
            let clock: Clock = clock::create_for_testing(ts::ctx(&mut ts));
            let oracle: CampaignOracle = ts::take_shared(&ts);
            let oracleCap = ts::take_from_sender<CampaignOracleCap>(&ts);
            let metadata = ts::take_from_sender<CoinMetadata<SWALL_CAMPAIGN_TESTS>>(&ts);
            let campaign_protocol_fee: CampaignProtocolFee = ts::take_shared(&ts);
            campaign::create_campaign<SWALL_CAMPAIGN_TESTS>(
                b"test",
                b"test",
                b"test",
                b"test",
                b"test",
                b"test",
                b"test",
                b"test",
                coin,
                &metadata,
                50,
                50,
                clock.timestamp_ms(),
                0,
                1000000,
                &campaign_protocol_fee,
                2,
                &oracle,
                b"link",
                &clock,
                ts::ctx(&mut ts)
            );
            clock::destroy_for_testing(clock);
            ts::return_shared<CampaignOracle>(oracle);
            ts::return_to_sender(&ts, oracleCap);
            ts::return_to_sender(&ts, metadata);
            ts::return_shared<CampaignProtocolFee>(campaign_protocol_fee);
        };
        {
            ts::next_tx(&mut ts, BOB);
            assert!(ts::has_most_recent_shared<Campaign<SWALL_CAMPAIGN_TESTS>>(), 1);
        };
        // {
        //     ts::next_tx(&mut ts, ADMIN);
        //     let coin = coin::mint_for_testing<SUI>(MINIMUM_FUND, ts::ctx(&mut ts));
        //     let clock: Clock = clock::create_for_testing(ts::ctx(&mut ts));
        //     let campaign_oracle: CampaignOracle = ts::take_shared(&ts);
        //     let campaign_protocol_fee: CampaignProtocolFee = ts::take_shared(&ts);
        //     campaign::create_campaign(
        //         b"test",
        //         b"test",
        //         b"test",
        //         b"test",
        //         b"test",
        //         b"test",
        //         b"test",
        //         b"test",
        //         ADMIN,
        //         coin,
        //         50,
        //         50,
        //         0,
        //         0,
        //         1,
        //         &campaign_protocol_fee,
        //         1,
        //         &campaign_oracle,
        //         b"link",
        //         &clock,
        //         ts::ctx(&mut ts)
        //     );
        //     clock::destroy_for_testing(clock);
        //     ts::return_shared<CampaignOracle>(campaign_oracle);
        //     ts::return_shared<CampaignProtocolFee>(campaign_protocol_fee);
        //     //coin::burn_for_testing(coin);
        // };
        // {
        //     ts::next_tx(&mut ts, ADMIN);
        //     let mut campaign: Campaign<SWALL_CAMPAIGN_TESTS> = ts::take_shared(&ts);
        //     let clock: Clock = clock::create_for_testing(ts::ctx(&mut ts));
        //     campaign::claim(b"test", ADMIN, &mut campaign, &campaign_secret, &clock, ts::ctx(&mut ts));
        //     ts::return_shared<Campaign>(campaign);
        //     clock::destroy_for_testing(clock);
        // };
        
        ts::end(ts);
    }

}


// #[test, expected_failure(abort_code = ::swall_campaign::swall_campaign_tests::ENotImplemented)]
// fun test_swall_campaign_fail() {
//     abort ENotImplemented
// }

