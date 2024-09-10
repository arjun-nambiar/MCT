
# Token Vesting Contracts

## Overview

On-Chain vesting scheme enabled by smart contracts.

`TokenVesting` contract can release its token balance gradually like a typical vesting scheme, with a cliff and vesting period.
Optionally revocable by the owner.


### ⛏️ Compile

```console
$ yarn compile
```

This task will compile all smart contracts in the `contracts` directory.
ABI files will be automatically exported in `build/abi` directory.

### 📚 Documentation

Documentation is auto-generated after each build in `docs` directory.

The generated output is a static website containing smart contract documentation.

### 🌡️ Testing

```console
$ yarn test
```

### 🐱‍💻 Verify & Publish contract source code

```console
$ npx hardhat  verify --network mainnet $CONTRACT_ADDRESS $CONSTRUCTOR_ARGUMENTS
```