use snforge_std::{
    ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait, declare, spy_events,
    start_cheat_caller_address, stop_cheat_caller_address,
};
use starknet::{ContractAddress, contract_address_const};
use super_market::events::super_market_event::{ProductCreated, ProductUpdated};
use super_market::interfaces::ISuper_market::{ISuperMarketDispatcher, ISuperMarketDispatcherTrait};


fn setup() -> ContractAddress {
    let contract_class = declare("SuperMarket").unwrap().contract_class();
    let (contract_address, _) = contract_class.deploy(@array![]).unwrap();
    contract_address
}

#[test]
fn test_add_product() {
    let contract_address = setup();

    let contract_instance = ISuperMarketDispatcher { contract_address };

    let name: ByteArray = "Darren";
    let address: ContractAddress = 'Darren'.try_into().unwrap();
}
