#![no_std]

use soroban_sdk::{
    contract, contracterror, contractimpl, contracttype, panic_with_error, Address, Env, Map,
    Symbol, Vec,
};

const MIN_RECORDS: u32 = 2;
const MAX_RECORDS: u32 = 25;
const MAX_DECIMALS: u32 = 18;
const DAY_IN_LEDGERS: u32 = 17_280;
const TTL_THRESHOLD: u32 = 89 * DAY_IN_LEDGERS;
const TTL_BUMP: u32 = 90 * DAY_IN_LEDGERS;

#[derive(Clone, Debug, Eq, PartialEq)]
#[contracttype]
pub struct PriceData {
    pub price: i128,
    pub timestamp: u64,
}

#[derive(Clone, Debug, Eq, PartialEq)]
#[contracttype]
pub enum OracleAsset {
    Stellar(Address),
    Other(Symbol),
}

#[derive(Clone)]
#[contracttype]
enum DataKey {
    Admin,
    Assets,
    Base,
    Count(Address),
    Decimals,
    Price(Address, u32),
    Resolution,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
#[contracterror]
#[repr(u32)]
pub enum TestOracleError {
    InvalidConfiguration = 1700,
    UnsupportedAsset = 1701,
    InvalidHistory = 1702,
}

/// Testnet-only authenticated SEP-40 fixture oracle.
///
/// Each observation occupies an independent bounded persistent entry so the
/// V2 pool exercises a stateful price-history layout. The authenticated
/// updater and fixed prices make this unsuitable as a production price source.
#[contract]
pub struct TestSep40Oracle;

#[contractimpl]
impl TestSep40Oracle {
    pub fn __constructor(
        env: Env,
        admin: Address,
        base: OracleAsset,
        assets: Vec<OracleAsset>,
        decimals: u32,
        resolution: u32,
    ) {
        if assets.is_empty()
            || decimals > MAX_DECIMALS
            || resolution == 0
            || assets.contains(base.clone())
        {
            panic_with_error!(&env, TestOracleError::InvalidConfiguration);
        }
        let mut seen = Map::<OracleAsset, bool>::new(&env);
        for asset in assets.iter() {
            if !matches!(asset, OracleAsset::Stellar(_)) || seen.contains_key(asset.clone()) {
                panic_with_error!(&env, TestOracleError::InvalidConfiguration);
            }
            seen.set(asset, true);
        }

        env.storage().instance().set(&DataKey::Admin, &admin);
        env.storage().instance().set(&DataKey::Base, &base);
        env.storage().instance().set(&DataKey::Assets, &assets);
        env.storage().instance().set(&DataKey::Decimals, &decimals);
        env.storage()
            .instance()
            .set(&DataKey::Resolution, &resolution);
        extend_instance_ttl(&env);
    }

    pub fn admin(env: Env) -> Address {
        extend_instance_ttl(&env);
        env.storage().instance().get(&DataKey::Admin).unwrap()
    }

    pub fn base(env: Env) -> OracleAsset {
        extend_instance_ttl(&env);
        env.storage().instance().get(&DataKey::Base).unwrap()
    }

    pub fn assets(env: Env) -> Vec<OracleAsset> {
        extend_instance_ttl(&env);
        env.storage().instance().get(&DataKey::Assets).unwrap()
    }

    pub fn decimals(env: Env) -> u32 {
        extend_instance_ttl(&env);
        env.storage().instance().get(&DataKey::Decimals).unwrap()
    }

    pub fn resolution(env: Env) -> u32 {
        extend_instance_ttl(&env);
        env.storage().instance().get(&DataKey::Resolution).unwrap()
    }

    pub fn set_prices(env: Env, asset: OracleAsset, prices: Vec<PriceData>) {
        extend_instance_ttl(&env);
        let admin: Address = env.storage().instance().get(&DataKey::Admin).unwrap();
        admin.require_auth();
        let address = require_supported_asset(&env, asset);
        validate_history(&env, &prices);

        let count = prices.len();
        let count_key = DataKey::Count(address.clone());
        let previous_count = env.storage().persistent().get(&count_key).unwrap_or(0_u32);
        for (index, datum) in prices.iter().enumerate() {
            let index = u32::try_from(index)
                .unwrap_or_else(|_| panic_with_error!(&env, TestOracleError::InvalidHistory));
            let key = DataKey::Price(address.clone(), index);
            env.storage().persistent().set(&key, &datum);
            env.storage()
                .persistent()
                .extend_ttl(&key, TTL_THRESHOLD, TTL_BUMP);
        }
        for index in count..previous_count {
            env.storage()
                .persistent()
                .remove(&DataKey::Price(address.clone(), index));
        }
        env.storage().persistent().set(&count_key, &count);
        env.storage()
            .persistent()
            .extend_ttl(&count_key, TTL_THRESHOLD, TTL_BUMP);
    }

    pub fn price(env: Env, asset: OracleAsset, timestamp: u64) -> Option<PriceData> {
        extend_instance_ttl(&env);
        let address = supported_asset(&env, asset)?;
        let prices = read_prices(&env, &address)?;
        prices.iter().find(|datum| datum.timestamp == timestamp)
    }

    pub fn lastprice(env: Env, asset: OracleAsset) -> Option<PriceData> {
        extend_instance_ttl(&env);
        let address = supported_asset(&env, asset)?;
        let prices = read_prices(&env, &address)?;
        prices.iter().max_by_key(|datum| datum.timestamp)
    }

    pub fn prices(env: Env, asset: OracleAsset, records: u32) -> Option<Vec<PriceData>> {
        extend_instance_ttl(&env);
        if !(MIN_RECORDS..=MAX_RECORDS).contains(&records) {
            return None;
        }
        let address = supported_asset(&env, asset)?;
        let all = read_prices(&env, &address)?;
        if all.len() < records {
            return None;
        }
        let mut latest = Vec::new(&env);
        for index in (all.len() - records)..all.len() {
            latest.push_back(all.get_unchecked(index));
        }
        Some(latest)
    }
}

fn validate_history(env: &Env, prices: &Vec<PriceData>) {
    let count = prices.len();
    if !(MIN_RECORDS..=MAX_RECORDS).contains(&count) {
        panic_with_error!(env, TestOracleError::InvalidHistory);
    }
    let resolution: u32 = env.storage().instance().get(&DataKey::Resolution).unwrap();
    let resolution = u64::from(resolution);
    let now = env.ledger().timestamp();
    let mut seen = Map::<u64, bool>::new(env);
    let mut minimum = u64::MAX;
    let mut maximum = 0_u64;
    let mut previous = None;
    for datum in prices.iter() {
        if datum.price <= 0
            || datum.timestamp > now
            || datum.timestamp % resolution != 0
            || seen.contains_key(datum.timestamp)
            || previous
                .and_then(|timestamp: u64| timestamp.checked_add(resolution))
                .is_some_and(|timestamp| timestamp != datum.timestamp)
        {
            panic_with_error!(env, TestOracleError::InvalidHistory);
        }
        seen.set(datum.timestamp, true);
        minimum = minimum.min(datum.timestamp);
        maximum = maximum.max(datum.timestamp);
        previous = Some(datum.timestamp);
    }
    let expected_span = resolution
        .checked_mul(u64::from(count - 1))
        .unwrap_or_else(|| panic_with_error!(env, TestOracleError::InvalidHistory));
    if maximum
        .checked_sub(minimum)
        .filter(|span| *span == expected_span)
        .is_none()
    {
        panic_with_error!(env, TestOracleError::InvalidHistory);
    }
}

fn supported_asset(env: &Env, asset: OracleAsset) -> Option<Address> {
    if !env
        .storage()
        .instance()
        .get::<_, Vec<OracleAsset>>(&DataKey::Assets)
        .unwrap()
        .contains(asset.clone())
    {
        return None;
    }
    let OracleAsset::Stellar(address) = asset else {
        return None;
    };
    Some(address)
}

fn require_supported_asset(env: &Env, asset: OracleAsset) -> Address {
    supported_asset(env, asset)
        .unwrap_or_else(|| panic_with_error!(env, TestOracleError::UnsupportedAsset))
}

fn read_prices(env: &Env, address: &Address) -> Option<Vec<PriceData>> {
    let count_key = DataKey::Count(address.clone());
    let count: u32 = env.storage().persistent().get(&count_key)?;
    env.storage()
        .persistent()
        .extend_ttl(&count_key, TTL_THRESHOLD, TTL_BUMP);
    let mut prices = Vec::new(env);
    for index in 0..count {
        let key = DataKey::Price(address.clone(), index);
        let datum: PriceData = env.storage().persistent().get(&key)?;
        env.storage()
            .persistent()
            .extend_ttl(&key, TTL_THRESHOLD, TTL_BUMP);
        prices.push_back(datum);
    }
    Some(prices)
}

fn extend_instance_ttl(env: &Env) {
    env.storage().instance().extend_ttl(TTL_THRESHOLD, TTL_BUMP);
}

#[cfg(test)]
mod tests {
    use super::*;
    use soroban_sdk::{symbol_short, testutils::Address as _, testutils::Ledger, vec};

    struct Fixture {
        env: Env,
        oracle: Address,
        asset: OracleAsset,
    }

    impl Fixture {
        fn create() -> Self {
            let env = Env::default();
            env.mock_all_auths();
            env.ledger().set_timestamp(2_100);
            let admin = Address::generate(&env);
            let address = Address::generate(&env);
            let asset = OracleAsset::Stellar(address);
            let assets = vec![&env, asset.clone()];
            let oracle = env.register(
                TestSep40Oracle,
                (
                    &admin,
                    OracleAsset::Other(symbol_short!("USD")),
                    assets,
                    7_u32,
                    300_u32,
                ),
            );
            Self { env, oracle, asset }
        }

        fn client(&self) -> TestSep40OracleClient<'_> {
            TestSep40OracleClient::new(&self.env, &self.oracle)
        }

        fn history(&self) -> Vec<PriceData> {
            vec![
                &self.env,
                PriceData {
                    price: 8_000_000,
                    timestamp: 1_200,
                },
                PriceData {
                    price: 9_000_000,
                    timestamp: 1_500,
                },
                PriceData {
                    price: 10_000_000,
                    timestamp: 1_800,
                },
                PriceData {
                    price: 11_000_000,
                    timestamp: 2_100,
                },
            ]
        }
    }

    #[test]
    fn prices_returns_the_latest_requested_records() {
        let fixture = Fixture::create();
        let client = fixture.client();
        client.set_prices(&fixture.asset, &fixture.history());

        let latest = client.prices(&fixture.asset, &2).unwrap();
        assert_eq!(latest.len(), 2);
        assert_eq!(latest.get_unchecked(0).price, 10_000_000);
        assert_eq!(latest.get_unchecked(1).price, 11_000_000);
        assert_eq!(client.lastprice(&fixture.asset).unwrap().price, 11_000_000);
        assert!(client.prices(&fixture.asset, &5).is_none());
    }

    #[test]
    fn set_prices_rejects_out_of_order_history() {
        let fixture = Fixture::create();
        let client = fixture.client();
        let history = vec![
            &fixture.env,
            PriceData {
                price: 10_000_000,
                timestamp: 1_500,
            },
            PriceData {
                price: 10_000_000,
                timestamp: 1_200,
            },
        ];

        assert!(client.try_set_prices(&fixture.asset, &history).is_err());
    }
}
