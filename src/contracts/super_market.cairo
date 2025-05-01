// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts for Cairo ^1.0.0

const PAUSER_ROLE: felt252 = selector!("PAUSER_ROLE");
const UPGRADER_ROLE: felt252 = selector!("UPGRADER_ROLE");
const ADMIN_ROLE: felt252 = selector!("ADMIN_ROLE");

// Define the token address as a constant felt252
const STARKNET_TOKEN_ADDRESS: felt252 =
    0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d;
// starknet token address

#[starknet::contract]
pub mod SuperMarketV1 {
    // Import conversion traits
    use core::traits::{Into, TryInto};
    use openzeppelin::access::accesscontrol::{AccessControlComponent, DEFAULT_ADMIN_ROLE};
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::security::pausable::PausableComponent;
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use openzeppelin::upgrades::UpgradeableComponent;
    use openzeppelin::upgrades::interface::IUpgradeable;
    use starknet::event::EventEmitter;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use starknet::{
        ClassHash, ContractAddress, get_block_timestamp, get_caller_address, get_contract_address,
    };

    // Import structs
    use super_market::Structs::Structs::{Order, OrderItem, Product, PurchaseItem};
    // import events
    use super_market::events::super_market_event::{
        AdminAdded, AdminRemoved, OwnershipTransferred, ProductCreated, ProductDeleted,
        ProductPurchased, ProductUpdated,
    };
    // import interfaces
    use super_market::interfaces::ISuper_market::ISuperMarket;
    use super::{ADMIN_ROLE, PAUSER_ROLE, STARKNET_TOKEN_ADDRESS, UPGRADER_ROLE};
    use super::*;

    component!(path: PausableComponent, storage: pausable, event: PausableEvent);
    component!(path: AccessControlComponent, storage: accesscontrol, event: AccessControlEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);

    // External
    #[abi(embed_v0)]
    impl PausableImpl = PausableComponent::PausableImpl<ContractState>;
    #[abi(embed_v0)]
    impl AccessControlMixinImpl =
        AccessControlComponent::AccessControlMixinImpl<ContractState>;

    // Internal
    impl PausableInternalImpl = PausableComponent::InternalImpl<ContractState>;
    impl AccessControlInternalImpl = AccessControlComponent::InternalImpl<ContractState>;
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        pausable: PausableComponent::Storage,
        #[substorage(v0)]
        accesscontrol: AccessControlComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
        // Add storage from original contract
        owner: ContractAddress, // Store owner address
        admins: Map<ContractAddress, bool>, // Store admin addresses
        admin_addresses: Map<u32, ContractAddress>, // Store admin addresses by index
        admin_count: u32, // Keep track of total admins
        products: Map<u32, Product>, // Store products by id
        next_id: u32, // Next product id
        total_sales: u32, // Total sales amount
        product_names: Map<felt252, bool>, // Store product names to prevent duplicates
        // Order management
        orders: Map<u32, Order>, // Store orders by id
        order_items: Map<(u32, u32), OrderItem>, // Store order items by (order_id, item_index)
        order_count: u32 // Track number of orders
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        #[flat]
        PausableEvent: PausableComponent::Event,
        #[flat]
        AccessControlEvent: AccessControlComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
        // Add events from original contract
        ProductCreated: ProductCreated,
        ProductUpdated: ProductUpdated,
        ProductDeleted: ProductDeleted,
        ProductPurchased: ProductPurchased,
        AdminAdded: AdminAdded,
        AdminRemoved: AdminRemoved,
        OwnershipTransferred: OwnershipTransferred,
    }

    #[constructor]
    fn constructor(ref self: ContractState, default_admin: ContractAddress) {
        self.accesscontrol.initializer();

        // Grant the owner all the admin roles
        self.accesscontrol._grant_role(DEFAULT_ADMIN_ROLE, default_admin);
        self.accesscontrol._grant_role(PAUSER_ROLE, default_admin);
        self.accesscontrol._grant_role(UPGRADER_ROLE, default_admin);
        self.accesscontrol._grant_role(ADMIN_ROLE, default_admin);

        // Initialize marketplace state
        self.owner.write(default_admin);
        self.admin_count.write(0);
        self.next_id.write(0);
        self.total_sales.write(0);
    }

    // Internal implementation for contract functions
    trait InternalFunctionsTrait {
        fn assert_has_admin_role(self: @ContractState, caller: ContractAddress);
        fn _pause(ref self: ContractState);
        fn _unpause(ref self: ContractState);
    }

    impl InternalFunctions of InternalFunctionsTrait {
        // Helper function to check if caller has admin role or default admin role
        fn assert_has_admin_role(self: @ContractState, caller: ContractAddress) {
            let has_admin_role = self.accesscontrol.has_role(ADMIN_ROLE, caller);
            let has_default_admin_role = self.accesscontrol.has_role(DEFAULT_ADMIN_ROLE, caller);
            assert(has_admin_role || has_default_admin_role, 'Not authorized');
        }

        // Internal function to pause the contract
        fn _pause(ref self: ContractState) {
            self.pausable.pause();
        }

        // Internal function to unpause the contract
        fn _unpause(ref self: ContractState) {
            self.pausable.unpause();
        }
    }

    #[generate_trait]
    #[abi(per_item)]
    impl ExternalImpl of ExternalTrait {
        #[external(v0)]
        fn pause(ref self: ContractState) {
            // Only owner can pause - use has_role instead of assert_only_role
            let caller = get_caller_address();
            let has_pauser_role = self.accesscontrol.has_role(PAUSER_ROLE, caller);
            assert(has_pauser_role, 'Caller is not a pauser');
            self.pausable.pause();
        }

        #[external(v0)]
        fn unpause(ref self: ContractState) {
            // Only owner can unpause - use has_role instead of assert_only_role
            let caller = get_caller_address();
            let has_pauser_role = self.accesscontrol.has_role(PAUSER_ROLE, caller);
            assert(has_pauser_role, 'Caller is not a pauser');
            self.pausable.unpause();
        }
    }

    //
    // Upgradeable
    //

    #[abi(embed_v0)]
    impl UpgradeableImpl of IUpgradeable<ContractState> {
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            // Use has_role instead of assert_only_role
            let caller = get_caller_address();
            let has_upgrader_role = self.accesscontrol.has_role(UPGRADER_ROLE, caller);
            assert(has_upgrader_role, 'Caller is not an upgrader');
            self.upgradeable.upgrade(new_class_hash);
        }
    }

    // Implement the ISuperMarket interface
    #[abi(embed_v0)]
    impl SuperMarketImpl of ISuperMarket<ContractState> {
        // Owner management functions
        fn transfer_ownership(ref self: ContractState, new_owner: ContractAddress) {
            // Use OpenZeppelin's has_role instead of custom modifier
            let caller = get_caller_address();
            let has_default_admin_role = self.accesscontrol.has_role(DEFAULT_ADMIN_ROLE, caller);
            assert(has_default_admin_role, 'Caller is not the admin');

            let previous_owner = self.owner.read();

            // Transfer all admin roles to the new owner
            self.accesscontrol._revoke_role(DEFAULT_ADMIN_ROLE, previous_owner);
            self.accesscontrol._revoke_role(PAUSER_ROLE, previous_owner);
            self.accesscontrol._revoke_role(UPGRADER_ROLE, previous_owner);
            self.accesscontrol._revoke_role(ADMIN_ROLE, previous_owner);

            self.accesscontrol._grant_role(DEFAULT_ADMIN_ROLE, new_owner);
            self.accesscontrol._grant_role(PAUSER_ROLE, new_owner);
            self.accesscontrol._grant_role(UPGRADER_ROLE, new_owner);
            self.accesscontrol._grant_role(ADMIN_ROLE, new_owner);

            self.owner.write(new_owner);

            self
                .emit(
                    Event::OwnershipTransferred(OwnershipTransferred { previous_owner, new_owner }),
                );
        }

        // Pausable functions
        fn pause_contract(ref self: ContractState) {
            // Only DEFAULT_ADMIN_ROLE can pause the contract
            let caller = get_caller_address();
            let has_default_admin_role = self.accesscontrol.has_role(DEFAULT_ADMIN_ROLE, caller);
            assert(has_default_admin_role, 'Caller is not the admin');
            
            // Call the internal pause function
            self.pausable.pause();
        }

        fn unpause_contract(ref self: ContractState) {
            // Only DEFAULT_ADMIN_ROLE can unpause the contract
            let caller = get_caller_address();
            let has_default_admin_role = self.accesscontrol.has_role(DEFAULT_ADMIN_ROLE, caller);
            assert(has_default_admin_role, 'Caller is not the admin');
            
            // Call the internal unpause function
            self.pausable.unpause();
        }

        fn contract_is_paused(self: @ContractState) -> bool {
            self.pausable.is_paused()
        }

        // Admin management functions
        fn add_admin(ref self: ContractState, admin: ContractAddress) {
            // Use OpenZeppelin's has_role instead of custom modifier
            let caller = get_caller_address();
            let has_default_admin_role = self.accesscontrol.has_role(DEFAULT_ADMIN_ROLE, caller);
            assert(has_default_admin_role, 'Caller is not the admin');

            // Check if already an admin
            let is_already_admin = self.admins.read(admin);
            if !is_already_admin {
                // Add to admins mapping
                self.admins.write(admin, true);

                // Add to admin addresses list
                let current_count = self.admin_count.read();
                self.admin_addresses.write(current_count, admin);
                self.admin_count.write(current_count + 1);

                // Grant ADMIN_ROLE to the new admin
                self.accesscontrol._grant_role(ADMIN_ROLE, admin);

                self.emit(Event::AdminAdded(AdminAdded { admin }));
            }
        }

        fn remove_admin(ref self: ContractState, admin: ContractAddress) {
            // Use OpenZeppelin's has_role instead of custom modifier
            let caller = get_caller_address();
            let has_default_admin_role = self.accesscontrol.has_role(DEFAULT_ADMIN_ROLE, caller);
            assert(has_default_admin_role, 'Caller is not the admin');

            let is_admin = self.admins.read(admin);

            if is_admin {
                // Remove from admins mapping
                self.admins.write(admin, false);

                // Find and remove from admin addresses list
                // Note: This is inefficient but works for demonstration
                // A more efficient implementation would maintain indices
                let count = self.admin_count.read();
                let mut found_index: u32 = 0;
                let mut found = false;

                // Find the index of the admin to remove
                let mut i: u32 = 0;
                while i != count { // exit when i == count
                    let current_admin = self.admin_addresses.read(i);
                    if current_admin == admin {
                        found = true;
                        found_index = i;
                        break;
                    }
                    i = i + 1_u32; // monotonic increment
                }

                // If found, replace with the last admin and decrease count
                if found {
                    let last_index = count - 1;
                    if found_index < last_index {
                        let last_admin = self.admin_addresses.read(last_index);
                        self.admin_addresses.write(found_index, last_admin);
                    }
                    self.admin_count.write(last_index);
                }

                // Revoke ADMIN_ROLE from the admin
                self.accesscontrol._revoke_role(ADMIN_ROLE, admin);

                self.emit(Event::AdminRemoved(AdminRemoved { admin }));
            }
        }

        fn is_admin(self: @ContractState, address: ContractAddress) -> bool {
            self.admins.read(address)
        }

        fn get_owner(self: @ContractState) -> ContractAddress {
            self.owner.read()
        }

        fn get_admins(self: @ContractState) -> Array<ContractAddress> {
            let count = self.admin_count.read();
            let mut admins = ArrayTrait::new();

            let mut i: u32 = 0;
            while i != count { // exit when i == count
                let admin = self.admin_addresses.read(i);
                admins.append(admin);
                i = i + 1_u32; // monotonic increment
            }

            admins
        }

        fn get_admin_count(self: @ContractState) -> u32 {
            self.admin_count.read()
        }

        // Product management functions
        fn add_product(
            ref self: ContractState,
            name: felt252,
            price: u32,
            stock: u32,
            description: ByteArray,
            category: felt252,
            image: ByteArray,
        ) -> u32 {
            // Check if contract is paused
            self.pausable.assert_not_paused();

            // Check if caller has ADMIN_ROLE or DEFAULT_ADMIN_ROLE
            let caller = get_caller_address();
            let has_admin_role = self.accesscontrol.has_role(ADMIN_ROLE, caller);
            let has_default_admin_role = self.accesscontrol.has_role(DEFAULT_ADMIN_ROLE, caller);
            assert(has_admin_role || has_default_admin_role, 'Not authorized');

            // Check if the product already exists
            let is_product_exists = self.product_names.read(name);
            assert(!is_product_exists, 'Product already exists');

            // get the next id for auto increment
            let id = self.get_prdct_id();

            let new_id = id + 1;

            // Store the descriptions so we can clone them for the event
            let description_clone = description.clone();
            let image_clone = image.clone();

            let product = Product { id: new_id, name, price, stock, description, category, image };
            self.products.write(new_id, product);

            // Record that this name is now in use
            self.product_names.write(name, true);

            // Update the next id
            self.next_id.write(new_id);

            // Emit event
            self
                .emit(
                    Event::ProductCreated(
                        ProductCreated {
                            id: new_id,
                            name,
                            price,
                            stock,
                            description: description_clone,
                            category,
                            image: image_clone,
                        },
                    ),
                );
            self.get_prdct_id()
        }

        fn get_prdct_id(self: @ContractState) -> u32 {
            self.next_id.read()
        }

        // update product by id
        fn update_product(
            ref self: ContractState,
            id: u32,
            name: felt252,
            price: u32,
            stock: u32,
            description: ByteArray,
            category: felt252,
            image: ByteArray,
        ) {
            // Check if contract is paused
            self.pausable.assert_not_paused();

            // Check if caller has ADMIN_ROLE or DEFAULT_ADMIN_ROLE
            let caller = get_caller_address();
            let has_admin_role = self.accesscontrol.has_role(ADMIN_ROLE, caller);
            let has_default_admin_role = self.accesscontrol.has_role(DEFAULT_ADMIN_ROLE, caller);
            assert(has_admin_role || has_default_admin_role, 'Not authorized');

            // Check if the product exists
            let mut product = self.products.read(id);
            assert(product.id == id, 'Product does not exist');

            // Store the descriptions so we can clone them for the event
            let description_clone = description.clone();
            let image_clone = image.clone();

            // Update product
            product.name = name;
            product.price = price;
            product.stock = stock;
            product.description = description;
            product.category = category;
            product.image = image;

            // If the name is changing, check if the new name exists
            let old_product = self.products.read(id);
            if old_product.name != name {
                let name_exists = self.product_names.read(name);
                assert(!name_exists, 'Product name already exists');

                // Remove old name and add new one
                self.product_names.write(old_product.name, false);
                self.product_names.write(name, true);
            }

            // Write the updated product back to storage
            self.products.write(id, product);

            // Emit the event
            self
                .emit(
                    Event::ProductUpdated(
                        ProductUpdated {
                            id,
                            name,
                            price,
                            stock,
                            description: description_clone,
                            category,
                            image: image_clone,
                        },
                    ),
                );
        }

        // delete product
        fn delete_product(ref self: ContractState, id: u32) {
            // Check if contract is paused
            self.pausable.assert_not_paused();

            // Check if caller has ADMIN_ROLE or DEFAULT_ADMIN_ROLE
            let caller = get_caller_address();
            let has_admin_role = self.accesscontrol.has_role(ADMIN_ROLE, caller);
            let has_default_admin_role = self.accesscontrol.has_role(DEFAULT_ADMIN_ROLE, caller);
            assert(has_admin_role || has_default_admin_role, 'Not authorized');

            // Check if the product exists
            let product = self.products.read(id);
            assert(product.id == id, 'Product does not exist');

            // Get the product name before deleting
            let product_name = self.products.read(id).name;

            // Delete the product (in Cairo, we don't have a way to actually remove from storage)
            // So we'll write a "blank" product with id = 0 to indicate deletion
            let deleted_product = Product {
                id: 0, name: 0, price: 0, stock: 0, description: "", category: 0, image: "",
            };

            self.products.write(id, deleted_product);

            // Remove the name from used names
            self.product_names.write(product_name, false);

            // Emit the event
            self.emit(Event::ProductDeleted(ProductDeleted { id }));
        }

        // get products
        fn get_products(self: @ContractState) -> Array<Product> {
            let count = self.next_id.read(); // felt252
            let mut products: Array<Product> = ArrayTrait::new();

            let mut i: u32 = 1;
            while i != count + 1 { // stop when i == count + 1
                let product = self.products.read(i);
                if product.id != 0 {
                    products.append(product);
                }
                i = i + 1;
            }
            products
        }

        // Get total sales
        fn get_total_sales(self: @ContractState) -> u32 {
            self.total_sales.read()
        }

        // Purchase product
        // Buy multiple products at once
        fn buy_product(ref self: ContractState, purchases: Array<PurchaseItem>) -> u32 {
            // Check if contract is paused
            self.pausable.assert_not_paused();

            let buyer = get_caller_address();
            let mut total_cost: u32 = 0;
            let mut i: u32 = 0;
            let purchases_len = purchases.len();

            // Verify product existence, stock, and calculate total cost WITHOUT modifying storage
            while i != purchases_len {
                let purchase = *purchases.at(i);
                let product_id = purchase.product_id;
                let quantity = purchase.quantity;

                // Verify quantity is positive
                assert(quantity > 0, 'Quantity must be positive');

                // Get product
                let product = self.products.read(product_id);
                assert(product.id == product_id, 'Product does not exist');
                assert(product.stock >= quantity, 'Not enough stock');

                // Calculate cost
                let item_cost = product.price * quantity;
                total_cost = total_cost + item_cost;

                i = i + 1_u32;
            }

            // Now handle payment
            let payment_token_address: felt252 = STARKNET_TOKEN_ADDRESS;
            let contract_address = starknet::get_contract_address();

            // Convert u32 to u256 for the ERC20 interface
            let total_cost_u256: u256 = total_cost.into();

            // Create a dispatcher to interact with the token contract
            let token_contract_address: ContractAddress = payment_token_address.try_into().unwrap();
            let token_dispatcher = IERC20Dispatcher { contract_address: token_contract_address };

            // Check if buyer has enough balance
            let buyer_balance = token_dispatcher.balance_of(buyer);
            assert(buyer_balance >= total_cost_u256, 'Insufficient balance');

            // Transfer tokens from buyer to contract
            token_dispatcher.transfer_from(buyer, contract_address, total_cost_u256);

            // After payment is confirmed, update stock levels and create order
            let order_id = self.order_count.read() + 1;
            let timestamp = get_block_timestamp();

            // Create new order
            let order = Order {
                id: order_id, buyer, total_cost, timestamp, items_count: purchases_len,
            };

            // Store the order
            self.orders.write(order_id, order);

            // Store each order item
            i = 0;
            while i != purchases_len {
                let purchase = *purchases.at(i);
                let product_id = purchase.product_id;
                let quantity = purchase.quantity;
                let product = self.products.read(product_id);
                // Get product and update stock

                // Store order item
                let order_item = OrderItem { product_id, quantity, price: product.price };

                self.order_items.write((order_id, i), order_item);

                // Update product stock
                let mut product = self.products.read(product_id);
                product.stock = product.stock - quantity;
                self.products.write(product_id, product);

                i = i + 1_u32;
            }

            // Update order count
            self.order_count.write(order_id);

            // Update total sales
            let current_sales = self.total_sales.read();
            self.total_sales.write(current_sales + total_cost);

            // Emit purchase event
            self.emit(Event::ProductPurchased(ProductPurchased { buyer, total_cost }));

            total_cost
        }

        fn withdraw_funds(ref self: ContractState, amount: u256) {
            // Check if contract is paused
            self.pausable.assert_not_paused();

            // Only owner can withdraw funds - use OpenZeppelin's has_role
            let caller = get_caller_address();
            let has_default_admin_role = self.accesscontrol.has_role(DEFAULT_ADMIN_ROLE, caller);
            assert(has_default_admin_role, 'Caller is not the admin');

            // Build a dispatcher to the STRK (ERC‑20) contract
            let payment_token_address: felt252 = STARKNET_TOKEN_ADDRESS;
            let token_addr: ContractAddress = payment_token_address.try_into().unwrap();
            let erc20 = IERC20Dispatcher { contract_address: token_addr };

            // Check this contract's token balance
            let this_contract: ContractAddress = get_contract_address();
            let balance: u256 = erc20.balance_of(this_contract);
            assert(balance >= amount, 'INSUFFICIENT_STRK_BALANCE');

            // Transfer STRK to the owner
            let owner: ContractAddress = self.owner.read();
            erc20.transfer(owner, amount);
        }

        // Get order items for a specific order
        fn get_order_items(self: @ContractState, order_id: u32) -> Array<OrderItem> {
            // Only owner, admins, or the buyer can view order items
            let caller = get_caller_address();
            let order = self.orders.read(order_id);

            assert(
                caller == order.buyer || caller == self.owner.read() || self.admins.read(caller),
                'Unauthorized',
            );

            let items_count = order.items_count;
            let mut items = ArrayTrait::new();

            let mut i: u32 = 0;
            while i != items_count {
                let item = self.order_items.read((order_id, i));
                items.append(item);
                i = i + 1;
            }

            items
        }

        // New function to get all orders (admin only)
        fn get_all_orders(self: @ContractState) -> Array<Order> {
            // Check if caller has ADMIN_ROLE or DEFAULT_ADMIN_ROLE
            let caller = get_caller_address();
            let has_admin_role = self.accesscontrol.has_role(ADMIN_ROLE, caller);
            let has_default_admin_role = self.accesscontrol.has_role(DEFAULT_ADMIN_ROLE, caller);
            assert(has_admin_role || has_default_admin_role, 'Not authorized');

            let order_count = self.order_count.read();
            let mut orders = ArrayTrait::new();

            let mut i: u32 = 1;
            while i != order_count + 1 { // stop when i == order_count + 1
                let order = self.orders.read(i);
                orders.append(order);
                i = i + 1;
            }

            orders
        }
    }
}
