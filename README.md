# 🪙 Foundry DeFi Stablecoin

A decentralized, over-collateralized stablecoin system built with Foundry. This project is my implementation and enhancement of the final project from the Cyfrin Updraft course, deployed on the Sepolia testnet.

---

## 📜 Table of Contents

- [📍 Deployed Contracts](#-deployed-contracts-on-sepolia)
- [📖 About The Project](#-about-the-project)
  - [Key Features](#key-features)
  - [Tech Stack](#-tech-stack)
- [🚀 Getting Started](#-getting-started)
  - [Prerequisites](#prerequisites)
  - [Installation](#installation)
- [🛠️ Usage](#️-usage)
  - [Running a Local Node](#running-a-local-node)
  - [Local Deployment](#local-deployment)
  - [Sepolia Deployment](#sepolia-deployment)
- [🧪 Testing](#-testing)
- [ взаимодействуя-with-the-contract](#-interacting-with-the-deployed-contract-on-sepolia)
- [⛽ Gas Usage](#-gas-usage)
- [🎨 Code Formatting](#-code-formatting)
- [🐍 Static Analysis](#-static-analysis)
- [🙏 Acknowledgements](#-acknowledgements)

---

## 📍 Deployed Contracts on Sepolia

| Contract                 | Address                                                                                              | Etherscan Link                                                                                                                              |
| ------------------------ | ---------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- |
| **DSCEngine**              | `0xe5C5598b13c6F27E8988baf002fc417a91D4035E`                                                         | [View on Sepolia Etherscan](https://sepolia.etherscan.io/address/0xe5C5598b13c6F27E8988baf002fc417a91D4035E#code)                             |
| **DecentralizedStableCoin**| `0x04F095cd4Be8733920d9Bf83D0B05CA0663eCf38`                                                         | [View on Sepolia Etherscan](https://sepolia.etherscan.io/address/0x04F095cd4Be8733920d9Bf83D0B05CA0663eCf38#code)                             |

---

## 📖 About The Project

This project implements a decentralized stablecoin (DSC) pegged to the US Dollar. It allows users to deposit collateral (WETH and WBTC) and mint DSC tokens. The system is designed to be over-collateralized, ensuring the stability and value of the minted tokens.

### Key Features

-   ✅ **Over-Collateralized Minting**: Users must deposit collateral worth at least 150% of the value of the DSC they wish to mint.
-   🏦 **Multi-Collateral Support**: Accepts both Wrapped Ether (WETH) and Wrapped Bitcoin (WBTC) as collateral.
-   💧 **Liquidations**: A mechanism to liquidate under-collateralized positions to maintain system solvency.
-   🔗 **Reliable Price Feeds**: Integrates **Chainlink** oracles and includes a custom `OracleLib` to ensure price data is never stale.
-   💎 **ERC20 Stablecoin**: The `DecentralizedStableCoin` is a fully compliant ERC20 token.

### 🤖 Tech Stack

-   **Solidity**: Smart contract language
-   **Foundry**: Smart contract development toolkit (Forge, Anvil, Cast)
-   **Chainlink**: Oracles for reliable price data
-   **OpenZeppelin**: Secure, battle-tested contract libraries

---

## 🚀 Getting Started

Follow these steps to set up the project locally.

### Prerequisites

-   [Git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)
-   [Foundry](https://getfoundry.sh/)

### Installation

1.  Clone the repository:
    ```sh
    git clone https://github.com/your-github-username/your-repo-name.git
    cd your-repo-name
    ```
2.  Install dependencies:
    ```sh
    forge install
    ```
3.  Build the contracts:
    ```sh
    forge build
    ```
4.  Set up your environment variables. The `Makefile` relies on these.
    ```sh
    cp .env.example .env 
    # Fill in your values in the .env file
    ```

---

## 🛠️ Usage

This project uses a `Makefile` to simplify common commands.

### Running a Local Node

Start a local Anvil node.

```bash
make anvil
```

### Local Deployment

In a new terminal, deploy the contracts to your local Anvil node.

```bash
make deploy
```

### Sepolia Deployment

1.  Ensure your `SEPOLIA_RPC_URL` and `PRIVATE_KEY` are set in your `.env` file.
2.  Load the environment variables into your shell session:
    ```bash
    source .env
    ```
3.  Run the deployment command:
    ```bash
    make deploy ARGS="--network sepolia"
    ```

> 💡 **Note**: If Etherscan verification fails for the library (a common issue), you can run the verification command manually. Be sure to replace the address with your new deployment address.
>
> ```bash
> forge verify-contract <YOUR_ORACLELIB_ADDRESS> src/libraries/OracleLib.sol:OracleLib --chain-id 11155111
> ```

---

## 🧪 Testing

This project includes comprehensive unit and fuzz tests.

-   **Run all tests**:
    ```bash
    forge test
    ```
-   **Run tests for a specific contract**:
    ```bash
    forge test --match-path test/unit/DSCEngineTest.t.sol
    ```
-   **Get a test coverage report**:
    ```bash
    forge coverage
    ```

---

##  взаимодействуя-with-the-Deployed-Contract-on-Sepolia

<!-- This is a collapsible section. It's great for long but useful content. -->
<details>
<summary><strong>Click here for a step-by-step guide on using `cast send`</strong></summary>

Here's how you can interact with the deployed contracts on Sepolia using `cast`. Make sure you have loaded your environment variables with `source .env`.

1.  **Wrap some ETH to get WETH**:
    ```bash
    cast send 0xdd13E5529fFd76AfE204dBda4007C227904f0a81 "deposit()" --value 0.1ether --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
    ```

2.  **Approve the `DSCEngine` to spend your WETH**:
    ```bash
    # Approving 1 WETH (1e18)
    cast send 0xdd13E5529fFd76AfE204dBda4007C227904f0a81 "approve(address,uint256)" 0xe5C5598b13c6F27E8988baf002fc417a91D4035E 1000000000000000000 --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
    ```

3.  **Deposit WETH as Collateral**:
    ```bash
    # Depositing 0.1 WETH
    cast send 0xe5C5598b13c6F27E8988baf002fc417a91D4035E "depositCollateral(address,uint256)" 0xdd13E55209Fd76AfE204dBda4007C227904f0a81 100000000000000000 --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
    ```

4.  **Mint DSC**:
    ```bash
    # Minting 100 DSC
    cast send 0xe5C5598b13c6F27E8988baf002fc417a91D4035E "mintDsc(uint256)" 100000000000000000000 --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
    ```

</details>

---

## ⛽ Gas Usage

To generate a gas report for the contracts, run:
```bash
forge snapshot
```
The report will be saved in `.gas-snapshot`.

---

## 🎨 Code Formatting

To format the Solidity code in the project, run:
```bash
forge fmt
```

---

## 🐍 Static Analysis

To run Slither and check for vulnerabilities:
```bash
# Make sure you have slither installed (pip install slither-analyzer)
slither . --config-file slither.config.json
```

---

## 🙏 Acknowledgements

This project is based on the "DeFi Stablecoin" module from the **Cyfrin Updraft** course. A huge thank you to **Patrick Collins** for creating the exceptional educational content that made this possible.

-   [Cyfrin Updraft](https://updraft.cyfrin.io/)
-   [Original Course Repository](https://github.com/Cyfrin/foundry-full-course-f23)

---
