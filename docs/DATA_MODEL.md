# SyncForge Data Model

## Overview

SyncForge is a **Real-Time Collaboration Infrastructure** platform. This document defines the data model for enabling real-time presence, live cursors, document collaboration, comments, notifications, and voice features.

**Tech Stack**: Elixir, Phoenix 1.7+, Ash Framework, PostgreSQL

---

## Entity Relationship Diagram

```
┌─────────────────┐       ┌─────────────────┐       ┌─────────────────┐
│  Organization   │───────│   Membership    │───────│      User       │
└─────────────────┘       └─────────────────┘       └─────────────────┘
        │                                                    │
        │                                                    │
        ▼                                                    │
┌─────────────────┐                                          │
│     ApiKey      │                                          │
└─────────────────┘                                          │
        │                                                    │
        │                                                    │
        ▼                                                    ▼
┌─────────────────┐       ┌─────────────────┐       ┌─────────────────┐
│      Room       │───────│   Participant   │───────│  (User joins)   │
└─────────────────┘       └─────────────────┘       └─────────────────┘
        │                         │
        │                         │
        ▼                         ▼
┌─────────────────┐       ┌─────────────────┐
│    Document     │       │   CursorState   │
└─────────────────┘       └─────────────────┘
        │
        ├─────────────────┬─────────────────┐
        ▼                 ▼                 ▼
┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐
│    Snapshot     │ │    Comment      │ │  Notification   │
└─────────────────┘ └─────────────────┘ └─────────────────┘
                          │
                          ▼
                  ┌─────────────────┐
                  │    Reaction     │
                  └─────────────────┘

┌─────────────────┐       ┌─────────────────┐
│  VoiceSession   │───────│ VoiceParticipant│
└─────────────────┘       └─────────────────┘

┌─────────────────┐
│    Webhook      │
└─────────────────┘
```

---

## Ash Domains

SyncForge organizes resources into three Ash domains:

```elixir
# lib/syncforge/accounts.ex
defmodule SyncForge.Accounts do
  use Ash.Domain

  resources do
    resource SyncForge.Accounts.User
    resource SyncForge.Accounts.Organization
    resource SyncForge.Accounts.Membership
    resource SyncForge.Accounts.ApiKey
    resource SyncForge.Accounts.Webhook
    resource SyncForge.Accounts.WebhookDelivery
  end
end

# lib/syncforge/collaboration.ex
defmodule SyncForge.Collaboration do
  use Ash.Domain

  resources do
    resource SyncForge.Collaboration.Room
    resource SyncForge.Collaboration.Participant
    resource SyncForge.Collaboration.Document
    resource SyncForge.Collaboration.Snapshot
    resource SyncForge.Collaboration.Comment
    resource SyncForge.Collaboration.Reaction
    resource SyncForge.Collaboration.Mention
    resource SyncForge.Collaboration.Notification
    resource SyncForge.Collaboration.VoiceSession
    resource SyncForge.Collaboration.VoiceParticipant
  end
end

# lib/syncforge/analytics.ex
defmodule SyncForge.Analytics do
  use Ash.Domain

  resources do
    resource SyncForge.Analytics.RoomAnalytics
    resource SyncForge.Analytics.ConnectionLog
  end
end
```

---

## Core Entities

### Organization

Multi-tenant workspace containing all collaboration resources.

```elixir
defmodule SyncForge.Accounts.Organization do
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    domain: SyncForge.Accounts

  postgres do
    table "organizations"
    repo SyncForge.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string, allow_nil?: false
    attribute :slug, :string, allow_nil?: false
    attribute :logo_url, :string

    # Subscription & Limits
    attribute :plan, :atom do
      constraints one_of: [:free, :starter, :pro, :business, :enterprise]
      default :free
    end

    attribute :max_rooms, :integer, default: 5
    attribute :max_monthly_connections, :integer, default: 1000
    attribute :max_concurrent_users, :integer, default: 10

    # Usage Tracking
    attribute :current_month_connections, :integer, default: 0
    attribute :usage_reset_at, :utc_datetime

    # Billing
    attribute :stripe_customer_id, :string
    attribute :stripe_subscription_id, :string

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_slug, [:slug]
  end

  relationships do
    has_many :memberships, SyncForge.Accounts.Membership
    has_many :users, through: [:memberships, :user]
    has_many :rooms, SyncForge.Collaboration.Room
    has_many :api_keys, SyncForge.Accounts.ApiKey
    has_many :webhooks, SyncForge.Accounts.Webhook
  end
end
```

### User

Individual user account with authentication.

```elixir
defmodule SyncForge.Accounts.User do
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    domain: SyncForge.Accounts

  postgres do
    table "users"
    repo SyncForge.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :email, :string, allow_nil?: false
    attribute :name, :string
    attribute :avatar_url, :string
    attribute :hashed_password, :string, sensitive?: true

    # OAuth
    attribute :google_id, :string
    attribute :github_id, :string

    # Status
    attribute :status, :atom do
      constraints one_of: [:active, :suspended, :pending_verification]
      default :pending_verification
    end

    attribute :email_verified_at, :utc_datetime

    # Preferences
    attribute :preferences, :map, default: %{}

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_email, [:email]
  end

  relationships do
    has_many :memberships, SyncForge.Accounts.Membership
    has_many :organizations, through: [:memberships, :organization]
    has_many :participants, SyncForge.Collaboration.Participant
    has_many :comments, SyncForge.Collaboration.Comment
    has_many :notifications, SyncForge.Collaboration.Notification
  end
end
```

### Membership

Joins users to organizations with roles.

```elixir
defmodule SyncForge.Accounts.Membership do
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    domain: SyncForge.Accounts

  postgres do
    table "memberships"
    repo SyncForge.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :role, :atom do
      constraints one_of: [:owner, :admin, :member, :viewer]
      default :member
    end

    attribute :status, :atom do
      constraints one_of: [:active, :invited, :suspended]
      default :invited
    end

    attribute :invited_at, :utc_datetime
    attribute :accepted_at, :utc_datetime

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :organization, SyncForge.Accounts.Organization, allow_nil?: false
    belongs_to :user, SyncForge.Accounts.User, allow_nil?: false
    belongs_to :invited_by, SyncForge.Accounts.User
  end

  identities do
    identity :unique_membership, [:organization_id, :user_id]
  end
end
```

---

## Collaboration Entities

### Room

A collaboration space where users connect in real-time.

```elixir
defmodule SyncForge.Collaboration.Room do
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    domain: SyncForge.Collaboration

  postgres do
    table "rooms"
    repo SyncForge.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string, allow_nil?: false
    attribute :slug, :string, allow_nil?: false
    attribute :description, :string

    # Room Type
    attribute :type, :atom do
      constraints one_of: [:document, :canvas, :whiteboard, :custom]
      default :document
    end

    # Access Control
    attribute :access, :atom do
      constraints one_of: [:private, :organization, :public]
      default :private
    end

    attribute :password_hash, :string, sensitive?: true

    # Feature Flags
    attribute :features, :map do
      default %{
        "presence" => true,
        "cursors" => true,
        "comments" => true,
        "voice" => false,
        "screen_share" => false
      }
    end

    # Metadata
    attribute :metadata, :map, default: %{}

    # Status
    attribute :status, :atom do
      constraints one_of: [:active, :archived, :deleted]
      default :active
    end

    attribute :archived_at, :utc_datetime

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_room_slug, [:organization_id, :slug]
  end

  relationships do
    belongs_to :organization, SyncForge.Accounts.Organization, allow_nil?: false
    belongs_to :created_by, SyncForge.Accounts.User

    has_many :participants, SyncForge.Collaboration.Participant
    has_many :documents, SyncForge.Collaboration.Document
    has_many :comments, SyncForge.Collaboration.Comment
    has_many :voice_sessions, SyncForge.Collaboration.VoiceSession
  end
end
```

### Participant

Real-time presence tracking for users in a room. Managed via Phoenix Presence.

```elixir
defmodule SyncForge.Collaboration.Participant do
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    domain: SyncForge.Collaboration

  postgres do
    table "participants"
    repo SyncForge.Repo
  end

  attributes do
    uuid_primary_key :id

    # Connection Info
    attribute :connection_id, :string, allow_nil?: false
    attribute :connected_at, :utc_datetime, allow_nil?: false
    attribute :disconnected_at, :utc_datetime
    attribute :last_seen_at, :utc_datetime

    # Presence Data (synced from Phoenix Presence)
    attribute :status, :atom do
      constraints one_of: [:online, :away, :busy, :offline]
      default :online
    end

    # Cursor State (ephemeral, but logged for analytics)
    attribute :cursor_x, :float
    attribute :cursor_y, :float
    attribute :selection_start, :integer
    attribute :selection_end, :integer

    # User Agent / Device
    attribute :user_agent, :string
    attribute :ip_address, :string

    # Custom presence data from client
    attribute :presence_data, :map, default: %{}

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :room, SyncForge.Collaboration.Room, allow_nil?: false
    belongs_to :user, SyncForge.Accounts.User, allow_nil?: false
  end

  calculations do
    calculate :is_connected, :boolean, expr(is_nil(disconnected_at))
    calculate :session_duration, :integer, expr(
      fragment("EXTRACT(EPOCH FROM (COALESCE(?, NOW()) - ?))", disconnected_at, connected_at)
    )
  end
end
```

### Document

CRDT document state storage using Yjs.

```elixir
defmodule SyncForge.Collaboration.Document do
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    domain: SyncForge.Collaboration

  postgres do
    table "documents"
    repo SyncForge.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string, allow_nil?: false
    attribute :slug, :string

    # Document Type
    attribute :type, :atom do
      constraints one_of: [:text, :json, :canvas, :blocks]
      default :text
    end

    # Yjs State (binary CRDT state)
    attribute :yjs_state, :binary
    attribute :yjs_state_vector, :binary

    # For simpler documents, JSON fallback
    attribute :content, :map

    # Version tracking
    attribute :version, :integer, default: 1
    attribute :last_modified_at, :utc_datetime

    # Metadata
    attribute :metadata, :map, default: %{}

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_document_slug, [:room_id, :slug]
  end

  relationships do
    belongs_to :room, SyncForge.Collaboration.Room, allow_nil?: false
    belongs_to :created_by, SyncForge.Accounts.User
    belongs_to :last_modified_by, SyncForge.Accounts.User

    has_many :snapshots, SyncForge.Collaboration.Snapshot
    has_many :comments, SyncForge.Collaboration.Comment
  end
end
```

### Snapshot

Document version history for recovery and time-travel.

```elixir
defmodule SyncForge.Collaboration.Snapshot do
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    domain: SyncForge.Collaboration

  postgres do
    table "snapshots"
    repo SyncForge.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :version, :integer, allow_nil?: false

    # Snapshot Data
    attribute :yjs_state, :binary
    attribute :content, :map

    # Snapshot Type
    attribute :type, :atom do
      constraints one_of: [:auto, :manual, :milestone]
      default :auto
    end

    attribute :name, :string
    attribute :description, :string

    # Size tracking for storage limits
    attribute :size_bytes, :integer

    create_timestamp :inserted_at
  end

  relationships do
    belongs_to :document, SyncForge.Collaboration.Document, allow_nil?: false
    belongs_to :created_by, SyncForge.Accounts.User
  end
end
```

### Comment

Threaded comments anchored to document elements.

```elixir
defmodule SyncForge.Collaboration.Comment do
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    domain: SyncForge.Collaboration

  postgres do
    table "comments"
    repo SyncForge.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :body, :string, allow_nil?: false

    # Anchor Point (where the comment is attached)
    attribute :anchor_type, :atom do
      constraints one_of: [:selection, :element, :position, :none]
      default :none
    end

    attribute :anchor_data, :map do
      # For selection: %{start: 10, end: 25, text: "selected text"}
      # For element: %{element_id: "abc123"}
      # For position: %{x: 100, y: 200, page: 1}
      default %{}
    end

    # Thread Support
    attribute :resolved, :boolean, default: false
    attribute :resolved_at, :utc_datetime

    # Editing
    attribute :edited, :boolean, default: false
    attribute :edited_at, :utc_datetime

    # Soft delete
    attribute :deleted_at, :utc_datetime

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :room, SyncForge.Collaboration.Room, allow_nil?: false
    belongs_to :document, SyncForge.Collaboration.Document
    belongs_to :user, SyncForge.Accounts.User, allow_nil?: false

    # Threading
    belongs_to :parent, SyncForge.Collaboration.Comment
    has_many :replies, SyncForge.Collaboration.Comment, destination_attribute: :parent_id

    # Resolver
    belongs_to :resolved_by, SyncForge.Accounts.User

    has_many :reactions, SyncForge.Collaboration.Reaction
    has_many :mentions, SyncForge.Collaboration.Mention
  end
end
```

### Reaction

Emoji reactions on comments.

```elixir
defmodule SyncForge.Collaboration.Reaction do
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    domain: SyncForge.Collaboration

  postgres do
    table "reactions"
    repo SyncForge.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :emoji, :string, allow_nil?: false

    create_timestamp :inserted_at
  end

  relationships do
    belongs_to :comment, SyncForge.Collaboration.Comment, allow_nil?: false
    belongs_to :user, SyncForge.Accounts.User, allow_nil?: false
  end

  identities do
    identity :unique_reaction, [:comment_id, :user_id, :emoji]
  end
end
```

### Mention

User mentions in comments for notifications.

```elixir
defmodule SyncForge.Collaboration.Mention do
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    domain: SyncForge.Collaboration

  postgres do
    table "mentions"
    repo SyncForge.Repo
  end

  attributes do
    uuid_primary_key :id

    create_timestamp :inserted_at
  end

  relationships do
    belongs_to :comment, SyncForge.Collaboration.Comment, allow_nil?: false
    belongs_to :user, SyncForge.Accounts.User, allow_nil?: false
  end
end
```

---

## Communication Entities

### Notification

Real-time notifications for collaboration events.

```elixir
defmodule SyncForge.Collaboration.Notification do
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    domain: SyncForge.Collaboration

  postgres do
    table "notifications"
    repo SyncForge.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :type, :atom do
      constraints one_of: [
        :mention,
        :reply,
        :comment,
        :reaction,
        :room_invite,
        :document_shared,
        :voice_call,
        :system
      ]
      allow_nil?: false
    end

    attribute :title, :string, allow_nil?: false
    attribute :body, :string

    # Related entities
    attribute :resource_type, :string  # "room", "document", "comment"
    attribute :resource_id, :uuid

    # Deep link
    attribute :action_url, :string

    # Status
    attribute :read, :boolean, default: false
    attribute :read_at, :utc_datetime

    # Delivery tracking
    attribute :delivered_at, :utc_datetime
    attribute :clicked_at, :utc_datetime

    # For grouping related notifications
    attribute :group_key, :string

    create_timestamp :inserted_at
  end

  relationships do
    belongs_to :user, SyncForge.Accounts.User, allow_nil?: false
    belongs_to :actor, SyncForge.Accounts.User  # Who triggered the notification
    belongs_to :room, SyncForge.Collaboration.Room
  end
end
```

### VoiceSession

Voice room sessions for real-time audio.

```elixir
defmodule SyncForge.Collaboration.VoiceSession do
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    domain: SyncForge.Collaboration

  postgres do
    table "voice_sessions"
    repo SyncForge.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string

    attribute :status, :atom do
      constraints one_of: [:active, :ended]
      default :active
    end

    attribute :started_at, :utc_datetime, allow_nil?: false
    attribute :ended_at, :utc_datetime

    # Recording
    attribute :recording_enabled, :boolean, default: false
    attribute :recording_url, :string

    # Analytics
    attribute :peak_participants, :integer, default: 0
    attribute :total_duration_seconds, :integer

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :room, SyncForge.Collaboration.Room, allow_nil?: false
    belongs_to :started_by, SyncForge.Accounts.User

    has_many :voice_participants, SyncForge.Collaboration.VoiceParticipant
  end
end
```

### VoiceParticipant

Tracks users in voice sessions.

```elixir
defmodule SyncForge.Collaboration.VoiceParticipant do
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    domain: SyncForge.Collaboration

  postgres do
    table "voice_participants"
    repo SyncForge.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :joined_at, :utc_datetime, allow_nil?: false
    attribute :left_at, :utc_datetime

    attribute :muted, :boolean, default: false
    attribute :deafened, :boolean, default: false
    attribute :speaking, :boolean, default: false

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :voice_session, SyncForge.Collaboration.VoiceSession, allow_nil?: false
    belongs_to :user, SyncForge.Accounts.User, allow_nil?: false
  end
end
```

---

## Integration Entities

### ApiKey

SDK authentication for client applications.

```elixir
defmodule SyncForge.Accounts.ApiKey do
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    domain: SyncForge.Accounts

  postgres do
    table "api_keys"
    repo SyncForge.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string, allow_nil?: false
    attribute :key_prefix, :string, allow_nil?: false  # First 8 chars for identification
    attribute :key_hash, :string, allow_nil?: false, sensitive?: true

    attribute :type, :atom do
      constraints one_of: [:publishable, :secret]
      default :publishable
    end

    # Scopes
    attribute :scopes, {:array, :string} do
      default ["rooms:read", "rooms:write", "presence:read", "presence:write"]
    end

    # Rate Limiting
    attribute :rate_limit, :integer, default: 1000  # requests per minute

    # Status
    attribute :status, :atom do
      constraints one_of: [:active, :revoked, :expired]
      default :active
    end

    attribute :expires_at, :utc_datetime
    attribute :revoked_at, :utc_datetime

    # Usage tracking
    attribute :last_used_at, :utc_datetime
    attribute :usage_count, :integer, default: 0

    # Allowed origins for CORS
    attribute :allowed_origins, {:array, :string}, default: []

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :organization, SyncForge.Accounts.Organization, allow_nil?: false
    belongs_to :created_by, SyncForge.Accounts.User
    belongs_to :revoked_by, SyncForge.Accounts.User
  end
end
```

### Webhook

Webhook endpoints for event delivery.

```elixir
defmodule SyncForge.Accounts.Webhook do
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    domain: SyncForge.Accounts

  postgres do
    table "webhooks"
    repo SyncForge.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string, allow_nil?: false
    attribute :url, :string, allow_nil?: false
    attribute :secret, :string, sensitive?: true

    # Event subscriptions
    attribute :events, {:array, :string} do
      default [
        "room.created",
        "room.deleted",
        "participant.joined",
        "participant.left",
        "document.updated",
        "comment.created"
      ]
    end

    attribute :status, :atom do
      constraints one_of: [:active, :paused, :failed]
      default :active
    end

    # Retry configuration
    attribute :max_retries, :integer, default: 3
    attribute :retry_delay_seconds, :integer, default: 60

    # Health tracking
    attribute :consecutive_failures, :integer, default: 0
    attribute :last_triggered_at, :utc_datetime
    attribute :last_success_at, :utc_datetime
    attribute :last_failure_at, :utc_datetime
    attribute :last_failure_reason, :string

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :organization, SyncForge.Accounts.Organization, allow_nil?: false
    belongs_to :created_by, SyncForge.Accounts.User
  end
end
```

### WebhookDelivery

Tracks webhook delivery attempts.

```elixir
defmodule SyncForge.Accounts.WebhookDelivery do
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    domain: SyncForge.Accounts

  postgres do
    table "webhook_deliveries"
    repo SyncForge.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :event_type, :string, allow_nil?: false
    attribute :payload, :map, allow_nil?: false

    attribute :status, :atom do
      constraints one_of: [:pending, :success, :failed, :retrying]
      default :pending
    end

    attribute :response_status, :integer
    attribute :response_body, :string
    attribute :response_time_ms, :integer

    attribute :attempt, :integer, default: 1
    attribute :next_retry_at, :utc_datetime

    attribute :delivered_at, :utc_datetime

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :webhook, SyncForge.Accounts.Webhook, allow_nil?: false
  end
end
```

---

## Analytics Entities

### RoomAnalytics

Aggregated analytics for room usage.

```elixir
defmodule SyncForge.Analytics.RoomAnalytics do
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    domain: SyncForge.Analytics

  postgres do
    table "room_analytics"
    repo SyncForge.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :date, :date, allow_nil?: false

    # Connection metrics
    attribute :total_connections, :integer, default: 0
    attribute :unique_users, :integer, default: 0
    attribute :peak_concurrent_users, :integer, default: 0
    attribute :total_session_duration_seconds, :integer, default: 0

    # Collaboration metrics
    attribute :documents_edited, :integer, default: 0
    attribute :comments_created, :integer, default: 0
    attribute :reactions_added, :integer, default: 0
    attribute :voice_minutes, :integer, default: 0

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :room, SyncForge.Collaboration.Room, allow_nil?: false
  end

  identities do
    identity :unique_room_date, [:room_id, :date]
  end
end
```

### ConnectionLog

Detailed connection logs for debugging and analytics.

```elixir
defmodule SyncForge.Analytics.ConnectionLog do
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    domain: SyncForge.Analytics

  postgres do
    table "connection_logs"
    repo SyncForge.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :event_type, :atom do
      constraints one_of: [:connect, :disconnect, :error, :reconnect]
      allow_nil?: false
    end

    attribute :connection_id, :string
    attribute :user_agent, :string
    attribute :ip_address, :string
    attribute :region, :string

    attribute :error_code, :string
    attribute :error_message, :string

    attribute :metadata, :map, default: %{}

    create_timestamp :inserted_at
  end

  relationships do
    belongs_to :room, SyncForge.Collaboration.Room, allow_nil?: false
    belongs_to :user, SyncForge.Accounts.User
  end
end
```

---

## Indexes

```sql
-- Organizations
CREATE INDEX idx_organizations_slug ON organizations(slug);
CREATE INDEX idx_organizations_plan ON organizations(plan);

-- Users
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_status ON users(status);

-- Memberships
CREATE INDEX idx_memberships_user_id ON memberships(user_id);
CREATE INDEX idx_memberships_org_id ON memberships(organization_id);

-- Rooms
CREATE INDEX idx_rooms_org_id ON rooms(organization_id);
CREATE INDEX idx_rooms_status ON rooms(status);
CREATE INDEX idx_rooms_org_slug ON rooms(organization_id, slug);

-- Participants
CREATE INDEX idx_participants_room_id ON participants(room_id);
CREATE INDEX idx_participants_user_id ON participants(user_id);
CREATE INDEX idx_participants_connected ON participants(room_id) WHERE disconnected_at IS NULL;

-- Documents
CREATE INDEX idx_documents_room_id ON documents(room_id);
CREATE INDEX idx_documents_room_slug ON documents(room_id, slug);

-- Comments
CREATE INDEX idx_comments_room_id ON comments(room_id);
CREATE INDEX idx_comments_document_id ON comments(document_id);
CREATE INDEX idx_comments_parent_id ON comments(parent_id);
CREATE INDEX idx_comments_unresolved ON comments(room_id) WHERE resolved = false AND deleted_at IS NULL;

-- Notifications
CREATE INDEX idx_notifications_user_id ON notifications(user_id);
CREATE INDEX idx_notifications_unread ON notifications(user_id) WHERE read = false;
CREATE INDEX idx_notifications_created_at ON notifications(user_id, inserted_at DESC);

-- API Keys
CREATE INDEX idx_api_keys_org_id ON api_keys(organization_id);
CREATE INDEX idx_api_keys_prefix ON api_keys(key_prefix);

-- Webhooks
CREATE INDEX idx_webhooks_org_id ON webhooks(organization_id);
CREATE INDEX idx_webhooks_status ON webhooks(status);

-- Analytics
CREATE INDEX idx_room_analytics_room_date ON room_analytics(room_id, date);
CREATE INDEX idx_connection_logs_room_created ON connection_logs(room_id, inserted_at);
```

---

## Data Retention Policies

| Entity | Retention | Action |
|--------|-----------|--------|
| Participant (disconnected) | 90 days | Archive to cold storage |
| Snapshot | Per plan limit | Oldest auto-deleted |
| Notification | 30 days | Delete |
| ConnectionLog | 30 days | Delete |
| WebhookDelivery | 7 days | Delete |
| RoomAnalytics | 1 year | Aggregate then delete |

---

## Real-Time State (Ephemeral)

These are NOT stored in PostgreSQL. They live in Phoenix Presence / ETS:

```elixir
# In-memory presence state (Phoenix.Presence)
%{
  user_id: "user_123",
  room_id: "room_456",
  cursor: %{x: 100, y: 200},
  selection: %{start: 10, end: 25},
  status: :online,
  last_seen: ~U[2024-01-15 10:30:00Z],
  metadata: %{
    name: "John Doe",
    avatar: "https://...",
    color: "#FF5733"
  }
}
```

---

## Migration Order

1. `organizations` - Base tenant entity
2. `users` - User accounts
3. `memberships` - User-org relationships
4. `api_keys` - SDK authentication
5. `webhooks` - Event delivery
6. `rooms` - Collaboration spaces
7. `participants` - Presence tracking
8. `documents` - CRDT storage
9. `snapshots` - Version history
10. `comments` - Threaded discussions
11. `reactions` - Emoji reactions
12. `mentions` - User mentions
13. `notifications` - Real-time alerts
14. `voice_sessions` - Voice rooms
15. `voice_participants` - Voice attendees
16. `webhook_deliveries` - Delivery tracking
17. `room_analytics` - Usage metrics
18. `connection_logs` - Debug logs

---

## Related Documents

- [API Specification](API_SPEC.md)
- [Technical Specifications](SPECS.md)
- [SDK Guide](SDK_GUIDE.md)
