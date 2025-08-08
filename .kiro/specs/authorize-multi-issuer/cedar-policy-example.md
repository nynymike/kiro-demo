# Cedar Policy Example: Single Token Property Query

## Goal
Create a valid Cedar policy that checks if there's an access token with location="miami" claim.

## Token Structure
Each token becomes a Cedar entity:

```cedar
entity Token = {
  "token_type": String,                  // e.g., "Jans::Access_Token"
  "jti": String,                         // Unique identifier
  "issuer": String,                      // JWT issuer claim
  "claims": Record<String, EntityValue>, // All JWT claims as key-value pairs
  "validated_at": Long,                  // Timestamp when token was validated
};
```

## Token Collection Structure
```cedar
entity TokenCollection = {
  // Format: {issuer_domain}_{token_type}
  "dolphin_sea_access_token": Token,           // Single joined access token from idp.dolphin.sea
  "dolphin_sea_id_token": Token,               // Single joined ID token from idp.dolphin.sea  
  "google_access_token": Token,                // Single joined access token from accounts.google.com
  "acme_dolphin_token": Token,                 // Single joined Acme::DolphinToken from idp.dolphin.sea
  "total_token_count": Long,
};
```

## Example Token Data

### Input JWT Token
```json
{
  "mapping": "Jans::Access_Token",
  "payload": "eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9.eyJpc3MiOiJpZHAuZG9scGhpbi5zZWEiLCJzdWIiOiJkb2xwaGluMTIzIiwibG9jYXRpb24iOiJtaWFtaSIsInNjb3BlIjpbInJlYWQ6cHJvZmlsZSIsIndyaXRlOmNhbGVuZGFyIl0sImV4cCI6MTcwOTg1NjAwMCwiaWF0IjoxNzA5ODUyNDAwLCJqdGkiOiJ0b2tlbi0xMjM0NSJ9..."
}
```

### Decoded JWT Claims
```json
{
  "iss": "idp.dolphin.sea",
  "sub": "dolphin123",
  "location": "miami",
  "scope": ["read:profile", "write:calendar"],
  "exp": 1709856000,
  "iat": 1709852400,
  "jti": "token-12345"
}
```

## How Token Collection Builder Creates the Entity

The Token Collection Builder would create:

### Individual Token Entity
```cedar
Token::"token-12345" = {
  "token_type": "Jans::Access_Token",
  "jti": "token-12345",
  "issuer": "idp.dolphin.sea",
  "claims": {
    "iss": "idp.dolphin.sea",
    "sub": "dolphin123", 
    "location": "miami",
    "scope": ["read:profile", "write:calendar"],
    "exp": 1709856000,
    "iat": 1709852400,
    "jti": "token-12345"
  },
  "validated_at": 1709852500
};
```

### Token Collection Context
```cedar
TokenCollection::"request-context" = {
  "dolphin_sea_access_token": Token::"token-12345",
  "total_token_count": 1
};
```

## Valid Cedar Policy for Access Token with location="miami"

Using the flattened structure with predictable naming, the policy becomes much cleaner:

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

### How Token Collection Builder Creates This

The Token Collection Builder processes multiple access tokens from the same issuer and joins them:

**Input:** Two access tokens from "idp.dolphin.sea"
- Token 1: `{"location": "miami", "scope": ["read:profile"]}`
- Token 2: `{"location": "miami", "scope": ["write:calendar"]}`

**Output:** Single joined token with flattened field name:

```cedar
TokenCollection::"request-context" = {
  "dolphin_sea_access_token": Token::"joined-token-dolphin-sea",
  "total_token_count": 2
};

Token::"joined-token-dolphin-sea" = {
  "token_type": "Jans::Access_Token",
  "jti": "joined-token-dolphin-sea",
  "issuer": "idp.dolphin.sea",
  "claims": {
    "iss": "idp.dolphin.sea",
    "sub": "dolphin123",
    "location": "miami",  // Common claim preserved
    "scope": ["read:profile", "write:calendar"],  // Scopes merged
    "exp": 1709856000,  // Latest expiration
    "iat": 1709852400   // Earliest issued time
  },
  "validated_at": 1709852500
};
```

### Field Naming Convention

The Token Collection Builder creates predictable field names using this pattern:
- `{issuer_domain}_{token_type_simplified}`

Examples:
- `idp.dolphin.sea` + `Jans::Access_Token` → `dolphin_sea_access_token`
- `accounts.google.com` + `Jans::Id_Token` → `google_id_token`
- `idp.dolphin.sea` + `Acme::DolphinToken` → `dolphin_sea_dolphin_token`

### Alternative Policy for Scope Check

Check if the joined access token has a specific scope:

```cedar
permit(
  principal,
  action == Acme::Action::"ReadProfile",
  resource
) when {
  context.token_collection has "dolphin_sea_access_token" &&
  context.token_collection.dolphin_sea_access_token.claims has "scope" &&
  "read:profile" in context.token_collection.dolphin_sea_access_token.claims.scope
};
```

## Conclusion

The flattened structure approach is much better because it creates the most ergonomic Cedar policy syntax.

**Key Insights:**
1. **Predictable naming**: Field names follow `{issuer_domain}_{token_type_simplified}` pattern
2. **Clean syntax**: `context.token_collection.dolphin_sea_access_token.claims.location == "miami"`
3. **No repetition**: Each token reference is short and readable
4. **Universal handling**: Works the same for standard and custom token types
5. **Developer-friendly**: Easy to read, write, and maintain policies

**Benefits:**
- **Ergonomic**: Policies are easy to read and understand
- **Scalable**: Handles arbitrary token types without syntax complexity
- **Maintainable**: No nested structures or repetitive paths
- **Intuitive**: Field names clearly indicate issuer and token type

**Example Policy Comparison:**

**Before (nested structure):**
```cedar
"idp.dolphin.sea" in context.token_collection.issuer_joined &&
"Jans::Access_Token" in context.token_collection.issuer_joined["idp.dolphin.sea"] &&
context.token_collection.issuer_joined["idp.dolphin.sea"]["Jans::Access_Token"].claims.location == "miami"
```

**After (flattened structure):**
```cedar
context.token_collection has "dolphin_sea_access_token" &&
context.token_collection.dolphin_sea_access_token.claims.location == "miami"
```

The flattened approach provides the best balance of simplicity, readability, and functionality.