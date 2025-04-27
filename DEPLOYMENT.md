# Deployment Guide

This guide explains how to deploy the Super Market contract to StarkNet.

## Prerequisites

- [Scarb](https://docs.swmansion.com/scarb/download)
- [StarkNet Foundry](https://foundry-rs.github.io/starknet-foundry/getting-started/installation.html)
- [SNcast](https://book.starknet.io/chapter_4/sncast.html)
- A StarkNet account
- Some ETH in your account for deployment
- ERC20 token address for payment integration

## Configuration

1. Set up your account in `~/.starknet_accounts/starknet_open_zeppelin_accounts.json`:

```json
{
	"alpha-goerli": {
		"deployer": {
			"private_key": "YOUR_PRIVATE_KEY",
			"public_key": "YOUR_PUBLIC_KEY",
			"address": "YOUR_ACCOUNT_ADDRESS",
			"salt": "SALT_VALUE"
		}
	}
}
```

## Deployment Steps

### 1. Build the Contract

```bash
scarb build
```

This will generate the Sierra and CASM files in the `target` directory.

### 2. Declare the Contract

```bash
sncast \
  --account your_account_alias \
  declare --contract-name SuperMarket \
  --network sepolia
```

Save the returned class hash for the next step.

### 3. Deploy the Contract

```bash
sncast \
  --account your_account_alias \
  deploy \
  --class-hash 0x[CLASS_HASH_FROM_STEP_2] \
  --constructor-calldata 0x[YOUR_WALLET_ADDRESS] 0x[ERC20_TOKEN_ADDRESS] \
  --network sepolia
```

Constructor arguments:

- `YOUR_WALLET_ADDRESS`: The address that will be the owner of the contract
- `ERC20_TOKEN_ADDRESS`: The address of the ERC20 token used for payments

- `STRK SEPOLIA`: 0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d

### 4. Verify Deployment

After deployment, you can verify your contract on [Starkscan](https://sepolia.starkscan.co/) by searching for your contract address.

## Post-Deployment Setup

1. Add admins using the `add_admin` function
2. Add initial products using the `add_product` function
3. Test a purchase to ensure everything works correctly

## Network Options

- Sepolia (testnet): `--network sepolia`
- Mainnet: `--network mainnet`

## Troubleshooting

If you encounter errors:

1. Ensure you have enough ETH for deployment
2. Verify your account configuration
3. Check that the ERC20 token address is correct
4. Confirm that your class hash is correct

For more detailed information about deployment, visit the [StarkNet documentation](https://docs.starknet.io/documentation/).
