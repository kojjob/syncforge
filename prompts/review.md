# Review Prompt - SyncForge

Use this prompt for code reviews, PR reviews, and quality assessments.

---

## Context

I'm working on SyncForge, a **Real-Time Collaboration Infrastructure** platform.

**Tech Stack**:
- Elixir
- Phoenix 1.7+ (with Channels and Presence)
- PostgreSQL (via Ecto)
- Oban for background jobs
- Yjs for CRDT document sync

**Quality Standards**:
- Elixir code quality (Credo strict)
- 80%+ test coverage
- Real-time latency SLAs (<50ms presence, <100ms sync)
- No security vulnerabilities
- Proper error handling

---

## Review Request

### Code to Review:
[Paste the code, diff, or PR link]

### Review Type:
- [ ] Full code review
- [ ] Security focused
- [ ] Performance focused
- [ ] Real-time focused
- [ ] Architecture review
- [ ] Pre-merge check

### Context:
[What does this code do? What problem does it solve?]

---

## Review Checklist

### 1. Correctness

- [ ] Code does what it's supposed to do
- [ ] Edge cases handled
- [ ] Error cases handled with proper return tuples
- [ ] No obvious bugs
- [ ] Business logic is correct
- [ ] Pattern matching is exhaustive

### 2. Security

- [ ] No SQL injection vulnerabilities (use Ecto queries)
- [ ] Input validation present
- [ ] Authentication/authorization in channels and controllers
- [ ] Sensitive data not logged
- [ ] No hardcoded secrets
- [ ] Proper token verification in socket connect
- [ ] Room authorization checked on join

### 3. Real-Time Performance

- [ ] Presence updates are efficient (incremental diff)
- [ ] No blocking operations in channel handlers
- [ ] Broadcasts use `broadcast_from!` to exclude sender
- [ ] Document sync operations are non-blocking
- [ ] Cursor updates throttled appropriately
- [ ] No N+1 queries in presence lookups
- [ ] PubSub topics are properly scoped

### 4. Code Quality

- [ ] Follows Elixir naming conventions (snake_case)
- [ ] Functions are small and focused (<15 lines)
- [ ] No code duplication
- [ ] Meaningful function/variable names
- [ ] Proper use of pattern matching
- [ ] Uses `with` for complex conditionals
- [ ] Pipe operator used appropriately
- [ ] Module organization follows project structure

### 5. Testing

- [ ] Tests exist for new code
- [ ] Tests cover happy path
- [ ] Tests cover error cases
- [ ] Channel tests use `Phoenix.ChannelTest`
- [ ] Presence tests verify tracking and diffs
- [ ] Tests are readable and well-named
- [ ] No flaky tests (async issues handled)

### 6. Documentation

- [ ] Complex logic has comments
- [ ] Public functions have @doc
- [ ] Module has @moduledoc
- [ ] Typespecs (@spec) for public functions
- [ ] API changes documented

### 7. Architecture

- [ ] Follows existing patterns
- [ ] Proper separation of concerns (contexts)
- [ ] No circular dependencies
- [ ] Channel handlers delegate to contexts
- [ ] Changes are backwards compatible (or documented)

---

## Review Categories

### Blocker (Must Fix)

Issues that must be fixed before merge:

- Security vulnerabilities
- Data loss risks
- Breaking changes without migration
- Missing critical tests
- Obvious bugs
- Real-time performance regression

### Major (Should Fix)

Issues that should be fixed but could be addressed in follow-up:

- Performance problems
- Poor error handling
- Missing edge case handling
- Code quality issues
- Incomplete test coverage

### Minor (Nice to Fix)

Suggestions for improvement:

- Style inconsistencies
- Minor refactoring opportunities
- Documentation improvements
- Additional test coverage
- Better naming

### Question

Clarification requests:

- Why was this approach chosen?
- Is this intentional behavior?
- What does this variable represent?

---

## Review Comment Templates

### Security Issue

```markdown
🔴 **Security: [Issue Type]**

**Problem:** [Description of the vulnerability]

**Risk:** [What could happen if exploited]

**Suggestion:**
```elixir
# Instead of:
def join("room:" <> room_id, _params, socket) do
  {:ok, socket}  # No authorization!
end

# Use:
def join("room:" <> room_id, _params, socket) do
  case Rooms.authorize_join(room_id, socket.assigns.current_user) do
    {:ok, room} -> {:ok, assign(socket, :room, room)}
    {:error, reason} -> {:error, %{reason: reason}}
  end
end
```
```

### Performance Issue

```markdown
🟡 **Performance: [Issue Type]**

**Problem:** [Description of the performance issue]

**Impact:** [Expected impact on latency/throughput]

**Suggestion:**
```elixir
# Instead of:
def handle_in("cursor:update", payload, socket) do
  # Blocking database call in channel handler
  Repo.insert!(cursor_changeset(payload))
  broadcast!(socket, "cursor:update", payload)
  {:noreply, socket}
end

# Use async persistence:
def handle_in("cursor:update", payload, socket) do
  broadcast!(socket, "cursor:update", payload)
  # Persist asynchronously
  Task.start(fn -> persist_cursor(payload) end)
  {:noreply, socket}
end
```
```

### Real-Time Issue

```markdown
🟠 **Real-Time: [Issue Type]**

**Problem:** [Description of the real-time issue]

**Impact:** [Expected impact on collaboration experience]

**Suggestion:**
```elixir
# Instead of:
def handle_info(:after_join, socket) do
  # Broadcasting to self causes duplicate
  broadcast!(socket, "user:joined", user_data)
  {:noreply, socket}
end

# Use broadcast_from to exclude sender:
def handle_info(:after_join, socket) do
  broadcast_from!(socket, "user:joined", user_data)
  {:noreply, socket}
end
```
```

### Code Quality Issue

```markdown
🟢 **Quality: [Issue Type]**

**Observation:** [What could be improved]

**Suggestion:**
```elixir
# Consider using pattern matching and with:
def handle_in("comment:add", %{"body" => body} = payload, socket)
    when is_binary(body) and byte_size(body) > 0 do
  with {:ok, comment} <- Comments.create(socket.assigns.user, payload),
       :ok <- broadcast_comment(socket, comment) do
    {:reply, {:ok, comment}, socket}
  else
    {:error, changeset} -> {:reply, {:error, format_errors(changeset)}, socket}
  end
end
```
```

### Question

```markdown
❓ **Question**

[Your question here]

Context: I'm trying to understand [specific aspect].
```

### Positive Feedback

```markdown
✅ **Nice!**

[What you liked about the code]

Good use of pattern matching and proper error handling!
```

---

## Review Response Format

When providing a review:

```markdown
## Summary

[Overall assessment: Approved / Approved with comments / Changes requested]

[Brief summary of the code and its purpose]

## Blockers (X)

[List of issues that must be fixed]

## Major Issues (X)

[List of significant issues]

## Minor Issues (X)

[List of minor suggestions]

## Questions (X)

[Clarification requests]

## Positive Notes

[What was done well]

## Recommendations

[Overall suggestions for improvement]
```

---

## Security Review Specifics

When doing security-focused review:

### Authentication & Authorization
- [ ] Socket connection verifies token
- [ ] Channel join checks user permissions
- [ ] Room access respects organization boundaries
- [ ] API endpoints require authentication
- [ ] Role checks at correct granularity

### Data Protection
- [ ] Sensitive data not in logs (Logger.metadata filtered)
- [ ] Database queries use Ecto (no raw SQL)
- [ ] User input validated with changesets
- [ ] File uploads validated (if applicable)

### Real-Time Security
- [ ] Broadcasts don't leak data to unauthorized users
- [ ] Presence metadata doesn't expose sensitive info
- [ ] Rate limiting on channel events
- [ ] Proper CSRF handling for socket connection

---

## Performance Review Specifics

When doing performance-focused review:

### Database
- [ ] Queries use proper indexes
- [ ] N+1 queries eliminated (preloading)
- [ ] Pagination for large datasets
- [ ] No blocking DB calls in channel handlers

### Real-Time
- [ ] Presence operations efficient (<50ms)
- [ ] Document sync within SLA (<100ms)
- [ ] Cursor broadcasts throttled
- [ ] Proper use of `broadcast_from!`
- [ ] No full state sync on every update

### Memory
- [ ] No unbounded data accumulation in socket assigns
- [ ] Proper cleanup in terminate callback
- [ ] GenServer state doesn't grow unbounded
- [ ] Large binaries not kept in process state

---

## Real-Time Review Specifics

When doing real-time-focused review:

### Channel Design
- [ ] Proper topic naming (room:id, user:id)
- [ ] Event names are clear and consistent
- [ ] Payloads are minimal (only needed data)
- [ ] Reply vs push used correctly

### Presence
- [ ] Tracker configured with appropriate timeout
- [ ] Metadata includes only necessary fields
- [ ] Multi-device handling considered
- [ ] Presence diff used instead of full list

### Document Sync
- [ ] CRDT updates applied correctly
- [ ] Sync state sent on join
- [ ] Persistence is asynchronous
- [ ] Conflict resolution tested

---

## Review Etiquette

### For Reviewers

1. Be constructive, not critical
2. Explain the "why" not just the "what"
3. Suggest solutions, don't just point out problems
4. Acknowledge good code
5. Ask questions instead of assuming
6. Consider real-time implications

### For Authors

1. Keep PRs small (< 400 lines changed)
2. Write clear PR descriptions
3. Self-review before requesting
4. Respond to all comments
5. Test with multiple clients before review
6. Don't take feedback personally

---

## Output Format

When completing a review:

1. **Summary** - Overall assessment
2. **Blockers** - Must-fix issues with solutions
3. **Major** - Should-fix issues with suggestions
4. **Minor** - Nice-to-fix suggestions
5. **Questions** - Clarification requests
6. **Positives** - What was done well
