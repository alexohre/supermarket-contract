use starknet::ContractAddress;

#[derive(Clone, Drop, Debug, starknet::Event)]
pub struct ProductCreated {
    pub id: u32,
    pub name: felt252,
    pub price: u32,
    pub stock: u32,
    pub description: ByteArray,
    pub category: felt252,
    pub image: ByteArray,
}

#[derive(Clone, Drop, Debug, starknet::Event)]
pub struct ProductUpdated {
    pub id: u32,
    pub name: felt252,
    pub price: u32,
    pub stock: u32,
    pub description: ByteArray,
    pub category: felt252,
    pub image: ByteArray,
}

#[derive(Clone, Drop, Debug, starknet::Event)]
pub struct ProductDeleted {
    pub id: u32,
}

#[derive(Clone, Drop, Debug, starknet::Event)]
pub struct AdminAdded {
    pub admin: ContractAddress,
}

#[derive(Clone, Drop, Debug, starknet::Event)]
pub struct AdminRemoved {
    pub admin: ContractAddress,
}

#[derive(Clone, Drop, Debug, starknet::Event)]
pub struct OwnershipTransferred {
    pub previous_owner: ContractAddress,
    pub new_owner: ContractAddress,
}

#[derive(Clone, Drop, Debug, starknet::Event)]
pub struct ProductPurchased {
    pub buyer: ContractAddress,
    pub total_cost: u32,
    // pub product_ids: Array<u32>,
}
