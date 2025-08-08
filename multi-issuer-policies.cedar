// Cedar Policies for Multi-Issuer Token Authorization

// ============================================================================
// BASIC TOKEN VALIDATION POLICIES
// ============================================================================

// Policy 1: Require at least one valid access token for resource access
permit (
  principal,
  action == Jans::Action::"ReadResource",
  resource
) when {
  context.token_context.access_tokens.size() > 0 &&
  context.token_context.access_tokens.any(|token| token.exp > context.current_time)
};

// Policy 2: Allow access if any access token contains required scope
permit (
  principal,
  action == Jans::Action::"ReadResource",
  resource
) when {
  resource.required_scope in context.token_context.all_scopes
};

// ============================================================================
// MULTI-SCOPE POLICIES (Handling scope combinations)
// ============================================================================

// Policy 3: Require multiple scopes that can come from different tokens
// Example: Need both "read:profile" AND "read:email" scopes
permit (
  principal,
  action == Jans::Action::"ReadResource",
  resource
) when {
  resource.resource_type == "user_profile" &&
  "read:profile" in context.token_context.all_scopes &&
  "read:email" in context.token_context.all_scopes
};

// Policy 4: Advanced scope combination - require scopes A AND B, or scope C
permit (
  principal,
  action == Jans::Action::"WriteResource",
  resource
) when {
  resource.resource_type == "document" &&
  (
    ("write:documents" in context.token_context.all_scopes && 
     "admin:documents" in context.token_context.all_scopes) ||
    "super:admin" in context.token_context.all_scopes
  )
};

// ============================================================================
// ISSUER-SPECIFIC POLICIES
// ============================================================================

// Policy 5: Require tokens from specific issuers for sensitive operations
permit (
  principal,
  action == Jans::Action::"DeleteResource",
  resource
) when {
  resource.sensitivity_level == "high" &&
  context.token_context.access_tokens.any(|token| 
    token.issuer == "https://trusted-issuer.example.com" &&
    "admin:delete" in token.scopes
  )
};

// Policy 6: Allow transaction execution only with valid transaction tokens
permit (
  principal,
  action == Jans::Action::"ExecuteTransaction",
  resource
) when {
  context.token_context.tx_tokens.any(|token|
    token.transaction_id == resource.transaction_id &&
    token.exp > context.current_time
  )
};

// ============================================================================
// MULTI-TOKEN VALIDATION POLICIES
// ============================================================================

// Policy 7: Require consistent subject across all tokens
permit (
  principal,
  action,
  resource
) when {
  context.token_context.access_tokens.all(|token| 
    token.sub == context.token_context.primary_subject
  ) &&
  context.token_context.id_tokens.all(|token|
    token.sub == context.token_context.primary_subject
  )
};

// Policy 8: Require both ID token and access token for user operations
permit (
  principal,
  action == Jans::Action::"ReadResource",
  resource
) when {
  resource.resource_type == "user_data" &&
  context.token_context.id_tokens.size() > 0 &&
  context.token_context.access_tokens.size() > 0 &&
  context.token_context.id_tokens.any(|id_token|
    context.token_context.access_tokens.any(|access_token|
      id_token.sub == access_token.sub &&
      "read:user" in access_token.scopes
    )
  )
};

// ============================================================================
// PASSKEY AUTHENTICATION POLICIES
// ============================================================================

// Policy 9: Allow high-security operations with passkey attestation
permit (
  principal,
  action == Jans::Action::"WriteResource",
  resource
) when {
  resource.security_level == "high" &&
  context.token_context.passkey_attestations.size() > 0 &&
  context.token_context.access_tokens.any(|token|
    "admin:write" in token.scopes
  )
};

// ============================================================================
// TIME-BASED AND EXPIRATION POLICIES
// ============================================================================

// Policy 10: Deny access if any token is expired
forbid (
  principal,
  action,
  resource
) when {
  context.token_context.access_tokens.any(|token| token.exp <= context.current_time) ||
  context.token_context.tx_tokens.any(|token| token.exp <= context.current_time) ||
  context.token_context.id_tokens.any(|token| token.exp <= context.current_time)
};

// ============================================================================
// AUDIENCE VALIDATION POLICIES
// ============================================================================

// Policy 11: Validate token audience matches the resource
permit (
  principal,
  action,
  resource
) when {
  context.token_context.access_tokens.any(|token|
    token.aud == resource.service_identifier
  ) ||
  context.token_context.id_tokens.any(|token|
    token.aud == resource.service_identifier
  )
};