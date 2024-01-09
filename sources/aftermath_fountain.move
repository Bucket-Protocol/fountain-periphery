module bucket_fountain_periphery::aftermath_fountain {

    use sui::sui::SUI;
    use sui::coin::{Self, Coin};
    use sui::balance;
    use sui::tx_context::TxContext;
    use sui::clock::Clock;
    use sui::transfer;
    use bucket_protocol::buck::{Self, BucketProtocol};
    use bucket_fountain::fountain_core::{Self, Fountain};
    use amm::pool::Pool;
    use amm::pool_registry::PoolRegistry;
    use amm::deposit as af_deposit;
    use protocol_fee_vault::vault::ProtocolFeeVault;
    use insurance_fund::insurance_fund::InsuranceFund;
    use referral_vault::referral_vault::ReferralVault;
    use treasury::treasury::Treasury;
    use 0x5d4b302506645c37ff133b98c4b50a5ae14841659738d6d733d59d0d217a93bf::coin::COIN as USDC;
    use 0xf1b901d93cc3652ee26e8d88fff8dc7b9402b2b2e71a59b244f938a140affc5e::af_lp::AF_LP;

    const EXPECTED_RATIO: u128 = 1_000_000_000_000_000_000; // 50-50
    const SLIPPAGE: u64 = 5_000_000_000_000_000_000; // 5%
    const MAX_LOCK_TIME: u64 = 4_838_400_000;

    public entry fun stake(
        protocol: &mut BucketProtocol,
        af_pool: &mut Pool<AF_LP>,
        af_pool_registry: &PoolRegistry,
        af_fee_vault: &ProtocolFeeVault,
        af_treasury: &mut Treasury,
        af_insurance: &mut InsuranceFund,
        af_referral_vault: &ReferralVault,
        fountain: &mut Fountain<AF_LP, SUI>,
        clock: &Clock,
        usdc_coin: Coin<USDC>,
        recipient: address,
        ctx: &mut TxContext,
    ) {
        let usdc_amount = coin::value(&usdc_coin);
        let usdc_to_psm = balance::split(coin::balance_mut(&mut usdc_coin), usdc_amount/2);
        let buck = buck::charge_reservoir<USDC>(protocol, usdc_to_psm);
        let buck_coin = coin::from_balance(buck, ctx);
        let af_lp = af_deposit::deposit_2_coins(
            af_pool,
            af_pool_registry,
            af_fee_vault,
            af_treasury,
            af_insurance,
            af_referral_vault,
            usdc_coin,
            buck_coin,
            EXPECTED_RATIO,
            SLIPPAGE,
            ctx,
        );
        let proof = fountain_core::stake(
            clock,
            fountain,
            coin::into_balance(af_lp),
            MAX_LOCK_TIME,
            ctx,
        );
        transfer::public_transfer(proof, recipient);
    }
}