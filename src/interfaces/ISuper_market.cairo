use starknet::ContractAddress;
use super_market::Structs::Structs::{Order, OrderItem, Product, PurchaseItem};

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
    fn withdraw_funds(ref self: TContractState, amount: u256);


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

    // get total sales
    fn get_total_sales(self: @TContractState) -> u32;

    // purchase products
    fn buy_product(ref self: TContractState, purchases: Array<PurchaseItem>) -> u32;

    // get order items
    fn get_order_items(self: @TContractState, order_id: u32) -> Array<OrderItem>;

    // get all orders
    fn get_all_orders(self: @TContractState) -> Array<Order>;
}
