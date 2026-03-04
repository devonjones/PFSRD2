---
name: stage-data
description: Selectively stage pfsrd2-data git changes by classifying diffs into known patterns, auto-staging safe changes, and flagging errors. Use this skill whenever working in the pfsrd2-data repo and dealing with git staging, unstaged changes, diff review, committing parser output, or preparing data for commit. Also use when the user mentions "stage data", "classify diffs", "stage safe", "what's unstaged", "commit data changes", "review diffs", "staging workflow", or any variation of reviewing/staging/committing JSON changes in pfsrd2-data — even if they don't explicitly ask for this skill.
---

# Stage Data

The pfsrd2 parser regenerates thousands of JSON files per run. Some changes are correct improvements (new content, structural fixes, remaster updates), others are parser bugs (data loss, wrong values). This skill provides tools to automatically classify changes by pattern and stage only the safe ones, so you don't have to review each file individually.

The classifier reads a pattern catalog (`references/patterns.json`) that encodes everything we've learned about which diff shapes are safe vs. problematic. When a new pattern emerges, add it to the catalog and every future run benefits.

## Why the rules exist

The pfsrd2-data repo has a special constraint: `git add <directory>` stages both modified and untracked files together, which destroys the ability to review modified files separately. Once mixed, there's no clean way to unstage just the modifications. The parser runs continuously, so files get regenerated — the durable asset is the pattern catalog, not any particular staging state.

## Staging workflow

Always work from `/home/devon/MasterworkTools/pfsrd2/pfsrd2-data`.

1. **Untracked files** — new parser output, always safe to add:
   ```bash
   git ls-files --others --exclude-standard | xargs -d '\n' git add
   ```

2. **License/key-reorder noise** — structural-only changes (key ordering + license block):
   ```bash
   python3 ../PFSRD2-Parser/bin/git_stage_license_only.py .
   ```

3. **Classify what's left**:
   ```bash
   scripts/git_diff_classifier --summary
   ```

4. **Preview and stage safe files**:
   ```bash
   scripts/git_stage_safe --dry-run    # review first
   scripts/git_stage_safe              # stage them
   ```

5. **Review unknowns** — files the classifier couldn't fully categorize:
   ```bash
   scripts/git_diff_classifier --unknown-only
   ```
   Then inspect each with `git diff -- <file>` and decide.

6. **Hunk-stage mixed files** — when a file has both safe and unsafe changes:
   ```bash
   scripts/git_stage_intermediate --apply-fn <fn> <file> --dry-run
   scripts/git_stage_intermediate --apply-fn <fn> <file>
   ```

## Tools

All scripts are in the `scripts/` directory of this skill.

### git_diff_classifier

Classifies each unstaged modified JSON file against the pattern catalog. Output is JSON lines (one per file) with `file`, `categories`, `safe`, and `names` fields.

```bash
scripts/git_diff_classifier [--summary] [--safe-only] [--unsafe-only] [--unknown-only] [path]
```

`--summary` prints a human-readable table grouped by category with safety indicators (`+` safe, `-` unsafe, `?` unknown).

### git_stage_safe

Runs the classifier internally and stages every file where all matched patterns are safe. Files with any unsafe or unknown pattern are skipped and reported.

```bash
scripts/git_stage_safe [--dry-run] [path]
```

### git_stage_intermediate

For files with mixed safe/unsafe changes. Builds an intermediate JSON version that applies only the requested transform, stages it via `git hash-object -w` + `git update-index --cacheinfo`, and leaves the working tree file untouched.

```bash
scripts/git_stage_intermediate --apply-fn FUNCTION file.json [--dry-run]
```

Available transforms:
- `license_reorder` — reorder keys + apply new license block
- `empty_text_removal` — remove `"text": ""` fields
- `trigger_effect_merge` — apply trigger/effect structural merges

### Existing tools (in PFSRD2-Parser/bin/)

- **`git_diff_filter`** — filter files by exact diff line counts and string patterns (+N -M string:count). Good for precise batch matching. See `pfsrd2-data/claude.md` for full docs.
- **`git_stage_license_only.py`** — the original intermediate-version stager for license/reorder changes.

## Adding new patterns

The pattern catalog lives at `references/patterns.json`. Each entry has an `id`, `name`, `safe` flag, `description`, and `detection` rules. When you discover a new change type during manual review, add it to the catalog so the classifier picks it up automatically.

Detection methods:
- `string_match` — checks added/removed/context lines for substrings (handles most patterns)
- `file_list` — matches specific filenames (for known one-off errors)
- `regex` — regex match on added lines
- `json_field` — checks if a JSON field appears in changes, with optional `top_level` flag for indent-aware matching
- `manual` — never auto-matches; requires human review

Safety: `true` (auto-stage), `false` (skip and warn), `null` (flag for review)

## Known error tracking

When a pattern is unsafe, the catalog entry references a doc in `pfsrd2-data/known_errors/` explaining the root cause (parser bug or HTML issue) and affected files. The classifier auto-skips these files, and the error docs give the parser-fixing Claude enough context to address the underlying problem.
