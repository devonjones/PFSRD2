# JSON Analysis Tools

Use this skill when analyzing JSON data structure, finding test cases, or investigating field value inconsistencies in the PFSRD2 data files.

## Available Tools

Both tools are located in `PFSRD2-Parser/bin/` (relative to the pfsrd2 root).

### json_map - Test Case Finder

Finds the first file containing any given JSON field. Use this to locate a test case file for a specific field.

```bash
# From pfsrd2-data directory:
../PFSRD2-Parser/bin/json_map <directory>

# Example: Map all equipment fields
../PFSRD2-Parser/bin/json_map equipment/ > equipment_map.json
```

**Output**: JSON where each key shows:
- `file`: First file containing this field (use as test case)
- `type`: Value type (dict, list, str, etc.)
- `children`: Nested keys

### json_cardinality - Field Value Analyzer

Analyzes field values to determine cardinality and find inconsistencies.

**Cardinality categories:**
- **VERY_LOW** (<=5 unique): Effectively an enum
- **LOW**: Controlled vocabulary
- **MEDIUM**: Worth investigating for inconsistencies/bugs
- **HIGH/VERY_HIGH**: Free text or ID fields

#### Mode 1: JSONPath

Analyze values at a specific JSON path:

```bash
../PFSRD2-Parser/bin/json_cardinality --path '$.type' equipment/
../PFSRD2-Parser/bin/json_cardinality --path '$.sources[*].name' monsters/
```

#### Mode 2: Object Type

Find all objects of a type anywhere in the JSON tree and analyze a field:

```bash
# By type field (e.g., "link", "source")
../PFSRD2-Parser/bin/json_cardinality --type link --field game-obj equipment/

# By subtype field (for stat_block_section objects)
../PFSRD2-Parser/bin/json_cardinality --subtype attack_damage --field damage_type monsters/
../PFSRD2-Parser/bin/json_cardinality --subtype bulk --field text equipment/
```

#### Finding Files with Specific Values

After seeing the distribution, use `--value` to find files containing a specific value:

```bash
# Find files with em-dash instead of hyphen
../PFSRD2-Parser/bin/json_cardinality --subtype bulk --field text --value '—' equipment/

# Find files where field doesn't exist
../PFSRD2-Parser/bin/json_cardinality --subtype bulk --field text --value '<DNE>' equipment/

# Find files with null value
../PFSRD2-Parser/bin/json_cardinality --subtype bulk --field text --value '<null>' equipment/
```

#### Options

- `--top N` - Show top N values (default 50)
- `--all` - Show all values

## Common Workflows

### Finding inconsistent data

1. Run cardinality analysis on a field
2. Look for similar values that should be the same (e.g., `-` vs `—`, `varies by weapon` vs `- varies by weapon`)
3. Use `--value` to get file lists for each variant
4. Fix the inconsistent files

```bash
# Step 1: See distribution
../PFSRD2-Parser/bin/json_cardinality --subtype bulk --field text equipment/

# Step 2: Find files with wrong variant
../PFSRD2-Parser/bin/json_cardinality --subtype bulk --field text --value '—' equipment/
```

### Finding a test case for a field

```bash
# Generate map
../PFSRD2-Parser/bin/json_map equipment/ > /tmp/eq_map.json

# Look up field in output to find first file with that field
```

### Validating enum-like fields

Fields with VERY_LOW or LOW cardinality should match schema enums. Compare the cardinality output against schema definitions to find invalid values.
