# temple-payments-forge

## setup

using forge tests

```sh
git clone https://github.com/onetxpunch/temple-payments
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

## tests

```sh
forge test -vvvv --fork-url https://rpc.ankr.com/eth
```

## deploy

```sh
forge create src/TempleTeamPaymentsFactory.sol:TempleTeamPaymentsFactory --rpc-url https://rpc.ankr.com/eth -i
```

## references

[protocol/contracts/admin/TempleTeamPayments.sol](https://github.com/TempleDAO/temple/blob/stage/protocol/contracts/admin/TempleTeamPayments.sol)
