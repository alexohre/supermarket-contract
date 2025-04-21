use starknet::{ContractAddress, get_block_timestamp, get_contract_address};

// product struct
#[derive(Clone, Debug, Drop, PartialEq, Serde, starknet::Store)]
pub struct Product {
    pub id: u32,
    pub name: felt252,
    pub price: u32,
    pub stock: u32,
    pub description: ByteArray,
    pub category: felt252,
    pub image: ByteArray,
}

// Define a purchase item structure to handle multiple products
#[derive(Clone, Debug, Drop, PartialEq, Serde, Copy)]
pub struct PurchaseItem {
    pub product_id: u32,
    pub quantity: u32,
}


// Add an Order structure to store purchase history
#[derive(Clone, Debug, Drop, PartialEq, Serde, starknet::Store)]
pub struct Order {
    pub id: u32,
    pub buyer: ContractAddress,
    pub total_cost: u32,
    pub timestamp: u64,
    pub items_count: u32,
}

// Define a structure to store order items
#[derive(Clone, Debug, Drop, PartialEq, Serde, starknet::Store)]
pub struct OrderItem {
    pub product_id: u32,
    pub quantity: u32,
    pub price: u32,
}

#[starknet::contract]
mod SuperMarket {
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::get_caller_address;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use super_market::events::super_market_event::{
        AdminAdded, AdminRemoved, OwnershipTransferred, ProductCreated, ProductDeleted,
        ProductPurchased, ProductUpdated,
    };
    use super_market::interfaces::ISuper_market::ISuperMarket;
    use super::*;

    #[storage]
    struct Storage {
        owner: ContractAddress, // Store owner address
        admins: Map<ContractAddress, bool>, // Store admin addresses
        admin_addresses: Map<u32, ContractAddress>, // Store admin addresses by index
        admin_count: u32, // Keep track of total admins
        products: Map<u32, Product>, // Store products by id
        next_id: u32, // Next product id
        total_sales: u32, // Total sales amount
        product_names: Map<felt252, bool>, // Store product names to prevent duplicates
        // stark contract address for payments
        payment_token: ContractAddress, // Address of the ERC20 token used for payments
        // Order management
        orders: Map<u32, Order>, // Store orders by id
        order_items: Map<(u32, u32), OrderItem>, // Store order items by (order_id, item_index)
        order_count: u32 // Track number of orders
    }


    #[event]
    #[derive(Debug, Clone, Drop, starknet::Event)]
    pub enum Event {
        ProductCreated: ProductCreated,
        ProductUpdated: ProductUpdated,
        ProductDeleted: ProductDeleted,
        ProductPurchased: ProductPurchased,
        AdminAdded: AdminAdded,
        AdminRemoved: AdminRemoved,
        OwnershipTransferred: OwnershipTransferred,
    }

    // Internal implementation for contract functions
    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        //Modifiers
        fn assert_only_owner(self: @ContractState) {
            let caller = get_caller_address();
            let owner = self.owner.read();
            assert(caller == owner, 'Only owner allowed');
        }

        fn assert_only_admin_or_owner(self: @ContractState) {
            let caller = get_caller_address();
            let owner = self.owner.read();
            let is_admin = self.admins.read(caller);

            assert(caller == owner || is_admin, 'Only owner or admin allowed');
        }
    }

    #[constructor]
    fn constructor(
        ref self: ContractState, owner: ContractAddress, payment_token: ContractAddress,
    ) {
        self.owner.write(owner);
        self.payment_token.write(payment_token);
        self.admin_count.write(0);
        self.next_id.write(0);
        self.total_sales.write(0);
    }


    #[abi(embed_v0)]
    impl SuperMarketImpl of ISuperMarket<ContractState> {
        // Owner management functions

        fn transfer_ownership(ref self: ContractState, new_owner: ContractAddress) {
            self.assert_only_owner();
            let previous_owner = self.owner.read();
            self.owner.write(new_owner);

            self
                .emit(
                    Event::OwnershipTransferred(OwnershipTransferred { previous_owner, new_owner }),
                );
        }

        fn add_admin(ref self: ContractState, admin: ContractAddress) {
            self.assert_only_owner();

            // Check if already an admin
            let is_already_admin = self.admins.read(admin);
            if !is_already_admin {
                // Add to admins mapping
                self.admins.write(admin, true);

                // Add to admin addresses list
                let current_count = self.admin_count.read();
                self.admin_addresses.write(current_count, admin);
                self.admin_count.write(current_count + 1);

                self.emit(Event::AdminAdded(AdminAdded { admin }));
            }
        }

        fn remove_admin(ref self: ContractState, admin: ContractAddress) {
            self.assert_only_owner();
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
        ) {
            // Only owner or admins can add products
            self.assert_only_admin_or_owner();
            // InternalFunctions::assert_only_admin_or_owner(@self);
            // Check if the product already exists
            let is_product_exists = self.product_names.read(name);
            assert(!is_product_exists, 'Product already exists');

            // get the next id for auto increment
            let id = self.next_id.read();
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
            // Only owner or admins can update products
            self.assert_only_admin_or_owner();

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
            // Only owner or admins can delete products
            self.assert_only_admin_or_owner();

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
            let payment_token_address = self.payment_token.read();
            let contract_address = starknet::get_contract_address();

            // Convert u32 to u256 for the ERC20 interface
            let total_cost_u256: u256 = total_cost.into();

            // Create a dispatcher to interact with the token contract
            let token_dispatcher = IERC20Dispatcher { contract_address: payment_token_address };

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
            self.assert_only_owner();

            // Build a dispatcher to the STRK (ERC‑20) contract
            let token_addr: ContractAddress = self.payment_token.read();
            let erc20 = IERC20Dispatcher { contract_address: token_addr };

            // Check this contract’s token balance
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
            // Only owner or admins can view all orders
            self.assert_only_admin_or_owner();

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
