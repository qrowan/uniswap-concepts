# UniswapV2 Study Repository

A repository for learning the core concepts and contract architecture of UniswapV2.

---

## 1. Constant Product AMM (CP-AMM)

UniswapV2 uses the **Constant Product Automated Market Maker** model.

### Core Formula

```
x * y = k (constant)
```

- `x`: Reserve of Token A (amount held in pool)
- `y`: Reserve of Token B (amount held in pool)  
- `k`: Constant (must remain the same before and after swaps)

### How It Works

```
                    ┌─────────────────────────────────────┐
                    │         Liquidity Pool              │
                    │                                     │
                    │   ┌─────────┐     ┌─────────┐      │
                    │   │   ETH   │     │  USDC   │      │
                    │   │   10    │  x  │  20000  │ = k  │
                    │   └─────────┘     └─────────┘      │
                    │                                     │
                    │        k = 200,000 (constant)       │
                    └─────────────────────────────────────┘
```

### Swap Example: 1 ETH → USDC

```
[Before Swap]
┌──────────────────────────────────────────────────────────┐
│  Pool: 10 ETH × 20,000 USDC = 200,000 (k)               │
│  Price: 1 ETH = 2,000 USDC                               │
└──────────────────────────────────────────────────────────┘
                            │
                            ▼
                   User deposits 1 ETH
                            │
                            ▼
┌──────────────────────────────────────────────────────────┐
│  New ETH Reserve: 10 + 1 = 11 ETH                        │
│  k must remain: 200,000                                  │
│  New USDC Reserve: 200,000 ÷ 11 = 18,181.82 USDC        │
│  USDC Output: 20,000 - 18,181.82 = 1,818.18 USDC        │
└──────────────────────────────────────────────────────────┘
                            │
                            ▼
[After Swap]
┌──────────────────────────────────────────────────────────┐
│  Pool: 11 ETH × 18,181.82 USDC = 200,000 (k)            │
│  New Price: 1 ETH = 1,652.89 USDC                        │
│  User received: 1,818.18 USDC (not 2,000!)              │
└──────────────────────────────────────────────────────────┘

※ In practice, a 0.3% fee is deducted, so the actual output is slightly less.
```

### Price Impact

Larger trades result in worse execution prices:

```
┌────────────────────────────────────────────────────────────────┐
│                     Price Impact Curve                         │
│                                                                │
│  Price │                                                       │
│  (USDC │ ●                                                     │
│  /ETH) │   ●                                                   │
│        │     ●●                                                │
│  2000  │─ ─ ─ ●●● ─ ─ ─ ─ ─ ─  Spot Price                     │
│        │          ●●●●                                         │
│        │              ●●●●●●                                   │
│        │                    ●●●●●●●●●●                         │
│        │                              ●●●●●●●●●●●●●●           │
│        └────────────────────────────────────────────► Trade    │
│              0.1   1    5    10   (ETH)              Size      │
│                                                                │
│  Small trades: Execute close to Spot Price                     │
│  Large trades: Execute at worse prices (High Slippage)         │
└────────────────────────────────────────────────────────────────┘
```

### 0.3% Fee

A 0.3% fee is charged on every swap:

```
┌─────────────────────────────────────────────────────────────┐
│                      Fee Structure                          │
│                                                             │
│  User Input: 1 ETH                                          │
│       │                                                     │
│       ▼                                                     │
│  ┌─────────────────────────────────────────┐               │
│  │  0.997 ETH → Used for Swap Calculation   │               │
│  │  0.003 ETH → Stays in Pool (LP Reward)   │               │
│  └─────────────────────────────────────────┘               │
│       │                                                     │
│       ▼                                                     │
│  Output: ~1,812.73 USDC (after fee + slippage)             │
│                                                             │
│  ※ Fees remain in the pool, increasing LP share value      │
└─────────────────────────────────────────────────────────────┘
```

---

## 2. Contract Architecture

UniswapV2 consists of 3 core contracts:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        UniswapV2 Architecture                           │
│                                                                         │
│   ┌─────────────┐         ┌─────────────┐         ┌─────────────┐      │
│   │    User     │────────▶│   Router    │────────▶│   Factory   │      │
│   └─────────────┘         └─────────────┘         └─────────────┘      │
│         │                       │                        │              │
│         │                       │                        │ creates      │
│         │                       │                        ▼              │
│         │                       │                 ┌─────────────┐      │
│         │                       │                 │    Pair     │      │
│         │                       │                 │  (ETH-USDC) │      │
│         │                       │                 └─────────────┘      │
│         │                       │                        │              │
│         │                       │                 ┌─────────────┐      │
│         │                       └────────────────▶│    Pair     │      │
│         │                         interacts       │  (ETH-DAI)  │      │
│         │                                         └─────────────┘      │
│         │                                                │              │
│         └────────────────────────────────────────────────┘              │
│                          (LP tokens)                                    │
└─────────────────────────────────────────────────────────────────────────┘
```

---

### 2.1 Factory Contract

**Role**: A factory that creates and manages Pair contracts

```
┌─────────────────────────────────────────────────────────────────┐
│                     UniswapV2Factory                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Functions:                                                     │
│  ┌────────────────────────────────────────────────────────┐    │
│  │  createPair(tokenA, tokenB)                             │    │
│  │  ├─ Creates a new Pair contract for two tokens          │    │
│  │  ├─ Uses CREATE2 for deterministic address generation   │    │
│  │  └─ Cannot create duplicate pairs                       │    │
│  └────────────────────────────────────────────────────────┘    │
│  ┌────────────────────────────────────────────────────────┐    │
│  │  getPair(tokenA, tokenB) → address                      │    │
│  │  └─ Returns the Pair address for a token pair           │    │
│  └────────────────────────────────────────────────────────┘    │
│  ┌────────────────────────────────────────────────────────┐    │
│  │  allPairs(index) → address                              │    │
│  │  └─ Returns all created Pairs                           │    │
│  └────────────────────────────────────────────────────────┘    │
│                                                                 │
│  State:                                                         │
│  ┌────────────────────────────────────────────────────────┐    │
│  │  feeTo        : Address receiving protocol fees (0.05%) │    │
│  │  feeToSetter  : Admin who can set feeTo                 │    │
│  │  allPairs[]   : Array of all Pair contracts             │    │
│  │  getPair[][]  : tokenA → tokenB → Pair mapping          │    │
│  └────────────────────────────────────────────────────────┘    │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘

CREATE2 Address Calculation:
┌─────────────────────────────────────────────────────────────────┐
│  pair_address = keccak256(                                      │
│      0xff,                                                      │
│      factory_address,                                           │
│      keccak256(token0, token1),    // salt                      │
│      init_code_hash               // Pair bytecode hash         │
│  )                                                              │
│                                                                 │
│  ※ This allows calculating Pair addresses without on-chain     │
│    queries                                                      │
└─────────────────────────────────────────────────────────────────┘
```

---

### 2.2 Pair Contract

**Role**: The core contract that holds liquidity and executes swaps

```
┌─────────────────────────────────────────────────────────────────┐
│                      UniswapV2Pair                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │                    Token Reserves                          │ │
│  │  ┌─────────────────┐         ┌─────────────────┐          │ │
│  │  │    Token0       │         │    Token1       │          │ │
│  │  │   (reserve0)    │         │   (reserve1)    │          │ │
│  │  │                 │         │                 │          │ │
│  │  │   10 WETH       │    ×    │   20000 USDC    │ = k      │ │
│  │  └─────────────────┘         └─────────────────┘          │ │
│  └───────────────────────────────────────────────────────────┘ │
│                                                                 │
│  Core Functions:                                                │
│  ┌────────────────────────────────────────────────────────┐    │
│  │  mint(to) → liquidity                                   │    │
│  │  ├─ Receives tokens and mints LP tokens                 │    │
│  │  ├─ First LP: sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY│   │
│  │  └─ After: min(amount0/reserve0, amount1/reserve1)*total│    │
│  └────────────────────────────────────────────────────────┘    │
│  ┌────────────────────────────────────────────────────────┐    │
│  │  burn(to) → (amount0, amount1)                          │    │
│  │  ├─ Receives LP tokens and returns underlying tokens    │    │
│  │  └─ Return amount = liquidity / totalSupply * reserves  │    │
│  └────────────────────────────────────────────────────────┘    │
│  ┌────────────────────────────────────────────────────────┐    │
│  │  swap(amount0Out, amount1Out, to, data)                 │    │
│  │  ├─ Executes token swap (low-level)                     │    │
│  │  ├─ Verifies k invariant (with 0.3% fee)                │    │
│  │  └─ Supports Flash Swaps (when data.length > 0)         │    │
│  └────────────────────────────────────────────────────────┘    │
│                                                                 │
│  LP Token (ERC20):                                              │
│  ┌────────────────────────────────────────────────────────┐    │
│  │  The Pair contract itself is an ERC20 token             │    │
│  │  LPs hold this token → proves pool ownership            │    │
│  │  Fees auto-accumulate in reserves → LP value increases  │    │
│  └────────────────────────────────────────────────────────┘    │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘

Swap Flow (Low-level):
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│  1. User sends Token0 to Pair contract                          │
│  2. Call swap(0, amountOut, to, "")                            │
│  3. Pair sends Token1 to user                                   │
│  4. Pair verifies: new_k >= old_k (with fee)                   │
│                                                                 │
│  ※ Verification formula:                                        │
│  (balance0 * 1000 - amount0In * 3) *                           │
│  (balance1 * 1000 - amount1In * 3) >= reserve0 * reserve1 * 1M │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

### 2.3 Router Contract

**Role**: Provides a user-friendly interface (Helper)

```
┌─────────────────────────────────────────────────────────────────┐
│                    UniswapV2Router02                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  The Router wraps Pair's low-level functions                    │
│  to make them easier to use.                                    │
│                                                                 │
│  Liquidity Functions:                                           │
│  ┌────────────────────────────────────────────────────────┐    │
│  │  addLiquidity(tokenA, tokenB, amountA, amountB, ...)   │    │
│  │  ├─ Calculates optimal ratio                            │    │
│  │  ├─ Transfers tokens → calls Pair.mint()                │    │
│  │  └─ Refunds excess tokens                               │    │
│  └────────────────────────────────────────────────────────┘    │
│  ┌────────────────────────────────────────────────────────┐    │
│  │  addLiquidityETH(token, amountToken, ...)              │    │
│  │  ├─ Converts ETH → WETH                                 │    │
│  │  └─ Executes addLiquidity                               │    │
│  └────────────────────────────────────────────────────────┘    │
│  ┌────────────────────────────────────────────────────────┐    │
│  │  removeLiquidity / removeLiquidityETH                  │    │
│  │  └─ Withdraws LP tokens → original tokens              │    │
│  └────────────────────────────────────────────────────────┘    │
│                                                                 │
│  Swap Functions:                                                │
│  ┌────────────────────────────────────────────────────────┐    │
│  │  swapExactTokensForTokens(amountIn, amountOutMin, ...) │    │
│  │  ├─ Specifies exact input amount                        │    │
│  │  ├─ Output amount calculated by AMM                     │    │
│  │  └─ amountOutMin provides slippage protection           │    │
│  └────────────────────────────────────────────────────────┘    │
│  ┌────────────────────────────────────────────────────────┐    │
│  │  swapTokensForExactTokens(amountOut, amountInMax, ...) │    │
│  │  ├─ Specifies exact output amount                       │    │
│  │  ├─ Input amount calculated by AMM                      │    │
│  │  └─ amountInMax provides slippage protection            │    │
│  └────────────────────────────────────────────────────────┘    │
│  ┌────────────────────────────────────────────────────────┐    │
│  │  swapExactETHForTokens / swapETHForExactTokens         │    │
│  │  swapExactTokensForETH / swapTokensForExactETH         │    │
│  │  └─ Automatically handles ETH ↔ WETH conversion        │    │
│  └────────────────────────────────────────────────────────┘    │
│                                                                 │
│  Quote Functions:                                               │
│  ┌────────────────────────────────────────────────────────┐    │
│  │  getAmountsOut(amountIn, path) → amounts[]             │    │
│  │  └─ Calculates expected output for given input          │    │
│  └────────────────────────────────────────────────────────┘    │
│  ┌────────────────────────────────────────────────────────┐    │
│  │  getAmountsIn(amountOut, path) → amounts[]             │    │
│  │  └─ Calculates required input for desired output        │    │
│  └────────────────────────────────────────────────────────┘    │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

### Contract Interaction Flow

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          Add Liquidity Flow                             │
│                                                                         │
│   User                Router                 Factory            Pair    │
│    │                    │                      │                  │     │
│    │  addLiquidityETH   │                      │                  │     │
│    │  (ETH + USDC)      │                      │                  │     │
│    │───────────────────▶│                      │                  │     │
│    │                    │   getPair(WETH,USDC) │                  │     │
│    │                    │─────────────────────▶│                  │     │
│    │                    │◀─────────────────────│                  │     │
│    │                    │   (pair address)     │                  │     │
│    │                    │                      │                  │     │
│    │                    │   If pair == 0:      │                  │     │
│    │                    │   createPair()       │                  │     │
│    │                    │─────────────────────▶│                  │     │
│    │                    │                      │─────────────────▶│     │
│    │                    │                      │    deploy Pair   │     │
│    │                    │                      │◀─────────────────│     │
│    │                    │◀─────────────────────│                  │     │
│    │                    │                      │                  │     │
│    │                    │   Transfer tokens to Pair               │     │
│    │                    │────────────────────────────────────────▶│     │
│    │                    │                      │                  │     │
│    │                    │   mint(user)         │                  │     │
│    │                    │────────────────────────────────────────▶│     │
│    │                    │                      │                  │     │
│    │  LP tokens         │◀────────────────────────────────────────│     │
│    │◀───────────────────│                      │                  │     │
│    │                    │                      │                  │     │
└─────────────────────────────────────────────────────────────────────────┘


┌─────────────────────────────────────────────────────────────────────────┐
│                            Swap Flow                                    │
│                                                                         │
│   User                Router                              Pair          │
│    │                    │                                  │            │
│    │  swapExactETH      │                                  │            │
│    │  ForTokens         │                                  │            │
│    │  (0.1 ETH→USDC)    │                                  │            │
│    │───────────────────▶│                                  │            │
│    │                    │                                  │            │
│    │                    │  1. Wrap ETH → WETH              │            │
│    │                    │                                  │            │
│    │                    │  2. Calculate output             │            │
│    │                    │     getAmountsOut()              │            │
│    │                    │                                  │            │
│    │                    │  3. Transfer WETH to Pair        │            │
│    │                    │─────────────────────────────────▶│            │
│    │                    │                                  │            │
│    │                    │  4. swap(0, amountOut, user, "") │            │
│    │                    │─────────────────────────────────▶│            │
│    │                    │                                  │            │
│    │                    │                      Verify k    │            │
│    │                    │                      Send USDC   │            │
│    │  USDC              │◀─────────────────────────────────│            │
│    │◀───────────────────│                                  │            │
│    │                    │                                  │            │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 3. LP Token & Fee Distribution

### LP Token Minting Formula

```
┌─────────────────────────────────────────────────────────────────┐
│                    LP Token Minting                             │
│                                                                 │
│  [First Liquidity Provider]                                     │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  liquidity = sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY │   │
│  │                                                          │   │
│  │  Example: 10 ETH + 20000 USDC                           │   │
│  │  liquidity = sqrt(10e18 * 20000e6) - 1000               │   │
│  │           = sqrt(2e26) - 1000                           │   │
│  │           ≈ 447,213,595,499,957 - 1000                  │   │
│  │           ≈ 447.21 LP tokens                            │   │
│  │                                                          │   │
│  │  ※ MINIMUM_LIQUIDITY (1000) is permanently locked       │   │
│  │    → Prevents pool from being fully drained             │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  [Subsequent Liquidity Providers]                               │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  liquidity = min(                                        │   │
│  │      amount0 * totalSupply / reserve0,                   │   │
│  │      amount1 * totalSupply / reserve1                    │   │
│  │  )                                                       │   │
│  │                                                          │   │
│  │  Example: 5 ETH + 10000 USDC (adding to existing pool)  │   │
│  │  liquidity = min(5/10, 10000/20000) * 447.21            │   │
│  │           = 0.5 * 447.21                                │   │
│  │           ≈ 223.61 LP tokens                            │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Fee Distribution

```
┌─────────────────────────────────────────────────────────────────┐
│                    Fee Distribution                             │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                  0.3% Swap Fee                           │   │
│  │                       │                                  │   │
│  │          ┌────────────┴────────────┐                    │   │
│  │          ▼                         ▼                    │   │
│  │    ┌──────────┐             ┌──────────┐                │   │
│  │    │   0.25%  │             │   0.05%  │                │   │
│  │    │    LP    │             │ Protocol │                │   │
│  │    │ Rewards  │             │   Fee    │                │   │
│  │    └──────────┘             └──────────┘                │   │
│  │         │                        │                      │   │
│  │         ▼                        ▼                      │   │
│  │  Stays in pool            feeTo address                 │   │
│  │  (increases k)          (if enabled)                    │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  How LPs Realize Profits:                                       │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Fees → k increases → reserves increase → LP value rises │   │
│  │                                                          │   │
│  │  On withdrawal:                                          │   │
│  │  amount = (myLP / totalLP) * reserves                   │   │
│  │  → Receive principal + accumulated fees                  │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 4. Key Concepts Summary

| Concept | Description |
|---------|-------------|
| **Constant Product** | `x * y = k` - Product remains constant before and after swaps (excluding fees) |
| **Price Impact** | Larger trades execute at worse prices |
| **Slippage** | Difference between expected price and actual execution price |
| **LP Token** | ERC20 token representing pool ownership share |
| **MINIMUM_LIQUIDITY** | 1000 wei permanently locked from first LP (prevents pool drain) |
| **Flash Swap** | Borrow tokens without collateral, repay in same transaction |

---

## 5. Scenario Test Results

Run: `forge test -vv --mc UniswapV2ScenariosTest`

### Scenario 1: Initial Liquidity Provision (Pool Creation)

```
============================================================
   SCENARIO 1: Initial Liquidity Provision (Pool Creation)
============================================================

[SITUATION]
  Alice wants to create a new ETH-USDC liquidity pool.
  She will set the initial price: 1 ETH = 2,000 USDC

[BEFORE] Alice's Wallet:
  ETH Balance:   100.0000 ETH
  USDC Balance:  200000.00 USDC

[ACTION] Alice adds liquidity to create new pool:
  Depositing:  10.0000 ETH
  Depositing:  20000.00 USDC

[RESULT] Pool Created!
  Pair Address:  0xD02A65fe8aE83aF26734d062A6ecBd2238A20056
  ETH Added:     10.0000 ETH
  USDC Added:    20000.00 USDC

[RESULT] LP Tokens Minted:
  Alice received:       0.000447 LP
  MINIMUM_LIQUIDITY:    0.000000 LP (permanently locked)
  Total LP Supply:      0.000447 LP

[AFTER] Alice's Wallet:
  ETH Balance:   90.0000 ETH
  USDC Balance:  180000.00 USDC
  LP Balance:    0.000447 LP

[POOL STATE]
  ETH Reserve:   10.0000 ETH
  USDC Reserve:  20000.00 USDC
  Spot Price:   1 ETH =  2000.00 USDC

[KEY CONCEPT]
  LP Token Formula: sqrt(ETH * USDC) - MINIMUM_LIQUIDITY
  sqrt(10 * 20000) = sqrt(200000) ~= 447.21
  Alice's LP = 447.21 - 0.000001 (min liquidity) ~= 447.21 LP tokens
```

---

### Scenario 2: Add Liquidity to Existing Pool

```
============================================================
   SCENARIO 2: Add Liquidity to Existing Pool
============================================================

[SITUATION]
  Alice has already created the ETH-USDC pool.
  Bob wants to add liquidity to earn trading fees.

[BEFORE] Pool State:
  ETH Reserve:     10.0000 ETH
  USDC Reserve:    20000.00 USDC
  Total LP Supply: 0.000447 LP
  Current Price:  1 ETH =  2000.00 USDC

[BEFORE] Bob's Wallet:
  ETH Balance:   50.0000 ETH
  USDC Balance:  100000.00 USDC
  LP Balance:    0.000000 LP

[ACTION] Bob adds liquidity:
  Depositing:  5.0000 ETH
  Depositing:  10000.00 USDC
  (Ratio matches pool: 1 ETH = 2000 USDC)

[RESULT] Liquidity Added:
  ETH Used:      5.0000 ETH
  USDC Used:     10000.00 USDC
  LP Received:   0.000224 LP

[AFTER] Bob's Wallet:
  ETH Balance:   45.0000 ETH
  USDC Balance:  90000.00 USDC
  LP Balance:    0.000224 LP

[AFTER] Pool State:
  ETH Reserve:     15.0000 ETH
  USDC Reserve:    30000.00 USDC
  Total LP Supply: 0.000671 LP
  Price (unchanged): 1 ETH =  2000.00 USDC

[OWNERSHIP]
  Alice's Share:  66 %
  Bob's Share:    33 %

[KEY CONCEPT]
  Bob added 50% of Alice's liquidity (5 ETH vs 10 ETH)
  Bob receives 50% of Alice's LP tokens
  Pool ownership: Alice ~67%, Bob ~33%
```

---

### Scenario 3: Swap - Exact Input (0.1 ETH -> USDC)

```
============================================================
   SCENARIO 3: Swap - Exact Input (0.1 ETH -> USDC)
============================================================

[SITUATION]
  Charlie wants to exchange ETH for USDC.
  He has exactly 0.1 ETH and wants to know how much USDC he'll get.
  (Exact Input Swap: input is fixed, output varies)

[BEFORE] Pool State:
  ETH Reserve:   10.0000 ETH
  USDC Reserve:  20000.00 USDC
  Spot Price:   1 ETH =  2000.00 USDC

[BEFORE] Charlie's Wallet:
  ETH Balance:   10.0000 ETH
  USDC Balance:  0.00 USDC

[PREVIEW] Expected Swap Result:
  Input:                   0.1000 ETH
  Theoretical Output:      200.00 USDC (at spot price)
  Actual Expected Output:  197.43 USDC (after 0.3% fee + slippage)

[ACTION] Charlie swaps 0.1 ETH for USDC...

[RESULT] Swap Completed:
  ETH Spent:       0.1000 ETH
  USDC Received:   197.43 USDC
  Effective Rate: 1 ETH =  1974.32 USDC

[AFTER] Charlie's Wallet:
  ETH Balance:   9.9000 ETH
  USDC Balance:  197.43 USDC

[AFTER] Pool State:
  ETH Reserve:    10.1000 ETH (increased)
  USDC Reserve:   19802.57 USDC (decreased)
  New Spot Price: 1 ETH =  1960.65 USDC

[ANALYSIS]
  Spot Price Before:      2000.00 USDC
  Effective Price:        1974.32 USDC
  Spot Price After:       1960.65 USDC
  Price Impact:           128 bps (1.28%)
  Price Moved:           - 39.35 USDC per ETH

[KEY CONCEPT]
  x * y = k (Constant Product Formula)
  After swap: More ETH in pool, Less USDC -> ETH price drops
  0.3% fee is retained in pool (benefits LPs)
```

---

### Scenario 4: Swap - Exact Output (ETH -> 10 USDC)

```
============================================================
   SCENARIO 4: Swap - Exact Output (ETH -> 10 USDC)
============================================================

[SITUATION]
  Charlie needs exactly 10 USDC to pay for something.
  He wants to know how much ETH he needs to spend.
  (Exact Output Swap: output is fixed, input varies)

[BEFORE] Pool State:
  ETH Reserve:   10.0000 ETH
  USDC Reserve:  20000.00 USDC
  Spot Price:   1 ETH =  2000.00 USDC

[BEFORE] Charlie's Wallet:
  ETH Balance:   10.0000 ETH
  USDC Balance:  0.00 USDC

[PREVIEW] Expected Swap Result:
  Desired Output:          10.00 USDC
  Theoretical Input:       0.005000 ETH (at spot price)
  Actual Expected Input:   0.005018 ETH (with 0.3% fee + slippage)

[ACTION] Charlie swaps ETH for exactly 10 USDC...
  (Sending  1.0000  ETH as max, unused will be refunded)

[RESULT] Swap Completed:
  ETH Spent:         0.005018 ETH
  ETH Refunded:      0.9950 ETH
  USDC Received:     10.00 USDC (exactly as requested!)
  Effective Rate:   1 ETH =  1993.00 USDC

[AFTER] Charlie's Wallet:
  ETH Balance:   9.9950 ETH
  USDC Balance:  10.00 USDC

[COST ANALYSIS]
  Theoretical Cost:   0.005000 ETH
  Actual Cost:        0.005018 ETH
  Overhead (fee+slip): 0.000018 ETH
  Overhead %:         35 bps (0.35%)

[KEY CONCEPT]
  Exact Output swaps guarantee you get the exact amount you need.
  You send more ETH than needed, excess is automatically refunded.
  Useful when you need a specific amount of tokens (e.g., to pay a bill).
```

---

## 6. Running Tests

```bash
# Run all tests
forge test

# Run scenario tests (with detailed logs)
forge test --match-contract UniswapV2ScenariosTest -vvv

# Run specific test
forge test --match-test test_Scenario1 -vvv
```

---

## References

- [Uniswap V2 Whitepaper](https://uniswap.org/whitepaper.pdf)
- [Uniswap V2 Core](https://github.com/Uniswap/v2-core)
- [Uniswap V2 Periphery](https://github.com/Uniswap/v2-periphery)
