# File Templates

Template content for each workspace file the wilma-setup wizard can create.
Replace `{TODAY}` with current date in `YYYY-MM-DD` format before writing.
Do not include the outer markdown fences when writing file content — they are display-only here.

---

## worklog.md

```text
| Date | Time | Tool | File/Command | Action | Project | Description |
| ---- | ---- | ---- | ------------ | ------ | ------- | ----------- |
```

---

## file-index.md

```text
# File Index

> Auto-maintained by wilma. Updated on every Write/Edit.
> When looking for a file: check this index first.

## Index
```

---

## backlog.md

```text
---
title: "Backlog"
created: {TODAY}
updated: {TODAY}
---

# Backlog

## Active

## Orphaned & Stale Work
```

---

## outcomes.md

```text
---
title: "Outcomes"
created: {TODAY}
updated: {TODAY}
---

# Outcomes

## Outcomes Register

| ID | Title | Status |
| -- | ----- | ------ |
```

---

## work-registry.md

```text
---
title: "Work Registry"
created: {TODAY}
updated: {TODAY}
---

# Work Registry

## Registry

## Orphaned Pool

| File | Last Updated | Notes |
| ---- | ------------ | ----- |
```
