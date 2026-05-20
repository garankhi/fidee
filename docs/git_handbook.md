# Git Handbook

## Purpose

This document defines the Git workflow, GitHub practices, branching strategy, PR process, and review rules for the project.

The goal is to:
- Keep the repository clean and maintainable
- Reduce accidental project breakages
- Improve collaboration quality
- Make reviews easier and faster
- Keep Git history readable and revert-friendly

---

# 1. Ticket Execution Rules

## 1.1 Avoid Cross-Task Changes

When implementing a ticket:

- ONLY modify files related to the current ticket
- DO NOT include unrelated refactors or cleanup
- DO NOT fix unrelated bugs while working on another task
- DO NOT restructure modules unless explicitly required in the ticket

### Why?

Cross-task changes:
- Increase review complexity
- Make regressions harder to trace
- Increase merge conflicts
- Create hidden side effects
- Make reverting dangerous

---

## 1.2 If You Find Another Problem

If you discover an unrelated issue while implementing a ticket:

### Preferred Approach
Create a new ticket.

### Alternative Approach (When Ticket Count Is Limited)
If Linear ticket limits are a concern:

1. Report the issue to the owner/assignee responsible
2. Perform a quick P2P review/discussion
3. Add additional Acceptance Criteria (AC) to the existing ticket
4. Clearly document the additional scope

DO NOT silently fix unrelated issues without communication.

---

## 1.3 Keep File Changes Reasonable

The number of changed files should match the scope of the ticket.

### Expected Guidelines

| Ticket Scope | Expected File Changes |
|---|---|
| Minor Fix | < 10 files |
| Medium Feature | 10–30 files |
| Large Feature | Depends on architecture |

If a ticket suddenly touches too many files:
- Re-evaluate the implementation
- Consider splitting the work
- Ask for architectural review

Large unexpected diffs are usually a warning sign.

---

## 1.4 Protect Project Stability

Before creating a PR:

- Ensure the project builds successfully
- Ensure lint passes
- Ensure tests pass (if available)
- Avoid breaking existing flows
- Avoid introducing unrelated formatting noise

---

# 2. Commit Message Convention

All commits MUST follow conventional commit standards.

## Format

```bash
type(scope): short description
```

---

## Examples

```bash
feat(auth): create auth middleware
fix(api): handle null response from backend
docs(git): add branching strategy documentation
test(user): add unit tests for profile service
refactor(ui): simplify modal state handling
```

---

## Allowed Types

| Type     | Purpose                                    |
| -------- | ------------------------------------------ |
| feat     | New feature                                |
| fix      | Bug fix                                    |
| docs     | Documentation                              |
| test     | Tests                                      |
| refactor | Code restructuring without behavior change |
| chore    | Maintenance                                |
| style    | Formatting only                            |
| perf     | Performance improvement                    |

---

## Commit Rules

### Good Practices

* Keep commits focused
* One logical change per commit
* Use meaningful descriptions
* Make commits reviewable

### Bad Practices

```bash
fix: update
feat: stuff
wip
final fix
aaaa
```

---

# 3. Branch Naming Strategy

## Branch Naming Format

```bash
<developer-name>/<ticket-id>-<ticket-title>
```

---

## Example

Ticket:

```txt
VIE-8
```

Branch:

```bash
hieudepoet/vie-8-tim-003-team-collaboration-guidelines-git-flow-branching-strategy-pr
```

---

## Rules

* Use lowercase only
* Use hyphens (`-`)
* No spaces
* Keep names readable
* Include ticket ID

---

# 4. Branch Workflow

## 4.1 Create Branch

Always create branches from the latest `main`.

```bash
git checkout main
git pull origin main
git checkout -b <branch-name>
```

---

## 4.2 Publish Branch Immediately

After creating a branch:

```bash
git push -u origin <branch-name>
```

This is REQUIRED.

### Why?

* Prevents lost work
* Enables visibility
* Enables early collaboration
* Allows draft PR creation

---

## 4.3 Open Draft PR Early

If the ticket is not finished yet:

* Create a Draft PR immediately after publishing the branch

### Why?

* Allows early feedback
* Makes progress visible
* Enables async review
* Helps track implementation

When completed:

* Convert Draft PR → Ready for Review

---

# 5. Pull Request Rules

## 5.1 PR Naming

Preferred:

* Same as commit convention

Alternative:

* Same as branch name

---

## Good Examples

```txt
feat(auth): create jwt authentication middleware
fix(payment): resolve duplicate transaction issue
docs(git): add PR review workflow
```

---

# 6. PR Review Process

## 6.1 Request Reviewers

Once PR is ready:

* Mark PR as Ready for Review
* Request reviewer(s)

---

## 6.2 Minimum Approval Rule

A PR can ONLY be merged when:

* At least 1 reviewer approves the PR

No self-approval.

---

## 6.3 Review Practices

Reviewers should review primarily from:

* `Files changed`

---

## Review Guidelines

### Use Inline Comments

Comment directly:

* On problematic lines
* On suspicious logic
* On architecture concerns
* On potential edge cases

---

## Suggested Review Actions

### Comment

For optional suggestions.

### Start Review

For grouped review feedback.

### Request Changes

When merge should be blocked until fixes are completed.

---

# 7. Resolving Review Feedback

When PR owner addresses feedback:

## Required Actions

* Reply to comments OR
* Click `Resolve conversation`

Then:

* Request review again

---

## Merge Rule

A PR must NOT be merged until:

* Review conversations are resolved
* Required approvals are obtained

---

# 8. Merge Strategy

## ONLY Squash Merge Into Main

When merging into `main`:

✅ Allowed:

* Squash merge

❌ Not allowed:

* Merge commit
* Rebase merge directly on GitHub

---

## Why Squash Merge?

Benefits:

* Clean Git history
* Easier revert
* Easier review
* Reduced commit noise
* Better readability

---

# 9. Keeping Branch Updated

When `main` changes and PR becomes outdated:

---

## Small Change Scenario

For very small changes:

* GitHub update branch is acceptable

---

## Preferred Approach (Recommended)

Always prefer:

```bash
git fetch origin
git checkout <your-branch>
git rebase origin/main
```

Then:

```bash
git push --force-with-lease
```

---

## Why Rebase?

Rebase keeps history:

* Linear
* Clean
* Readable
* Easier to debug
* Easier to revert

Avoid tangled commit graphs.

---

# 10. Review Philosophy

Code review is:

* NOT personal criticism
* NOT ownership conflict
* A collaboration process

The goal is:

* Improve code quality
* Protect project stability
* Share knowledge
* Prevent production issues

---

# 11. Summary Checklist

## Before Commit

* [ ] Scope is limited to the ticket
* [ ] No unrelated changes
* [ ] Files changed are reasonable
* [ ] Commit message follows convention

---

## Before PR

* [ ] Branch pushed to remote
* [ ] Draft PR created
* [ ] Build passes
* [ ] Lint passes
* [ ] Tests pass

---

## Before Merge

* [ ] PR marked Ready
* [ ] Reviewer assigned
* [ ] All comments resolved
* [ ] At least 1 approval
* [ ] Squash merge selected

---

# 12. Golden Rules

1. Keep scope small
2. Keep history clean
3. Keep reviews easy
4. Communicate early
5. Never silently fix unrelated issues
6. Prefer clarity over cleverness
7. Protect project stability first
