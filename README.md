# Basic Trustless Asset Swap Vault

This project demonstrates how to implement a trustless asset swap using Uniswap.

To use, clone the github and run ```npm install```

Then deploy the script folder using npm run scripts/sample-script.js.

- The deployment will deploy the TrustlessAssetLockFactory.sol
- The contract will allow a user deposit funds
- Then swap to a destination token using Uniswap and store destination token in the contract.
- Withdraw the token after the timeout has elapsed OR allow a named beneficiary withdraw the token before the timeout has elapsed.

Future improvements:
- Including the ERC165 type checker
- Including chainlink pricefeed oracle for better swapping.
