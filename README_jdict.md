# jdict - A Universal Dictionary Interface for MATLAB/Octave

- Webpage: https://neurojson.org/jdict 
- Version: 0.8.0
- Author: Qianqian Fang <q.fang at neu.edu>
- Register: To receive future critical bug fixes and new releases, please register using https://neurojson.org/wiki/index.cgi?keywords=registration&tool=jdict&ref=mathworks
- Acknowledgement: Part of the JSONLab toolbox (https://neurojson.org/jsonlab), Developed with funding support from the NIH (U24-NS124027).

`jdict` is a powerful, [xarray](https://xarray.pydata.org/)-inspired data structure that combines the flexibility of Python dictionaries with MATLAB's numerical computing power. It provides a unified interface for working with hierarchical data structures including `struct`, `containers.Map`, and `dictionary` objects.

---

## Introduction

`jdict` brings modern data structure capabilities to MATLAB and Octave in a single, lightweight class. Despite its small footprint, it delivers features comparable to popular Python libraries like xarray and Pydantic, while maintaining exceptional backward compatibility with MATLAB R2010b+ and GNU Octave 5.2+ — supporting systems over 15 years old.

At its core, `jdict` provides a unified dictionary-like interface that works seamlessly across `struct`, `containers.Map`, and `dictionary` objects. Unlike native MATLAB structs that impose strict field naming rules, `jdict` accepts arbitrary key names including spaces, dashes, unicode characters, and JSON Schema special keys like `$ref`. Navigation through deeply nested structures becomes intuitive with fluent key chaining (`jd.('a').('b').('c')()`) and full JSONPath support, including the powerful deep-search operator (`$..key`) that finds all matching keys at any depth.

For scientific computing, `jdict` introduces xarray-inspired dimension labeling, allowing users to select array slices by meaningful names like `jd.time(1:100).channels(5)` instead of cryptic numeric indices. Rich metadata attachment enables storing units, descriptions, sampling rates, and custom attributes at any level of the data hierarchy.

Data integrity is ensured through comprehensive JSON Schema validation inspired by Python's Pydantic library. Users can define schemas with type constraints, ranges, enums, patterns, and more, then validate existing data or use the guarded assignment operator (`<=`) to prevent invalid values from ever entering the structure. Schema constraints can also be defined inline as attributes and exported to standard JSON Schema format.

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
  - [Struct Arrays](#struct-arrays)
- [JSON Schema Validation](#json-schema-validation)
  - [Setting a Schema](#setting-a-schema)
  - [Validating Data](#validating-data)
  - [Schema Attributes](#schema-attributes)
  - [Validated Assignment with `<=`](#validated-assignment-with-)
- [API Reference](#api-reference)
  - [Constructors](#constructors)
  - [Navigation Methods](#navigation-methods)
  - [Attribute Methods](#attribute-methods)
  - [Schema Methods](#schema-methods)
  - [Utility Methods](#utility-methods)
- [Examples](#examples)
- [License](#license)

---

## Features

| Feature | Description |
|---------|-------------|
| 🚀 **Extreme Portability** | Supports MATLAB R2010b+ and Octave 5.2+ — works on 15+ year old systems |
| 🔗 **Fluent Key Chaining** | Navigate deep structures with clean `jd.('a').('b').('c')()` syntax |
| 🔑 **Arbitrary Key Names** | Use any characters: spaces, dashes, unicode — no restrictions |
| 🎯 **Full JSONPath** | Industry-standard queries with deep search (`..`), array indexing, and more |
| 📊 **Dimension Labels** | xarray-inspired named dimensions: `jd.time(1:100).channels(5)` |
| ✅ **Schema Validation** | Pydantic-style JSON Schema validation with comprehensive constraints |
| 🛡️ **Guarded Assignment** | `<=` operator validates BEFORE assignment — invalid data never enters |
| 📎 **Rich Metadata** | Attach attributes (units, descriptions, etc.) to any node |
| 📦 **Incredibly Lightweight** | ~1200 lines total — no bloat, no unnecessary dependencies |
| 🔄 **Unified Interface** | One syntax for `struct`, `containers.Map`, and `dictionary` |

---

## Installation

### Option 1: Full installation (support all features): clone from GitHub

```bash
git clone https://github.com/NeuroJSON/jsonlab.git
```

### Add to MATLAB Path

```matlab
addpath('/path/to/jsonlab');
```

### Option 2: Minimal installation (core features): download jdict.m alone

Download the jdict.m unit and add it to your project, or use this command in matlab
```matlab
websave('jdict.m', 'https://neurojson.org/jdict/src/')
```

---

## Quick Start

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

---

## Core Concepts

### Creating jdict Objects

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
```

### Navigating Data

`jdict` provides multiple ways to navigate hierarchical data:

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

### JSONPath Queries

JSONPath provides powerful querying capabilities for deeply nested structures:

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

### Attributes

Attach metadata to any level of your data hierarchy:

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

### Dimension Labels

xarray-inspired dimension-based indexing for multidimensional arrays:

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

### Struct Arrays

Build and manage struct arrays with ease:

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

---

## JSON Schema Validation

`jdict` supports comprehensive JSON Schema validation to ensure data integrity.

### Setting a Schema

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

### Validated Assignment with `<=`

Use the `<=` operator for schema-validated assignments that throw errors before corrupting your data:

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

---

## API Reference

### Constructors

| Syntax | Description |
|--------|-------------|
| `jd = jdict` | Create empty jdict |
| `jd = jdict(data)` | Wrap any MATLAB data |
| `jd = jdict(data, 'param', value, ...)` | Initialize with options |
| `jd = jdict('https://...')` | Load from URL |

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

### Attribute Methods

| Method | Description |
|--------|-------------|
| `jd{'attr'}` | Get attribute (MATLAB) |
| `jd{'attr'} = val` | Set attribute (MATLAB) |
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
| `jd.key <= value` | Validated assignment |

### Utility Methods

| Method | Description |
|--------|-------------|
| `jd.tojson()` | Export to JSON string |
| `jd.tojson('compact', 0)` | Export with formatting |
| `jd.fromjson(file)` | Load from JSON file |

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

% Select data by dimension
baseline = eeg.time(1:100);
channel_data = eeg.channels(1:10).trials(1:5);

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
