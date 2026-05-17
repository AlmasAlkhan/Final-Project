# Subgraph GraphQL Queries

Subgraph schema: `subgraph/schema.graphql` (9 entities).

Set `SUBGRAPH_URL` in the frontend (see `frontend/config.js`) after deploying to [The Graph Studio](https://thegraph.com/studio/).

---

## Q1 — Global protocol statistics

```graphql
query ProtocolStats {
  protocolStats(id: "global") {
    totalRWAMinted
    totalBorrowed
    totalCertificates
    lastUpdated
  }
}
```

## Q2 — Recent mint events

```graphql
query RecentMints($first: Int = 10) {
  mintEvents(first: $first, orderBy: timestamp, orderDirection: desc) {
    id
    to
    amount
    timestamp
    token { symbol }
  }
}
```

## Q3 — User lending position

```graphql
query LendingPosition($user: ID!) {
  lendingPosition(id: $user) {
    collateral
    debt
    lastUpdated
    borrows(first: 5, orderBy: timestamp, orderDirection: desc) {
      amount
      timestamp
    }
  }
}
```

## Q4 — Active governance proposals

```graphql
query ActiveProposals {
  proposals(where: { state: "Active" }, orderBy: startBlock, orderDirection: desc) {
    id
    description
    state
    forVotes
    againstVotes
    abstainVotes
    startBlock
    endBlock
  }
}
```

## Q5 — Proposal votes breakdown

```graphql
query ProposalVotes($proposalId: ID!) {
  proposal(id: $proposalId) {
    description
    state
    votes(first: 20, orderBy: timestamp, orderDirection: desc) {
      voter
      support
      weight
      reason
      timestamp
    }
  }
}
```

## Q6 — Certificates by owner

```graphql
query CertificatesByOwner($owner: Bytes!) {
  certificates(where: { owner: $owner, active: true }) {
    id
    assetId
    faceValue
    issuedAt
  }
}
```

## Q7 — Liquidation history

```graphql
query RecentLiquidations($first: Int = 10) {
  liquidationEvents(first: $first, orderBy: timestamp, orderDirection: desc) {
    borrower
    liquidator
    debtCovered
    collateralSeized
    timestamp
  }
}
```
