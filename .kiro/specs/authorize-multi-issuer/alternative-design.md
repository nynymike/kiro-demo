# Alternative Design: Simplified Cedar Policy Syntax

## Problem Statement

The current design creates unergonomic Cedar policy syntax:

```cedar
permit(
  principal,
  action == Acme::Action::"GetFood",
  resource in Acme::Resources::"ApprovedDolphinFoods"
) when {
  "idp.dolphin.sea" in context.token_collection.issuer_joined &&
  "Jans::Access_Token" in context.token_collection.issuer_joined["idp.dolphin.sea"] &&
  context.token_collection.issuer_joined["idp.dolphin.sea"]["Jans::Access_Token"].claims has "location" &&
  context.token_collection.issuer_joined["idp.dolphin.sea"]["Jans::Access_Token"].claims.location == "miami"
};
```

This is:
- Hard to read and write
- Error-prone due to repetition
- Difficult to maintain
- Not developer-friendly

## Design Goals for Alternative

1. **Ergonomic Policy Syntax** - Policies should be easy to read and write
2. **Minimal Repetition** - Avoid repeating long paths multiple times
3. **Intuitive Structure** - Policy authors should easily understand the token structure
4. **Scalable** - Handle arbitrary token types without explosion
5. **Cedar Compatible** - Work within Cedar's limitations

## Alternative 1: Flattened Token Collections with Smart Naming

### Structure
```cedar
entity TokenCollection = {
  // Format: {issuer_domain}_{token_type}
  "dolphin_sea_access_token": Token,           // Single joined access token from dolphin.sea
  "dolphin_sea_id_token": Token,               // Single joined ID token from dolphin.sea
  "google_access_token": Token,                // Single joined access token from google.com
  "acme_dolphin_token": Token,                 // Single joined Acme::DolphinToken
  "total_token_count": Long,
};
```

### Policy Syntax
```cedar
permit(
  principal,
  action == Acme::Action::"GetFood",
  resource in Acme::Resources::"ApprovedDolphinFoods"
) when {
  context.token_collection has "dolphin_sea_access_token" &&
  context.token_collection.dolphin_sea_access_token.claims has "location" &&
  context.token_collection.dolphin_sea_access_token.claims.location == "miami"
};
```

**Pros:**
- Much cleaner syntax
- Easy to read and write
- No repetition

**Cons:**
- Field names must be generated dynamically
- Potential naming conflicts
- Still some explosion (but manageable)

## Alternative 2: Context Variables Approach

### Structure
```cedar
entity TokenCollection = {
  "tokens": Record<String, Token>,             // All tokens by unique ID
  "by_issuer_type": Record<String, String>,   // Maps "issuer:type" -> token_id
  "total_token_count": Long,
};
```

### Policy Syntax
```cedar
permit(
  principal,
  action == Acme::Action::"GetFood",
  resource in Acme::Resources::"ApprovedDolphinFoods"
) when {
  "idp.dolphin.sea:Jans::Access_Token" in context.token_collection.by_issuer_type &&
  context.token_collection.tokens[
    context.token_collection.by_issuer_type["idp.dolphin.sea:Jans::Access_Token"]
  ].claims has "location" &&
  context.token_collection.tokens[
    context.token_collection.by_issuer_type["idp.dolphin.sea:Jans::Access_Token"]
  ].claims.location == "miami"
};
```

**Pros:**
- No field explosion
- Handles arbitrary token types

**Cons:**
- Still repetitive
- Complex nested lookups
- Not much better than original

## Alternative 3: Simplified Issuer-Only Structure

### Structure
```cedar
entity TokenCollection = {
  "issuers": Record<String, IssuerTokens>,     // One entry per issuer
  "total_token_count": Long,
};

entity IssuerTokens = {
  "access_token": Token,                       // Joined access token (if any)
  "id_token": Token,                          // Joined ID token (if any)
  "userinfo_token": Token,                    // Joined userinfo token (if any)
  "custom_tokens": Record<String, Token>,     // Custom token types by name
};
```

### Policy Syntax
```cedar
permit(
  principal,
  action == Acme::Action::"GetFood",
  resource in Acme::Resources::"ApprovedDolphinFoods"
) when {
  "idp.dolphin.sea" in context.token_collection.issuers &&
  context.token_collection.issuers["idp.dolphin.sea"].access_token.claims has "location" &&
  context.token_collection.issuers["idp.dolphin.sea"].access_token.claims.location == "miami"
};
```

**Pros:**
- Much cleaner syntax
- Intuitive structure
- Handles common token types elegantly
- Extensible with custom_tokens

**Cons:**
- Requires predefined common token types
- Custom tokens still need nested access

## Alternative 4: Helper Functions Approach (If Cedar Supports)

### Structure
```cedar
entity TokenCollection = {
  "issuer_joined": Record<String, Record<String, Token>>,
  "total_token_count": Long,
};

// Helper function (if Cedar supports)
function getToken(issuer: String, tokenType: String): Token {
  context.token_collection.issuer_joined[issuer][tokenType]
}
```

### Policy Syntax
```cedar
permit(
  principal,
  action == Acme::Action::"GetFood",
  resource in Acme::Resources::"ApprovedDolphinFoods"
) when {
  getToken("idp.dolphin.sea", "Jans::Access_Token").claims has "location" &&
  getToken("idp.dolphin.sea", "Jans::Access_Token").claims.location == "miami"
};
```

**Status:** Need to verify if Cedar supports custom functions.

## Alternative 5: Hybrid Approach - Common + Custom

### Structure
```cedar
entity TokenCollection = {
  // Common token types flattened by issuer
  "dolphin_sea_access": Token,
  "dolphin_sea_id": Token,
  "google_access": Token,
  "google_id": Token,
  
  // Custom tokens for non-standard types
  "custom": Record<String, Record<String, Token>>,  // issuer -> token_type -> token
  
  "total_token_count": Long,
};
```

### Policy Syntax for Common Tokens
```cedar
permit(
  principal,
  action == Acme::Action::"GetFood",
  resource in Acme::Resources::"ApprovedDolphinFoods"
) when {
  context.token_collection has "dolphin_sea_access" &&
  context.token_collection.dolphin_sea_access.claims has "location" &&
  context.token_collection.dolphin_sea_access.claims.location == "miami"
};
```

### Policy Syntax for Custom Tokens
```cedar
permit(
  principal,
  action == Acme::Action::"SwimWithDolphins",
  resource
) when {
  "idp.dolphin.sea" in context.token_collection.custom &&
  "Acme::DolphinToken" in context.token_collection.custom["idp.dolphin.sea"] &&
  context.token_collection.custom["idp.dolphin.sea"]["Acme::DolphinToken"].claims has "clearance" &&
  context.token_collection.custom["idp.dolphin.sea"]["Acme::DolphinToken"].claims.clearance == "advanced"
};
```

**Pros:**
- Clean syntax for common cases (90% of policies)
- Handles custom tokens when needed
- Balances ergonomics with flexibility

**Cons:**
- Two different patterns to learn
- Still verbose for custom tokens

## Recommendation: Alternative 3 (Simplified Issuer-Only)

I recommend **Alternative 3** because:

1. **Clean Syntax**: `context.token_collection.issuers["idp.dolphin.sea"].access_token.claims.location == "miami"`
2. **Intuitive**: Matches how developers think about tokens (by issuer, then by type)
3. **Extensible**: Custom tokens handled via `custom_tokens` record
4. **Readable**: Policy intent is clear
5. **Maintainable**: Easy to modify and debug

### Implementation Details

The Token Collection Builder would:
1. Group tokens by issuer
2. For each issuer, create an `IssuerTokens` entity
3. Map common token types to dedicated fields
4. Put custom token types in the `custom_tokens` record
5. Join tokens of the same type from the same issuer

This provides the best balance of ergonomics, flexibility, and Cedar compatibility.