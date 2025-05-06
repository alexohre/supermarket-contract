use starknet::ContractAddress;
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
    pub trans_id: felt252,
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

// Define reward tiers for NFT rewards
#[derive(Clone, Debug, Drop, PartialEq, Serde, starknet::Store)]
pub struct RewardTier {
    pub id: u32,
    pub name: felt252,
    pub description: ByteArray,
    pub threshold: u32, // Minimum order total to qualify
    pub image_uri: ByteArray // URI for the NFT image
}

// Define a structure to track claimed rewards
#[derive(Clone, Debug, Drop, PartialEq, Serde, starknet::Store)]
pub struct ClaimedReward {
    pub buyer: ContractAddress,
    pub order_id: u32,
    pub reward_tier_id: u32,
    pub claimed_at: u64,
}
