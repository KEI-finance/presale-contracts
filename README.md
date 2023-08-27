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
