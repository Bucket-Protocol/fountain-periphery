module bucket_fountain_periphery::aftermath_fountain {

    use sui::sui::SUI;
    use sui::coin::{Self, Coin};
    use sui::balance;
    use sui::tx_context::TxContext;
    use sui::clock::Clock;
    use sui::transfer;
    use bucket_protocol::buck::{Self, BucketProtocol, BUCK};
    use bucket_fountain::fountain_core::{Self, Fountain, StakeProof};
    use amm::pool::Pool;
    use amm::pool_registry::PoolRegistry;
    use amm::deposit as af_deposit;
    use amm::withdraw as af_withdraw;
    use protocol_fee_vault::vault::ProtocolFeeVault;
    use insurance_fund::insurance_fund::InsuranceFund;
    use referral_vault::referral_vault::ReferralVault;
    use treasury::treasury::Treasury;
    use cetus_integrate::router;
    use cetus_clmm::pool::Pool as CetusPool;
    use cetus_clmm::config::GlobalConfig as CetusConfig;
    use usdc_package::coin::COIN as USDC;
    use af_lp_package::af_lp::AF_LP;

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

    public entry fun unstake(
        af_pool: &mut Pool<AF_LP>,
        af_pool_registry: &PoolRegistry,
        af_fee_vault: &ProtocolFeeVault,
        af_treasury: &mut Treasury,
        af_insurance: &mut InsuranceFund,
        af_referral_vault: &ReferralVault,
        cetus_config: &CetusConfig,
        cetus_pool: &mut CetusPool<BUCK, USDC>,
        fountain: &mut Fountain<AF_LP, SUI>,
        clock: &Clock,
        proof: StakeProof<AF_LP, SUI>,
        recipient: address,
        ctx: &mut TxContext,
    ) {
        let (af_lp, sui_reward) = fountain_core::force_unstake(clock, fountain, proof);
        let af_lp_coin = coin::from_balance(af_lp, ctx);
        let (usdc_coin, buck_coin) = af_withdraw::all_coin_withdraw_2_coins(
            af_pool,
            af_pool_registry,
            af_fee_vault,
            af_treasury,
            af_insurance,
            af_referral_vault,
            af_lp_coin,
            ctx,
        );
        let buck_value = coin::value(&buck_coin);
        let (buck_out, usdc_out) = router::swap(
            cetus_config,
            cetus_pool,
            buck_coin,
            usdc_coin,
            true,
            true,
            buck_value,
            4295048016_u128,
            false,
            clock,
            ctx,
        );
        let sui_reward = coin::from_balance(sui_reward, ctx);
        transfer::public_transfer(sui_reward, recipient);
        transfer::public_transfer(usdc_out, recipient);
        transfer::public_transfer(buck_out, recipient);
    }

    public entry fun claim(
        fountain: &mut Fountain<AF_LP, SUI>,
        clock: &Clock,
        proof: &mut StakeProof<AF_LP, SUI>,
        recipient: address,
        ctx: &mut TxContext,
    ) {
        let sui_reward = fountain_core::claim(
            clock, fountain, proof,
        );
        let sui_reward = coin::from_balance(sui_reward, ctx);
        transfer::public_transfer(sui_reward, recipient);
    }
}