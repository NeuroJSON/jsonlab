function [valid, errors] = jsonschema(data, schema, varargin)
%
% [valid, errors] = jsonschema(data, schema)
% [valid, errors] = jsonschema(data, schemafile)
% [valid, errors] = jsonschema(data, schema, 'option', value, ...)
% output = jsonschema(schema)
%
% Validate MATLAB data structures against JSON Schema (draft-07 compatible),
% or generate a minimal valid object from a schema
%
% Author: Qianqian Fang (q.fang at neu.edu) (with AI assistant)
%
% Input:
%     data:   MATLAB data (struct, cell, array, string, number, logical)
%     schema: JSON Schema as containers.Map, struct, JSON string, URL, or file path
%
% Options:
%     'rootschema': containers.Map/struct - root schema for resolving $ref (default: schema)
%     'stoponfirst': logical - stop on first error (default: false)
%     'generate': string - 'all', 'required', 'requireddefaults' (default)
%
% Output:
%     valid:  logical true if data conforms to schema
%     errors: cell array of validation error messages with paths
%
% License: BSD or GPL version 3, see LICENSE_{BSD,GPLv3}.txt
%
% -- this function is part of JSONLab toolbox (http://neurojson.org/jsonlab)
%

opt = varargin2struct(varargin{:});

% Expose resolveref for external use
if isfield(opt, 'resolveref')
    valid = resolveref(opt.resolveref, data);
    errors = {};
    return
end

% Expose getsubschema for external use: jsonschema(schema, [], 'getsubschema', '$.path')
if isfield(opt, 'getsubschema')
    valid = getsubschema(data, opt.getsubschema);
    errors = {};
    return
end

% Generation mode: jsonschema(schema) or jsonschema(schema, [])
if nargin == 1 || (nargin >= 2 && isempty(schema))
    schemaarg = data;
    if ischar(schemaarg) || isa(schemaarg, 'string')
        schemaarg = loadjson(char(schemaarg), 'usemap', 1);
    end
    opt.rootschema = schemaarg;
    valid = generatedata(schemaarg, opt);
    errors = {};
    return
end

if ischar(schema) || isa(schema, 'string')
    schema = loadjson(char(schema), 'usemap', 1);
end

opt.rootschema = jsonopt('rootschema', schema, opt);

[valid, errors] = validatedata(data, schema, '$', opt);

%% -------------------------------------------------------------------------
function [valid, errors] = validatedata(data, schema, path, varargin)

opt = varargin{1};
rootschema = opt.rootschema;
valid = true;
errors = {};

if islogical(schema) && isscalar(schema)
    valid = schema;
    if ~valid
        errors{end + 1} = [path ': schema is false'];
    end
    return
end
if ~(isa(schema, 'containers.Map') || isstruct(schema)) || isempty(schemakeys(schema))
    return
end

% $ref
if hasschemakey(schema, '$ref')
    ref = getschemavalue(schema, '$ref');
    if ref(1) == '#'
        refschema = resolveref(ref, rootschema);
        if ~isempty(refschema)
            [valid, errors] = validatedata(data, refschema, path, opt);
        else
            valid = false;
            errors{end + 1} = sprintf('%s: cannot resolve $ref "%s"', path, ref);
        end
    end
    return
end

% type
if hasschemakey(schema, 'type')
    schematype = getschemavalue(schema, 'type');
    if iscell(schematype)
        match = false;
        for i = 1:length(schematype)
            match = match || checktype(data, schematype{i});
        end
        if ~match
            valid = false;
            errors{end + 1} = sprintf('%s: type mismatch', path);
        end
    elseif ~checktype(data, schematype)
        valid = false;
        errors{end + 1} = sprintf('%s: expected %s, got %s', path, schematype, gettype(data));
    end
end

% enum
if hasschemakey(schema, 'enum')
    enumvalues = getschemavalue(schema, 'enum');
    match = false;
    data_is_empty_str = (ischar(data) && isempty(data)) || (isa(data, 'string') && strlength(data) == 0);
    for i = 1:length(enumvalues)
        enumval = enumvalues{i};
        enum_is_empty_str = isempty(enumval) || (isa(enumval, 'string') && strlength(enumval) == 0);
        if data_is_empty_str && enum_is_empty_str
            match = true;
            break
        elseif (ischar(data) || isa(data, 'string')) && (ischar(enumval) || isa(enumval, 'string'))
            if strcmp(char(data), char(enumval))
                match = true;
                break
            end
        elseif isequal(data, enumval)
            match = true;
            break
        end
    end
    if ~match
        valid = false;
        errors{end + 1} = [path ': not in enum'];
    end
end

% const
if hasschemakey(schema, 'const') && ~isequal(data, getschemavalue(schema, 'const'))
    valid = false;
    errors{end + 1} = [path ': const mismatch'];
end

% numeric
if isnumeric(data) && isscalar(data)
    [isvalid, errmsg] = validatenumeric(data, schema, path);
    if ~isvalid
        valid = false;
        errors = [errors errmsg];
    end
end

% binary type and dimensions
if isnumeric(data) || islogical(data)
    [isvalid, errmsg] = validatebinary(data, schema, path);
    if ~isvalid
        valid = false;
        errors = [errors errmsg];
    end
end

% string
if ischar(data) || isa(data, 'string')
    [isvalid, errmsg] = validatestring(char(data), schema, path);
    if ~isvalid
        valid = false;
        errors = [errors errmsg];
    end
end

% array
if isarray_json(data)
    [isvalid, errmsg] = validatearray(data, schema, path, opt);
    if ~isvalid
        valid = false;
        errors = [errors errmsg];
    end
end

% object
if isstruct(data) || isa(data, 'containers.Map')
    [isvalid, errmsg] = validateobject(data, schema, path, opt);
    if ~isvalid
        valid = false;
        errors = [errors errmsg];
    end
end

% composition
[isvalid, errmsg] = validatecomposition(data, schema, path, opt);
if ~isvalid
    valid = false;
    errors = [errors errmsg];
end

% if/then/else
if hasschemakey(schema, 'if')
    ifok = validatedata(data, getschemavalue(schema, 'if'), path, opt);
    subkey = '';
    if ifok && hasschemakey(schema, 'then')
        subkey = 'then';
    elseif ~ifok && hasschemakey(schema, 'else')
        subkey = 'else';
    end
    if ~isempty(subkey)
        [isvalid, errmsg] = validatedata(data, getschemavalue(schema, subkey), path, opt);
        if ~isvalid
            valid = false;
            errors = [errors errmsg];
        end
    end
end

%% -------------------------------------------------------------------------
function keys = schemakeys(schema)
% Get all keys from schema (struct or containers.Map)
if isstruct(schema)
    keys = fieldnames(schema);
else
    keys = schema.keys();
end

%% -------------------------------------------------------------------------
function tf = hasschemakey(schema, key)
% Check if schema has key (handles struct with encoded names)
if isstruct(schema)
    tf = isfield(schema, encodevarname(key));
else
    tf = isKey(schema, key);
end

%% -------------------------------------------------------------------------
function val = getschemavalue(schema, key)
% Get value from schema (handles struct with encoded names)
if isstruct(schema)
    val = schema.(encodevarname(key));
else
    val = schema(key);
end

%% -------------------------------------------------------------------------
function isarr = isarray_json(data)

if iscell(data)
    isarr = true;
elseif isnumeric(data) && ~isscalar(data)
    isarr = true;
elseif islogical(data) && ~isscalar(data)
    isarr = true;
else
    isarr = false;
end

%% -------------------------------------------------------------------------
function refschema = resolveref(ref, root)

refschema = [];
ptr = ref(2:end);
if isempty(ptr)
    refschema = root;
    return
end
if ptr(1) == '/'
    ptr = ptr(2:end);
end

parts = regexp(ptr, '/', 'split');
current = root;

for i = 1:length(parts)
    part = strrep(strrep(parts{i}, '~1', '/'), '~0', '~');
    if isa(current, 'containers.Map') && isKey(current, part)
        current = current(part);
    elseif isstruct(current) && isfield(current, encodevarname(part))
        current = current.(encodevarname(part));
    elseif iscell(current)
        idx = str2double(part);
        if ~isnan(idx) && idx < length(current)
            current = current{idx + 1};
        else
            return
        end
    else
        return
    end
end
refschema = current;

%% -------------------------------------------------------------------------
function ok = checktype(data, schematype)

switch schematype
    case 'null'
        ok = isnumeric(data) && isempty(data);
    case 'boolean'
        ok = islogical(data) && isscalar(data);
    case 'integer'
        ok = isnumeric(data) && isscalar(data) && mod(data, 1) == 0;
    case 'number'
        ok = isnumeric(data) && isscalar(data);
    case 'string'
        ok = ischar(data) || isa(data, 'string');
    case 'array'
        ok = iscell(data) || (isnumeric(data) && ~isscalar(data)) || (islogical(data) && ~isscalar(data));
    case 'object'
        ok = isstruct(data) || isa(data, 'containers.Map');
    otherwise
        ok = true;
end

%% -------------------------------------------------------------------------
function typestr = gettype(data)

if ischar(data) || isa(data, 'string')
    typestr = 'string';
elseif isnumeric(data) && isempty(data)
    typestr = 'null';
elseif islogical(data)
    if isscalar(data)
        typestr = 'boolean';
    else
        typestr = 'array';
    end
elseif isnumeric(data)
    if isscalar(data)
        if mod(data, 1) == 0
            typestr = 'integer';
        else
            typestr = 'number';
        end
    else
        typestr = 'array';
    end
elseif iscell(data)
    typestr = 'array';
elseif isstruct(data) || isa(data, 'containers.Map')
    typestr = 'object';
else
    typestr = 'unknown';
end

%% -------------------------------------------------------------------------
function [valid, errors] = validatenumeric(data, schema, path)

valid = true;
errors = {};

if hasschemakey(schema, 'minimum') && data < getschemavalue(schema, 'minimum')
    valid = false;
    errors{end + 1} = sprintf('%s: value < minimum', path);
end
if hasschemakey(schema, 'maximum') && data > getschemavalue(schema, 'maximum')
    valid = false;
    errors{end + 1} = sprintf('%s: value > maximum', path);
end
if hasschemakey(schema, 'exclusiveMinimum') && data <= getschemavalue(schema, 'exclusiveMinimum')
    valid = false;
    errors{end + 1} = sprintf('%s: value <= exclusiveMinimum', path);
end
if hasschemakey(schema, 'exclusiveMaximum') && data >= getschemavalue(schema, 'exclusiveMaximum')
    valid = false;
    errors{end + 1} = sprintf('%s: value >= exclusiveMaximum', path);
end
if hasschemakey(schema, 'multipleOf')
    mult = getschemavalue(schema, 'multipleOf');
    if mult > 0 && abs(mod(data, mult)) > eps * abs(data)
        valid = false;
        errors{end + 1} = sprintf('%s: not multipleOf %g', path, mult);
    end
end

%% -------------------------------------------------------------------------
function [valid, errors] = validatebinary(data, schema, path)

valid = true;
errors = {};

% binType validation
if hasschemakey(schema, 'binType')
    bintype = getschemavalue(schema, 'binType');
    validtypes = {'uint8', 'int8', 'uint16', 'int16', 'uint32', 'int32', 'uint64', 'int64', 'single', 'double', 'logical'};
    if ~ismember(bintype, validtypes)
        valid = false;
        errors{end + 1} = sprintf('%s: invalid binType "%s"', path, bintype);
    elseif ~(isnumeric(data) || islogical(data)) || ~strcmp(class(data), bintype)
        valid = false;
        errors{end + 1} = sprintf('%s: expected %s, got %s', path, bintype, class(data));
    end
end

% minDims/maxDims validation
actualsize = size(data);
for dimtype = {'minDims', 'maxDims'}
    if hasschemakey(schema, dimtype{1})
        dims = getschemavalue(schema, dimtype{1});
        if iscell(dims)
            dims = [dims{:}];
        end
        if (length(dims) == 1)
            if (~isvector(data))
                errors{end + 1} = sprintf('%s: length of dim is %d, violates %s length of %d', path, length(actualsize), dimtype{1}, length(dims));
            else
                actualsize = max(actualsize);
            end
        end
        ismin = strcmp(dimtype{1}, 'minDims');
        checklen = min(length(actualsize), length(dims));
        if ismin
            actualsize = [actualsize ones(1, max(0, length(dims) - length(actualsize)))];
            checklen = length(dims);
        end
        for i = 1:checklen
            if (ismin && actualsize(i) < dims(i)) || (~ismin && actualsize(i) > dims(i))
                valid = false;
                errors{end + 1} = sprintf('%s: dim %d is %d, violates %s %d', path, i, actualsize(i), dimtype{1}, dims(i));
            end
        end
        if ~ismin && length(actualsize) > length(dims) && any(actualsize(length(dims) + 1:end) > 1)
            valid = false;
            errors{end + 1} = sprintf('%s: has %d dimensions, %s only specifies %d', path, ndims(data), dimtype{1}, length(dims));
        end
    end
end

%% -------------------------------------------------------------------------
function [valid, errors] = validatestring(str, schema, path)

valid = true;
errors = {};
len = length(str);

if hasschemakey(schema, 'minLength') && len < getschemavalue(schema, 'minLength')
    valid = false;
    errors{end + 1} = [path ': string too short'];
end
if hasschemakey(schema, 'maxLength') && len > getschemavalue(schema, 'maxLength')
    valid = false;
    errors{end + 1} = [path ': string too long'];
end
if hasschemakey(schema, 'pattern') && isempty(regexp(str, getschemavalue(schema, 'pattern'), 'once'))
    valid = false;
    errors{end + 1} = [path ': pattern mismatch'];
end
if hasschemakey(schema, 'format')
    fmt = getschemavalue(schema, 'format');
    patterns = struct('email', '^[^@\s]+@[^@\s]+\.[^@\s]+$', ...
                      'uri', '^https?://', ...
                      'date', '^\d{4}-\d{2}-\d{2}$', ...
                      'ipv4', '^(\d{1,3}\.){3}\d{1,3}$', ...
                      'uuid', '^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$');
    if isfield(patterns, fmt) && isempty(regexp(str, patterns.(fmt), 'once'))
        valid = false;
        errors{end + 1} = [path ': invalid ' fmt];
    end
end

%% -------------------------------------------------------------------------
function [len, getelem] = getarrayaccessor(data)

if iscell(data)
    len = length(data);
    getelem = @(i) data{i};
else
    if isvector(data)
        len = length(data);
        getelem = @(i) data(i);
    else
        len = size(data, 1);
        getelem = @(i) data(i, :);
    end
end

%% -------------------------------------------------------------------------
function [valid, errors] = validatearray(data, schema, path, varargin)

opt = varargin{1};
valid = true;
errors = {};

[len, getelem] = getarrayaccessor(data);

if hasschemakey(schema, 'minItems') && len < getschemavalue(schema, 'minItems')
    valid = false;
    errors{end + 1} = [path ': too few items'];
end
if hasschemakey(schema, 'maxItems') && len > getschemavalue(schema, 'maxItems')
    valid = false;
    errors{end + 1} = [path ': too many items'];
end
if hasschemakey(schema, 'uniqueItems') && getschemavalue(schema, 'uniqueItems')
    for i = 1:len
        for j = i + 1:len
            if isequal(getelem(i), getelem(j))
                valid = false;
                errors{end + 1} = [path ': duplicate items'];
                break
            end
        end
    end
end
if hasschemakey(schema, 'items')
    items = getschemavalue(schema, 'items');
    if iscell(items)
        for i = 1:min(len, length(items))
            elem = getelem(i);
            [isvalid, errmsg] = validatedata(elem, items{i}, sprintf('%s[%d]', path, i - 1), opt);
            if ~isvalid
                valid = false;
                errors = [errors errmsg];
            end
        end
    else
        for i = 1:len
            elem = getelem(i);
            [isvalid, errmsg] = validatedata(elem, items, sprintf('%s[%d]', path, i - 1), opt);
            if ~isvalid
                valid = false;
                errors = [errors errmsg];
            end
        end
    end
end
if hasschemakey(schema, 'contains')
    found = false;
    for i = 1:len
        elem = getelem(i);
        isvalid = validatedata(elem, getschemavalue(schema, 'contains'), path, opt);
        if isvalid
            found = true;
            break
        end
    end
    if ~found
        valid = false;
        errors{end + 1} = [path ': contains not satisfied'];
    end
end

%% -------------------------------------------------------------------------
function [valid, errors] = validateobject(data, schema, path, varargin)

opt = varargin{1};
valid = true;
errors = {};

if isstruct(data)
    datakeys = fieldnames(data);
    getvalue = @(k) data.(k);
    haskey = @(k) isfield(data, k);
else
    datakeys = keys(data);
    getvalue = @(k) data(k);
    haskey = @(k) isKey(data, k);
end
numkeys = length(datakeys);

if hasschemakey(schema, 'minProperties') && numkeys < getschemavalue(schema, 'minProperties')
    valid = false;
    errors{end + 1} = [path ': too few properties'];
end
if hasschemakey(schema, 'maxProperties') && numkeys > getschemavalue(schema, 'maxProperties')
    valid = false;
    errors{end + 1} = [path ': too many properties'];
end
if hasschemakey(schema, 'required')
    reqfields = getschemavalue(schema, 'required');
    for i = 1:length(reqfields)
        if ~haskey(reqfields{i})
            valid = false;
            errors{end + 1} = sprintf('%s: missing "%s"', path, reqfields{i});
        end
    end
end

validatedkeys = {};

if hasschemakey(schema, 'properties')
    props = getschemavalue(schema, 'properties');
    if isstruct(props)
        propnames = fieldnames(props);
        % Decode field names for struct
        for i = 1:length(propnames)
            propnames{i} = decodevarname(propnames{i});
        end
    else
        propnames = keys(props);
    end
    for i = 1:length(propnames)
        pname = propnames{i};
        if haskey(pname)
            validatedkeys{end + 1} = pname;
            if isstruct(props)
                propschema = props.(encodevarname(pname));
            else
                propschema = props(pname);
            end
            [isvalid, errmsg] = validatedata(getvalue(pname), propschema, [path '.' pname], opt);
            if ~isvalid
                valid = false;
                errors = [errors errmsg];
            end
        end
    end
end

if hasschemakey(schema, 'patternProperties')
    patternprops = getschemavalue(schema, 'patternProperties');
    if isstruct(patternprops)
        patterns = fieldnames(patternprops);
        for i = 1:length(patterns)
            patterns{i} = decodevarname(patterns{i});
        end
    else
        patterns = keys(patternprops);
    end
    for i = 1:length(datakeys)
        keyname = datakeys{i};
        if iscell(keyname)
            keyname = keyname{1};
        end
        for j = 1:length(patterns)
            if ~isempty(regexp(keyname, patterns{j}, 'once'))
                validatedkeys{end + 1} = keyname;
                if isstruct(patternprops)
                    propschema = patternprops.(encodevarname(patterns{j}));
                else
                    propschema = patternprops(patterns{j});
                end
                [isvalid, errmsg] = validatedata(getvalue(keyname), propschema, [path '.' keyname], opt);
                if ~isvalid
                    valid = false;
                    errors = [errors errmsg];
                end
            end
        end
    end
end

if hasschemakey(schema, 'additionalProperties')
    addprops = getschemavalue(schema, 'additionalProperties');
    for i = 1:length(datakeys)
        keyname = datakeys{i};
        if iscell(keyname)
            keyname = keyname{1};
        end
        if ~ismember(keyname, validatedkeys)
            if islogical(addprops) && ~addprops
                valid = false;
                errors{end + 1} = sprintf('%s: extra property "%s"', path, keyname);
            elseif isa(addprops, 'containers.Map') || isstruct(addprops)
                [isvalid, errmsg] = validatedata(getvalue(keyname), addprops, [path '.' keyname], opt);
                if ~isvalid
                    valid = false;
                    errors = [errors errmsg];
                end
            end
        end
    end
end

%% -------------------------------------------------------------------------
function [valid, errors] = validatecomposition(data, schema, path, varargin)

opt = varargin{1};
valid = true;
errors = {};

if hasschemakey(schema, 'allOf')
    schemas = getschemavalue(schema, 'allOf');
    for i = 1:length(schemas)
        [isvalid, errmsg] = validatedata(data, schemas{i}, path, opt);
        if ~isvalid
            valid = false;
            errors = [errors errmsg];
        end
    end
end

if hasschemakey(schema, 'anyOf')
    schemas = getschemavalue(schema, 'anyOf');
    match = false;
    for i = 1:length(schemas)
        isvalid = validatedata(data, schemas{i}, path, opt);
        if isvalid
            match = true;
            break
        end
    end
    if ~match
        valid = false;
        errors{end + 1} = [path ': anyOf not satisfied'];
    end
end

if hasschemakey(schema, 'oneOf')
    schemas = getschemavalue(schema, 'oneOf');
    matchcount = 0;
    for i = 1:length(schemas)
        isvalid = validatedata(data, schemas{i}, path, opt);
        if isvalid
            matchcount = matchcount + 1;
        end
    end
    if matchcount ~= 1
        valid = false;
        errors{end + 1} = sprintf('%s: oneOf matched %d', path, matchcount);
    end
end

if hasschemakey(schema, 'not')
    isvalid = validatedata(data, getschemavalue(schema, 'not'), path, opt);
    if isvalid
        valid = false;
        errors{end + 1} = [path ': not violated'];
    end
end

%% -------------------------------------------------------------------------
function output = generatedata(schema, varargin)

opt = varargin{1};
genopt = jsonopt('generate', 'requireddefaults', opt);
rootschema = opt.rootschema;

output = [];

if ~(isa(schema, 'containers.Map') || isstruct(schema)) || isempty(schemakeys(schema))
    return
end

if hasschemakey(schema, '$ref')
    refschema = resolveref(getschemavalue(schema, '$ref'), rootschema);
    if ~isempty(refschema)
        output = generatedata(refschema, opt);
    end
    return
end

if hasschemakey(schema, 'default')
    output = getschemavalue(schema, 'default');
    return
end
if hasschemakey(schema, 'const')
    output = getschemavalue(schema, 'const');
    return
end
if hasschemakey(schema, 'enum')
    enumvalues = getschemavalue(schema, 'enum');
    if ~isempty(enumvalues)
        output = enumvalues{1};
    end
    return
end

schematype = '';
if hasschemakey(schema, 'type')
    schematype = getschemavalue(schema, 'type');
    if iscell(schematype)
        schematype = schematype{1};
    end
elseif hasschemakey(schema, 'properties') || hasschemakey(schema, 'required')
    schematype = 'object';
elseif hasschemakey(schema, 'items')
    schematype = 'array';
end

% Handle binType with minDims
if hasschemakey(schema, 'binType')
    bintype = getschemavalue(schema, 'binType');
    if hasschemakey(schema, 'minDims')
        dims = getschemavalue(schema, 'minDims');
        if iscell(dims)
            dims = [dims{:}];
        end
    else
        dims = 1;
    end
    switch bintype
        case 'logical'
            output = false(dims);
        otherwise
            output = zeros(dims, bintype);
    end
    return
end

switch schematype
    case 'null'
        output = [];
    case 'boolean'
        output = false;
    case 'integer'
        output = generateinteger(schema);
    case 'number'
        output = generatenumber(schema);
    case 'string'
        output = generatestring(schema);
    case 'array'
        output = generatearray(schema, opt);
    case 'object'
        output = generateobject(schema, opt);
end

if hasschemakey(schema, 'allOf')
    schemas = getschemavalue(schema, 'allOf');
    for i = 1:length(schemas)
        subdata = generatedata(schemas{i}, opt);
        if isstruct(output) && isstruct(subdata)
            fnames = fieldnames(subdata);
            for j = 1:length(fnames)
                output.(fnames{j}) = subdata.(fnames{j});
            end
        end
    end
end

%% -------------------------------------------------------------------------
function val = generateinteger(schema)

val = 0;
if hasschemakey(schema, 'minimum')
    val = getschemavalue(schema, 'minimum');
end
if hasschemakey(schema, 'exclusiveMinimum')
    excmin = getschemavalue(schema, 'exclusiveMinimum');
    if val <= excmin
        val = floor(excmin) + 1;
    end
end
val = ceil(val);
if hasschemakey(schema, 'multipleOf')
    mult = getschemavalue(schema, 'multipleOf');
    if mult > 0
        val = ceil(val / mult) * mult;
    end
end

%% -------------------------------------------------------------------------
function val = generatenumber(schema)

val = 0;
if hasschemakey(schema, 'minimum')
    val = getschemavalue(schema, 'minimum');
end
if hasschemakey(schema, 'exclusiveMinimum')
    excmin = getschemavalue(schema, 'exclusiveMinimum');
    if val <= excmin
        val = excmin + eps(excmin);
    end
end
if hasschemakey(schema, 'multipleOf')
    mult = getschemavalue(schema, 'multipleOf');
    if mult > 0
        val = ceil(val / mult) * mult;
    end
end

%% -------------------------------------------------------------------------
function val = generatestring(schema)

val = '';
if hasschemakey(schema, 'format')
    fmt = getschemavalue(schema, 'format');
    formats = struct('email', 'user@example.com', ...
                     'uri', 'http://example.com', ...
                     'date', '2000-01-01', ...
                     'ipv4', '0.0.0.0', ...
                     'uuid', '00000000-0000-0000-0000-000000000000');
    if isfield(formats, fmt)
        val = formats.(fmt);
    end
end
if hasschemakey(schema, 'minLength')
    minlen = getschemavalue(schema, 'minLength');
    if length(val) < minlen
        val = [val repmat('a', 1, minlen - length(val))];
    end
end

%% -------------------------------------------------------------------------
function val = generatearray(schema, varargin)

opt = varargin{1};
rootschema = opt.rootschema;
val = {};
minitems = 0;

if hasschemakey(schema, 'minItems')
    minitems = getschemavalue(schema, 'minItems');
end

if hasschemakey(schema, 'items')
    items = getschemavalue(schema, 'items');
    if iscell(items)
        for i = 1:length(items)
            val{i} = generatedata(items{i}, opt);
        end
    else
        for i = 1:minitems
            val{i} = generatedata(items, opt);
        end
    end
else
    for i = 1:minitems
        val{i} = [];
    end
end

%% -------------------------------------------------------------------------
function val = generateobject(schema, varargin)

opt = varargin{1};
genopt = jsonopt('generate', 'requireddefaults', opt);
val = struct();
reqfields = {};

if hasschemakey(schema, 'required')
    reqfields = getschemavalue(schema, 'required');
end

if hasschemakey(schema, 'properties')
    props = getschemavalue(schema, 'properties');
    if isstruct(props)
        propnames = fieldnames(props);
        % Decode field names for struct
        for i = 1:length(propnames)
            propnames{i} = decodevarname(propnames{i});
        end
    else
        propnames = keys(props);
    end

    for i = 1:length(propnames)
        pname = propnames{i};
        if isstruct(props)
            propschema = props.(encodevarname(pname));
        else
            propschema = props(pname);
        end
        fname = encodevarname(pname);
        isreq = ismember(pname, reqfields);
        hasdefault = (isa(propschema, 'containers.Map') && isKey(propschema, 'default')) || ...
                     (isstruct(propschema) && isfield(propschema, 'default'));

        shouldgen = false;
        switch genopt
            case 'all'
                shouldgen = true;
            case 'required'
                shouldgen = isreq;
            case 'requireddefaults'
                shouldgen = isreq || hasdefault;
        end

        if shouldgen
            if isa(propschema, 'containers.Map') || isstruct(propschema)
                val.(fname) = generatedata(propschema, opt);
            else
                val.(fname) = [];
            end
        end
    end
else
    for i = 1:length(reqfields)
        val.(genvarname(reqfields{i})) = [];
    end
end

%%
function subschema = getsubschema(schema, jsonpath)

subschema = schema;
if isempty(schema) || isempty(jsonpath) || strcmp(jsonpath, '$')
    return
end

% Parse path after $.
path = regexprep(jsonpath, '^\$\.?', '');
if isempty(path)
    return
end

% Tokenize: split by unescaped dots and array indices
tokens = regexp(path, '(?:\\.|[^\.\[]+|\[\d+\])', 'match');

for i = 1:length(tokens)
    tok = tokens{i};

    % Resolve $ref if present
    if (isstruct(subschema))
        while isfield(subschema, encodevarname('$ref'))
            subschema = resolveref(subschema.(encodevarname('$ref')), schema);
            if isempty(subschema)
                return
            end
        end
    else
        while isKey(subschema, '$ref')
            subschema = resolveref(subschema('$ref'), schema);
            if isempty(subschema)
                return
            end
        end
    end

    if tok(1) == '['
        % Array index -> use items schema
        if isstruct(subschema) && isfield(subschema, 'items')
            subschema = subschema.items;
            if iscell(subschema) && ~isempty(subschema)
                subschema = subschema{1};
            end
        elseif (isa(subschema, 'containers.Map') || isa(subschema, 'dictionary')) && isKey(subschema, 'items')
            subschema = subschema('items');
            if iscell(subschema) && ~isempty(subschema)
                subschema = subschema{1};
            end
        else
            subschema = [];
        end
    else
        % Property name (unescape \.)
        prop = strrep(tok, '\.', '.');
        if isstruct(subschema) && isfield(subschema, 'properties')
            props = subschema.properties;
            if isstruct(props) && isfield(props, encodevarname(prop))
                subschema = props.(encodevarname(prop));
            else
                subschema = [];
            end
        elseif (isa(subschema, 'containers.Map') || isa(subschema, 'dictionary')) && isKey(subschema, 'properties')
            props = subschema('properties');
            if (isa(subschema, 'containers.Map') || isa(subschema, 'dictionary')) && isKey(props, prop)
                subschema = props(prop);
            else
                subschema = [];
            end
        else
            subschema = [];
        end
    end
end
