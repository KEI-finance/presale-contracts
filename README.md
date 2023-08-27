# KEI Presale Contract

The KEI finance Presale contract. Distributing placeholder tokens for the launch of the KEI finance protocol.

https://docs.kei.fi/welcome-to-kei-finance/presale-opportunity-29th-aug

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

```bash
forge test -vvv
```

## Test Coverage

```bash
forge coverage
```

## Deploying


Create a `.env` and fill it out

```bash
cp .env.example .env
vim .env
```

Deploy the contracts to the selected `{network}`
Supported networks `goerli` `arbitrumOne`

```bash
npx hardhat run scripts/deploy.ts --network {network}
```
