use starknet::ContractAddress;

#[starknet::interface]
pub trait ISuperMarketNft<TContractState> {
    fn safe_mint(
        ref self: TContractState, recipient: ContractAddress, token_id: u256, data: Span<felt252>,
    );

    fn safeMint(
        ref self: TContractState, recipient: ContractAddress, tokenId: u256, data: Span<felt252>,
    );

    fn burn(ref self: TContractState, token_id: u256);

    fn pause(ref self: TContractState);

    fn unpause(ref self: TContractState);
}
