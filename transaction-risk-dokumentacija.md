# Transaction Risk Logistic Regression

## Purpose and architecture

The transaction-risk module estimates the probability that an external Send Money transaction
requires manual review. `TransactionService` supplies the current transfer context, while
`TransactionRiskService` calculates historical features with database-side aggregate queries and
passes the resulting vector to `TransactionRiskLogisticModel`.

The model is separate from `LoanRecommendationService`; the two modules solve different problems.

## Model provenance and limitation

The repository does not contain a labelled transaction-fraud dataset or an existing trained model
artifact. Therefore, version `transaction-risk-logreg-v1` is a deterministic, rule-informed,
preconfigured logistic-regression inference model for the academic/demo scenario. It is not claimed
to be trained or empirically validated, and no accuracy, precision, recall or AUC is claimed.

For production use, the coefficients should be replaced by parameters trained and validated on an
appropriately governed labelled dataset, without changing the runtime feature contract.

## Feature vector and preprocessing

All features are numeric and clipped to a documented range to prevent a single extreme value from
making the linear score unstable.

| Feature | Existing data source | Calculation and normalization | Rationale |
|---|---|---|---|
| `amountBamNormalized` | Requested amount and currency conversion service | `clip(amountBAM / 10000, 0, 3)` | Larger transfers generally warrant more scrutiny. |
| `sourceBalanceRatio` | Debit amount and current source-account balance | `clip(sourceDebit / sourceBalance, 0, 2)` | A transfer consuming most of the available balance is less typical. |
| `outgoingVelocity24Hours` | Outgoing transactions from the customer's accounts | `clip(outgoingCount24h / 5, 0, 2)` | Rapid repeated outgoing activity increases risk. |
| `outgoingVolume7Days` | Grouped outgoing `TransferAmount`/`TransferCurrency` | Convert grouped sums to BAM, then `clip(volumeBAM / 50000, 0, 3)` | Captures recent monetary velocity without loading transaction history. |
| `historicalAmountDeviation` | Completed outgoing transfers in the same currency during 30 days | `clip(max(currentAmount / averageAmount - 1, 0), 0, 3)`; zero without comparable history | Transactions far above the customer's recent norm are less typical. |
| `newRecipient` | Previous completed transfers to `DestinationAccountId` | `1` when no previous completed transfer exists, otherwise `0` | A previously unseen recipient contributes risk. |
| `adverseHistory30Days` | Failed transactions previously marked high-risk | `clip(adverseCount30d / 3, 0, 2)` | Recent rejected high-risk activity contributes to the estimate. |

No demographic or other sensitive customer attributes are used. Historical features are calculated
with `CountAsync`, `AnyAsync`, `AverageAsync` and grouped `Sum` queries. The complete transaction
history is never loaded into application memory.

## Logistic-regression formula

The model calculates:

```text
z = b0 + b1*x1 + b2*x2 + b3*x3 + b4*x4 + b5*x5 + b6*x6 + b7*x7
p = 1 / (1 + exp(-z))
```

The result is constrained to the interval `[0, 1]`.

| Parameter | Value |
|---|---:|
| Intercept | -3.9 |
| BAM-normalized amount | 3.0 |
| Source balance ratio | 1.2 |
| 24-hour velocity | 0.8 |
| 7-day volume | 0.7 |
| Historical amount deviation | 0.7 |
| New recipient | 0.8 |
| Adverse history | 1.0 |

## Decision threshold and persistence

`TransactionRisk:ReviewThreshold` is centrally configured as `0.60`.

```text
IsHighRisk = probability >= 0.60
```

Every new external Send Money debit transaction stores `RiskProbability`, `IsHighRiskReview`, and
`RiskModelVersion`. Legacy transactions retain `null` probability/version rather than receiving an
invented historical score.

High-risk transactions remain Pending without immediate balance movement and enter Transaction
Review. Low-risk transactions complete through the existing atomic transfer flow. Admin approval
books the pending transfer; rejection preserves the ledger and does not move balances.

## Example

For a BAM 10,000 transfer to a known recipient, with a BAM 100,000 source balance, no recent
velocity/adverse history, and a comparable historical average, an example vector is:

```text
[1.0, 0.1, 0, 0.2, 0, 0, 0]
z = -3.9 + 3.0*1.0 + 1.2*0.1 + 0.7*0.2 = -0.64
p = sigmoid(-0.64) = approximately 0.345
```

That example remains below the `0.60` review threshold. The same amount can exceed the threshold
when its balance ratio, velocity, recipient novelty, volume or adverse-history context is riskier.
