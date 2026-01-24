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

## Error Handling

Parser scripts log errors to `errors.pf2.<type>.log` files. If a parse fails:

1. Check the error log
2. Examine the problematic HTML file
3. Fix the issue (HTML or code)
4. Re-run the parser
5. Errors file can be used to re-parse only failed items

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
