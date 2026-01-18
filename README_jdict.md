# jdict - A Universal Dictionary Interface for MATLAB/Octave & Python

- Webpage: https://neurojson.org/jdict 
- Version: 1.0.0
- Author: Qianqian Fang <q.fang at neu.edu>
- Register: To receive future critical bug fixes and new releases, please register using https://neurojson.org/wiki/index.cgi?keywords=registration&tool=jdict&ref=mathworks
- Acknowledgement: Part of the JSONLab toolbox (https://neurojson.org/jsonlab), Developed with funding support from the NIH (U24-NS124027).

`jdict` is a powerful, [xarray](https://xarray.pydata.org/)-inspired data structure that combines the flexibility of Python dictionaries with MATLAB's numerical computing power. It provides a unified interface for working with hierarchical data structures including `struct`, `containers.Map`, and `dictionary` objects.

---

## Introduction

`jdict` brings modern data structure capabilities to MATLAB and Octave in a single, lightweight class. Despite its small footprint, it delivers features comparable to popular Python libraries like xarray and Pydantic, while maintaining exceptional backward compatibility with MATLAB R2010b+ and GNU Octave 5.2+ — supporting systems over 15 years old. **A Python version is also available** via the `jdata` package.

At its core, `jdict` provides a unified dictionary-like interface that works seamlessly across `struct`, `containers.Map`, and `dictionary` objects. Unlike native MATLAB structs that impose strict field naming rules, `jdict` accepts arbitrary key names including spaces, dashes, unicode characters, and JSON Schema special keys like `$ref`. Navigation through deeply nested structures becomes intuitive with fluent key chaining (`jd.('a').('b').('c')()`) and full JSONPath support, including the powerful deep-search operator (`$..key`) that finds all matching keys at any depth.

For scientific computing, `jdict` introduces xarray-inspired dimension labeling and **coordinate-based indexing**, allowing users to select array slices by meaningful names like `jd.time(1:100).channels('Fp1')` instead of cryptic numeric indices. Rich metadata attachment enables storing units, descriptions, sampling rates, and custom attributes at any level of the data hierarchy.

Data integrity is ensured through comprehensive JSON Schema validation inspired by Python's Pydantic library. Users can define schemas with type constraints, ranges, enums, patterns, and more, then validate existing data or use the guarded assignment operator (`<=`) to prevent invalid values from ever entering the structure. **Built-in "kind" schemas** provide ready-to-use validated data types for common formats like `date`, `time`, `datetime`, `uuid`, `email`, and `uri`. Schema constraints can also be defined inline as attributes and exported to standard JSON Schema format.

The entire package requires no external dependencies beyond JSONLab, making it ideal for legacy systems, HPC clusters, cross-platform projects, and open-source software requiring maximum accessibility.

---

## Table of Contents

- [Features](#features)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Core Concepts](#core-concepts)
  - [Creating jdict Objects](#creating-jdict-objects)
  - [Navigating Data](#navigating-data)
  - [JSONPath Queries](#jsonpath-queries)
  - [Attributes](#attributes)
  - [Dimension Labels](#dimension-labels)
  - [Coordinate-Based Indexing](#coordinate-based-indexing)
  - [Struct Arrays](#struct-arrays)
- [JSON Schema Validation](#json-schema-validation)
  - [Setting a Schema](#setting-a-schema)
  - [Validating Data](#validating-data)
  - [Schema Attributes](#schema-attributes)
  - [Validated Assignment with `<=`](#validated-assignment-with-)
  - [Auto-Casting with binType](#auto-casting-with-bintype)
  - [Built-in Data Kinds](#built-in-data-kinds)
- [API Reference](#api-reference)
  - [Constructors](#constructors)
  - [Navigation Methods](#navigation-methods)
  - [Attribute Methods](#attribute-methods)
  - [Schema Methods](#schema-methods)
  - [Utility Methods](#utility-methods)
- [Python Support](#python-support)
- [Examples](#examples)
- [License](#license)

---

## Features

| Feature | Description |
|---------|-------------|
| 🚀 **Extreme Portability** | Supports MATLAB R2010b+ and Octave 5.2+ — write once, run everywhere! |
| 🐍 **Python Support** | Also available in Python via `pip install jdata` |
| 🔗 **Fluent Key Chaining** | Navigate deep structures with clean `jd.a.b.c()` syntax |
| 🔑 **Arbitrary Key Names** | Use any characters: spaces, dashes, unicode — no restrictions |
| 🎯 **Full JSONPath** | Industry-standard queries with deep search (`..`), array indexing, and more |
| 📊 **Dimension Labels** | xarray-inspired named dimensions: `jd.time(1:100).channels(5)` |
| 🗺️ **Coordinate Indexing** | Select by coordinate labels: `jd.channels('Fp1')` instead of numeric indices |
| ✅ **Schema Validation** | Pydantic-style JSON Schema validation with comprehensive constraints |
| 🛡️ **Guarded Assignment** | `<=` operator validates BEFORE assignment — invalid data never enters |
| 🔄 **Auto-Casting** | `binType` schema attribute automatically converts data types |
| 📦 **Built-in Kinds** | Ready-to-use schemas for `date`, `time`, `datetime`, `uuid`, `email`, `uri` |
| 🔎 **Rich Metadata** | Attach attributes (units, descriptions, etc.) to any node |
| 📦 **Incredibly Lightweight** | ~1500 lines total — no bloat, no unnecessary dependencies |
| 🔄 **Unified Interface** | One syntax for `struct`, `containers.Map`, and `dictionary` |

---

## Installation

### MATLAB/Octave

#### Option 1: Full installation (support all features): clone from GitHub

```bash
git clone https://github.com/NeuroJSON/jsonlab.git
```

#### Add to MATLAB Path

```matlab
addpath('/path/to/jsonlab');
```

#### Option 2: Minimal installation (core features): download jdict.m alone

Download the jdict.m unit and add it to your project, or use this command in matlab
```matlab
websave('jdict.m', 'https://neurojson.org/jdict/src/')
```

### Python

```bash
pip install jdata
```

```python
from jdata import jdict
```

---

## Quick Start

### MATLAB/Octave

```matlab
% Create a jdict from a struct
data = struct('name', 'Alice', 'age', 30, 'scores', [95, 87, 92]);
jd = jdict(data);

% Access nested data with clean syntax
jd.name()           % → 'Alice'
jd.scores.v(1)()    % → 95

% Use JSONPath for deep queries
jd.('$.name')()     % → 'Alice'

% Export to JSON
jd.tojson()         % → '{"name":"Alice","age":30,"scores":[95,87,92]}'
```

### Python

```python
from jdata import jdict

# Create a jdict from a dict
data = {'name': 'Alice', 'age': 30, 'scores': [95, 87, 92]}
jd = jdict(data)

# Access nested data with clean syntax
jd.name()           # → 'Alice'
jd.scores.v(0)      # → 95

# Use JSONPath for deep queries
jd['$.name']()      # → 'Alice'

# Export to JSON
jd.tojson()         # → '{"name":"Alice","age":30,"scores":[95,87,92]}'
```

---

## Core Concepts

### Creating jdict Objects

#### MATLAB/Octave

```matlab
% Empty jdict
jd = jdict;

% From struct
jd = jdict(struct('key1', 'value1', 'key2', 42));

% From containers.Map
m = containers.Map({'name', 'value'}, {'test', 42});
jd = jdict(m);

% From URL (loads JSON data)
jd = jdict('https://api.example.com/data.json');

% With initialization options
jd = jdict(data, 'attr', attrMap, 'schema', schemaMap);

% With built-in kind schema
jd = jdict([], 'kind', 'date');
```

#### Python

```python
from jdata import jdict

# Empty jdict
jd = jdict()

# From dict
jd = jdict({'key1': 'value1', 'key2': 42})

# From URL (loads JSON data)
jd = jdict('https://api.example.com/data.json')

# With built-in kind schema
jd = jdict(kind='date')
```

### Navigating Data

`jdict` provides multiple ways to navigate hierarchical data:

#### MATLAB/Octave

```matlab
% Create nested data
jd = jdict;
jd.key1 = struct('subkey1', 1, 'subkey2', [1, 2, 3]);
jd.key2 = 'str';
jd.key1.subkey3 = {8, 'test', containers.Map('special key', 10)};

% Dot notation
jd.key1.subkey1()                      % → 1

% Parentheses notation (for special keys)
jd.('key1').('subkey1')()              % → 1

% Mixed notation
jd.key1.('subkey1')()                  % → 1

% Array indexing with .v()
jd.key1.subkey3.v(1)()                 % → 8
jd.key1.subkey3.v(3).('special key')() % → 10

% Retrieve raw data
jd.key1.subkey3()                      % → {8, 'test', containers.Map(...)}
```

#### Python

```python
# Create nested data
jd = jdict()
jd.key1 = {'subkey1': 1, 'subkey2': [1, 2, 3]}
jd.key2 = 'str'

# Dot notation
jd.key1.subkey1()                      # → 1

# Bracket notation (for special keys)
jd['key1']['subkey1']()                # → 1

# Array indexing
jd.key1.subkey2.v(0)                   # → 1

# Retrieve raw data
jd.key1()                              # → {'subkey1': 1, 'subkey2': [1, 2, 3]}
```

### JSONPath Queries

JSONPath provides powerful querying capabilities for deeply nested structures:

#### MATLAB/Octave

```matlab
% Direct path access
jd.('$.key1.subkey1')()                % → 1

% Array indexing (0-based in JSONPath)
jd.('$.key1.subkey3[0]')()             % → 8

% Deep search with '..' operator
jd.('$..subkey2')()                    % → {'str', [1 2 3]} (finds ALL matches)

% Combine with further navigation
jd.('$..subkey2').v(2)()               % → [1, 2, 3]
```

#### Python

```python
# Direct path access
jd['$.key1.subkey1']()                 # → 1

# Array indexing (0-based in JSONPath)
jd['$.key1.subkey3[0]']()              # → 8

# Deep search with '..' operator
jd['$..subkey2']()                     # → finds ALL matches
```

### Attributes

Attach metadata to any level of your data hierarchy:

#### MATLAB/Octave

```matlab
% Create data with attributes
jd = jdict(rand(100, 64));

% Set attributes using curly braces (MATLAB only)
jd{'dims'} = {'time', 'channels'};
jd{'units'} = 'microvolts';
jd{'sampling_rate'} = 1000;

% Set attributes using setattr() (works in both MATLAB and Octave)
jd.setattr('dims', {'time', 'channels'});
jd.setattr('units', 'microvolts');

% Get attributes
jd{'units'}                            % → 'microvolts'
jd.getattr('units')                    % → 'microvolts'
jd.getattr()                           % → list all attribute names

% Attributes on nested keys
jd.('$.key1').setattr('description', 'Primary data');
jd.('$.key1'){'description'}           % → 'Primary data'
```

#### Python

```python
import numpy as np
from jdata import jdict

# Create data with attributes
jd = jdict(np.random.rand(100, 64))

# Set attributes using bracket syntax
jd['{dims}'] = ['time', 'channels']
jd['{units}'] = 'microvolts'
jd['{sampling_rate}'] = 1000

# Get attributes
jd['{units}']                          # → 'microvolts'
jd.getattr('units')                    # → 'microvolts'
```

### Dimension Labels

xarray-inspired dimension-based indexing for multidimensional arrays:

#### MATLAB/Octave

```matlab
% Create 3D data: 1000 timepoints × 64 channels × 50 trials
jd = jdict(rand(1000, 64, 50));
jd{'dims'} = {'time', 'channels', 'trials'};

% Select by dimension NAME instead of position
first_100_timepoints = jd.time(1:100);      % First 100 timepoints
channel_5 = jd.channels(5);                  % Channel 5 only
first_10_trials = jd.trials(1:10);           % First 10 trials

% Chain dimension selections
subset = jd.time(1:500).trials(1:10);        % Combined selection

% Much clearer than: data(1:100, :, :) vs data(:, 5, :)
```

#### Python

```python
import numpy as np
from jdata import jdict

# Create 3D data: 1000 timepoints × 64 channels × 50 trials
jd = jdict(np.random.rand(1000, 64, 50))
jd['{dims}'] = ['time', 'channels', 'trials']

# Select by dimension NAME instead of position
first_100_timepoints = jd.time(slice(0, 100))  # First 100 timepoints
channel_5 = jd.channels(5)                      # Channel 5 only
```

### Coordinate-Based Indexing

**New in 1.0:** Define coordinate labels to select data by meaningful names instead of numeric indices:

#### MATLAB/Octave

```matlab
% Create EEG data with dimension labels
jd = jdict(rand(1000, 64, 50));
jd{'dims'} = {'time', 'channels', 'trials'};

% Define coordinate labels for channels
jd{'coords'} = struct('channels', {{'Fp1','Fp2','F3','F4','C3','C4','P3','P4'}});

% Select by coordinate label instead of index!
fp1_data = jd.channels('Fp1');              % Get channel by name
frontal = jd.channels({'Fp1','Fp2','F3','F4'});  % Multiple labels

% Numeric coordinates work too (e.g., time in seconds)
jd{'coords'} = struct('time', 0:0.001:0.999);  % 1000 samples @ 1kHz
early = jd.time(0.1);                       % Select t=0.1s by value
```

#### Python

```python
import numpy as np
from jdata import jdict

# Create EEG data with dimension labels
jd = jdict(np.random.rand(1000, 64, 50))
jd['{dims}'] = ['time', 'channels', 'trials']

# Define coordinate labels for channels
jd['{coords}'] = {'channels': ['Fp1','Fp2','F3','F4','C3','C4','P3','P4']}

# Select by coordinate label instead of index!
fp1_data = jd.channels('Fp1')               # Get channel by name
frontal = jd.channels(['Fp1','Fp2'])        # Multiple labels
```

### Struct Arrays

Build and manage struct arrays with ease:

#### MATLAB/Octave

```matlab
% Create empty struct array with predefined fields
person = jdict(struct('name', {}, 'age', {}, 'gender', {}));

% Direct struct assignment
person.v(1) = struct('name', 'Alice', 'age', 30, 'gender', 'F');
person.v(2) = struct('name', 'Bob', 'age', 25, 'gender', 'M');

% Field-by-field assignment
person.v(3).name = 'Charlie';
person.v(3).age = 35;
person.v(3).gender = 'M';

% Export to JSON
person.tojson()  % → '[{"name":"Alice","age":30,...},...]'
```

#### Python

```python
from jdata import jdict

# Create a list of dicts
person = jdict([
    {'name': 'Alice', 'age': 30, 'gender': 'F'},
    {'name': 'Bob', 'age': 25, 'gender': 'M'},
    {'name': 'Charlie', 'age': 35, 'gender': 'M'}
])

# Export to JSON
person.tojson()  # → '[{"name":"Alice",...},...]'
```

---

## JSON Schema Validation

`jdict` supports comprehensive JSON Schema validation to ensure data integrity.

### Setting a Schema

#### MATLAB/Octave

```matlab
% Create data
jd = jdict(struct('name', 'John', 'age', 30));

% Define schema
schema = struct('type', 'object', ...
    'properties', struct( ...
        'name', struct('type', 'string', 'minLength', 1), ...
        'age', struct('type', 'integer', 'minimum', 0, 'maximum', 150)), ...
    'required', {{'name', 'age'}});

% Set schema (accepts struct, JSON string, URL, or file path)
jd.setschema(schema);

% Get schema back
jd.getschema()         % → containers.Map with schema
jd.getschema('json')   % → JSON string
```

#### Python

```python
from jdata import jdict

# Create data
jd = jdict({'name': 'John', 'age': 30})

# Define schema
schema = {
    'type': 'object',
    'properties': {
        'name': {'type': 'string', 'minLength': 1},
        'age': {'type': 'integer', 'minimum': 0, 'maximum': 150}
    },
    'required': ['name', 'age']
}

# Set schema
jd.setschema(schema)

# Get schema back
jd.getschema()         # → dict with schema
jd.getschema('json')   # → JSON string
```

### Validating Data

```matlab
% Validate entire object
errors = jd.validate();
if isempty(errors)
    disp('Data is valid!');
else
    disp('Validation errors:');
    disp(errors);
end

% Validate specific subkeys
jd.name.validate()     % Validates only the 'name' field
jd.age.validate()      % Validates only the 'age' field
```

### Schema Attributes

Define schema constraints inline using `:keyword` attributes, then export to a full JSON Schema:

#### MATLAB/Octave

```matlab
% Create data
jd = jdict(struct('name', 'test', 'count', 5));

% Define schema inline using :keyword attributes
jd.('name').setattr(':type', 'string');
jd.('name').setattr(':minLength', 1);
jd.('count').setattr(':type', 'integer');
jd.('count').setattr(':minimum', 0);
jd.('count').setattr(':maximum', 100);

% Export to JSON Schema
schema = jd.attr2schema('title', 'My Data Schema');

% Use the generated schema
jd.setschema(schema);
errors = jd.validate();
```

#### Python

```python
from jdata import jdict

# Create data
jd = jdict({'name': 'test', 'count': 5})

# Define schema inline using :keyword attributes
jd.name['{:type}'] = 'string'
jd.name['{:minLength}'] = 1
jd['count']['{:type}'] = 'integer'
jd['count']['{:minimum}'] = 0
jd['count']['{:maximum}'] = 100

# Export to JSON Schema
schema = jd.attr2schema(title='My Data Schema')

# Use the generated schema
jd.setschema(schema)
errors = jd.validate()
```

**Supported Schema Keywords:**

| Category | Keywords |
|----------|----------|
| Type | `type`, `enum`, `const`, `default` |
| Numeric | `minimum`, `maximum`, `exclusiveMinimum`, `exclusiveMaximum`, `multipleOf` |
| String | `minLength`, `maxLength`, `pattern`, `format` |
| Array | `items`, `minItems`, `maxItems`, `uniqueItems`, `contains`, `prefixItems` |
| Object | `properties`, `required`, `additionalProperties`, `minProperties`, `maxProperties`, `patternProperties`, `propertyNames`, `dependentRequired`, `dependentSchemas` |
| Logic | `allOf`, `anyOf`, `oneOf`, `not`, `if`, `then`, `else` |
| Meta | `title`, `description`, `examples`, `$comment`, `$ref`, `$defs`, `definitions` |
| Binary Arrays | `binType`, `minDims`, `maxDims` (jdict extension for typed array validation) |

### Validated Assignment with `<=`

Use the `<=` operator for schema-validated assignments that throw errors before corrupting your data:

#### MATLAB/Octave

```matlab
% Setup data with schema
jd = jdict(struct('name', '', 'age', 0, 'status', ''));
jd.setschema(struct('type', 'object', 'properties', struct( ...
    'name', struct('type', 'string'), ...
    'age', struct('type', 'integer', 'minimum', 0, 'maximum', 150), ...
    'status', struct('enum', {{'active', 'inactive'}}))));

% Valid assignments pass silently
jd.name <= 'Jane';           % ✓ OK
jd.age <= 25;                % ✓ OK
jd.status <= 'inactive';     % ✓ OK

% Invalid assignments throw errors!
jd.age <= -5;                % ✗ Error: minimum violation
jd.age <= 200;               % ✗ Error: maximum violation
jd.status <= 'unknown';      % ✗ Error: not in enum
jd.name <= 123;              % ✗ Error: type mismatch
```

#### Python

```python
from jdata import jdict

# Setup data with schema
jd = jdict({'name': '', 'age': 0, 'status': ''})
jd.setschema({
    'type': 'object',
    'properties': {
        'name': {'type': 'string'},
        'age': {'type': 'integer', 'minimum': 0, 'maximum': 150},
        'status': {'enum': ['active', 'inactive']}
    }
})

# Valid assignments pass silently
jd.name <= 'Jane'            # ✓ OK
jd.age <= 25                 # ✓ OK
jd.status <= 'inactive'      # ✓ OK

# Invalid assignments throw errors!
jd.age <= -5                 # ✗ ValueError: minimum violation
```

### Auto-Casting with binType

**New in 1.0:** The `<=` operator automatically converts data types when `binType` is specified in the schema:

#### MATLAB/Octave

```matlab
% Setup data with schema including binType
jd = jdict();
jd{':type'} = 'array';
jd{':binType'} = 'uint8';      % Expect uint8 array
jd{':minDims'} = 2;            % Min length 2
jd{':maxDims'} = 6;            % Max length 6
jd.setschema(jd.attr2schema());

% Auto-casting: double → uint8 automatically!
jd <= [1, 2, 3];              % ✓ Auto-cast to uint8([1,2,3])
class(jd())                   % → 'uint8'

% Validation still enforced
jd <= uint8([1]);             % ✗ Error: length < minDims (2)
jd <= [1,2;3,4];              % ✗ Error: 2D array fails dims check
```

#### Python

```python
from jdata import jdict

# Setup data with schema including binType
jd = jdict()
jd['{:type}'] = 'array'
jd['{:binType}'] = 'uint8'        # Expect uint8 array
jd['{:minDims}'] = 2              # Min length 2
jd['{:maxDims}'] = 6              # Max length 6
jd.setschema(jd.attr2schema())

# Auto-casting: list → np.uint8 array automatically!
jd <= [1, 2, 3]               # ✓ Auto-cast to np.uint8
jd().dtype                    # → dtype('uint8')

# Validation still enforced
jd <= [1]                     # ✗ ValueError: length < minDims
```

### Built-in Data Kinds

**New in 1.0:** Use the `kind` parameter to create objects with built-in schemas. Assignments are automatically validated without needing to call `validate()`:

#### Available Kinds

| Kind | Fields | Description |
|------|--------|-------------|
| `uuid` | `time_low`, `time_mid`, `time_high`, `clock_seq`, `node` | UUID components |
| `date` | `year`, `month`, `day` | Calendar date |
| `time` | `hour`, `min`, `sec` | Time of day |
| `datetime` | `year`, `month`, `day`, `hour`, `min`, `sec` | Full timestamp |
| `email` | `user`, `domain` | Email address components |
| `uri` | `scheme`, `host`, `port`, `path`, `query`, `fragment` | URI components |

#### MATLAB/Octave

```matlab
% Create a date object with built-in schema
jd = jdict([], 'kind', 'date');

% Fields are pre-defined with validation rules
jd.keys()                    % → {'day', 'month', 'year'}

% Assignments are AUTO-VALIDATED against the schema!
jd.year = 2026;              % ✓ OK (1-9999)
jd.month = 1;                % ✓ OK (1-12)
jd.day = 20;                 % ✓ OK (1-31)

% Print formatted output
jd()                         % → '2026-01-20'

% Invalid values throw errors immediately!
jd.month = 13;               % ✗ Error: value > maximum (12)
jd.day = -5;                 % ✗ Error: value < minimum (1)

% UUID example
uuid = jdict([], 'kind', 'uuid');
uuid()                       % → '00000000-0000-0000-0000-000000000000'
uuid.time_low = 305419896;   % Set UUID parts
```

#### Python

```python
from jdata import jdict

# Create a date object with built-in schema
jd = jdict(kind='date')

# Fields are pre-defined with validation rules
jd.keys()                    # → ['day', 'month', 'year']

# Assignments are AUTO-VALIDATED against the schema!
jd.year = 2026               # ✓ OK (1-9999)
jd.month = 1                 # ✓ OK (1-12)
jd.day = 20                  # ✓ OK (1-31)

# Print formatted output
jd()                         # → '2026-01-20'

# Invalid values throw errors immediately!
jd.month = 13                # ✗ ValueError: value > maximum (12)
```

#### User-Defined Data Kinds

`jdict` supported data kinds are not only limited to those few listed above. 
When both `schema` and `kind` are specified, `jdict` automatically
perform validation agaist the schema when any of the data fields is assigned
using the `=` operator. This allows user to define arbitrary schema-guarded
data types and ensure the content is always compliant with the schema.

#### MATLAB/Octave

```matlab
% Create a date object with built-in schema
jd = jdict([], 'kind', 'intpair', 'schema', struct('type', 'array', 'binType', 'int32', 'minDims', [0, 2], 'maxDims', [inf, 2]));
jd.v(:,:) = [2, 5; -1 7]           % ✓ OK (Nx2 array allowed)
jd.v(:,:) = [2.1, 5.0; -1.2 7.1]   % ✓ OK (float-number cast to int32)
jd.v(:,:) = [1,2,3]                % ✗ ValueError: maxDims > maximum (2)
---

## API Reference

### Constructors

| Syntax | Description |
|--------|-------------|
| `jd = jdict` | Create empty jdict |
| `jd = jdict(data)` | Wrap any MATLAB data |
| `jd = jdict(data, 'param', value, ...)` | Initialize with options |
| `jd = jdict('https://...')` | Load from URL |
| `jd = jdict([], 'kind', 'date')` | Create with built-in kind schema |

### Navigation Methods

| Method | Description |
|--------|-------------|
| `jd.('key')` | Navigate to subkey |
| `jd.key` | Navigate using dot notation |
| `jd.('$.path')` | Navigate using JSONPath |
| `jd.v(idx)` | Access array/cell element by index |
| `jd()` | Retrieve underlying data |
| `jd.keys()` | List subkey names |
| `jd.len()` | Number of subkeys/elements |
| `jd.size()` | Dimension vector |
| `jd.isKey(key)` | Test if key exists |
| `jd.rmfield(key)` | Remove a key/field |

### Attribute Methods

| Method | Description |
|--------|-------------|
| `jd{'attr'}` | Get attribute (MATLAB) |
| `jd{'attr'} = val` | Set attribute (MATLAB) |
| `jd['{attr}']` | Get attribute (Python) |
| `jd['{attr}'] = val` | Set attribute (Python) |
| `jd.getattr()` | List all attributes |
| `jd.getattr('name')` | Get specific attribute |
| `jd.setattr('name', val)` | Set attribute |
| `jd.setattr(path, 'name', val)` | Set attribute at path |

### Schema Methods

| Method | Description |
|--------|-------------|
| `jd.setschema(schema)` | Set JSON Schema (struct, JSON, URL, or file) |
| `jd.getschema()` | Get schema as containers.Map |
| `jd.getschema('json')` | Get schema as JSON string |
| `jd.validate()` | Validate data against schema |
| `jd.attr2schema()` | Export `:keyword` attributes to JSON Schema |
| `jd.key <= value` | Validated assignment with auto-casting |

### Utility Methods

| Method | Description |
|--------|-------------|
| `jd.tojson()` | Export to JSON string |
| `jd.tojson('compact', 0)` | Export with formatting |
| `jd.fromjson(file)` | Load from JSON file |

---

## Python Support

`jdict` is also available in Python as part of the `jdata` package:

```bash
pip install jdata
```

```python
from jdata import jdict
```

The Python version provides the same core functionality with Pythonic syntax:

| MATLAB | Python |
|--------|--------|
| `jd{'attr'}` | `jd['{attr}']` |
| `jd.('key')` | `jd['key']` or `jd.key` |
| `jd.('$.path')` | `jd['$.path']` |
| `jd.v(1)` | `jd.v(0)` (0-based indexing) |
| `struct('a', 1)` | `{'a': 1}` |

---

## Examples

### Loading REST API Data

```matlab
% Load complex data from REST API
jd = jdict('https://neurojson.io:7777/cotilab/NeuroCaptain_2025');

% Navigate and query
jd.('Atlas_Age_19_0')
jd.Atlas_Age_19_0.('Landmark_10_10').('$.._DataLink_')
```

### Scientific Data with Metadata

```matlab
% EEG data example
eeg = jdict(rand(1000, 64, 50));  % time × channels × trials
eeg{'dims'} = {'time', 'channels', 'trials'};
eeg{'units'} = 'microvolts';
eeg{'sampling_rate'} = 1000;
eeg{'subject'} = 'P001';
eeg{'date'} = '2025-01-01';

% Define channel coordinates
eeg{'coords'} = struct('channels', {{'Fp1','Fp2','F3','F4','C3','C4','P3','P4'}});

% Select data by dimension and coordinate
baseline = eeg.time(1:100);
frontal = eeg.channels({'Fp1', 'Fp2'}).trials(1:5);

% Export with metadata preserved
eeg.tojson()
```

### Data Validation Pipeline

```matlab
% Define schema for experimental data
schema = struct('type', 'object', ...
    'properties', struct( ...
        'subject_id', struct('type', 'string', 'pattern', '^P[0-9]{3}$'), ...
        'age', struct('type', 'integer', 'minimum', 18, 'maximum', 100), ...
        'condition', struct('enum', {{'control', 'treatment'}}), ...
        'score', struct('type', 'number', 'minimum', 0, 'maximum', 100)), ...
    'required', {{'subject_id', 'age', 'condition'}});

% Create validated data entry
entry = jdict(struct('subject_id', '', 'age', 0, 'condition', '', 'score', 0));
entry.setschema(schema);

% Safe data entry with validation
entry.subject_id <= 'P001';    % ✓ Matches pattern
entry.age <= 25;               % ✓ Within range
entry.condition <= 'control';  % ✓ Valid enum value
entry.score <= 85.5;           % ✓ Within range

% Invalid entries throw errors
% entry.subject_id <= 'ABC';   % ✗ Pattern mismatch
% entry.age <= 15;             % ✗ Below minimum
```

### Using Built-in Kinds

```matlab
% Create a datetime object
dt = jdict([], 'kind', 'datetime');
dt.year = 2025;
dt.month = 6;
dt.day = 15;
dt.hour = 14;
dt.min = 30;
dt.sec = 0;
dt()                           % → '2025-06-15T14:30:00'

% Create a URI object
uri = jdict([], 'kind', 'uri');
uri.scheme = 'https';
uri.host = 'example.com';
uri.port = 8080;
uri.path = '/api/data';
uri.query = 'format=json';
uri()                          % → 'https://example.com:8080/api/data?format=json'
```

---

## License

BSD or GPL version 3 — see `LICENSE_BSD.txt` and `LICENSE_GPLv3.txt` for details.

---

## Author

**Qianqian Fang** (q.fang <at> neu.edu)

Part of the [NeuroJSON Project](http://neurojson.org/)

---

## Links

- 📦 [JSONLab GitHub Repository](https://github.com/NeuroJSON/jsonlab)
- 📖 [NeuroJSON Project](http://neurojson.org/)
- 🐛 [Report Issues](https://github.com/NeuroJSON/jsonlab/issues)