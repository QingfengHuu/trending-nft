# 部署到测试网

本文档说明如何将 TrendingNFT 合约部署到以太坊测试网。

## 准备工作

1. 获取测试网 ETH:
   - Sepolia: https://sepoliafaucet.com/ 或 https://faucets.chain.link/sepolia
   - Goerli: https://goerlifaucet.com/ 或 https://faucets.chain.link/goerli

2. 获取 API 密钥:
   - INFURA_API_KEY: 在 [Infura](https://infura.io/) 注册并创建项目获取 API 密钥
   - ETHERSCAN_API_KEY: 在 [Etherscan](https://etherscan.io/) 注册并获取 API 密钥

3. 配置环境变量:
   在 `.env` 文件中填写以下信息:
   ```
   PRIVATE_KEY=你的钱包私钥
   INFURA_API_KEY=你的Infura API密钥
   ETHERSCAN_API_KEY=你的Etherscan API密钥
   ```

## 部署步骤

1. 编译合约:
   ```bash
   forge build
   ```

2. 部署到 Sepolia 测试网:
   ```bash
   forge script script/Deploy.s.sol:Deploy --rpc-url sepolia --broadcast --verify -vvvv
   ```

   或部署到 Goerli 测试网:
   ```bash
   forge script script/Deploy.s.sol:Deploy --rpc-url goerli --broadcast --verify -vvvv
   ```

## 验证合约

如果在部署时没有自动验证，可以手动验证:

```bash
forge verify-contract \
  --chain sepolia \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  <合约地址> \
  src/TrendingNFT.sol:TrendingNFT
```

## 环境变量说明

- `PRIVATE_KEY`: 用于部署合约的以太坊账户私钥
- `INFURA_API_KEY`: Infura API 密钥，用于连接到以太坊网络
- `ETHERSCAN_API_KEY`: Etherscan API 密钥，用于验证合约

## 注意事项

1. 永远不要将私钥提交到版本控制系统中
2. 确保有足够的测试网 ETH 支付 gas 费用
3. 部署后记录合约地址以便后续交互