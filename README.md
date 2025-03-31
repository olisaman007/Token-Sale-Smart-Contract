# Token Sale Smart Contract

A Clarity smart contract for conducting token sales on the Stacks blockchain with multiple phases, whitelist functionality, and administrative controls.

## Overview

This project implements a configurable token sale smart contract on the Stacks blockchain. The contract creates a SIP-010 compliant fungible token and manages a multi-phase sale process with whitelist capabilities.

### Features

- **SIP-010 Compliant Token**: Creates a standard-compliant fungible token
- **Multi-Phase Sale**: Supports whitelist and public sale phases
- **Configurable Pricing**: Different prices for each phase
- **Whitelist Management**: Add/remove addresses for early access
- **Purchase Limits**: Set maximum purchase amounts per address
- **Supply Management**: Configurable maximum supply
- **Administrative Controls**: Pause/resume sale, change phases, withdraw funds

## Getting Started

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) for local development and testing
- [Stacks CLI](https://github.com/blockstack/stacks.js) for deployment (optional)

### Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/yourusername/token-sale-contract.git
   cd token-sale-contract
