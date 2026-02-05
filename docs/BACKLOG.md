# SyncForge - Product Backlog

## Overview

Structured backlog organized as Epics → User Stories → Tasks. Prioritized for MVP delivery with clear acceptance criteria.

---

## Epic Structure

```
Epic (E-XXX)
└── User Story (US-XXX)
    └── Task (T-XXX)
```

**Priority Levels**:
- **P0**: Must have for MVP launch
- **P1**: Should have, important for user experience
- **P2**: Nice to have, can defer
- **P3**: Future consideration

---

## E-001: Authentication & User Management

### US-001: Email/Password Registration
**As a** new user
**I want to** sign up with my email and password
**So that** I can create an account and start using SyncForge

**Acceptance Criteria**:
- [ ] User can enter email and password
- [ ] Password must be at least 8 characters with 1 number and 1 special character
- [ ] Email verification is sent upon registration
- [ ] User cannot access app until email is verified
- [ ] Duplicate email addresses are rejected with clear error

**Tasks**:
| ID | Task | Estimate | Priority |
|----|------|----------|----------|
| T-001 | Create User model with Prisma schema | 2h | P0 |
| T-002 | Implement password hashing with Argon2 | 1h | P0 |
| T-003 | Build registration API endpoint | 2h | P0 |
| T-004 | Create registration form UI | 3h | P0 |
| T-005 | Implement email verification flow | 3h | P0 |
| T-006 | Add rate limiting for registration | 1h | P0 |
| T-007 | Write unit tests for registration | 2h | P0 |

---

### US-002: Email/Password Login
**As a** registered user
**I want to** log in with my email and password
**So that** I can access my account

**Acceptance Criteria**:
- [ ] User can log in with correct credentials
- [ ] Failed login shows generic error (security)
- [ ] Account locks after 5 failed attempts for 15 minutes
- [ ] Successful login redirects to dashboard
- [ ] Session persists for 7 days with "Remember me"

**Tasks**:
| ID | Task | Estimate | Priority |
|----|------|----------|----------|
| T-008 | Implement login API endpoint | 2h | P0 |
| T-009 | Create JWT token generation/validation | 2h | P0 |
| T-010 | Build login form UI | 2h | P0 |
| T-011 | Implement session management | 2h | P0 |
| T-012 | Add brute force protection | 2h | P0 |
| T-013 | Write login flow tests | 2h | P0 |

---

### US-003: Google OAuth Sign-up/Sign-in
**As a** user
**I want to** sign up or sign in with my Google account
**So that** I can quickly access SyncForge without creating a new password

**Acceptance Criteria**:
- [ ] "Continue with Google" button on auth pages
- [ ] First-time Google users create new account
- [ ] Existing Google users log into their account
- [ ] Google profile picture is used as avatar
- [ ] Email from Google is pre-verified

**Tasks**:
| ID | Task | Estimate | Priority |
|----|------|----------|----------|
| T-014 | Set up Google OAuth credentials | 1h | P0 |
| T-015 | Implement OAuth callback handler | 3h | P0 |
| T-016 | Handle account linking for existing emails | 2h | P0 |
| T-017 | Build OAuth button components | 1h | P0 |
| T-018 | Write OAuth integration tests | 2h | P0 |

---

### US-004: Password Reset
**As a** user who forgot my password
**I want to** reset my password via email
**So that** I can regain access to my account

**Acceptance Criteria**:
- [ ] User can request password reset by email
- [ ] Reset email sent within 30 seconds
- [ ] Reset link expires after 1 hour
- [ ] Reset link can only be used once
- [ ] User is logged in after successful reset

**Tasks**:
| ID | Task | Estimate | Priority |
|----|------|----------|----------|
| T-019 | Implement password reset request endpoint | 2h | P0 |
| T-020 | Create password reset email template | 1h | P0 |
| T-021 | Build password reset form | 2h | P0 |
| T-022 | Implement reset token validation | 2h | P0 |
| T-023 | Write password reset tests | 2h | P0 |

---

### US-005: User Profile Management
**As a** logged-in user
**I want to** update my profile information
**So that** my account reflects my current details

**Acceptance Criteria**:
- [ ] User can update name, email, avatar
- [ ] Email changes require re-verification
- [ ] User can change password (requires current password)
- [ ] User can delete their account

**Tasks**:
| ID | Task | Estimate | Priority |
|----|------|----------|----------|
| T-024 | Create profile settings page | 3h | P0 |
| T-025 | Implement profile update API | 2h | P0 |
| T-026 | Add avatar upload functionality | 2h | P1 |
| T-027 | Implement email change flow | 2h | P0 |
| T-028 | Build account deletion flow | 2h | P1 |

---

## E-002: Organization Management

### US-006: Create Organization
**As a** new user
**I want to** create an organization
**So that** I can set up my workspace for syncs

**Acceptance Criteria**:
- [ ] User is prompted to create org after first login
- [ ] Organization name is required (2-50 chars)
- [ ] Slug is auto-generated from name
- [ ] User becomes Owner of new organization
- [ ] Free plan is assigned by default

**Tasks**:
| ID | Task | Estimate | Priority |
|----|------|----------|----------|
| T-029 | Create Organization model | 1h | P0 |
| T-030 | Implement create organization API | 2h | P0 |
| T-031 | Build organization creation UI | 2h | P0 |
| T-032 | Generate unique slugs | 1h | P0 |
| T-033 | Set up plan defaults | 1h | P0 |

---

### US-007: Invite Team Members
**As an** organization owner or admin
**I want to** invite team members by email
**So that** my team can collaborate on syncs

**Acceptance Criteria**:
- [ ] Can invite multiple emails at once
- [ ] Can select role for each invite (Admin, Editor, Viewer)
- [ ] Invitation email is sent immediately
- [ ] Invitation expires after 7 days
- [ ] Can resend or cancel pending invitations

**Tasks**:
| ID | Task | Estimate | Priority |
|----|------|----------|----------|
| T-034 | Create Membership model | 1h | P0 |
| T-035 | Implement invitation API | 3h | P0 |
| T-036 | Create invitation email template | 1h | P0 |
| T-037 | Build team management UI | 4h | P0 |
| T-038 | Implement invitation acceptance flow | 2h | P0 |
| T-039 | Add invitation management (resend/cancel) | 2h | P1 |

---

### US-008: Manage Team Roles
**As an** organization owner or admin
**I want to** change team member roles and remove members
**So that** I can control access to organization resources

**Acceptance Criteria**:
- [ ] Owners can change any role except other Owners
- [ ] Admins can change Editor/Viewer roles only
- [ ] Members can be removed from organization
- [ ] Cannot remove the last Owner
- [ ] Role changes take effect immediately

**Tasks**:
| ID | Task | Estimate | Priority |
|----|------|----------|----------|
| T-040 | Implement role update API | 2h | P0 |
| T-041 | Implement member removal API | 2h | P0 |
| T-042 | Add role-based access control middleware | 3h | P0 |
| T-043 | Build role management UI | 2h | P0 |
| T-044 | Write RBAC tests | 3h | P0 |

---

## E-003: Connector Management

### US-009: Connect Salesforce
**As a** user
**I want to** connect my Salesforce account
**So that** I can sync my Salesforce data

**Acceptance Criteria**:
- [ ] OAuth flow authenticates with Salesforce
- [ ] Required scopes are requested
- [ ] Connection success shows available objects
- [ ] Failed auth shows clear error message
- [ ] Token refresh happens automatically

**Tasks**:
| ID | Task | Estimate | Priority |
|----|------|----------|----------|
| T-045 | Set up Salesforce connected app | 2h | P0 |
| T-046 | Implement Salesforce OAuth flow | 4h | P0 |
| T-047 | Build connector base class | 3h | P0 |
| T-048 | Implement Salesforce connector | 6h | P0 |
| T-049 | Add token refresh mechanism | 3h | P0 |
| T-050 | Fetch and cache Salesforce metadata | 3h | P0 |
| T-051 | Write Salesforce connector tests | 4h | P0 |

---

### US-010: Connect HubSpot
**As a** user
**I want to** connect my HubSpot account
**So that** I can sync my HubSpot data

**Acceptance Criteria**:
- [ ] OAuth flow authenticates with HubSpot
- [ ] Contacts, Companies, Deals objects available
- [ ] Connection shows account info
- [ ] Clear error on insufficient permissions

**Tasks**:
| ID | Task | Estimate | Priority |
|----|------|----------|----------|
| T-052 | Set up HubSpot OAuth app | 1h | P0 |
| T-053 | Implement HubSpot OAuth flow | 3h | P0 |
| T-054 | Implement HubSpot connector | 5h | P0 |
| T-055 | Fetch HubSpot object metadata | 2h | P0 |
| T-056 | Write HubSpot connector tests | 3h | P0 |

---

### US-011: Connect PostgreSQL Database
**As a** user
**I want to** connect to my PostgreSQL database
**So that** I can sync data to/from my database

**Acceptance Criteria**:
- [ ] User provides connection string or individual params
- [ ] Connection is tested before saving
- [ ] SSL is supported and recommended
- [ ] Database tables are discovered automatically
- [ ] Schema information is cached

**Tasks**:
| ID | Task | Estimate | Priority |
|----|------|----------|----------|
| T-057 | Implement PostgreSQL connector | 5h | P0 |
| T-058 | Build database connection form | 3h | P0 |
| T-059 | Implement connection testing | 2h | P0 |
| T-060 | Add SSL certificate handling | 2h | P0 |
| T-061 | Implement table/column discovery | 3h | P0 |
| T-062 | Write PostgreSQL connector tests | 3h | P0 |

---

### US-012: Connect Google Sheets
**As a** user
**I want to** connect my Google Sheets
**So that** I can sync data from spreadsheets

**Acceptance Criteria**:
- [ ] OAuth flow with Google
- [ ] User can browse and select spreadsheets
- [ ] Individual sheets are treated as objects
- [ ] First row is used as column headers

**Tasks**:
| ID | Task | Estimate | Priority |
|----|------|----------|----------|
| T-063 | Set up Google OAuth credentials | 1h | P1 |
| T-064 | Implement Google Sheets OAuth | 3h | P1 |
| T-065 | Implement Google Sheets connector | 4h | P1 |
| T-066 | Build spreadsheet picker UI | 2h | P1 |
| T-067 | Write Google Sheets tests | 2h | P1 |

---

### US-013: Connect Airtable
**As a** user
**I want to** connect my Airtable bases
**So that** I can sync Airtable data

**Acceptance Criteria**:
- [ ] User provides API key
- [ ] Available bases are discovered
- [ ] Tables within bases are shown
- [ ] Field types are mapped correctly

**Tasks**:
| ID | Task | Estimate | Priority |
|----|------|----------|----------|
| T-068 | Implement Airtable connector | 4h | P1 |
| T-069 | Build Airtable API key setup UI | 2h | P1 |
| T-070 | Implement base/table discovery | 2h | P1 |
| T-071 | Write Airtable connector tests | 2h | P1 |

---

### US-014: Test & Manage Connectors
**As a** user
**I want to** test my connector and see its status
**So that** I know my connections are working

**Acceptance Criteria**:
- [ ] Test connection button for each connector
- [ ] Status indicator (connected/error/rate-limited)
- [ ] Last tested timestamp shown
- [ ] Error details are displayed
- [ ] Can disconnect/remove connectors

**Tasks**:
| ID | Task | Estimate | Priority |
|----|------|----------|----------|
| T-072 | Implement connection testing API | 2h | P0 |
| T-073 | Build connector list page | 3h | P0 |
| T-074 | Create connector status component | 2h | P0 |
| T-075 | Implement disconnect functionality | 1h | P0 |
| T-076 | Add connector health monitoring | 3h | P1 |

---

## E-004: Sync Configuration

### US-015: Create New Sync
**As a** user
**I want to** create a sync between two connectors
**So that** I can keep my data synchronized

**Acceptance Criteria**:
- [ ] Step-by-step wizard guides sync creation
- [ ] Select source and destination connectors
- [ ] Select source and destination objects
- [ ] System auto-suggests field mappings
- [ ] Can manually adjust mappings
- [ ] Preview sync before activation

**Tasks**:
| ID | Task | Estimate | Priority |
|----|------|----------|----------|
| T-077 | Create Sync model | 2h | P0 |
| T-078 | Build sync creation wizard container | 4h | P0 |
| T-079 | Implement connector selection step | 3h | P0 |
| T-080 | Implement object selection step | 3h | P0 |
| T-081 | Build field mapping interface | 6h | P0 |
| T-082 | Implement auto-mapping algorithm | 4h | P0 |
| T-083 | Build sync preview functionality | 3h | P0 |
| T-084 | Create sync API endpoints | 4h | P0 |

---

### US-016: Configure Field Mappings
**As a** user
**I want to** map fields between source and destination
**So that** my data transforms correctly during sync

**Acceptance Criteria**:
- [ ] Visual mapping interface showing source → destination
- [ ] Type compatibility warnings
- [ ] Required fields are highlighted
- [ ] Can apply transformations (uppercase, lowercase, trim)
- [ ] Can set default values for missing fields

**Tasks**:
| ID | Task | Estimate | Priority |
|----|------|----------|----------|
| T-085 | Create FieldMapping model | 1h | P0 |
| T-086 | Implement transformation functions | 4h | P0 |
| T-087 | Build drag-and-drop mapping UI | 5h | P0 |
| T-088 | Add type compatibility checking | 2h | P0 |
| T-089 | Implement default value support | 2h | P0 |

---

### US-017: Set Sync Schedule
**As a** user
**I want to** schedule my sync to run automatically
**So that** my data stays current without manual intervention

**Acceptance Criteria**:
- [ ] Options: Manual only, Every 15 min, Hourly, Daily
- [ ] Daily syncs can specify time (in user's timezone)
- [ ] Schedule can be paused/resumed
- [ ] Next run time is displayed
- [ ] Schedule respects plan limits

**Tasks**:
| ID | Task | Estimate | Priority |
|----|------|----------|----------|
| T-090 | Implement scheduling options | 2h | P0 |
| T-091 | Build schedule configuration UI | 2h | P0 |
| T-092 | Implement schedule executor (BullMQ) | 4h | P0 |
| T-093 | Add timezone support | 2h | P0 |
| T-094 | Implement schedule pause/resume | 2h | P0 |

---

### US-018: Manage Syncs
**As a** user
**I want to** view, edit, pause, and delete my syncs
**So that** I can manage my data synchronization

**Acceptance Criteria**:
- [ ] List of all syncs with status
- [ ] Quick actions: Run now, Pause, Edit, Delete
- [ ] Sync detail page with full configuration
- [ ] Edit preserves existing mappings
- [ ] Delete requires confirmation

**Tasks**:
| ID | Task | Estimate | Priority |
|----|------|----------|----------|
| T-095 | Build syncs list page | 3h | P0 |
| T-096 | Create sync detail page | 4h | P0 |
| T-097 | Implement edit sync flow | 3h | P0 |
| T-098 | Add pause/resume functionality | 2h | P0 |
| T-099 | Implement delete with confirmation | 1h | P0 |

---

## E-005: Sync Execution Engine

### US-019: Run Sync Manually
**As a** user
**I want to** run a sync manually
**So that** I can sync data on demand

**Acceptance Criteria**:
- [ ] "Run Now" button triggers immediate sync
- [ ] Progress indicator shows sync status
- [ ] Can view records processed in real-time
- [ ] Completion shows summary stats
- [ ] Errors are displayed clearly

**Tasks**:
| ID | Task | Estimate | Priority |
|----|------|----------|----------|
| T-100 | Implement sync execution service | 6h | P0 |
| T-101 | Create SyncRun model | 1h | P0 |
| T-102 | Build sync progress UI | 3h | P0 |
| T-103 | Implement real-time progress updates | 3h | P0 |
| T-104 | Add execution summary display | 2h | P0 |

---

### US-020: Incremental Sync
**As a** user
**I want to** sync only changed records
**So that** syncs are fast and efficient

**Acceptance Criteria**:
- [ ] Only new/modified records are synced
- [ ] Deleted records are handled appropriately
- [ ] Cursor position is saved for resume
- [ ] Full sync can be forced if needed
- [ ] Incremental logic works for all connectors

**Tasks**:
| ID | Task | Estimate | Priority |
|----|------|----------|----------|
| T-105 | Implement change detection | 5h | P0 |
| T-106 | Create SyncState model for cursors | 2h | P0 |
| T-107 | Add delete detection | 3h | P0 |
| T-108 | Implement force full sync option | 1h | P0 |
| T-109 | Write incremental sync tests | 4h | P0 |

---

### US-021: Handle Sync Errors
**As a** user
**I want to** see and retry failed records
**So that** I can fix sync issues

**Acceptance Criteria**:
- [ ] Failed records are logged with error details
- [ ] Sync continues after individual record failures
- [ ] Can retry failed records
- [ ] Error categorization (validation, rate limit, etc.)
- [ ] Critical errors stop sync immediately

**Tasks**:
| ID | Task | Estimate | Priority |
|----|------|----------|----------|
| T-110 | Create SyncRecord model | 1h | P0 |
| T-111 | Implement error categorization | 2h | P0 |
| T-112 | Build error display UI | 3h | P0 |
| T-113 | Implement record retry functionality | 3h | P0 |
| T-114 | Add critical error handling | 2h | P0 |

---

### US-022: View Sync History
**As a** user
**I want to** view the history of sync runs
**So that** I can track sync performance over time

**Acceptance Criteria**:
- [ ] List of past sync runs with timestamps
- [ ] Statistics: records created/updated/failed
- [ ] Duration of each run
- [ ] Filter by date range, status
- [ ] Click to view run details

**Tasks**:
| ID | Task | Estimate | Priority |
|----|------|----------|----------|
| T-115 | Build sync history list | 3h | P0 |
| T-116 | Create run detail view | 2h | P0 |
| T-117 | Add history filtering | 2h | P1 |
| T-118 | Implement statistics aggregation | 2h | P0 |

---

## E-006: Monitoring & Alerts

### US-023: Dashboard Overview
**As a** user
**I want to** see an overview of my sync health
**So that** I can quickly understand my sync status

**Acceptance Criteria**:
- [ ] Summary cards: Active syncs, Recent runs, Error rate
- [ ] List of recent activity
- [ ] Quick access to problematic syncs
- [ ] Sync health indicators

**Tasks**:
| ID | Task | Estimate | Priority |
|----|------|----------|----------|
| T-119 | Design dashboard layout | 2h | P0 |
| T-120 | Build summary statistics cards | 3h | P0 |
| T-121 | Create activity feed component | 2h | P1 |
| T-122 | Implement health scoring | 2h | P0 |
| T-123 | Add quick action buttons | 1h | P0 |

---

### US-024: Email Notifications
**As a** user
**I want to** receive email notifications for sync failures
**So that** I can respond to issues quickly

**Acceptance Criteria**:
- [ ] Email sent immediately on sync failure
- [ ] Email includes error summary and link to details
- [ ] Can configure notification preferences
- [ ] Daily digest option available
- [ ] Can unsubscribe from specific notifications

**Tasks**:
| ID | Task | Estimate | Priority |
|----|------|----------|----------|
| T-124 | Set up email service (Resend/Postmark) | 2h | P0 |
| T-125 | Create failure notification template | 2h | P0 |
| T-126 | Implement notification triggers | 2h | P0 |
| T-127 | Build notification preferences UI | 2h | P1 |
| T-128 | Add daily digest functionality | 3h | P1 |

---

## E-007: Billing & Plans

### US-025: Display Plan Limits
**As a** user
**I want to** see my current plan and usage
**So that** I know when I'm approaching limits

**Acceptance Criteria**:
- [ ] Current plan name and price displayed
- [ ] Usage meters for syncs, records, connectors
- [ ] Warning when approaching limits (80%)
- [ ] Clear indication when limits reached

**Tasks**:
| ID | Task | Estimate | Priority |
|----|------|----------|----------|
| T-129 | Implement usage tracking | 3h | P0 |
| T-130 | Build plan overview component | 2h | P0 |
| T-131 | Create usage meters | 2h | P0 |
| T-132 | Add limit warning notifications | 2h | P0 |

---

### US-026: Upgrade Plan
**As a** user
**I want to** upgrade my plan
**So that** I can access more features and capacity

**Acceptance Criteria**:
- [ ] Plans comparison page
- [ ] Stripe Checkout for payment
- [ ] Plan upgrades are immediate
- [ ] Proration for mid-cycle upgrades
- [ ] Receipt sent via email

**Tasks**:
| ID | Task | Estimate | Priority |
|----|------|----------|----------|
| T-133 | Set up Stripe products and prices | 2h | P0 |
| T-134 | Implement Stripe Checkout flow | 4h | P0 |
| T-135 | Build pricing/plans page | 3h | P0 |
| T-136 | Handle Stripe webhooks | 3h | P0 |
| T-137 | Implement plan change logic | 3h | P0 |

---

### US-027: Manage Billing
**As a** user
**I want to** manage my billing details
**So that** I can update payment methods and view invoices

**Acceptance Criteria**:
- [ ] View and update payment method
- [ ] View invoice history
- [ ] Download invoices as PDF
- [ ] Cancel subscription

**Tasks**:
| ID | Task | Estimate | Priority |
|----|------|----------|----------|
| T-138 | Implement Stripe Customer Portal | 2h | P0 |
| T-139 | Build billing settings page | 2h | P0 |
| T-140 | Add invoice listing | 2h | P1 |
| T-141 | Implement cancellation flow | 2h | P1 |

---

## Backlog Summary

### MVP Totals by Epic

| Epic | User Stories | Tasks | Est. Hours |
|------|-------------|-------|------------|
| E-001: Auth | 5 | 28 | 52h |
| E-002: Organizations | 3 | 16 | 29h |
| E-003: Connectors | 6 | 32 | 68h |
| E-004: Sync Config | 4 | 23 | 55h |
| E-005: Sync Engine | 4 | 19 | 42h |
| E-006: Monitoring | 2 | 10 | 18h |
| E-007: Billing | 3 | 13 | 26h |
| **Total** | **27** | **141** | **290h** |

### Sprint Planning Recommendation

**Sprint 1 (Week 1-2)**: E-001 Auth + E-002 Organizations
**Sprint 2 (Week 3-4)**: E-003 Connectors (Salesforce, HubSpot, PostgreSQL)
**Sprint 3 (Week 5-6)**: E-004 Sync Configuration + E-005 Sync Engine
**Sprint 4 (Week 7-8)**: E-006 Monitoring + E-007 Billing + Polish

---

## Post-MVP Backlog

### v1.1 Features
- Real-time sync via webhooks
- Additional connectors (Stripe, Notion, MySQL)
- MFA/2FA support
- Custom cron schedules

### v1.2 Features
- Bidirectional sync
- Conditional field mapping
- Custom JavaScript transformations
- Record filtering

### v2.0 Features
- Custom connector builder
- Public API
- SSO/SAML
- Audit logs
- Self-hosted option

---

## Related Documents

- [MVP Scope](MVP_SCOPE.md)
- [Technical Specifications](SPECS.md)
- [Test Plan](TEST_PLAN.md)
