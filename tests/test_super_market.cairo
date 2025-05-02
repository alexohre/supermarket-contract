use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, spy_events,
    start_cheat_caller_address, stop_cheat_caller_address,
    EventSpyTrait, EventSpyAssertionsTrait, Event, IsEmitted,
    EventsFilterTrait
};
use starknet::{ContractAddress, contract_address_const};
use super_market::interfaces::ISuper_market::{ISuperMarketDispatcher, ISuperMarketDispatcherTrait};
use super_market::events::super_market_event::{ProductCreated, ProductUpdated, AdminAdded};

// Constants for roles
const ADMIN_ROLE: felt252 = selector!("ADMIN_ROLE");
const PAUSER_ROLE: felt252 = selector!("PAUSER_ROLE");
const UPGRADER_ROLE: felt252 = selector!("UPGRADER_ROLE");

// Setup function that returns contract address and owner address
fn setup() -> (ContractAddress, ContractAddress) {
    let owner = contract_address_const::<'owner'>();
    let contract_class = declare("SuperMarketV1").unwrap().contract_class();
    // Deploy with only the owner address as the default_admin parameter
    let (contract_address, _) = contract_class.deploy(@array![owner.into()]).unwrap();
    (contract_address, owner)
}

// Setup function that also adds an admin
fn setup_with_admin() -> (ContractAddress, ContractAddress, ContractAddress) {
    let (contract_address, owner) = setup();
    let admin = contract_address_const::<'admin'>();

    // Add admin
    let contract_instance = ISuperMarketDispatcher { contract_address };
    start_cheat_caller_address(contract_instance.contract_address, owner);
    contract_instance.add_admin(admin);
    stop_cheat_caller_address(contract_instance.contract_address);

    (contract_address, owner, admin)
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
    let random_user = contract_address_const::<'john'>();

    let name: felt252 = 'Orange';
    let price: u32 = 3;
    let stock: u32 = 15;
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
    let random_user = contract_address_const::<'john'>();

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
    assert(event.keys.len() > 0, 'Event has no keys');
    assert(event.keys.at(0) == @selector!("ProductUpdated"), 'Wrong event name');
    
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
    let random_user = contract_address_const::<'john'>();

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
    assert(event.keys.len() > 0, 'Event has no keys');
    assert(event.keys.at(0) == @selector!("ProductDeleted"), 'Wrong event name');
    
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
