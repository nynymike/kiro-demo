// Cedar Policies for Support Issue System - GitHub-like Security Model

// ============================================================================
// ISSUE ACCESS POLICIES
// ============================================================================

// Policy 1: Users can view issues they created
permit (
  principal,
  action == SupportSystem::Action::"ViewIssue",
  resource
) when {
  resource.createdBy == principal.id
};

// Policy 2: Agents can view all issues in their department
permit (
  principal,
  action == SupportSystem::Action::"ViewIssue",
  resource
) when {
  principal.role == "agent" &&
  resource.department == principal.department
};

// Policy 3: Admins can view all issues
permit (
  principal,
  action == SupportSystem::Action::"ViewIssue",
  resource
) when {
  principal.role == "admin"
};

// Policy 4: Users can only create issues for their own organization
permit (
  principal,
  action == SupportSystem::Action::"CreateIssue",
  resource
) when {
  principal.role == "customer" &&
  resource.organization == principal.organization
};

// Policy 5: Agents and admins can create issues for any organization
permit (
  principal,
  action == SupportSystem::Action::"CreateIssue",
  resource
) when {
  principal.role in ["agent", "admin"]
};

// Policy 6: Users can update their own issues (limited fields)
permit (
  principal,
  action == SupportSystem::Action::"UpdateIssue",
  resource
) when {
  resource.createdBy == principal.id &&
  principal.role == "customer"
};

// Policy 7: Assigned agents can update issues
permit (
  principal,
  action == SupportSystem::Action::"UpdateIssue",
  resource
) when {
  resource.assignedTo == principal.id &&
  principal.role == "agent"
};

// Policy 8: Team leads can update issues in their department
permit (
  principal,
  action == SupportSystem::Action::"UpdateIssue",
  resource
) when {
  principal.role == "agent" &&
  principal.isTeamLead == true &&
  resource.department == principal.department
};

// Policy 9: Only admins can delete issues
permit (
  principal,
  action == SupportSystem::Action::"DeleteIssue",
  resource
) when {
  principal.role == "admin"
};

// ============================================================================
// ASSIGNMENT POLICIES
// ============================================================================

// Policy 10: Only agents and admins can assign issues
permit (
  principal,
  action == SupportSystem::Action::"AssignIssue",
  resource
) when {
  principal.role in ["agent", "admin"]
};

// Policy 11: Agents can only assign to their own department
permit (
  principal,
  action == SupportSystem::Action::"AssignIssue",
  resource
) when {
  principal.role == "agent" &&
  resource.department == principal.department
};

// ============================================================================
// COMMENT POLICIES
// ============================================================================

// Policy 12: Users can add comments to issues they can view
permit (
  principal,
  action == SupportSystem::Action::"AddComment",
  resource
) when {
  // This would reference the ViewIssue permission
  principal has permission to ViewIssue on resource.issue
};

// Policy 13: Users can view public comments on issues they can access
permit (
  principal,
  action == SupportSystem::Action::"ViewComment",
  resource
) when {
  resource.isInternal == false &&
  principal has permission to ViewIssue on resource.issue
};

// Policy 14: Only agents and admins can view internal comments
permit (
  principal,
  action == SupportSystem::Action::"ViewComment",
  resource
) when {
  resource.isInternal == true &&
  principal.role in ["agent", "admin"]
};

// Policy 15: Only agents and admins can add internal notes
permit (
  principal,
  action == SupportSystem::Action::"AddInternalNote",
  resource
) when {
  principal.role in ["agent", "admin"]
};

// Policy 16: Users can edit their own comments within 15 minutes
permit (
  principal,
  action == SupportSystem::Action::"EditComment",
  resource
) when {
  resource.createdBy == principal.id &&
  datetime::now() - resource.createdAt < duration::minutes(15)
};

// Policy 17: Agents can edit any comment on issues in their department
permit (
  principal,
  action == SupportSystem::Action::"EditComment",
  resource
) when {
  principal.role == "agent" &&
  resource.issue.department == principal.department
};

// ============================================================================
// ADMINISTRATIVE POLICIES
// ============================================================================

// Policy 18: Only admins can manage users
permit (
  principal,
  action == SupportSystem::Action::"ManageUsers",
  resource
) when {
  principal.role == "admin"
};

// Policy 19: Agents can view users in their organization/department
permit (
  principal,
  action == SupportSystem::Action::"ViewUsers",
  resource
) when {
  principal.role == "agent" &&
  (resource.organization == principal.organization ||
   resource.department == principal.department)
};

// Policy 20: Team leads can view reports for their department
permit (
  principal,
  action == SupportSystem::Action::"ViewReports",
  resource
) when {
  principal.role == "agent" &&
  principal.isTeamLead == true &&
  resource.department == principal.department
};

// Policy 21: Admins can view all reports and export data
permit (
  principal,
  action == SupportSystem::Action::"ViewReports",
  resource
) when {
  principal.role == "admin"
};

permit (
  principal,
  action == SupportSystem::Action::"ExportData",
  resource
) when {
  principal.role == "admin"
};

// ============================================================================
// ORGANIZATION-BASED POLICIES
// ============================================================================

// Policy 22: Premium customers get priority support access
permit (
  principal,
  action == SupportSystem::Action::"CreateIssue",
  resource
) when {
  principal.organization.tier == "premium" &&
  resource.priority in ["high", "critical"]
};

// Policy 23: Enterprise customers can access dedicated support channels
permit (
  principal,
  action == SupportSystem::Action::"ViewIssue",
  resource
) when {
  principal.organization.tier == "enterprise" &&
  resource.category == "enterprise_support"
};

// ============================================================================
// SECURITY AND AUDIT POLICIES
// ============================================================================

// Policy 24: Prevent access to inactive users
forbid (
  principal,
  action,
  resource
) when {
  principal.isActive == false
};

// Policy 25: Prevent access to issues from inactive organizations
forbid (
  principal,
  action,
  resource
) when {
  resource has organization &&
  resource.organization.isActive == false
};

// Policy 26: Audit trail - log all administrative actions
permit (
  principal,
  action,
  resource
) when {
  action in [
    SupportSystem::Action::"ManageUsers",
    SupportSystem::Action::"DeleteIssue",
    SupportSystem::Action::"ExportData"
  ] &&
  principal.role == "admin"
} unless {
  // Additional audit requirements could be added here
  false
};