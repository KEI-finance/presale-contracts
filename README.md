# KEI Presale Contract

Contract allows for off-chain purchases via fiat to be registered in contract state.

ETH price is taken from the Chainlink Oracle on Arbitrum One:

https://data.chain.link/arbitrum/mainnet/crypto-usd/eth-usd

## Setup

```bash
yarn # installs the package dependencies
forge install # installs the forge dependencies
```

## Building

```bash
forge build
```

## Testing

```
forge test -vvv
```

## Test Coverage

```
forge coverage
```

## Deploying

Supported networks `goerli` `arbitrumOne`

Create a `.env` and fill it out

```env
cp .env.example .env
vim .env
```

Deploy the contracts
```
npx hardhat run scripts/deploy.ts --network {network}
```
