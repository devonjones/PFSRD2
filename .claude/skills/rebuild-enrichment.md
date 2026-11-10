# Rebuild Enrichment

Use this skill when the user wants to rebuild the enrichment database, re-run parsers with enrichment, or do a full data reload. Triggers on: "rebuild enrichment", "reload data", "blow away enrichment", "re-enrich", "full rebuild", "repopulate enrichment".

## Architecture

Two separate databases in `~/.pfsrd2/`:
- **`enrichment.db`** — Working state. Ability records, creature links, change records, categories, UMA flags. Can be blown away and rebuilt.
- **`llm_cache.db`** — Persistent LLM response cache. Keyed on `(prompt_hash, model)`. Survives rebuilds. NEVER delete this unless you want to re-run all LLM queries.

### Inline Enrichment

Parsers now run regex enrichment **inline** during their enrichment pass. When a new ability record is inserted or an existing record has no enrichment, the parser calls `extract_all()` from the regex extractor and stores the result immediately. This means:

- **Normal parser runs** produce fully enriched output in a single pass — no separate enrichment step needed.
- **From-scratch rebuilds** use `--no-enrich` on the first parser run (to avoid enriching before classification), then run `pf2_enrich_abilities --all` for classification and LLM tiers, then re-run parsers (which self-enrich via inline).
- **The parser→enrich→parser cycle is eliminated** for normal development. Parser changes that affect ability text no longer require a separate enrichment run — the parser self-enriches the new records.

## Full Rebuild From Scratch

**Parallel execution is safe once the DB schema exists.** The enrichment DB uses WAL mode with a 30-second busy timeout, so concurrent writers wait instead of failing. But parallel parsers racing to create a *fresh* `enrichment.db` fail with `table change_records already exists` (PFSRD2-Parser-0da5), so create the schema serially first.

Run every command from `PFSRD2-Parser/`: pyenv picks the interpreter from its `.python-version`, and the wrong CWD gets the wrong Python.

Write logs to disk, not `/tmp`: `/tmp` is RAM-backed.

```bash
cd /home/devon/MasterworkTools/pfsrd2/PFSRD2-Parser

# 0. Delete enrichment DB (llm_cache.db is preserved)
rm -f ~/.pfsrd2/enrichment.db

# 0b. Create the schema serially, before any parallel parse
bin/pf2_enrich_abilities --stats
bin/pf2_enrich_changes --stats
```

When clearing files by glob, use `find <dir> -name '<glob>' -delete`, not `rm <glob>`: zsh aborts the whole command when a glob matches nothing.

### Phase 1: Populate enrichment DB (no inline enrichment)

First parser run inserts raw ability records and creature links. Use `--no-enrich` to skip inline regex enrichment — classification needs creature links first.

```bash
# Run in parallel — WAL mode handles concurrent writes
bin/pf2_run_creatures.sh --no-enrich &
bin/pf2_run_npcs.sh --no-enrich &
bin/pf2_run_monster_families.sh --no-enrich &
bin/pf2_run_monster_templates.sh --no-enrich &
wait
```

After this:
- `ability_records` ~16K (creatures + families + templates)
- `ability_creature_links` ~26K (creatures only)
- `change_records` ~900 (families + templates)

### Phase 2: Classify and enrich abilities

```bash
# Run everything: UMA + classify + LLM classify + regex + all LLM types
bin/pf2_enrich_abilities --all
```

This runs: UMA detection → deterministic + creature data classification → LLM classification → regex extraction → LLM frequency/dc/area/damage. All LLM calls are cached after first run, so subsequent runs are fast.

Individual steps can still be run separately if needed:
```bash
bin/pf2_enrich_abilities --uma            # UMA detection only
bin/pf2_enrich_abilities --classify       # Deterministic + creature data
bin/pf2_enrich_abilities --llm-classify   # LLM classification only
bin/pf2_enrich_abilities                  # Regex + stale re-enrichment only
bin/pf2_enrich_abilities --llm damage     # Single LLM type
```

### Phase 3: Enrich changes

```bash
bin/pf2_enrich_changes
# LLM change enrichment if needed (check --stats for unenriched)

# Then seed the git-stored overrides (overrides/*.json, e.g. Bola Hurl, Ekriathe's Breath).
# They upsert onto existing records and exit nonzero if a record is missing,
# so this must run after pf2_enrich_changes.
bin/pf2_seed_change_overrides
```

### Phase 4: Final parser run — merge all enrichment into JSON

Inline enrichment handles regex enrichment automatically. This run merges classification, UMA, and LLM enrichment from the DB plus self-enriches any remaining gaps.

```bash
bin/pf2_run_creatures.sh &
bin/pf2_run_npcs.sh &
bin/pf2_run_monster_families.sh &
bin/pf2_run_monster_templates.sh &
wait
```

Now the JSON output has:
- `ability_category` on template/family abilities (where to place in creature stat block)
- `universal_monster_ability` objects on UMAs (from monster abilities DB)
- Enriched fields (saving_throw, damage, area, range, frequency) on all abilities
- Enriched change effects (change_category, effects arrays) on template/family changes

### Phase 5: Verify

```bash
# Check for parser errors — zero errors required
ls bin/errors.pf2.creatures.log      # Should not exist
ls bin/errors.pf2.npc.log
ls bin/errors.pf2.monster_family.log
ls bin/errors.pf2.monster_template.log

# Check enrichment stats
bin/pf2_enrich_abilities --stats
bin/pf2_enrich_abilities --classify-stats
bin/pf2_enrich_changes --stats
```

## Normal Development Workflow

After parser code changes, just run the affected parsers. Inline enrichment handles everything:

```bash
# Parser change affecting creatures
bin/pf2_run_creatures.sh
# Done — enrichment is applied inline. No separate enrichment step needed.
```

If you change the enrichment regex patterns or add new extractors:

```bash
# Bump ENRICHMENT_VERSION in pfsrd2/enrichment/regex_extractor.py
# Then re-run parsers — inline enrichment will re-enrich with new patterns
bin/pf2_run_creatures.sh &
bin/pf2_run_npcs.sh &
bin/pf2_run_monster_families.sh &
bin/pf2_run_monster_templates.sh &
wait
```

## Classification Rules

Applied in order — first match wins:
1. **Deterministic** (action type): Reaction → `reactive`, 1/2/3 actions → `offensive`, Free Action + trigger → `reactive`
2. **Creature links**: Direct copy from `ability_creature_links.ability_category` (authoritative)
3. **Name lookup**: Case-insensitive match against creature data (majority vote)
4. **UMA**: Name match against `monster_abilities` table in pfsrd2.db
5. **LLM**: Ollama classify with stat block structure prompt (cached in llm_cache.db)

Valid categories: `offensive`, `automatic`, `reactive`, `interaction`, `special_sense`, `hp_automatic`, `communication`

## Partial Rebuilds

When only one content type changed (e.g., fixed family parser):

```bash
# 1. Delete just that type's enrichment records
python3 -c "
from pfsrd2.sql.enrichment import get_enrichment_db_connection
conn = get_enrichment_db_connection()
curs = conn.cursor()
# For families/templates (no creature links):
curs.execute('DELETE FROM ability_records WHERE ability_id NOT IN (SELECT DISTINCT ability_id FROM ability_creature_links)')
conn.commit()
print(f'Deleted {curs.rowcount} records')
conn.close()
"

# 2. Re-run just that parser (inline enrichment handles regex)
bin/pf2_run_monster_families.sh

# 3. Re-classify (fast — LLM calls are cached)
bin/pf2_enrich_abilities --uma
bin/pf2_enrich_abilities --classify
bin/pf2_enrich_abilities --llm-classify
bin/pf2_enrich_changes

# 4. Re-run parser to merge classification + LLM enrichment
bin/pf2_run_monster_families.sh
```

## Monitoring

```bash
bin/pf2_enrich_abilities --stats           # ability enrichment counts
bin/pf2_enrich_abilities --classify-stats  # category breakdown
bin/pf2_enrich_changes --stats             # change enrichment counts
python3 -c "from pfsrd2.enrichment.llm_cache import cache_stats; print(cache_stats())"
```

## Important Notes

- **Inline enrichment** — parsers self-enrich new/unenriched records via regex. No separate enrichment step for regex-extractable fields. Use `--no-enrich` for from-scratch phase 1.
- **Parallel safe after schema exists** — enrichment.db and llm_cache.db use WAL mode with 30s busy timeout; a fresh DB must get its schema serially first (step 0b).
- **Seed overrides last** — `pf2_seed_change_overrides` runs after `pf2_enrich_changes`.
- **Creature links are authoritative** — each creature ability's category comes from its stat block position.
- **Action type is deterministic** — Reactions are always reactive, action-cost abilities are always offensive.
- **UMA detection is mechanistic** — name match against monster_abilities table.
- **LLM cache persists** — changing prompt templates automatically invalidates stale entries.
- **Order matters for from-scratch** — abilities must be enriched before changes, because changes contain abilities.
- **Keep this skill updated** — as new enrichment types are added, update the phase steps and notes.
