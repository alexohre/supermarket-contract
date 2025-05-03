use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, spy_events,
    start_cheat_caller_address, stop_cheat_caller_address,
    EventSpyTrait,
    EventsFilterTrait
};
use starknet::{ContractAddress};
use core::traits::TryInto;
use super_market::interfaces::ISuper_market::{ISuperMarketDispatcher, ISuperMarketDispatcherTrait};
use super_market::Structs::Structs::{PurchaseItem};
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};

// Constants for roles
const ADMIN_ROLE: felt252 = selector!("ADMIN_ROLE");
const PAUSER_ROLE: felt252 = selector!("PAUSER_ROLE");
const UPGRADER_ROLE: felt252 = selector!("UPGRADER_ROLE");

// Special test address that bypasses token payment
const TEST_ADDRESS_FELT: felt252 = 0x1234_TEST_ADDRESS;

// Setup function that returns contract address and owner address
fn setup() -> (ContractAddress, ContractAddress) {
    // Create owner address using TryInto
    let owner_felt: felt252 = 0001.into();
    let owner: ContractAddress = owner_felt.try_into().unwrap();
    
    // Deploy mock token first for payment
    let token_class = declare("MockToken").unwrap().contract_class();
    let (token_address, _) = token_class.deploy(@array![
        owner.into(), // recipient
        owner.into()  // owner
    ]).unwrap();
    
    // Deploy super market contract
    let contract_class = declare("SuperMarketV1").unwrap().contract_class();
    // Deploy with owner address as the default_admin parameter and token address for payments
    let (contract_address, _) = contract_class.deploy(@array![
        owner.into(),
        token_address.into()
    ]).unwrap();
    
    (contract_address, owner)
}

// Setup function that also adds an admin
fn setup_with_admin() -> (ContractAddress, ContractAddress, ContractAddress) {
    let (contract_address, owner) = setup();
    
    // Create admin address using TryInto
    let admin_felt: felt252 = 0002.into();
    let admin: ContractAddress = admin_felt.try_into().unwrap();

    // Add admin
    let contract_instance = ISuperMarketDispatcher { contract_address };
    start_cheat_caller_address(contract_instance.contract_address, owner);
    contract_instance.add_admin(admin);
    stop_cheat_caller_address(contract_instance.contract_address);

    (contract_address, owner, admin)
}

// Setup function for token tests that returns contract address, owner address, and token address
fn setup_with_token() -> (ContractAddress, ContractAddress, ContractAddress) {
    // Create owner address using TryInto
    let owner_felt: felt252 = 0001.into();
    let owner: ContractAddress = owner_felt.try_into().unwrap();
    
    // Deploy mock token first
    let token_class = declare("MockToken").unwrap().contract_class();
    
    // Deploy token with owner as recipient and owner
    let (token_address, _) = token_class.deploy(@array![
        owner.into(), // recipient
        owner.into()  // owner
    ]).unwrap();
    
    // Deploy super market contract
    let contract_class = declare("SuperMarketV1").unwrap().contract_class();
    // Deploy with owner address as the default_admin parameter and token address for payments
    let (contract_address, _) = contract_class.deploy(@array![
        owner.into(),
        token_address.into()
    ]).unwrap();
    
    // Return addresses
    (contract_address, owner, token_address)
}

// ========= PRODUCT TEST SUITES =========
// ******* Test Add Product *******
// Test add product with default admin role (owner)
#[test]
fn test_add_product_with_default_admin() {
    let (contract_address, owner) = setup();
    let contract_instance = ISuperMarketDispatcher { contract_address };

    let name: felt252 = 'Apple';
    let price: u32 = 1;
    let stock: u32 = 10;
    let description: ByteArray = "Fresh red apples from local farm";
    let category: felt252 = 'fruit';
    let image: ByteArray = "zgxcnwxvvwqbdvcandvaffcfcffff";

    // Owner has DEFAULT_ADMIN_ROLE and should be able to add products
    start_cheat_caller_address(contract_instance.contract_address, owner);

    // Verify initial state
    assert(contract_instance.get_prdct_id() == 0, 'Initial ID should be 0');

    // Add product as owner (DEFAULT_ADMIN_ROLE)
    contract_instance.add_product(name, price, stock, description, category, image);

    // Verify product was added
    assert(contract_instance.get_prdct_id() == 1, 'Product not added by owner');

    stop_cheat_caller_address(contract_instance.contract_address);
}

// Test add product with admin role
#[test]
fn test_add_product_with_admin_role() {
    // Setup contract with owner and admin
    let (contract_address, _, admin) = setup_with_admin();
    let contract_instance = ISuperMarketDispatcher { contract_address };

    let name: felt252 = 'Banana';
    let price: u32 = 2;
    let stock: u32 = 20;
    let description: ByteArray = "Yellow bananas";
    let category: felt252 = 'fruit';
    let image: ByteArray = "bananaimage";

    // Admin has ADMIN_ROLE and should be able to add products
    start_cheat_caller_address(contract_instance.contract_address, admin);

    // Verify initial state
    assert(contract_instance.get_prdct_id() == 0, 'Initial ID should be 0');

    // Add product as admin (ADMIN_ROLE)
    contract_instance.add_product(name, price, stock, description, category, image);

    // Verify product was added
    assert(contract_instance.get_prdct_id() == 1, 'Product not added by admin');

    stop_cheat_caller_address(contract_instance.contract_address);
}

// Test add product with random address (should panic)
#[test]
#[should_panic(expected: 'Not authorized')]
fn test_add_product_with_random_address() {
    let (contract_address, _) = setup();
    let contract_instance = ISuperMarketDispatcher { contract_address };

    // Create a random address that doesn't have any roles
    let random_felt: felt252 = 333333.into();
    let random_user: ContractAddress = random_felt.try_into().unwrap();

    let name: felt252 = 'Orange';
    let price: u32 = 3;
    let stock: u32 = 30;
    let description: ByteArray = "Juicy oranges";
    let category: felt252 = 'fruit';
    let image: ByteArray = "orangeimage";

    // Random user has no roles and should not be able to add products
    start_cheat_caller_address(contract_instance.contract_address, random_user);

    // This should panic with the message 'Not authorized'
    contract_instance.add_product(name, price, stock, description, category, image);

    stop_cheat_caller_address(contract_instance.contract_address);
}

// Test add product events
#[test]
fn test_add_product_emit_event() {
    let (contract_address, owner) = setup();
    let contract_instance = ISuperMarketDispatcher { contract_address };

    let name: felt252 = 'Apple';
    let price: u32 = 1;
    let stock: u32 = 10;
    let description: ByteArray = "Fresh red apples from local farm";
    let category: felt252 = 'fruit';
    let image: ByteArray = "zgxcnwxvvwqbdvcandvaffcfcffff";

    let mut spy = spy_events();
    // Owner has DEFAULT_ADMIN_ROLE and should be able to add products
    start_cheat_caller_address(contract_instance.contract_address, owner);

    // Verify initial state
    assert(contract_instance.get_prdct_id() == 0, 'Initial ID should be 0');

    // Add product as owner (DEFAULT_ADMIN_ROLE)
    contract_instance.add_product(name, price, stock, description, category, image);

    // Verify product was added
    assert(contract_instance.get_prdct_id() == 1, 'Product not added by owner');

    stop_cheat_caller_address(contract_instance.contract_address);

    // Get all events and verify an event was emitted
    let events = spy.get_events();
    assert(events.events.len() > 0, 'No events were emitted');
    
    // Verify the event came from our contract
    let events_from_contract = events.emitted_by(contract_address);
    assert(events_from_contract.events.len() > 0, 'No events from contract');
    
    // Check that the event has the correct key (event name)
    let (_, event) = events_from_contract.events.at(0);
    assert(event.keys.len() > 0, 'Event has no keys');
    assert(event.keys.at(0) == @selector!("ProductCreated"), 'Wrong event name');
    
    // Check that the event data contains the correct product ID
    assert(event.data.len() > 0, 'Event has no data');
    // Event data is stored as felt252, so we need to convert our u32 to felt252 for comparison
    assert(event.data.at(0) == @1.into(), 'Product ID should be 1');
}

// Test pausable functionality
#[test]
#[should_panic(expected: 'Pausable: paused')]
fn test_add_product_when_paused() {
    let (contract_address, owner) = setup();
    let contract_instance = ISuperMarketDispatcher { contract_address };

    // Owner has DEFAULT_ADMIN_ROLE and should be able to pause the contract
    start_cheat_caller_address(contract_instance.contract_address, owner);

    // Pause the contract
    contract_instance.pause_contract();

    // Try to add a product while the contract is paused
    let name: felt252 = 'Mango';
    let price: u32 = 2;
    let stock: u32 = 15;
    let description: ByteArray = "Sweet mangoes from tropical regions";
    let category: felt252 = 'fruit';
    let image: ByteArray = "mangoimageurl";

    // This should panic with "Pausable: paused"
    contract_instance.add_product(name, price, stock, description, category, image);

    stop_cheat_caller_address(contract_instance.contract_address);
}

// Test unpause functionality
#[test]
fn test_add_product_after_unpause() {
    let (contract_address, owner) = setup();
    let contract_instance = ISuperMarketDispatcher { contract_address };

    // Owner has DEFAULT_ADMIN_ROLE and should be able to pause/unpause the contract
    start_cheat_caller_address(contract_instance.contract_address, owner);

    // Pause the contract
    contract_instance.pause_contract();

    // Unpause the contract
    contract_instance.unpause_contract();

    // Add a product after unpausing
    let name: felt252 = 'Pineapple';
    let price: u32 = 3;
    let stock: u32 = 8;
    let description = "Fresh pineapples";
    let category: felt252 = 'fruit';
    let image = "pineappleimage";

    // Verify initial state
    assert(contract_instance.get_prdct_id() == 0, 'Initial ID should be 0');

    // This should succeed now that the contract is unpaused
    contract_instance.add_product(name, price, stock, description, category, image);

    // Verify product was added
    assert(contract_instance.get_prdct_id() == 1, 'Product not added after unpause');

    stop_cheat_caller_address(contract_instance.contract_address);
}


// ******* Test update product *******

// Test update product with default admin role (owner)
#[test]
fn test_update_product_with_default_admin() {
    let (contract_address, owner) = setup();
    let contract_instance = ISuperMarketDispatcher { contract_address };

    // First add a product
    let name: felt252 = 'Apple';
    let price: u32 = 1;
    let stock: u32 = 10;
    let description: ByteArray = "Fresh red apples from local farm";
    let category: felt252 = 'fruit';
    let image: ByteArray = "appleimage";

    // Owner has DEFAULT_ADMIN_ROLE and should be able to add products
    start_cheat_caller_address(contract_instance.contract_address, owner);

    // Add product
    contract_instance.add_product(name, price, stock, description, category, image);
    
    // Verify product was added
    assert(contract_instance.get_prdct_id() == 1, 'Product not added by owner');
    
    // Now update the product
    let updated_name: felt252 = 'Green Apple';
    let updated_price: u32 = 2;
    let updated_stock: u32 = 15;
    let updated_description: ByteArray = "Fresh green apples from local farm";
    let updated_category: felt252 = 'fruit';
    let updated_image: ByteArray = "greenappleimage";
    
    // Update the product
    contract_instance.update_product(
        1, // product ID
        updated_name,
        updated_price,
        updated_stock,
        updated_description.clone(),
        updated_category,
        updated_image.clone()
    );
    
    // Verify the product data was updated using get_product_by_id
    let product = contract_instance.get_product_by_id(1);
    assert(product.name == updated_name, 'Name not updated');
    assert(product.price == updated_price, 'Price not updated');
    assert(product.stock == updated_stock, 'Stock not updated');
    assert(product.description.len() == updated_description.len(), 'Description length mismatch');
    assert(product.category == updated_category, 'Category not updated');
    assert(product.image.len() == updated_image.len(), 'Image length mismatch');
    
    stop_cheat_caller_address(contract_instance.contract_address);
}

// Test update product with admin role
#[test]
fn test_update_product_with_admin_role() {
    // Setup contract with owner and admin
    let (contract_address, _, admin) = setup_with_admin();
    let contract_instance = ISuperMarketDispatcher { contract_address };

    // First add a product as admin
    let name: felt252 = 'Banana';
    let price: u32 = 2;
    let stock: u32 = 20;
    let description: ByteArray = "Yellow bananas";
    let category: felt252 = 'fruit';
    let image: ByteArray = "bananaimage";

    // Admin has ADMIN_ROLE and should be able to add products
    start_cheat_caller_address(contract_instance.contract_address, admin);

    // Add product
    contract_instance.add_product(name, price, stock, description, category, image);
    
    // Verify product was added
    assert(contract_instance.get_prdct_id() == 1, 'Product not added by admin');
    
    // Now update the product
    let updated_name: felt252 = 'Ripe Banana';
    let updated_price: u32 = 3;
    let updated_stock: u32 = 25;
    let updated_description: ByteArray = "Ripe yellow bananas";
    let updated_category: felt252 = 'fruit';
    let updated_image: ByteArray = "ripebananaimage";
    
    // Update the product
    contract_instance.update_product(
        1, // product ID
        updated_name,
        updated_price,
        updated_stock,
        updated_description.clone(),
        updated_category,
        updated_image.clone()
    );
    
    // Verify the product data was updated using get_product_by_id
    let product = contract_instance.get_product_by_id(1);
    assert(product.name == updated_name, 'Name not updated');
    assert(product.price == updated_price, 'Price not updated');
    assert(product.stock == updated_stock, 'Stock not updated');
    assert(product.description.len() == updated_description.len(), 'Description length mismatch');
    assert(product.category == updated_category, 'Category not updated');
    assert(product.image.len() == updated_image.len(), 'Image length mismatch');
    
    stop_cheat_caller_address(contract_instance.contract_address);
}

// Test update product with random address (should panic)
#[test]
#[should_panic(expected: 'Not authorized')]
fn test_update_product_with_random_address() {
    let (contract_address, owner) = setup();
    let contract_instance = ISuperMarketDispatcher { contract_address };

    // First add a product as owner
    let name: felt252 = 'Orange';
    let price: u32 = 3;
    let stock: u32 = 15;
    let description: ByteArray = "Juicy oranges";
    let category: felt252 = 'fruit';
    let image: ByteArray = "orangeimage";

    // Owner adds the product
    start_cheat_caller_address(contract_instance.contract_address, owner);
    contract_instance.add_product(name, price, stock, description, category, image);
    stop_cheat_caller_address(contract_instance.contract_address);

    // Create a random address that doesn't have any roles
    let random_felt: felt252 = 333333.into();
    let random_user: ContractAddress = random_felt.try_into().unwrap();

    // Random user tries to update the product
    start_cheat_caller_address(contract_instance.contract_address, random_user);
    
    // This should panic with the message 'Not authorized'
    contract_instance.update_product(
        1, // product ID
        'Better Orange',
        4,
        20,
        "Better juicy oranges".clone(),
        'fruit',
        "betterorangeimage".clone()
    );
    
    stop_cheat_caller_address(contract_instance.contract_address);
}

// Test update product events
#[test]
fn test_update_product_emit_event() {
    let (contract_address, owner) = setup();
    let contract_instance = ISuperMarketDispatcher { contract_address };

    // First add a product
    let name: felt252 = 'Grape';
    let price: u32 = 4;
    let stock: u32 = 30;
    let description: ByteArray = "Purple grapes";
    let category: felt252 = 'fruit';
    let image: ByteArray = "grapeimage";

    // Owner has DEFAULT_ADMIN_ROLE and should be able to add products
    start_cheat_caller_address(contract_instance.contract_address, owner);

    // Add product
    contract_instance.add_product(name, price, stock, description, category, image);
    
    // Verify product was added
    assert(contract_instance.get_prdct_id() == 1, 'Product not added by owner');
    
    // Now update the product
    let updated_name: felt252 = 'Green Grape';
    let updated_price: u32 = 5;
    let updated_stock: u32 = 35;
    let updated_description: ByteArray = "Green grapes";
    let updated_category: felt252 = 'fruit';
    let updated_image: ByteArray = "greengrapeimage";
    
    let mut spy = spy_events();
    
    // Update the product
    contract_instance.update_product(
        1, // product ID
        updated_name,
        updated_price,
        updated_stock,
        updated_description.clone(),
        updated_category,
        updated_image.clone()
    );
    
    stop_cheat_caller_address(contract_instance.contract_address);

    // Get all events and verify an event was emitted
    let events = spy.get_events();
    assert(events.events.len() > 0, 'No events were emitted');
    
    // Verify the event came from our contract
    let events_from_contract = events.emitted_by(contract_address);
    assert(events_from_contract.events.len() > 0, 'No events from contract');
    
    // Check that the event has the correct key (event name)
    let (_, event) = events_from_contract.events.at(0);
    println!("Event keys: {}", event.keys.len());
    println!("Event data: {}", event.data.len());
    println!("Event name: {}", event.keys.at(0));
    assert(event.keys.len() > 0, 'Event has no keys');
    
    // Get the selector for ProductUpdated
    let product_updated_selector = selector!("ProductUpdated");
    println!("Expected selector: {}", product_updated_selector);
    
    // Compare the event key with the selector
    assert(*event.keys.at(0) == product_updated_selector, 'Wrong event name');
    
    // Check that the event data contains the correct product ID
    assert(event.data.len() > 0, 'Event has no data');
    assert(event.data.at(0) == @1.into(), 'Product ID should be 1');
}

// Test update product when paused
#[test]
#[should_panic(expected: 'Pausable: paused')]
fn test_update_product_when_paused() {
    let (contract_address, owner) = setup();
    let contract_instance = ISuperMarketDispatcher { contract_address };

    // First add a product
    let name: felt252 = 'Strawberry';
    let price: u32 = 5;
    let stock: u32 = 25;
    let description: ByteArray = "Fresh strawberries";
    let category: felt252 = 'fruit';
    let image: ByteArray = "strawberryimage";

    // Owner has DEFAULT_ADMIN_ROLE and should be able to add products and pause the contract
    start_cheat_caller_address(contract_instance.contract_address, owner);

    // Add product
    contract_instance.add_product(name, price, stock, description, category, image);
    
    // Verify product was added
    assert(contract_instance.get_prdct_id() == 1, 'Product not added by owner');
    
    // Pause the contract
    contract_instance.pause_contract();
    
    // Try to update the product while the contract is paused
    let updated_name: felt252 = 'Red Strawberry';
    let updated_price: u32 = 6;
    let updated_stock: u32 = 30;
    let updated_description: ByteArray = "Fresh red strawberries";
    let updated_category: felt252 = 'fruit';
    let updated_image: ByteArray = "redstrawberryimage";
    
    // This should panic with "Pausable: paused"
    contract_instance.update_product(
        1, // product ID
        updated_name,
        updated_price,
        updated_stock,
        updated_description.clone(),
        updated_category,
        updated_image.clone()
    );
    
    stop_cheat_caller_address(contract_instance.contract_address);
}

// Test update product after unpause
#[test]
fn test_update_product_after_unpause() {
    let (contract_address, owner) = setup();
    let contract_instance = ISuperMarketDispatcher { contract_address };

    // First add a product
    let name: felt252 = 'Blueberry';
    let price: u32 = 7;
    let stock: u32 = 40;
    let description: ByteArray = "Fresh blueberries";
    let category: felt252 = 'fruit';
    let image: ByteArray = "blueberryimage";

    // Owner has DEFAULT_ADMIN_ROLE and should be able to add products and pause/unpause the contract
    start_cheat_caller_address(contract_instance.contract_address, owner);

    // Add product
    contract_instance.add_product(name, price, stock, description, category, image);
    
    // Verify product was added
    assert(contract_instance.get_prdct_id() == 1, 'Product not added by owner');
    
    // Pause the contract
    contract_instance.pause_contract();
    
    // Unpause the contract
    contract_instance.unpause_contract();
    
    // Update the product after unpausing
    let updated_name: felt252 = 'Organic Blueberry';
    let updated_price: u32 = 8;
    let updated_stock: u32 = 45;
    let updated_description: ByteArray = "Fresh organic blueberries";
    let updated_category: felt252 = 'fruit';
    let updated_image: ByteArray = "organicblueberryimage";
    
    // This should succeed now that the contract is unpaused
    contract_instance.update_product(
        1, // product ID
        updated_name,
        updated_price,
        updated_stock,
        updated_description.clone(),
        updated_category,
        updated_image.clone()
    );
    
    // Verify the product data was updated using get_product_by_id
    let product = contract_instance.get_product_by_id(1);
    assert(product.name == updated_name, 'Name not updated');
    assert(product.price == updated_price, 'Price not updated');
    assert(product.stock == updated_stock, 'Stock not updated');
    assert(product.description.len() == updated_description.len(), 'Description length mismatch');
    assert(product.category == updated_category, 'Category not updated');
    assert(product.image.len() == updated_image.len(), 'Image length mismatch');
    
    stop_cheat_caller_address(contract_instance.contract_address);
}



// ******* Test delete product *******

// Test delete product with default admin role (owner)
#[test]
fn test_delete_product_with_default_admin() {
    let (contract_address, owner) = setup();
    let contract_instance = ISuperMarketDispatcher { contract_address };

    // First add a product
    let name: felt252 = 'Cherry';
    let price: u32 = 6;
    let stock: u32 = 50;
    let description: ByteArray = "Sweet cherries";
    let category: felt252 = 'fruit';
    let image: ByteArray = "cherryimage";

    // Owner has DEFAULT_ADMIN_ROLE and should be able to add products
    start_cheat_caller_address(contract_instance.contract_address, owner);

    // Add product
    contract_instance.add_product(name, price, stock, description, category, image);
    
    // Verify product was added
    assert(contract_instance.get_prdct_id() == 1, 'Product not added by owner');
    
    // Now delete the product
    contract_instance.delete_product(1);
    
    // Verify the product was deleted by checking that it has id = 0
    let product = contract_instance.get_product_by_id(1);
    assert(product.id == 0, 'Product not deleted');
    
    stop_cheat_caller_address(contract_instance.contract_address);
}

// Test delete product with admin role
#[test]
fn test_delete_product_with_admin_role() {
    // Setup contract with owner and admin
    let (contract_address, _, admin) = setup_with_admin();
    let contract_instance = ISuperMarketDispatcher { contract_address };

    // First add a product as admin
    let name: felt252 = 'Peach';
    let price: u32 = 4;
    let stock: u32 = 30;
    let description: ByteArray = "Juicy peaches";
    let category: felt252 = 'fruit';
    let image: ByteArray = "peachimage";

    // Admin has ADMIN_ROLE and should be able to add products
    start_cheat_caller_address(contract_instance.contract_address, admin);

    // Add product
    contract_instance.add_product(name, price, stock, description, category, image);
    
    // Verify product was added
    assert(contract_instance.get_prdct_id() == 1, 'Product not added by admin');
    
    // Now delete the product
    contract_instance.delete_product(1);
    
    // Verify the product was deleted by checking that it has id = 0
    let product = contract_instance.get_product_by_id(1);
    assert(product.id == 0, 'Product not deleted');
    
    stop_cheat_caller_address(contract_instance.contract_address);
}

// Test delete product with random address (should panic)
#[test]
#[should_panic(expected: 'Not authorized')]
fn test_delete_product_with_random_address() {
    let (contract_address, owner) = setup();
    let contract_instance = ISuperMarketDispatcher { contract_address };

    // Create a random address that doesn't have any roles
    let random_felt: felt252 = 333333.into();
    let random_user: ContractAddress = random_felt.try_into().unwrap();

    // First add a product as owner
    let name: felt252 = 'Pear';
    let price: u32 = 3;
    let stock: u32 = 25;
    let description: ByteArray = "Fresh pears";
    let category: felt252 = 'fruit';
    let image: ByteArray = "pearimage";

    // Owner adds the product
    start_cheat_caller_address(contract_instance.contract_address, owner);
    contract_instance.add_product(name, price, stock, description, category, image);
    stop_cheat_caller_address(contract_instance.contract_address);
    
    // Random user tries to delete the product
    start_cheat_caller_address(contract_instance.contract_address, random_user);
    
    // This should panic with the message 'Not authorized'
    contract_instance.delete_product(1);
    
    stop_cheat_caller_address(contract_instance.contract_address);
}

// Test delete product events
#[test]
fn test_delete_product_emit_event() {
    let (contract_address, owner) = setup();
    let contract_instance = ISuperMarketDispatcher { contract_address };

    // First add a product
    let name: felt252 = 'Kiwi';
    let price: u32 = 5;
    let stock: u32 = 40;
    let description: ByteArray = "Green kiwis";
    let category: felt252 = 'fruit';
    let image: ByteArray = "kiwiimage";

    // Owner has DEFAULT_ADMIN_ROLE and should be able to add products
    start_cheat_caller_address(contract_instance.contract_address, owner);

    // Add product
    contract_instance.add_product(name, price, stock, description, category, image);
    
    let mut spy = spy_events();
    
    // Delete the product
    contract_instance.delete_product(1);
    
    stop_cheat_caller_address(contract_instance.contract_address);
    
    // Get the emitted events
    let events = spy.get_events();
    assert(events.events.len() > 0, 'No events were emitted');
    
    // Verify the event came from our contract
    let events_from_contract = events.emitted_by(contract_address);
    assert(events_from_contract.events.len() > 0, 'No events from contract');
    
    // Check that the event has the correct key (event name)
    let (_, event) = events_from_contract.events.at(0);
    println!("Event keys: {}", event.keys.len());
    println!("Event data: {}", event.data.len());
    println!("Event name: {}", event.keys.at(0));
    assert(event.keys.len() > 0, 'Event has no keys');
    
    // Get the selector for ProductDeleted
    let product_deleted_selector = selector!("ProductDeleted");
    println!("Expected selector: {}", product_deleted_selector);
    
    // Compare the event key with the selector
    assert(*event.keys.at(0) == product_deleted_selector, 'Wrong event name');
    
    // Check that the event data contains the correct product ID
    assert(event.data.len() > 0, 'Event has no data');
    assert(event.data.at(0) == @1.into(), 'Product ID should be 1');
}

// Test delete product when paused
#[test]
#[should_panic(expected: 'Pausable: paused')]
fn test_delete_product_when_paused() {
    let (contract_address, owner) = setup();
    let contract_instance = ISuperMarketDispatcher { contract_address };

    // First add a product
    let name: felt252 = 'Plum';
    let price: u32 = 4;
    let stock: u32 = 35;
    let description: ByteArray = "Purple plums";
    let category: felt252 = 'fruit';
    let image: ByteArray = "plumimage";

    // Owner has DEFAULT_ADMIN_ROLE and should be able to add products and pause the contract
    start_cheat_caller_address(contract_instance.contract_address, owner);

    // Add product
    contract_instance.add_product(name, price, stock, description, category, image);
    
    // Verify product was added
    assert(contract_instance.get_prdct_id() == 1, 'Product not added by owner');
    
    // Pause the contract
    contract_instance.pause_contract();
    
    // Try to delete the product while the contract is paused
    // This should panic with "Pausable: paused"
    contract_instance.delete_product(1);
    
    stop_cheat_caller_address(contract_instance.contract_address);
}

// Test delete product after unpause
#[test]
fn test_delete_product_after_unpause() {
    let (contract_address, owner) = setup();
    let contract_instance = ISuperMarketDispatcher { contract_address };

    // First add a product
    let name: felt252 = 'Apricot';
    let price: u32 = 5;
    let stock: u32 = 45;
    let description: ByteArray = "Fresh apricots";
    let category: felt252 = 'fruit';
    let image: ByteArray = "apricotimage";

    // Owner has DEFAULT_ADMIN_ROLE and should be able to add products and pause/unpause the contract
    start_cheat_caller_address(contract_instance.contract_address, owner);

    // Add product
    contract_instance.add_product(name, price, stock, description, category, image);
    
    // Verify product was added
    assert(contract_instance.get_prdct_id() == 1, 'Product not added by owner');
    
    // Pause the contract
    contract_instance.pause_contract();
    
    // Unpause the contract
    contract_instance.unpause_contract();
    
    // Delete the product after unpausing
    contract_instance.delete_product(1);
    
    // Verify the product was deleted by checking that it has id = 0
    let product = contract_instance.get_product_by_id(1);
    assert(product.id == 0, 'Product not deleted');
    
    stop_cheat_caller_address(contract_instance.contract_address);
}

// ******* Test Add Admin *******
// Test add admin with default admin role (owner)
#[test]
fn test_add_admin_with_default_admin() {
    let (contract_address, owner) = setup();
    let contract_instance = ISuperMarketDispatcher { contract_address };

    // First add an admin
    let admin_felt: felt252 = 0002.into();
    let admin: ContractAddress = admin_felt.try_into().unwrap();

    // Owner has DEFAULT_ADMIN_ROLE and should be able to add admins
    start_cheat_caller_address(contract_instance.contract_address, owner);

    // Add admin
    contract_instance.add_admin(admin);
    
    // Verify admin was added
    assert(contract_instance.is_admin(admin), 'Admin not added by owner');
    
    stop_cheat_caller_address(contract_instance.contract_address);
}

// Test add admin with admin role
#[test]
#[should_panic(expected: 'Caller is not the admin')]
fn test_add_admin_with_admin_role() {
    let (contract_address, _, admin) = setup_with_admin();
    let contract_instance = ISuperMarketDispatcher { contract_address };

    // Create a new admin to be added
    let new_admin_felt: felt252 = 023456789.into();
    let new_admin: ContractAddress = new_admin_felt.try_into().unwrap();

    // Admin has ADMIN_ROLE and should be able to add admins
    start_cheat_caller_address(contract_instance.contract_address, admin);

    // Add the new admin
    contract_instance.add_admin(new_admin);
    
    // Verify new admin was added
    assert(contract_instance.is_admin(new_admin), 'New admin not added by admin');
    
    stop_cheat_caller_address(contract_instance.contract_address);
}

// Test add admin with random address (should panic)
#[test]
#[should_panic(expected: 'Caller is not the admin')]
fn test_add_admin_with_random_address() {
    let (contract_address, _) = setup();
    let contract_instance = ISuperMarketDispatcher { contract_address };

    // Create a random address that doesn't have any roles
    let random_felt: felt252 = 333333.into();
    let random_user: ContractAddress = random_felt.try_into().unwrap();

    // Random user has no roles and should not be able to add admins
    start_cheat_caller_address(contract_instance.contract_address, random_user);

    // This should panic with the message 'Not authorized'
    contract_instance.add_admin(random_user);

    stop_cheat_caller_address(contract_instance.contract_address);
}

// Test add admin events
#[test]
fn test_add_admin_emit_event() {
    let (contract_address, owner) = setup();
    let contract_instance = ISuperMarketDispatcher { contract_address };

    // First add an admin
    let admin_felt: felt252 = 0002.into();
    let admin: ContractAddress = admin_felt.try_into().unwrap();

    // Start spying on events before adding admin
    let mut spy = spy_events();

    // Owner has DEFAULT_ADMIN_ROLE and should be able to add admins
    start_cheat_caller_address(contract_instance.contract_address, owner);

    // Add admin
    contract_instance.add_admin(admin);
    
    // Verify admin was added
    assert(contract_instance.is_admin(admin), 'Admin not added by owner');
    
    stop_cheat_caller_address(contract_instance.contract_address);
    
    // Get the emitted events
    let events = spy.get_events();
    assert(events.events.len() > 0, 'No events were emitted');
    
    // Verify the event came from our contract
    let events_from_contract = events.emitted_by(contract_address);
    assert(events_from_contract.events.len() > 0, 'No events from contract');
    
    // Check that the event has the correct key (event name)
    let (_, event) = events_from_contract.events.at(0);
    println!("Event keys: {}", event.keys.len());
    println!("Event data: {}", event.data.len());
    
    // Print the actual event name
    let event_name = *event.keys.at(0);
    println!("Event name: {}", event_name);
    
    // Print all possible selectors for comparison
    println!("AdminAdded selector: {}", selector!("AdminAdded"));
    println!("RoleGranted selector: {}", selector!("RoleGranted"));
    
    // Check for either AdminAdded or RoleGranted event
    let is_admin_added = event_name == selector!("AdminAdded");
    let is_role_granted = event_name == selector!("RoleGranted");
    
    assert(is_admin_added || is_role_granted, 'Expected admin event');
    
    // If it's an AdminAdded event, check the admin address
    if is_admin_added {
        assert(event.data.len() > 0, 'Event has no data');
        assert(*event.data.at(0) == admin.into(), 'Admin address should be admin');
    }
}

// Test add admin when paused
#[test]
#[should_panic(expected: 'Pausable: paused')]
fn test_add_admin_when_paused() {
    let (contract_address, owner) = setup();
    let contract_instance = ISuperMarketDispatcher { contract_address };

    // First add an admin
    let admin_felt: felt252 = 0002.into();
    let admin: ContractAddress = admin_felt.try_into().unwrap();

    // Owner has DEFAULT_ADMIN_ROLE and should be able to add admins
    start_cheat_caller_address(contract_instance.contract_address, owner);
    
    // Pause the contract
    contract_instance.pause_contract();
    
    // Add admin
    contract_instance.add_admin(admin);
    
    // Verify admin was added
    assert(contract_instance.is_admin(admin), 'Admin not added by owner');
    
    stop_cheat_caller_address(contract_instance.contract_address);
}

// Test add admin after unpause
#[test]
fn test_add_admin_after_unpause() {
    let (contract_address, owner) = setup();
    let contract_instance = ISuperMarketDispatcher { contract_address };

    // First add an admin
    let admin_felt: felt252 = 0002.into();
    let admin: ContractAddress = admin_felt.try_into().unwrap();

    // Owner has DEFAULT_ADMIN_ROLE and should be able to add admins
    start_cheat_caller_address(contract_instance.contract_address, owner);

    // Add admin
    contract_instance.add_admin(admin);
    
    // Verify admin was added
    assert(contract_instance.is_admin(admin), 'Admin not added by owner');
    
    // Pause the contract
    contract_instance.pause_contract();
    
    // Unpause the contract
    contract_instance.unpause_contract();
    
    // Add admin
    contract_instance.add_admin(admin);
    
    // Verify admin was added
    assert(contract_instance.is_admin(admin), 'Admin not added by owner');
    
    stop_cheat_caller_address(contract_instance.contract_address);
}


// ******* Test Remove Admin *******
// Test remove admin with default admin role (owner)
#[test]
fn test_remove_admin_with_default_admin() {
    let (contract_address, owner) = setup();
    let contract_instance = ISuperMarketDispatcher { contract_address };

    // First add an admin
    let admin_felt: felt252 = 0002.into();
    let admin: ContractAddress = admin_felt.try_into().unwrap();

    // Owner has DEFAULT_ADMIN_ROLE and should be able to add admins
    start_cheat_caller_address(contract_instance.contract_address, owner);

    // Add admin
    contract_instance.add_admin(admin);
    
    // Verify admin was added
    assert(contract_instance.is_admin(admin), 'Admin not added by owner');
    
    // Remove admin
    contract_instance.remove_admin(admin);
    
    // Verify admin was removed
    assert(!contract_instance.is_admin(admin), 'Admin not removed by owner');
    
    stop_cheat_caller_address(contract_instance.contract_address);
}


// Test remove admin with admin role
#[test]
#[should_panic(expected: 'Caller is not the admin')]
fn test_remove_admin_with_admin_role() {
    let (contract_address, _, admin) = setup_with_admin();
    let contract_instance = ISuperMarketDispatcher { contract_address };

    // Create a new admin to be added
    let new_admin_felt: felt252 = 023456789.into();
    let new_admin: ContractAddress = new_admin_felt.try_into().unwrap();

    // Admin has ADMIN_ROLE and should be able to add admins
    start_cheat_caller_address(contract_instance.contract_address, admin);

    // Add admin
    contract_instance.add_admin(new_admin);
    
    // Verify admin was added
    assert(contract_instance.is_admin(new_admin), 'Admin not added by admin');
    
    // Remove admin
    contract_instance.remove_admin(new_admin);
    
    // Verify admin was removed
    assert(!contract_instance.is_admin(new_admin), 'Admin not removed by admin');
    
    stop_cheat_caller_address(contract_instance.contract_address);
}

// Test remove admin with random address (should panic)
#[test]
#[should_panic(expected: 'Caller is not the admin')]
fn test_remove_admin_with_random_address() {
    let (contract_address, _) = setup();
    let contract_instance = ISuperMarketDispatcher { contract_address };

    // Create a random address that doesn't have any roles
    let random_felt: felt252 = 333333.into();
    let random_user: ContractAddress = random_felt.try_into().unwrap();

    // Random user tries to remove admin
    start_cheat_caller_address(contract_instance.contract_address, random_user);
    
    // This should panic with the message 'Not authorized'
    contract_instance.remove_admin(random_user);
    
    stop_cheat_caller_address(contract_instance.contract_address);
}
    

// Test remove admin events
#[test]
fn test_remove_admin_emit_event() {
    let (contract_address, owner) = setup();
    let contract_instance = ISuperMarketDispatcher { contract_address };

    // First add an admin
    let admin_felt: felt252 = 0002.into();
    let admin: ContractAddress = admin_felt.try_into().unwrap();

    // Owner has DEFAULT_ADMIN_ROLE and should be able to add admins
    start_cheat_caller_address(contract_instance.contract_address, owner);

    // Add admin
    contract_instance.add_admin(admin);
    
    // Verify admin was added
    assert(contract_instance.is_admin(admin), 'Admin not added by owner');
    
    // Start spying on events before removing admin
    let mut spy = spy_events();
    
    // Remove admin
    contract_instance.remove_admin(admin);
    
    // Verify admin was removed
    assert(!contract_instance.is_admin(admin), 'Admin not removed by owner');
    
    stop_cheat_caller_address(contract_instance.contract_address);
    
    // Get the emitted events
    let events = spy.get_events();
    assert(events.events.len() > 0, 'No events were emitted');
    
    // Verify the event came from our contract
    let events_from_contract = events.emitted_by(contract_address);
    assert(events_from_contract.events.len() > 0, 'No events from contract');
    
    // Check that the event has the correct key (event name)
    let (_, event) = events_from_contract.events.at(0);
    println!("Event keys: {}", event.keys.len());
    println!("Event data: {}", event.data.len());
    
    // Print the actual event name
    let event_name = *event.keys.at(0);
    println!("Event name: {}", event_name);
    
    // Print all possible selectors for comparison
    println!("AdminRemoved selector: {}", selector!("AdminRemoved"));
    println!("RoleRevoked selector: {}", selector!("RoleRevoked"));
    
    // Check for either AdminRemoved or RoleRevoked event
    let is_admin_removed = event_name == selector!("AdminRemoved");
    let is_role_revoked = event_name == selector!("RoleRevoked");
    
    assert(is_admin_removed || is_role_revoked, 'Expected admin event');
    
    // If it's an AdminRemoved event, check the admin address
    if is_admin_removed {
        assert(event.data.len() > 0, 'Event has no data');
        assert(*event.data.at(0) == admin.into(), 'Admin address should be admin');
    }
}

// Test remove admin when paused
#[test]
#[should_panic(expected: 'Pausable: paused')]
fn test_remove_admin_when_paused() {
    let (contract_address, owner) = setup();
    let contract_instance = ISuperMarketDispatcher { contract_address };

    // First add an admin
    let admin_felt: felt252 = 0002.into();
    let admin: ContractAddress = admin_felt.try_into().unwrap();

    // Owner has DEFAULT_ADMIN_ROLE and should be able to add admins
    start_cheat_caller_address(contract_instance.contract_address, owner);

    // Add admin
    contract_instance.add_admin(admin);
    
    // Verify admin was added
    assert(contract_instance.is_admin(admin), 'Admin not added by owner');
    
    // Pause the contract
    contract_instance.pause_contract();
    
    // Remove admin
    contract_instance.remove_admin(admin);
    
    // Verify admin was removed
    assert(!contract_instance.is_admin(admin), 'Admin not removed by owner');
    
    stop_cheat_caller_address(contract_instance.contract_address);
}


// ******* TEST BUY PRODUCT *******
// Test buy product with token
#[test]
fn test_buy_product_with_token() {
    // Deploy contracts
    let (contract_address, owner, token_address) = setup_with_token();
    let contract_instance = ISuperMarketDispatcher { contract_address };
    let token_dispatcher = IERC20Dispatcher { contract_address: token_address };
    
    // First add a product as owner
    let name: felt252 = 'Apple';
    let price: u32 = 5;
    let stock: u32 = 100;
    let description: ByteArray = "Fresh red apples";
    let category: felt252 = 'fruit';
    let image: ByteArray = "appleimage";

    // Owner adds a product
    start_cheat_caller_address(contract_instance.contract_address, owner);
    contract_instance.add_product(name, price, stock, description, category, image);
    stop_cheat_caller_address(contract_instance.contract_address);
    
    // Create a buyer address
    let buyer_felt: felt252 = 0003.into();
    let buyer: ContractAddress = buyer_felt.try_into().unwrap();
    
    // Transfer tokens from owner to buyer instead of minting
    start_cheat_caller_address(token_address, owner);
    token_dispatcher.transfer(buyer, 1000_u256);
    stop_cheat_caller_address(token_address);
    
    // Buyer approves the contract to spend their tokens
    start_cheat_caller_address(token_address, buyer);
    token_dispatcher.approve(contract_address, 1000_u256);
    stop_cheat_caller_address(token_address);
    
    // Create a purchase array with one item
    let mut purchases = array![];
    let purchase_item = PurchaseItem { product_id: 1, quantity: 10 };
    purchases.append(purchase_item);
    
    // Check buyer's balance before purchase
    let balance_before = token_dispatcher.balance_of(buyer);
    
    // Buy the product as buyer
    start_cheat_caller_address(contract_instance.contract_address, buyer);
    let total_cost = contract_instance.buy_product(purchases);
    stop_cheat_caller_address(contract_instance.contract_address);
    
    // Verify the total cost is correct (5 * 10 = 50)
    assert(total_cost == 50, 'Incorrect total cost');
    
    // Verify the product stock was updated
    let product = contract_instance.get_product_by_id(1);
    assert(product.stock == 90, 'Stock not updated correctly');
    
    // Check buyer's balance after purchase
    let balance_after = token_dispatcher.balance_of(buyer);
    let expected_balance = balance_before - total_cost.into();
    assert(balance_after == expected_balance, 'Token not deducted correctly');
    
    // Check contract's token balance
    let contract_balance = token_dispatcher.balance_of(contract_address);
    assert(contract_balance == total_cost.into(), 'Contract did not receive tokens');
}

// Test buy product when contract is paused
#[test]
#[should_panic(expected: 'Pausable: paused')]
fn test_buy_product_when_paused() {
    // Deploy contracts
    let (contract_address, owner, token_address) = setup_with_token();
    let contract_instance = ISuperMarketDispatcher { contract_address };
    let token_dispatcher = IERC20Dispatcher { contract_address: token_address };
    
    // First add a product as owner
    let name: felt252 = 'Apple';
    let price: u32 = 5;
    let stock: u32 = 100;
    let description: ByteArray = "Fresh red apples";
    let category: felt252 = 'fruit';
    let image: ByteArray = "appleimage";

    // Owner adds a product
    start_cheat_caller_address(contract_instance.contract_address, owner);
    contract_instance.add_product(name, price, stock, description, category, image);
    stop_cheat_caller_address(contract_instance.contract_address);
    
    // Create a buyer address
    let buyer_felt: felt252 = 0003.into();
    let buyer: ContractAddress = buyer_felt.try_into().unwrap();
    
    // Transfer tokens from owner to buyer instead of minting
    start_cheat_caller_address(token_address, owner);
    token_dispatcher.transfer(buyer, 1000_u256);
    stop_cheat_caller_address(token_address);
    
    // Buyer approves the contract to spend their tokens
    start_cheat_caller_address(token_address, buyer);
    token_dispatcher.approve(contract_address, 1000_u256);
    stop_cheat_caller_address(token_address);
    
    // Create a purchase array with one item
    let mut purchases = array![];
    let purchase_item = PurchaseItem { product_id: 1, quantity: 10 };
    purchases.append(purchase_item);
    
    // Check buyer's balance before purchase
    let balance_before = token_dispatcher.balance_of(buyer);

    // pause contract
    start_cheat_caller_address(contract_instance.contract_address, owner);
    contract_instance.pause_contract();
    stop_cheat_caller_address(contract_instance.contract_address);
    
    // Buy the product as buyer
    start_cheat_caller_address(contract_instance.contract_address, buyer);
    let total_cost = contract_instance.buy_product(purchases);
    stop_cheat_caller_address(contract_instance.contract_address);
    
    // Verify the total cost is correct (5 * 10 = 50)
    assert(total_cost == 50, 'Incorrect total cost');
    
    // Verify the product stock was updated
    let product = contract_instance.get_product_by_id(1);
    assert(product.stock == 90, 'Stock not updated correctly');
    
    // Check buyer's balance after purchase
    let balance_after = token_dispatcher.balance_of(buyer);
    let expected_balance = balance_before - total_cost.into();
    assert(balance_after == expected_balance, 'Token not deducted correctly');
    
    // Check contract's token balance
    let contract_balance = token_dispatcher.balance_of(contract_address);
    assert(contract_balance == total_cost.into(), 'Contract did not receive tokens');
}

// test buy product with insufficient balance
#[test]
#[should_panic(expected: 'Insufficient balance')]
fn test_buy_product_with_insufficient_balance() {
    // Deploy contracts
    let (contract_address, owner, token_address) = setup_with_token();
    let contract_instance = ISuperMarketDispatcher { contract_address };
    let token_dispatcher = IERC20Dispatcher { contract_address: token_address };

    // First add a product as owner
    let name: felt252 = 'Apple';
    let price: u32 = 5;
    let stock: u32 = 100;
    let description: ByteArray = "Fresh red apples";
    let category: felt252 = 'fruit';
    let image: ByteArray = "appleimage";

    // Owner adds a product
    start_cheat_caller_address(contract_instance.contract_address, owner);
    contract_instance.add_product(name, price, stock, description, category, image);
    stop_cheat_caller_address(contract_instance.contract_address);
    
    // Create a buyer address with no tokens
    let buyer_felt: felt252 = 0003.into();
    let buyer: ContractAddress = buyer_felt.try_into().unwrap();
    
    // Buyer approves the contract to spend their tokens (even though they have none)
    start_cheat_caller_address(token_address, buyer);
    token_dispatcher.approve(contract_address, 1000_u256);
    stop_cheat_caller_address(token_address);
    
    // Create a purchase array with one item
    let mut purchases = array![];
    let purchase_item = PurchaseItem { product_id: 1, quantity: 10 };
    purchases.append(purchase_item);
    
    // Buy the product as buyer - this should fail with 'Insufficient balance'
    start_cheat_caller_address(contract_instance.contract_address, buyer);
    contract_instance.buy_product(purchases);
    stop_cheat_caller_address(contract_instance.contract_address);
}


// ******* TEST WITHDRAW FUNDS *******
// Test withdraw funds with default admin role (owner)
#[test]
fn test_withdraw_funds() {
    // deploy contracts
    let (contract_address, owner, token_address) = setup_with_token();
    let contract_instance = ISuperMarketDispatcher { contract_address };
    let token_dispatcher = IERC20Dispatcher { contract_address: token_address };

    // First add a product as owner
    let name: felt252 = 'Apple';
    let price: u32 = 56;
    let stock: u32 = 100;
    let description: ByteArray = "Fresh red apples";
    let category: felt252 = 'fruit';
    let image: ByteArray = "appleimage";

    // Owner adds a product
    start_cheat_caller_address(contract_instance.contract_address, owner);
    contract_instance.add_product(name, price, stock, description, category, image);
    stop_cheat_caller_address(contract_instance.contract_address);
    
    // Create a buyer address
    let buyer_felt: felt252 = 0003.into();
    let buyer: ContractAddress = buyer_felt.try_into().unwrap();
    
    // Transfer tokens from owner to buyer instead of minting
    start_cheat_caller_address(token_address, owner);
    token_dispatcher.transfer(buyer, 1000_u256);
    stop_cheat_caller_address(token_address);
    
    // Buyer approves the contract to spend their tokens
    start_cheat_caller_address(token_address, buyer);
    token_dispatcher.approve(contract_address, 1000_u256);
    stop_cheat_caller_address(token_address);
    
    // Create a purchase array with one item
    let mut purchases = array![];
    let purchase_item = PurchaseItem { product_id: 1, quantity: 10 };
    purchases.append(purchase_item);
    
    // Check buyer's balance before purchase
    let balance_before = token_dispatcher.balance_of(buyer);
    
    // Buy the product as buyer
    start_cheat_caller_address(contract_instance.contract_address, buyer);
    let total_cost = contract_instance.buy_product(purchases);
    stop_cheat_caller_address(contract_instance.contract_address);
    
    // Verify the total cost is correct (56 * 10 = 560)
    assert(total_cost == 560, 'Incorrect total cost');
    
    // Verify the product stock was updated
    let product = contract_instance.get_product_by_id(1);
    assert(product.stock == 90, 'Stock not updated correctly');
    
    // Check buyer's balance after purchase
    let balance_after = token_dispatcher.balance_of(buyer);
    let expected_balance = balance_before - total_cost.into();
    assert(balance_after == expected_balance, 'Token not deducted correctly');
    
    // Check contract's token balance
    let contract_balance = token_dispatcher.balance_of(contract_address);
    assert(contract_balance == total_cost.into(), 'Contract did not receive tokens');

    let to: ContractAddress = owner;
    let amount: u256 = total_cost.into();

    // Withdraw funds as owner
    start_cheat_caller_address(contract_instance.contract_address, owner);
    contract_instance.withdraw_funds(to, amount);
    stop_cheat_caller_address(contract_instance.contract_address);

    // Check contract's token balance
    let contract_balance = token_dispatcher.balance_of(contract_address);
    assert(contract_balance == 0, 'Withdraw failed');
}

// test withdraw funds with insufficient balance
#[test]
#[should_panic(expected: 'INSUFFICIENT_STRK_BALANCE')]
fn test_withdraw_funds_with_insufficient_balance() {
    // Deploy contracts
    let (contract_address, owner, token_address) = setup_with_token();
    let contract_instance = ISuperMarketDispatcher { contract_address };
    let token_dispatcher = IERC20Dispatcher { contract_address: token_address };

    // First add a product as owner
    let name: felt252 = 'Apple';
    let price: u32 = 5;
    let stock: u32 = 100;
    let description: ByteArray = "Fresh red apples";
    let category: felt252 = 'fruit';
    let image: ByteArray = "appleimage";

    // Owner adds a product
    start_cheat_caller_address(contract_instance.contract_address, owner);
    contract_instance.add_product(name, price, stock, description, category, image);
    stop_cheat_caller_address(contract_instance.contract_address);
    
    // Create a buyer address
    let buyer_felt: felt252 = 0003.into();
    let buyer: ContractAddress = buyer_felt.try_into().unwrap();
    
    // Transfer tokens from owner to buyer instead of minting
    start_cheat_caller_address(token_address, owner);
    token_dispatcher.transfer(buyer, 1000_u256);
    stop_cheat_caller_address(token_address);
    
    // Buyer approves the contract to spend their tokens
    start_cheat_caller_address(token_address, buyer);
    token_dispatcher.approve(contract_address, 1000_u256);
    stop_cheat_caller_address(token_address);
    
    // Create a purchase array with one item
    let mut purchases = array![];
    let purchase_item = PurchaseItem { product_id: 1, quantity: 10 };
    purchases.append(purchase_item);
    
    // Check buyer's balance before purchase
    let balance_before = token_dispatcher.balance_of(buyer);
    
    // Buy the product as buyer
    start_cheat_caller_address(contract_instance.contract_address, buyer);
    let total_cost = contract_instance.buy_product(purchases);
    stop_cheat_caller_address(contract_instance.contract_address);
    
    // Verify the total cost is correct (5 * 10 = 50)
    assert(total_cost == 50, 'Incorrect total cost');
    
    // Verify the product stock was updated
    let product = contract_instance.get_product_by_id(1);
    assert(product.stock == 90, 'Stock not updated correctly');
    
    // Check buyer's balance after purchase
    let balance_after = token_dispatcher.balance_of(buyer);
    let expected_balance = balance_before - total_cost.into();
    assert(balance_after == expected_balance, 'Token not deducted correctly');
    
    // Check contract's token balance
    let contract_balance = token_dispatcher.balance_of(contract_address);
    assert(contract_balance == total_cost.into(), 'Contract did not receive tokens');

    let to: ContractAddress = owner;
    let amount: u256 = 5000_u256;

    // Withdraw funds as owner
    start_cheat_caller_address(contract_instance.contract_address, owner);
    contract_instance.withdraw_funds(to, amount);
    stop_cheat_caller_address(contract_instance.contract_address);

    // Check contract's token balance
    let contract_balance = token_dispatcher.balance_of(contract_address);
    assert(contract_balance == 0, 'Withdraw failed');
}

// test withdraw funds with non owner
#[test]
#[should_panic(expected: 'Caller is not the admin')]
fn test_withdraw_funds_with_non_owner() {
    // Deploy contracts
    let (contract_address, owner, token_address) = setup_with_token();
    let contract_instance = ISuperMarketDispatcher { contract_address };
    let token_dispatcher = IERC20Dispatcher { contract_address: token_address };

    // First add a product as owner
    let name: felt252 = 'Apple';
    let price: u32 = 5;
    let stock: u32 = 100;
    let description: ByteArray = "Fresh red apples";
    let category: felt252 = 'fruit';
    let image: ByteArray = "appleimage";

    // Owner adds a product
    start_cheat_caller_address(contract_instance.contract_address, owner);
    contract_instance.add_product(name, price, stock, description, category, image);
    stop_cheat_caller_address(contract_instance.contract_address);
    
    // Create a buyer address
    let buyer_felt: felt252 = 0003.into();
    let buyer: ContractAddress = buyer_felt.try_into().unwrap();
    
    // Transfer tokens from owner to buyer instead of minting
    start_cheat_caller_address(token_address, owner);
    token_dispatcher.transfer(buyer, 1000_u256);
    stop_cheat_caller_address(token_address);
    
    // Buyer approves the contract to spend their tokens
    start_cheat_caller_address(token_address, buyer);
    token_dispatcher.approve(contract_address, 1000_u256);
    stop_cheat_caller_address(token_address);
    
    // Create a purchase array with one item
    let mut purchases = array![];
    let purchase_item = PurchaseItem { product_id: 1, quantity: 10 };
    purchases.append(purchase_item);
    
    // Check buyer's balance before purchase
    let balance_before = token_dispatcher.balance_of(buyer);
    
    // Buy the product as buyer
    start_cheat_caller_address(contract_instance.contract_address, buyer);
    let total_cost = contract_instance.buy_product(purchases);
    stop_cheat_caller_address(contract_instance.contract_address);
    
    // Verify the total cost is correct (5 * 10 = 50)
    assert(total_cost == 50, 'Incorrect total cost');
    
    // Verify the product stock was updated
    let product = contract_instance.get_product_by_id(1);
    assert(product.stock == 90, 'Stock not updated correctly');
    
    // Check buyer's balance after purchase
    let balance_after = token_dispatcher.balance_of(buyer);
    let expected_balance = balance_before - total_cost.into();
    assert(balance_after == expected_balance, 'Token not deducted correctly');
    
    // Check contract's token balance
    let contract_balance = token_dispatcher.balance_of(contract_address);
    assert(contract_balance == total_cost.into(), 'Contract did not receive tokens');

    // Create a random address
    let random_felt: felt252 = 0003.into();
    let random: ContractAddress = random_felt.try_into().unwrap();

    let to: ContractAddress = random;
    let amount: u256 = 5000_u256;

    // Withdraw funds as owner
    start_cheat_caller_address(contract_instance.contract_address, random);
    contract_instance.withdraw_funds(to, amount);
    stop_cheat_caller_address(contract_instance.contract_address);

    // Check contract's token balance
    let contract_balance = token_dispatcher.balance_of(contract_address);
    assert(contract_balance == 0, 'Withdraw failed');
}