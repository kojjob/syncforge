# SyncForge - API Specification

## Overview

RESTful API specification for SyncForge. All endpoints follow platform conventions defined in the shared architecture.

**Base URL**: `https://api.syncforge.io/v1`

---

## Authentication

### Bearer Token Authentication

```http
Authorization: Bearer <access_token>
```

### API Key Authentication

```http
X-API-Key: sf_live_abc123...
```

API keys use `sf_live_` prefix for production and `sf_test_` for sandbox.

---

## Common Headers

### Request Headers

| Header | Required | Description |
|--------|----------|-------------|
| `Authorization` | Yes* | Bearer token or API key |
| `Content-Type` | Yes | `application/json` |
| `X-Request-ID` | No | Client-generated request ID |
| `X-Organization-ID` | Varies | Required for multi-org users |

### Response Headers

| Header | Description |
|--------|-------------|
| `X-Request-ID` | Echo of client ID or generated |
| `X-RateLimit-Limit` | Requests allowed per window |
| `X-RateLimit-Remaining` | Requests remaining |
| `X-RateLimit-Reset` | Unix timestamp when limit resets |

---

## Endpoints

### Authentication

#### POST /auth/register

Create a new user account.

**Request:**
```json
{
  "email": "user@example.com",
  "password": "securePassword123!",
  "firstName": "John",
  "lastName": "Doe"
}
```

**Response (201):**
```json
{
  "data": {
    "user": {
      "id": "usr_abc123",
      "email": "user@example.com",
      "firstName": "John",
      "lastName": "Doe",
      "emailVerified": false,
      "createdAt": "2024-01-15T10:30:00Z"
    },
    "accessToken": "eyJhbGciOiJIUzI1NiIs...",
    "refreshToken": "rt_xyz789..."
  }
}
```

#### POST /auth/login

Authenticate and receive tokens.

**Request:**
```json
{
  "email": "user@example.com",
  "password": "securePassword123!"
}
```

**Response (200):**
```json
{
  "data": {
    "accessToken": "eyJhbGciOiJIUzI1NiIs...",
    "refreshToken": "rt_xyz789...",
    "expiresIn": 3600
  }
}
```

#### POST /auth/refresh

Refresh access token.

**Request:**
```json
{
  "refreshToken": "rt_xyz789..."
}
```

#### POST /auth/logout

Invalidate current session.

---

### Organizations

#### GET /organizations

List organizations for current user.

**Response (200):**
```json
{
  "data": [
    {
      "id": "org_abc123",
      "name": "Acme Inc",
      "slug": "acme-inc",
      "plan": "PROFESSIONAL",
      "role": "OWNER",
      "createdAt": "2024-01-01T00:00:00Z"
    }
  ],
  "pagination": {
    "total": 1,
    "limit": 20,
    "offset": 0,
    "hasMore": false
  }
}
```

#### POST /organizations

Create a new organization.

**Request:**
```json
{
  "name": "Acme Inc",
  "slug": "acme-inc"
}
```

#### GET /organizations/:id

Get organization details.

#### PATCH /organizations/:id

Update organization settings.

#### DELETE /organizations/:id

Delete organization (owner only).

---

### Organization Members

#### GET /organizations/:orgId/members

List organization members.

**Response (200):**
```json
{
  "data": [
    {
      "id": "mem_abc123",
      "userId": "usr_xyz789",
      "email": "user@example.com",
      "firstName": "John",
      "lastName": "Doe",
      "role": "ADMIN",
      "status": "ACTIVE",
      "joinedAt": "2024-01-15T10:30:00Z"
    }
  ]
}
```

#### POST /organizations/:orgId/members/invite

Invite a new member.

**Request:**
```json
{
  "email": "newuser@example.com",
  "role": "EDITOR"
}
```

#### PATCH /organizations/:orgId/members/:memberId

Update member role.

**Request:**
```json
{
  "role": "ADMIN"
}
```

#### DELETE /organizations/:orgId/members/:memberId

Remove member from organization.

---

### Connectors

#### GET /connectors

List connectors for organization.

**Query Parameters:**
- `status`: Filter by status (CONNECTED, DISCONNECTED, ERROR)
- `type`: Filter by connector type

**Response (200):**
```json
{
  "data": [
    {
      "id": "con_abc123",
      "name": "Production Salesforce",
      "type": "SALESFORCE",
      "status": "CONNECTED",
      "lastTestedAt": "2024-01-15T10:30:00Z",
      "createdAt": "2024-01-01T00:00:00Z"
    }
  ]
}
```

#### POST /connectors

Create a new connector.

**Request (OAuth Connector):**
```json
{
  "name": "Production Salesforce",
  "type": "SALESFORCE",
  "config": {
    "instanceUrl": "https://acme.salesforce.com"
  }
}
```

**Response (201):**
```json
{
  "data": {
    "id": "con_abc123",
    "authUrl": "https://login.salesforce.com/oauth/authorize?..."
  }
}
```

**Request (Database Connector):**
```json
{
  "name": "Analytics DB",
  "type": "POSTGRESQL",
  "config": {
    "host": "db.example.com",
    "port": 5432,
    "database": "analytics",
    "ssl": true
  },
  "credentials": {
    "username": "sync_user",
    "password": "secure_password"
  }
}
```

#### GET /connectors/:id

Get connector details including metadata.

**Response (200):**
```json
{
  "data": {
    "id": "con_abc123",
    "name": "Production Salesforce",
    "type": "SALESFORCE",
    "status": "CONNECTED",
    "config": {
      "instanceUrl": "https://acme.salesforce.com"
    },
    "metadata": {
      "objects": [
        {
          "name": "Contact",
          "label": "Contact",
          "fields": [
            {"name": "Id", "type": "id", "label": "Contact ID"},
            {"name": "Email", "type": "email", "label": "Email"},
            {"name": "FirstName", "type": "string", "label": "First Name"}
          ]
        }
      ],
      "updatedAt": "2024-01-15T10:30:00Z"
    },
    "lastTestedAt": "2024-01-15T10:30:00Z",
    "createdAt": "2024-01-01T00:00:00Z"
  }
}
```

#### PATCH /connectors/:id

Update connector configuration.

#### DELETE /connectors/:id

Delete connector (fails if used in syncs).

#### POST /connectors/:id/test

Test connector connectivity.

**Response (200):**
```json
{
  "data": {
    "success": true,
    "latency": 234,
    "message": "Connection successful"
  }
}
```

#### POST /connectors/:id/refresh-metadata

Refresh connector metadata (objects, fields).

#### POST /connectors/:id/oauth/callback

Handle OAuth callback.

**Request:**
```json
{
  "code": "auth_code_from_provider",
  "state": "state_token"
}
```

---

### Syncs

#### GET /syncs

List syncs for organization.

**Query Parameters:**
- `status`: Filter by status
- `connectorId`: Filter by connector

**Response (200):**
```json
{
  "data": [
    {
      "id": "syn_abc123",
      "name": "Salesforce → HubSpot Contacts",
      "direction": "SOURCE_TO_DEST",
      "status": "ACTIVE",
      "triggerType": "SCHEDULED",
      "schedule": "0 * * * *",
      "sourceConnector": {
        "id": "con_sf123",
        "name": "Salesforce",
        "type": "SALESFORCE"
      },
      "destConnector": {
        "id": "con_hs456",
        "name": "HubSpot",
        "type": "HUBSPOT"
      },
      "sourceObject": "Contact",
      "destObject": "contacts",
      "lastRunAt": "2024-01-15T10:00:00Z",
      "lastSuccessAt": "2024-01-15T10:00:00Z",
      "stats": {
        "totalRecordsSynced": 15420,
        "totalErrors": 12
      },
      "createdAt": "2024-01-01T00:00:00Z"
    }
  ]
}
```

#### POST /syncs

Create a new sync.

**Request:**
```json
{
  "name": "Salesforce → HubSpot Contacts",
  "sourceConnectorId": "con_sf123",
  "destConnectorId": "con_hs456",
  "sourceObject": "Contact",
  "destObject": "contacts",
  "direction": "SOURCE_TO_DEST",
  "triggerType": "SCHEDULED",
  "schedule": "0 * * * *",
  "conflictStrategy": "SOURCE_WINS",
  "fieldMappings": [
    {
      "sourceField": "Email",
      "destField": "email",
      "transformType": "LOWERCASE"
    },
    {
      "sourceField": "FirstName",
      "destField": "firstname",
      "transformType": "DIRECT"
    },
    {
      "sourceField": "LastName",
      "destField": "lastname",
      "transformType": "DIRECT"
    }
  ]
}
```

#### GET /syncs/:id

Get sync details.

#### PATCH /syncs/:id

Update sync configuration.

#### DELETE /syncs/:id

Delete sync.

#### POST /syncs/:id/activate

Activate a sync.

#### POST /syncs/:id/pause

Pause a sync.

#### POST /syncs/:id/run

Trigger a manual sync run.

**Request (optional):**
```json
{
  "fullSync": true
}
```

**Response (202):**
```json
{
  "data": {
    "syncRunId": "run_xyz789",
    "status": "PENDING",
    "startedAt": "2024-01-15T10:30:00Z"
  }
}
```

---

### Sync Runs

#### GET /syncs/:syncId/runs

List sync runs.

**Query Parameters:**
- `status`: Filter by status
- `since`: Filter runs after date
- `limit`: Number of results (default 20, max 100)

**Response (200):**
```json
{
  "data": [
    {
      "id": "run_xyz789",
      "triggeredBy": "MANUAL",
      "status": "COMPLETED",
      "startedAt": "2024-01-15T10:30:00Z",
      "completedAt": "2024-01-15T10:32:45Z",
      "stats": {
        "recordsProcessed": 1250,
        "recordsCreated": 45,
        "recordsUpdated": 1180,
        "recordsDeleted": 5,
        "recordsFailed": 20,
        "recordsSkipped": 0
      }
    }
  ]
}
```

#### GET /syncs/:syncId/runs/:runId

Get sync run details.

**Response (200):**
```json
{
  "data": {
    "id": "run_xyz789",
    "triggeredBy": "MANUAL",
    "triggeredByUserId": "usr_abc123",
    "status": "COMPLETED",
    "startedAt": "2024-01-15T10:30:00Z",
    "completedAt": "2024-01-15T10:32:45Z",
    "stats": {
      "recordsProcessed": 1250,
      "recordsCreated": 45,
      "recordsUpdated": 1180,
      "recordsDeleted": 5,
      "recordsFailed": 20,
      "recordsSkipped": 0
    },
    "errors": [
      {
        "sourceId": "003abc123",
        "error": "Required field 'email' is missing",
        "errorCode": "VALIDATION_ERROR"
      }
    ]
  }
}
```

#### POST /syncs/:syncId/runs/:runId/retry

Retry failed records in a sync run.

#### POST /syncs/:syncId/runs/:runId/cancel

Cancel a running sync.

---

### Sync Records (for debugging)

#### GET /syncs/:syncId/runs/:runId/records

List records from a sync run.

**Query Parameters:**
- `status`: Filter by status (SUCCESS, FAILED, SKIPPED)
- `limit`: Number of results
- `cursor`: Pagination cursor

**Response (200):**
```json
{
  "data": [
    {
      "id": "rec_abc123",
      "sourceId": "003xyz789",
      "destId": "contact_456",
      "operation": "UPDATE",
      "status": "SUCCESS",
      "processedAt": "2024-01-15T10:31:00Z"
    }
  ],
  "pagination": {
    "cursor": "eyJpZCI6InJlY18xMjMifQ==",
    "hasMore": true
  }
}
```

---

### Field Mappings

#### GET /syncs/:syncId/mappings

List field mappings for a sync.

#### POST /syncs/:syncId/mappings

Add a field mapping.

**Request:**
```json
{
  "sourceField": "Phone",
  "destField": "phone",
  "transformType": "DIRECT",
  "required": false
}
```

#### PATCH /syncs/:syncId/mappings/:mappingId

Update a field mapping.

#### DELETE /syncs/:syncId/mappings/:mappingId

Delete a field mapping.

#### POST /syncs/:syncId/mappings/auto-suggest

Get auto-suggested field mappings.

**Response (200):**
```json
{
  "data": {
    "suggestions": [
      {
        "sourceField": "Email",
        "destField": "email",
        "confidence": 0.98,
        "transformType": "LOWERCASE"
      },
      {
        "sourceField": "FirstName",
        "destField": "firstname",
        "confidence": 0.95,
        "transformType": "DIRECT"
      }
    ]
  }
}
```

---

### Webhooks

#### GET /webhooks

List organization webhooks.

#### POST /webhooks

Create a webhook.

**Request:**
```json
{
  "name": "Sync Notifications",
  "url": "https://example.com/webhooks/syncforge",
  "events": ["sync.run.completed", "sync.run.failed"],
  "headers": {
    "X-Custom-Header": "value"
  }
}
```

#### GET /webhooks/:id

Get webhook details.

#### PATCH /webhooks/:id

Update webhook configuration.

#### DELETE /webhooks/:id

Delete webhook.

#### POST /webhooks/:id/test

Send test webhook.

---

### API Keys

#### GET /api-keys

List organization API keys.

**Response (200):**
```json
{
  "data": [
    {
      "id": "key_abc123",
      "name": "Production Integration",
      "keyPrefix": "sf_live_a",
      "scopes": ["syncs:read", "syncs:run"],
      "status": "ACTIVE",
      "lastUsedAt": "2024-01-15T10:30:00Z",
      "createdAt": "2024-01-01T00:00:00Z"
    }
  ]
}
```

#### POST /api-keys

Create API key.

**Request:**
```json
{
  "name": "Production Integration",
  "scopes": ["syncs:read", "syncs:run"],
  "expiresAt": "2025-01-01T00:00:00Z"
}
```

**Response (201):**
```json
{
  "data": {
    "id": "key_abc123",
    "name": "Production Integration",
    "key": "sf_live_abc123xyz789...",
    "scopes": ["syncs:read", "syncs:run"],
    "expiresAt": "2025-01-01T00:00:00Z"
  }
}
```

⚠️ **Note**: Full API key is only returned on creation.

#### DELETE /api-keys/:id

Revoke API key.

---

### Activity Log

#### GET /activity

List organization activity.

**Query Parameters:**
- `action`: Filter by action type
- `resourceType`: Filter by resource
- `since`: Filter after date
- `until`: Filter before date

**Response (200):**
```json
{
  "data": [
    {
      "id": "act_abc123",
      "action": "sync.created",
      "resourceType": "Sync",
      "resourceId": "syn_xyz789",
      "actor": {
        "type": "USER",
        "id": "usr_abc123",
        "name": "John Doe"
      },
      "metadata": {
        "syncName": "Salesforce → HubSpot"
      },
      "ipAddress": "192.168.1.1",
      "createdAt": "2024-01-15T10:30:00Z"
    }
  ]
}
```

---

## Webhook Events

### Event Payload Format

```json
{
  "id": "evt_abc123",
  "type": "sync.run.completed",
  "timestamp": "2024-01-15T10:30:00Z",
  "data": {
    // Event-specific data
  },
  "organizationId": "org_xyz789"
}
```

### Event Types

| Event | Description |
|-------|-------------|
| `sync.created` | New sync created |
| `sync.updated` | Sync configuration updated |
| `sync.deleted` | Sync deleted |
| `sync.activated` | Sync activated |
| `sync.paused` | Sync paused |
| `sync.run.started` | Sync run started |
| `sync.run.completed` | Sync run completed successfully |
| `sync.run.failed` | Sync run failed |
| `sync.run.completed_with_errors` | Sync completed with some errors |
| `connector.connected` | Connector connected successfully |
| `connector.disconnected` | Connector disconnected |
| `connector.error` | Connector encountered error |

### Webhook Signature Verification

```
X-SyncForge-Signature: sha256=abc123...
X-SyncForge-Timestamp: 1705315800
```

Verify signature:
```javascript
const crypto = require('crypto');

function verifyWebhookSignature(payload, signature, timestamp, secret) {
  const signedPayload = `${timestamp}.${JSON.stringify(payload)}`;
  const expectedSignature = crypto
    .createHmac('sha256', secret)
    .update(signedPayload)
    .digest('hex');
  return `sha256=${expectedSignature}` === signature;
}
```

---

## Error Codes

| Code | HTTP Status | Description |
|------|-------------|-------------|
| `AUTHENTICATION_ERROR` | 401 | Invalid or missing credentials |
| `AUTHORIZATION_ERROR` | 403 | Insufficient permissions |
| `NOT_FOUND` | 404 | Resource not found |
| `VALIDATION_ERROR` | 422 | Request validation failed |
| `CONFLICT` | 409 | Resource conflict |
| `RATE_LIMIT_EXCEEDED` | 429 | Too many requests |
| `INTERNAL_ERROR` | 500 | Internal server error |
| `CONNECTOR_ERROR` | 502 | External connector error |
| `SERVICE_UNAVAILABLE` | 503 | Service temporarily unavailable |

---

## Rate Limits

| Plan | Requests/Minute | Requests/Hour |
|------|----------------|---------------|
| Free | 60 | 1,000 |
| Starter | 300 | 5,000 |
| Pro | 1,000 | 20,000 |
| Enterprise | Custom | Custom |

---

## Related Documents

- [Technical Specifications](SPECS.md)
- [Data Model](DATA_MODEL.md)
