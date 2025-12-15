# pHYPE - Liquid Staked HYPE

pHYPE is a liquid staking token (LST) for HYPE on Hyperliquid, based on the Ventuals vHYPE architecture.

## Overview

- **Token**: pHYPE (Liquid Staked HYPE)
- **Minimum Stake**: 500,000 HYPE (HIP-3 requirement)
- **Batch Processing**: 24 hours
- **Unstaking Period**: 7 days
- **Architecture**: Based on Ventuals vHYPE contracts

## Contracts

- `PHYPE.sol` - ERC20 LST token
- `StakingVault.sol` - Core staking logic
- `StakingVaultManager.sol` - HyperCore integration
- `RoleRegistry.sol` - Access control

## Roles

- **OWNER**: Multisig wallet (full admin control)
- **MANAGER**: StakingVaultManager (HIP-3 deployer)
- **OPERATOR**: Bot wallet (executes batches)

## Getting Started

Install [Foundry](https://getfoundry.sh/):

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

Clone and set up the repository:

```bash
git clone https://github.com/ventuals/ventuals-contracts.git && cd ventuals-contracts
git submodule update --init --recursive
forge build
```

## Testing

```bash
# Run tests
forge test

# Run coverage report
forge coverage
```

## Security

- Based on audited Ventuals contracts
- All staking logic unchanged from original
- Custom deployment with personal addresses

## Attribution

pHYPE is based on the Ventuals vHYPE liquid staking token contracts.

Original repository: https://github.com/ventuals/ventuals-contracts

pHYPE maintains the same core staking logic, timing parameters, and security architecture as vHYPE, with customizations for personal deployment.

We thank the Ventuals team for open-sourcing their high-quality LST implementation.

## License

Apache-2.0 (same as Ventuals)
