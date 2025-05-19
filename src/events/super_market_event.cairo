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

#[derive(Clone, Drop, Debug, starknet::Event)]
pub struct WithdrawalMade {
    pub to: ContractAddress,
    pub amount: u32,
}

#[derive(Clone, Drop, Debug, starknet::Event)]
pub struct RewardClaimed {
    pub buyer: ContractAddress,
    pub order_id: u32,
    pub reward_tier_id: u32,
    pub claimed_at: u64,
}

#[derive(Clone, Drop, Debug, starknet::Event)]
pub struct RewardTierAdded {
    pub id: u32,
    pub name: felt252,
    pub description: ByteArray,
    pub threshold: u32,
    pub image_uri: ByteArray,
}

#[derive(Clone, Drop, Debug, starknet::Event)]
pub struct RewardTierUpdated {
    pub id: u32,
    pub name: felt252,
    pub description: ByteArray,
    pub threshold: u32,
    pub image_uri: ByteArray,
}

#[derive(Clone, Drop, Debug, starknet::Event)]
pub struct RewardTierDeleted {
    pub id: u32,
}
