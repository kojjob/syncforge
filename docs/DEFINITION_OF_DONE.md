# SyncForge - Definition of Done

## Overview

This checklist defines when a task, user story, or feature is truly "done" and ready for merge/deployment.

---

## Task-Level Definition of Done

Every task must satisfy:

### Code Quality
- [ ] Code compiles without warnings (`mix compile --warnings-as-errors`)
- [ ] No Credo warnings or errors (`mix credo --strict`)
- [ ] Follows project coding standards (see CLAUDE.md)
- [ ] No IO.inspect, IEx.pry, or TODO comments left behind
- [ ] Functions are small (< 15 lines) and single-purpose
- [ ] Code is DRY (no copy-paste duplication)

### Testing
- [ ] Unit tests written and passing
- [ ] Test coverage ≥ 80% for new code
- [ ] Edge cases tested
- [ ] Error cases tested
- [ ] Integration tests passing (if applicable)

### Documentation
- [ ] Complex logic has inline comments
- [ ] Public functions have `@doc` attributes
- [ ] Modules have `@moduledoc` descriptions
- [ ] API changes documented in API_SPEC.md
- [ ] Database changes have migration files

### Review Ready
- [ ] Self-reviewed before requesting review
- [ ] PR description explains what and why
- [ ] Linked to relevant issue/task

---

## User Story Definition of Done

In addition to task-level items:

### Acceptance Criteria
- [ ] All acceptance criteria met
- [ ] Product owner/stakeholder approved
- [ ] Matches designs/specs (if applicable)

### User Experience
- [ ] Loading states implemented
- [ ] Error states implemented
- [ ] Empty states implemented
- [ ] Responsive design works (mobile, tablet, desktop)
- [ ] Accessibility requirements met (WCAG 2.1 AA)
- [ ] Works in supported browsers (Chrome, Firefox, Safari, Edge)

### Integration
- [ ] Integrates correctly with existing features
- [ ] No regression in existing functionality
- [ ] Feature flags configured (if phased rollout)

---

## Feature/Epic Definition of Done

In addition to user story items:

### End-to-End
- [ ] E2E tests written and passing
- [ ] Full user flow works as expected
- [ ] Performance within acceptable limits
- [ ] Security review completed

### Documentation
- [ ] User documentation written
- [ ] Help text in UI
- [ ] Release notes prepared
- [ ] Team trained on feature (if needed)

### Deployment
- [ ] Database migrations tested on staging
- [ ] Environment variables configured
- [ ] Feature verified on staging
- [ ] Rollback plan documented

---

## Release Definition of Done

Before any release:

### Quality Gates
- [ ] All tests passing (unit, integration, E2E)
- [ ] Code coverage above threshold (80%)
- [ ] Security scan passed (no high/critical)
- [ ] Performance benchmarks met
- [ ] No critical bugs open

### Operational Readiness
- [ ] Monitoring and alerts configured
- [ ] Logging implemented for key operations
- [ ] Runbook updated
- [ ] Backup and recovery verified

### Communication
- [ ] Changelog updated
- [ ] Release notes written
- [ ] Customer communication prepared (if applicable)
- [ ] Support team briefed

---

## Quick Reference Checklist

Copy this for PR descriptions:

```markdown
## Definition of Done

### Code
- [ ] Elixir compiles without warnings
- [ ] Credo passes
- [ ] No debug code (IO.inspect, IEx.pry)

### Tests
- [ ] Unit tests pass
- [ ] Coverage ≥ 80%
- [ ] Edge/error cases tested

### UI (if applicable)
- [ ] Loading states
- [ ] Error states
- [ ] Mobile responsive
- [ ] Accessible

### Documentation
- [ ] Code commented
- [ ] API docs updated
- [ ] Migrations included
```

---

## Non-Negotiables

These items are **never** skipped:

1. **Tests Pass** - All existing tests must pass (`mix test`)
2. **No Compile Warnings** - Warnings as errors, no shortcuts
3. **Security Review** - For auth, payment, data handling (use `mix sobelow`)
4. **Error Handling** - All errors handled gracefully
5. **No Secrets** - No credentials in code

---

## When to Escalate

Escalate to tech lead if:

- Cannot achieve 80% coverage
- Security concerns identified
- Breaking change required
- Performance significantly degraded
- Architecture decision needed

---

## Related Documents

- [CLAUDE.md](../CLAUDE.md) - Development standards
- [TEST_PLAN.md](TEST_PLAN.md) - Testing strategy
- [SPECS.md](SPECS.md) - Technical specifications
