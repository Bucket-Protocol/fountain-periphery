module bucket_fountain_periphery::cetus_fountain {

    use sui::sui::SUI;
    use sui::coin::{Self, Coin};
    use sui::tx_context::TxContext;
    use sui::clock::Clock;
    use sui::transfer;
    use cetus_integrate::router;
    use cetus_clmm::pool::{Self, Pool};
    use cetus_clmm::config::GlobalConfig;
    use bucket_protocol::buck::{Self, BucketProtocol, BUCK};
    use bucket_fountain::fountain_core::{Self, Fountain, StakeProof};
    use strater_lp_vault::bucketus::{Self, BUCKETUS, BucketusTreasury, CetusLpVault};
    use usdc_package::coin::COIN as USDC;

    const DUST_COLLECTION_ACCOUNT: address = @0xbfd2e22f32d4bcaaf6f12f218fcc26488fdf63f338481e0d4f96e95160d61ba9;
    const UNIT_LIQUIDITY: u128 = 15811389;
    const UNIT_OUTPUT: u128 = 1000000022;
    const MAX_LOCK_TIME: u64 = 4_838_400_000;

    public entry fun stake(
        protocol: &mut BucketProtocol,
        fountain: &mut Fountain<BUCKETUS, SUI>,
        treasury: &mut BucketusTreasury,
        vault: &mut CetusLpVault,
        config: &GlobalConfig,
        pool: &mut Pool<BUCK, USDC>,
        clock: &Clock,
        usdc_coin: Coin<USDC>,
        recipient: address,
        ctx: &mut TxContext,
    ) {
        let usdc_norm_value = ((coin::value(&usdc_coin) * 995) as u128);
        let delta_liquidity = (usdc_norm_value as u128) * UNIT_LIQUIDITY / UNIT_OUTPUT;
        let (bucketus_out, receipt) = bucketus::deposit(
            treasury,
            vault,
            config,
            pool,
            delta_liquidity,
            clock,
            ctx,
        );
        let (buck_amount, usdc_amount) = pool::add_liquidity_pay_amount(&receipt);
        let usdc_to_charge = coin::split(&mut usdc_coin, buck_amount/999 + 10, ctx);
        let buck_all = buck::charge_reservoir<USDC>(protocol, coin::into_balance(usdc_to_charge));
        let buck_all = coin::from_balance(buck_all, ctx);
        let buck_in = coin::split(&mut buck_all, buck_amount, ctx);
        transfer::public_transfer(buck_all, DUST_COLLECTION_ACCOUNT);
        let usdc_in = coin::split(&mut usdc_coin, usdc_amount, ctx);
        pool::repay_add_liquidity(
            config,
            pool,
            coin::into_balance(buck_in),
            coin::into_balance(usdc_in),
            receipt,
        );
        let proof = fountain_core::stake(
            clock,
            fountain,
            coin::into_balance(bucketus_out),
            MAX_LOCK_TIME,
            ctx,
        );
        transfer::public_transfer(usdc_coin, recipient);
        transfer::public_transfer(proof, recipient);
    }

    public entry fun unstake(
        fountain: &mut Fountain<BUCKETUS, SUI>,
        treasury: &mut BucketusTreasury,
        vault: &mut CetusLpVault,
        config: &GlobalConfig,
        pool: &mut Pool<BUCK, USDC>,
        clock: &Clock,
        proof: StakeProof<BUCKETUS, SUI>,
        recipient: address,
        ctx: &mut TxContext,
    ) {
        let (bucketus_out, sui_reward) = fountain_core::force_unstake(
            clock,
            fountain,
            proof,
        );
        let sui_reward = coin::from_balance(sui_reward, ctx);
        transfer::public_transfer(sui_reward, recipient);
        let bucketus_out = coin::from_balance(bucketus_out, ctx);
        let (buck_coin, usdc_coin) = bucketus::withdraw(
            treasury,
            vault,
            config,
            pool,
            clock,
            bucketus_out,
            ctx,
        );
        let buck_value = coin::value(&buck_coin);
        let (buck_out, usdc_out) = router::swap(
            config,
            pool,
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
        transfer::public_transfer(usdc_out, recipient);
        transfer::public_transfer(buck_out, recipient);
    }

    public entry fun claim(
        fountain: &mut Fountain<BUCKETUS, SUI>,
        clock: &Clock,
        proof: &mut StakeProof<BUCKETUS, SUI>,
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