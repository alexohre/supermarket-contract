use snforge_std::{
    ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait, declare, spy_events,
    start_cheat_caller_address, stop_cheat_caller_address,
};
use starknet::{ContractAddress, contract_address_const};
use super_market::events::super_market_event::{ProductCreated, ProductUpdated};
use super_market::interfaces::ISuper_market::{ISuperMarketDispatcher, ISuperMarketDispatcherTrait};


fn setup() -> (ContractAddress, ContractAddress) {
    let owner = contract_address_const::<'owner'>();
    let contract_class = declare("SuperMarket").unwrap().contract_class();
    let (contract_address, _) = contract_class.deploy(@array![owner.into()]).unwrap();
    (contract_address, owner)
}

#[test]
fn test_add_product() {
    let (contract_address, owner) = setup();

    let contract_instance = ISuperMarketDispatcher { contract_address };
    let name: felt252 = 'Apple';
    let price: u32 = 1;
    let stock: u32 = 1;
    let description: ByteArray = "Fresh red apples from local farm";
    let category: felt252 = 'fruit';
    let image: ByteArray = "zgxcnwxvvwqbdvcandvaffcfcffff";

    start_cheat_caller_address(contract_instance.contract_address, owner);
    assert(contract_instance.get_prdct_id() == 0, 'deployment failed');
    contract_instance.add_product(name, price, stock, description, category, image);
    assert(contract_instance.get_prdct_id() == 1, 'add roduct failed');
    stop_cheat_caller_address(contract_instance.contract_address);
}
