# Super Market Smart Contract

A decentralized marketplace built on StarkNet using Cairo 1.0, allowing product management, purchases with ERC20 tokens, and order tracking.

## Features

### Product Management

- Create, update, and delete products
- Product details include name, price, stock, description, category, and image
- Prevent duplicate product names
- Track product inventory

### User Roles

- Owner: Full control over the marketplace
- Admins: Can manage products
- Buyers: Can purchase products

### Order System

- Multi-product purchases in a single transaction
- Order history tracking
- Detailed order items tracking
- Total sales tracking

### Payment System

- ERC20 token integration for payments
- Secure fund withdrawal mechanism
- Balance checking before purchases

## Contract Structure

```
src/
├── contracts/
│   └── super_market.cairo    # Main contract implementation
├── events/
│   └── super_market_event.cairo    # Event definitions
├── interfaces/
│   └── ISuper_market.cairo    # Contract interface
└── lib.cairo    # Library entry point
tests/
```

## Key Components

### Structures

- `Product`: Stores product information
- `PurchaseItem`: Handles purchase requests
- `Order`: Tracks purchase history
- `OrderItem`: Stores individual items in orders

### Main Functions

#### Admin Management

- `transfer_ownership`: Transfer contract ownership
- `add_admin`: Add new admin
- `remove_admin`: Remove existing admin
- `is_admin`: Check admin status

#### Product Management

- `add_product`: Create new product
- `update_product`: Modify existing product
- `delete_product`: Remove product
- `get_products`: Retrieve all products

#### Purchase System

- `buy_product`: Purchase multiple products
- `get_order_items`: Retrieve order details
- `get_all_orders`: Get all orders (admin only)
- `get_total_sales`: Get total sales amount

#### Financial Management

- `withdraw_funds`: Withdraw contract balance

## Getting Started

### Prerequisites

- Scarb
- StarkNet Foundry

### Installation

1. Clone the repository
2. Install dependencies:

```bash
scarb install
```

### Testing

Run the tests using:

```bash
scarb test
```

## Deployment

For detailed deployment instructions, see the [Deployment Guide](DEPLOYMENT.md).

## Security Features

- Role-based access control
- Stock validation
- Payment validation
- Duplicate product prevention
- Safe fund withdrawal

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
