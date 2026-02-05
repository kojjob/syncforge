# SyncForge - Changelog

All notable changes to SyncForge will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Planned
- Real-time sync via webhooks
- Bidirectional sync support
- Additional connectors: Stripe, Notion, MySQL

---

## [1.0.0] - YYYY-MM-DD

### 🎉 Initial Release

SyncForge v1.0 - No-code data synchronization for modern teams.

### Added

#### Authentication & Accounts
- Email/password registration with email verification
- Google OAuth sign-up and sign-in
- Password reset via email
- User profile management (name, email, avatar)

#### Organizations
- Create organizations with auto-generated slugs
- Invite team members via email
- Role-based access control (Owner, Admin, Editor, Viewer)
- Remove team members

#### Connectors
- **Salesforce** connector (OAuth 2.0)
  - Contact, Lead, Account, Opportunity objects
  - Incremental sync support
- **HubSpot** connector (OAuth 2.0)
  - Contact, Company, Deal objects
  - Incremental sync support
- **PostgreSQL** connector (Connection string)
  - All tables supported
  - SSL support
- **Google Sheets** connector (OAuth 2.0)
  - All sheets as objects
- **Airtable** connector (API key)
  - All tables supported

#### Sync Configuration
- One-way sync (source → destination)
- Object selection with auto-discovery
- Visual field mapping interface
- Auto-suggested field mappings
- Basic transformations:
  - Direct (no change)
  - Uppercase
  - Lowercase
  - Trim whitespace
- Schedule options: Manual, Hourly, Daily
- Conflict resolution: Source wins

#### Sync Execution
- Manual sync trigger (Run Now)
- Scheduled sync execution (cron-based)
- Incremental sync (only changed records)
- Sync history with run details
- Error display with failed records
- Retry failed sync runs

#### Monitoring & Alerts
- Dashboard with sync health overview
- Sync status indicators (Active/Error/Paused)
- Email notifications on sync failures
- Activity feed (recent actions)

#### Billing
- Free tier: 1 connector, 1 sync, 1,000 records/month
- Starter plan ($49/month): 5 connectors, 5 syncs, 50,000 records
- Pro plan ($199/month): 20 connectors, unlimited syncs, 500,000 records
- Stripe Checkout integration
- Plan limit enforcement

### Technical
- Next.js 14 with App Router
- PostgreSQL with Prisma ORM
- BullMQ + Redis for job queue
- JWT authentication
- API rate limiting

---

## Release Notes Format

### Template for Future Releases

```markdown
## [X.Y.Z] - YYYY-MM-DD

### Added
- New features

### Changed
- Changes in existing functionality

### Deprecated
- Features that will be removed in future versions

### Removed
- Features that were removed

### Fixed
- Bug fixes

### Security
- Security improvements or vulnerability fixes
```

---

## Version Guidelines

### Semantic Versioning

- **MAJOR** (X.0.0): Incompatible API changes, breaking changes
- **MINOR** (0.X.0): New features, backward compatible
- **PATCH** (0.0.X): Bug fixes, backward compatible

### Version Examples

| Change | Version Bump | Example |
|--------|--------------|---------|
| Breaking API change | Major | 1.0.0 → 2.0.0 |
| New connector added | Minor | 1.0.0 → 1.1.0 |
| Bug fix | Patch | 1.0.0 → 1.0.1 |
| Security fix | Patch | 1.0.0 → 1.0.1 |
| Performance improvement | Patch | 1.0.0 → 1.0.1 |
| New feature (backward compatible) | Minor | 1.0.0 → 1.1.0 |
| Deprecation notice | Minor | 1.0.0 → 1.1.0 |

---

## Roadmap Changelog

### v1.1.0 - Planned

#### Target: Month 2 post-launch

- [ ] Real-time sync via webhooks (Salesforce, HubSpot)
- [ ] Stripe connector
- [ ] Notion connector
- [ ] MySQL connector
- [ ] MFA/2FA support
- [ ] Custom cron schedules
- [ ] Performance improvements

### v1.2.0 - Planned

#### Target: Month 3 post-launch

- [ ] Bidirectional sync
- [ ] Conditional field mapping (if/then logic)
- [ ] Custom JavaScript transformations
- [ ] Record filtering (sync only matching records)
- [ ] Improved error recovery

### v1.3.0 - Planned

#### Target: Month 4 post-launch

- [ ] Public API (REST)
- [ ] Webhook notifications for events
- [ ] MongoDB connector
- [ ] Audit logging
- [ ] API key management improvements

### v2.0.0 - Planned

#### Target: Month 6 post-launch

- [ ] Custom connector builder
- [ ] Enterprise features (SSO/SAML)
- [ ] Data warehouse support (Snowflake, BigQuery)
- [ ] Advanced analytics and reporting
- [ ] Self-hosted option

---

## Migration Guides

### Upgrading to v1.1.0

```markdown
No breaking changes. Update your deployment:

1. Pull latest version
2. Run database migrations: `npx prisma migrate deploy`
3. Restart application

New environment variables (optional):
- STRIPE_WEBHOOK_URL: For Stripe connector
- NOTION_INTEGRATION_TOKEN: For Notion connector
```

### Upgrading to v2.0.0

```markdown
⚠️ Breaking Changes

1. API endpoint changes:
   - /api/v1/sync → /api/v2/syncs (plural)
   - Response format updated

2. Database migrations required:
   - Backup your database first
   - Run: `npx prisma migrate deploy`

3. Environment variable changes:
   - AUTH_SECRET → JWT_SECRET (renamed)
   - Add: SESSION_DURATION (optional)

See full migration guide: docs/migrations/v1-to-v2.md
```

---

## Communication

### Release Announcements

**Channels**:
- In-app notification banner
- Email to all users
- Blog post for major releases
- Twitter/X announcement
- Discord community (if applicable)

### Email Template

```
Subject: SyncForge v1.1.0 Released - Real-Time Sync & New Connectors

Hi [Name],

We're excited to announce SyncForge v1.1.0!

What's New:
✅ Real-time sync via webhooks
✅ Stripe connector
✅ Notion connector
✅ MySQL connector
✅ MFA/2FA support

These features are available now in your dashboard.

Questions? Reply to this email or visit our help center.

Best,
The SyncForge Team
```

### In-App Notification

```json
{
  "type": "release",
  "version": "1.1.0",
  "title": "New: Real-Time Sync & More Connectors",
  "message": "SyncForge v1.1.0 adds real-time sync, Stripe, Notion, and MySQL connectors.",
  "cta": {
    "label": "See What's New",
    "url": "/changelog"
  },
  "dismissible": true
}
```

---

## Historical Context

### Why SyncForge Exists

SyncForge was created to solve a common problem: keeping data in sync between SaaS applications is surprisingly difficult. Most solutions require:

1. Custom code and engineering time
2. Expensive enterprise platforms
3. Unreliable Zapier-style point solutions

SyncForge provides a middle path: professional-grade data sync that anyone can set up in minutes.

### Founding Principles

1. **No-code first**: Business users should be able to set up syncs
2. **Reliability matters**: Data sync must work every time
3. **Transparent pricing**: No hidden fees or surprise bills
4. **Developer-friendly**: When you need code, we have APIs

---

## Links

- [Product Roadmap](https://syncforge.io/roadmap) (public)
- [Documentation](https://docs.syncforge.io)
- [API Reference](https://docs.syncforge.io/api)
- [Status Page](https://status.syncforge.io)
- [GitHub Discussions](https://github.com/syncforge/syncforge/discussions)
