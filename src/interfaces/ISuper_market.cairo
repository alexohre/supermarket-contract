use starknet::ContractAddress;
use super_market::Structs::Structs::{Order, OrderItem, Product, PurchaseItem, RewardTier};

#[starknet::interface]
pub trait ISuperMarket<TContractState> {
    //  transfer ownership
    fn transfer_ownership(ref self: TContractState, new_owner: ContractAddress);

    // add admin
    fn add_admin(ref self: TContractState, admin: ContractAddress);


    // remove admin
    fn remove_admin(ref self: TContractState, admin: ContractAddress);

    // is admin
    fn is_admin(self: @TContractState, address: ContractAddress) -> bool;

    // get owner
    fn get_owner(self: @TContractState) -> ContractAddress;

    // get admins
    fn get_admins(self: @TContractState) -> Array<ContractAddress>;

    // get admin count
    fn get_admin_count(self: @TContractState) -> u32;

    // withdraw funds
    fn withdraw_funds(ref self: TContractState, to: ContractAddress, amount: u256);

    // Pausable functions
    fn pause_contract(ref self: TContractState);
    fn unpause_contract(ref self: TContractState);
    fn contract_is_paused(self: @TContractState) -> bool;

    // add product
    fn add_product(
        ref self: TContractState,
        name: felt252,
        price: u32,
        stock: u32,
        description: ByteArray,
        category: felt252,
        image: ByteArray,
    ) -> u32;

    // update product by id
    fn update_product(
        ref self: TContractState,
        id: u32,
        name: felt252,
        price: u32,
        stock: u32,
        description: ByteArray,
        category: felt252,
        image: ByteArray,
    );

    fn get_prdct_id(self: @TContractState) -> u32;

    // delete product by id
    fn delete_product(ref self: TContractState, id: u32);

    // get products
    fn get_products(self: @TContractState) -> Array<Product>;

    // get product by id
    fn get_product_by_id(self: @TContractState, id: u32) -> Product;

    // get total sales
    fn get_total_sales(self: @TContractState) -> u32;

    // purchase products
    fn buy_product(ref self: TContractState, purchases: Array<PurchaseItem>) -> u32;

    // get order items
    fn get_order_items(self: @TContractState, order_id: u32) -> Array<OrderItem>;

    // get all orders with items
    fn get_all_orders_with_items(self: @TContractState) -> Array<(Order, Array<OrderItem>)>;

    // Get the number of orders for a specific buyer
    fn get_buyer_order_count(self: @TContractState, buyer: ContractAddress) -> u32;

    // Get all orders with their items for a specific buyer
    // Returns an array of tuples, each containing an order and its items
    fn get_buyer_orders_with_items(
        self: @TContractState, buyer: ContractAddress,
    ) -> Array<(Order, Array<OrderItem>)>;

    // Get the number of reward tiers
    fn get_reward_tier_count(self: @TContractState) -> u32;

    // Add a reward tier (admin only)
    fn add_reward_tier(
        ref self: TContractState,
        name: felt252,
        description: ByteArray,
        threshold: u32,
        image_uri: ByteArray,
    ) -> u32;

    // update tier by id
    fn update_reward_tier(
        ref self: TContractState,
        id: u32,
        name: felt252,
        description: ByteArray,
        threshold: u32,
        image_uri: ByteArray,
    );

    // delete tier by id
    fn delete_reward_tier(ref self: TContractState, id: u32);

    // Get reward tier by id
    fn get_reward_tier_by_id(self: @TContractState, id: u32) -> Option<RewardTier>;

    // Get all reward tiers
    fn get_reward_tiers(self: @TContractState) -> Array<RewardTier>;

    // Get order by transaction ID
    fn get_order_by_transaction_id(self: @TContractState, trans_id: felt252) -> Option<Order>;

    // Check if a buyer is eligible for a reward based on transaction ID
    fn check_reward_eligibility(self: @TContractState, trans_id: felt252) -> Option<RewardTier>;

    // Claim a reward for an order
    fn claim_reward(ref self: TContractState, trans_id: felt252) -> u32;
}
