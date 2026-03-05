# PFSRD2 Project Documentation

## Project Overview

This project scrapes and parses Pathfinder 2E data from aonprd.com (Archives of Nethys) to create structured JSON data files. The project consists of three main components, each in its own git repository.

## Directory Structure

```
pfsrd2/
├── PFSRD2-Parser/      # Python parsing code (git repo)
├── pfsrd2-data/        # Output JSON files (git repo)
├── pfsrd2-web/         # Scraped HTML files (git repo)
│   └── 2e.aonprd.com/  # The actual HTML content
└── pfsrd2-web.download.*.tar.gz  # Archived web snapshots
```

### PFSRD2-Parser

Contains the Python code that parses HTML and generates JSON.

**Key directories:**
- `bin/` - Shell scripts to run parsers (e.g., `pf2_run_creatures.sh`, `pf2_run_traits.sh`)
- `pfsrd2/` - Python parser modules for PF2E content
  - `creatures.py` - Parses monsters and creatures
  - `trait.py` - Parses traits
  - `condition.py` - Parses conditions
  - `skill.py` - Parses skills
  - `monster_ability.py` - Parses monster abilities
  - `source.py` - Parses source books
  - `schema/` - JSON schema definitions
  - `sql/` - Database utilities and loaders

**Dependencies:** See `requirements.txt` - mainly uses BeautifulSoup4, lxml, markdownify

### pfsrd2-data

Contains the generated JSON output files organized by content type.

**Structure:**
- `monsters/` - Individual monster JSON files
- `npcs/` - NPC JSON files
- `conditions/` - Condition definitions
- `traits/` - Trait definitions
- `sources/` - Source book information
- `monster_abilities/` - Monster ability definitions
- `*.schema.*.json` - JSON schema files for validation

### pfsrd2-web

Contains the scraped HTML from aonprd.com.

**Key location:**
- `2e.aonprd.com/` - The raw HTML files organized by content type
  - `Monsters/Monsters.aspx.ID_*.html` - Monster pages
  - `Traits/`, `Conditions/`, `Skills/`, etc. - Other content types

## HTML Tag Rules

**NEVER change `<b>` to `<strong>` in source HTML without asking the user first.** The `<b>` tag is excluded from the markdown validset for strategic fragility — if `<b>` appears in parsed text, it means the parser failed to extract structured content. The correct fix is usually to improve the parser. Only in rare cases where the bold text genuinely belongs in description (not as a title/label) should it be changed to `<strong>`, and only with the user's explicit approval.

## Never Paper Over Errors

**When a validation or assertion fails, fix the root cause — never skip, suppress, or add exceptions to make it pass.** Strategic fragility exists to surface real problems. If a check fails, it means something upstream needs fixing (parser logic, HTML structure, data routing). Bypassing the check (e.g., `if x: continue`, catching and ignoring exceptions, adding blanket allowances) hides the problem and causes silent data quality regressions. The only acceptable "exception" is when the check itself is wrong for a specific well-understood context (e.g., license text legitimately uses `<b>` tags) — and even then, the fix should be scoped as narrowly as possible (allow `<b>` only in license paths, not globally skip license validation).

## Core Philosophy: HTML Bugs vs Code Bugs

**Critical distinction:**

1. **HTML bugs** - Hand-maintained content has errors
   - Fix these in the HTML files in `pfsrd2-web/2e.aonprd.com/`
   - Examples: typos, malformed tags, inconsistent formatting in specific files

2. **Code bugs** - Parser handles patterns incorrectly
   - Fix these in the Python parsers in `PFSRD2-Parser/pfsrd2/`
   - Examples: consistent HTML patterns that parse wrong, missing edge cases

**When HTML has consistent bugs across many files, solve it in code. When it's a one-off error, fix the HTML.**

## Development Workflow

### Making Changes

When fixing a bug:

1. **Identify the root cause** - Is it an HTML issue or a code issue?
2. **Make the fix** - Edit HTML source or Python parser accordingly
3. **Run the pipeline** - Execute the appropriate parser script
4. **Verify changes** - Check the JSON output to ensure:
   - The bug is fixed
   - No unintended side effects
   - Only expected files changed

### Running Parsers

Parser scripts are in `PFSRD2-Parser/bin/`. Common ones:

```bash
cd PFSRD2-Parser/bin
./pf2_run_creatures.sh      # Parse all creatures/monsters
./pf2_run_npcs.sh           # Parse all NPCs
./pf2_run_traits.sh         # Parse all traits
./pf2_run_conditions.sh     # Parse all conditions
./pf2_run_skills.sh         # Parse all skills
./pf2_run_monster_abilities.sh  # Parse monster abilities
./pf2_run_sources.sh        # Parse source books
```

Scripts use config from `dir.conf` to locate web and data directories.

### Verifying Changes

After running a parser:

```bash
cd pfsrd2-data
git status .                 # See what changed
git diff <file>             # Review specific changes
```

**Important:** Only the files related to your fix should change. If you see unexpected changes, investigate before committing.

## Error Handling & Fast Iteration

Parser scripts have a two-file error system for fast iteration:

- `errors.pf2.<type>.log` - **Output**: failures from the last run (written by the script)
- `errors.pf2.<type>` - **Input**: if this file exists, the script ONLY processes files listed in it (skips the full `ls` scan)

### Iteration workflow

1. **Seed an errors file** with a representative subset of files (or the user may provide one pre-made)
2. **Run the parser** - it processes only those files, logging new failures to `.log`
3. **Fix the code** based on errors
4. **Promote failures for re-run**: `mv errors.pf2.<type>.log errors.pf2.<type>`
5. **Repeat** until `.log` is empty (all files in the subset pass)
6. **Delete the errors file** (`rm errors.pf2.<type>`) and run the full parser to catch any remaining issues across all files

```bash
# Example: iterating on traits
cd PFSRD2-Parser/bin
source dir.conf
bash pf2_run_traits.sh          # runs only errors.pf2.trait entries
# fix code...
mv errors.pf2.trait.log errors.pf2.trait   # promote failures
bash pf2_run_traits.sh          # re-run just the failures
# when clean:
rm errors.pf2.trait             # remove seed file
bash pf2_run_traits.sh          # full run against all files
```

This is critical for parsers with many files (traits, creatures, equipment) where a full run takes minutes. Always use this pattern during development.

## Web Download Issues

See `pfsrd2-web/readme.md` for detailed troubleshooting. Common issues:

### Missing Files

After downloading, check for deleted/renamed files:

```bash
git status .
# If there are missing files:
git restore --staged .
mkdir tmp && cd tmp
../../../get_missing.py
# Rename files to fix URL encoding
rename -f 's/\&NoRedirect\=1//' *
rename -e "s/\?/./g" *
rename -e "s/\&/./g" *
rename -e "s/\=/_/g" *
mv * ..
cd .. && git add . && git status .
```

### Binary File Problems

```bash
./find_binary.py 2e.aonprd.com > 2e.aonprd.com/fix.sh
cd 2e.aonprd.com
chmod +x fix.sh
./fix.sh
rename -f "s/\.1//" *
```

For brotli-encoded files:

```bash
./find_binary.py -b 2e.aonprd.com | sort > 2e.aonprd.com/fix.sh
cd 2e.aonprd.com
chmod +x fix.sh
./fix.sh
brotli --decompress --rm *.br
```

## Git Workflow

Each of the three main directories is its own git repository:

- `PFSRD2-Parser/` - Track parser code changes
- `pfsrd2-data/` - Track JSON output changes
- `pfsrd2-web/` - Track HTML source changes

When making a fix:
1. Commit HTML changes to `pfsrd2-web` if fixing HTML
2. Commit code changes to `PFSRD2-Parser` if fixing parsers
3. Commit resulting JSON changes to `pfsrd2-data`

This allows tracking what changed in the source (HTML or code) and what changed in the output (JSON).

## Content Types

The project handles various Pathfinder 2E content types:

- **Creatures/Monsters** - Stat blocks for enemies
- **NPCs** - Pre-generated character stat blocks
- **Traits** - Special keywords and properties
- **Conditions** - Status effects (e.g., frightened, prone)
- **Skills** - Character skills and their uses
- **Monster Abilities** - Special creature abilities
- **Sources** - Book/publication information
- **Actions** - Character actions
- **Backgrounds** - Character background options
- **Classes** - Character classes
- **Archetypes** - Class archetypes
- **Items** - Equipment, weapons, armor

Each has its own parser module and JSON schema.

## Testing Changes

1. **Make the change** (HTML or code)
2. **Run affected parsers** - Only run parsers for the content type you changed
3. **Check git status** in pfsrd2-data - Verify only expected files changed
4. **Review diffs** - Ensure changes match expectations
5. **Commit if correct** - Only commit when verified

## Tips for Working with This Codebase

- **Read before editing** - Always examine existing HTML and code before making changes
- **Test locally first** - Run parsers and check output before committing
- **One fix at a time** - Don't batch unrelated changes
- **Follow existing patterns** - Match the style of existing parser code
- **Document edge cases** - If you handle a special case, comment why
- **Keep schemas updated** - If JSON structure changes, update the schema files

## Interaction Principles: Be a Thought Partner

**Critical feedback is expected.** Challenge assumptions and push back on decisions:

### Key Questions to Ask
- **Is this inherent or accidental complexity?** - Call out complexity that isn't required by the problem
- **What's the actual bottleneck?** - Demand measurement before optimization
- **Can we evolve existing code instead of rewrite?** - Working code has value; rewrites are expensive
- **Is this tool justified at current scale?** - Challenge use of Kafka/K8s/distributed systems for small problems
- **What's the 80% solution using what we already have?** - Prefer known tools over new dependencies
- **What are the failure modes at 10x? 100x scale?** - Think about orders of magnitude
- **Can we do this with simpler text interfaces first?** - Binary protocols are optimizations, not defaults

### Response Approach
**DO:**
- Question whether added complexity is necessary
- Suggest simpler alternatives with trade-offs clearly stated
- Call out over-engineering for current scale
- Push for evolutionary changes over rewrites
- Challenge new dependencies (learning curve, ops burden, lock-in costs)

**DON'T:**
- Just agree with proposed approaches
- Assume latest/shiniest tech is best
- Propose rewrites when evolution is viable
- Ignore that complex tools have real costs
- Let cargo-culting go unchallenged

**If something is over-engineered, say so directly. If there's a simpler path, push for it.**

## Task Management

Use `bd` (beads) instead of TaskCreate/TodoWrite for ALL task tracking. TaskCreate/TodoWrite disappear on compaction; beads persists in git.

**Core commands:**
- `bd ready` - See unblocked work
- `bd create --title="task" --priority=2` - Create task (priority 0-4, 0=critical)
- `bd update <id> --status=in_progress --claim` - Claim work (use `--claim` for explicit failure if already taken)
- `bd update <id> --note "Progress update"` - Add progress note
- `bd update <id> --desc "New description"` - Update description
- `bd close <id> --reason="description"` - Complete task with context
- `bd list --status=open` - All open issues
- `bd dep add <issue> <depends-on>` - Add dependency (constraint-based, not sequential)
- `bd sync` - Sync with git (REQUIRED at session end)

**Do NOT use:**
- TaskCreate, TaskUpdate, TaskList, TodoWrite - Use beads exclusively
- `bd edit` - Opens interactive editor, unusable by AI. Use `bd update` flags instead

For simple conversational work that doesn't need tracking, just work directly - not everything needs a ticket.

### Surviving Compaction

Beads is one of the few ways to maintain continuity after context compaction. Follow these patterns:

**1. Session Start - Load Context**
- Run `bd ready` to see available work
- Run `bd show <id>` to read notes/context before starting
- The session hook runs `bd prime` automatically, but explicitly checking helps

**2. Write Rich Notes (Past Tense)**
When closing or updating beads, document *what was decided* and *why*, not just "done":
- BAD: "Fixed auth"
- GOOD: "Implemented JWT tokens with 1hr expiry. Chose rotating refresh tokens over long-lived tokens for security. Login endpoint at /api/auth/login."

This lets future sessions (post-compaction) reconstruct context.

**3. Update at Milestones**
Don't wait until completion - update beads at significant milestones:
```bash
bd update <id> --note "Completed schema changes. Next: update parser to match."
```
Creates breadcrumbs for recovery if compaction happens mid-task.

**4. Constraint-Based Thinking**
Express work as dependency relationships, not sequences:
```bash
bd create --title="Write tests for feature X"
bd create --title="Implement feature X"
bd dep add <tests-id> <feature-id>  # Tests depend on feature
```
Let `bd ready` discover what's unblocked rather than planning sequences.

**5. Discovered Work Pattern**
When finding new issues during active work, link them for traceability:
```bash
bd create --title="Bug: found during feature X" -t bug --deps discovered-from:<parent-id>
```

**6. Session End - "Landing the Plane"**
Work is NOT complete until synced. Before ending a session:
```bash
bd close <completed-ids> --reason="What was done and why"
bd sync                    # Commit and push beads changes
git add <files>            # Stage code changes
git commit -m "..."        # Commit code
```

**7. Troubleshooting**
Debug variables when things go wrong:
```bash
BD_DEBUG=1 bd <command>        # General logging
BD_DEBUG_SYNC=1 bd sync        # Sync issues
BD_DEBUG_RPC=1 bd <command>    # Daemon communication
```
Run `bd doctor` to diagnose common problems.
