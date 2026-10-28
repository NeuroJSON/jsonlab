function [valid, errors, skipped] = jsonschema(data, schema, varargin)
%
% [valid, errors] = jsonschema(data, schema)
% [valid, errors] = jsonschema(data, schemafile)
% [valid, errors] = jsonschema(data, schema, 'option', value, ...)
% [valid, errors, skipped] = jsonschema(data, schema, ...)
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
%     'virtual': string - 'skip' (default) or 'error'; how to treat a schema
%                keyword that needs the values of a virtual array (see below)
%     'errorformat': string - 'string' (default) returns errors and skipped as
%                cell arrays of messages; 'struct' returns struct arrays with
%                fields path (JSONPath of the data), keyword (the schema
%                keyword that failed, such as 'required' or 'minDims'),
%                message (the same text as the string form) and property
%                (the missing or extra property for 'required' and
%                'additionalProperties', otherwise empty)
%
% Output:
%     valid:  logical true if data conforms to schema
%     errors: cell array of validation error messages with paths, or a
%             struct array if 'errorformat' is 'struct'
%     skipped: the checks that were not run on virtual arrays, in the same
%             format as errors
%
% Virtual arrays:
%     a JData array header that has _ArrayType_ and _ArraySize_ but neither
%     _ArrayData_ nor _ArrayZipData_, such as a dataset that loadh5 did not
%     read because of its MaxBytes option, is validated as an array of that
%     type and size rather than as an object. type, binType, minDims, maxDims,
%     minItems and maxItems are checked; keywords that need the values, such
%     as enum, const, minimum or items, are listed in skipped, or reported as
%     errors when 'virtual' is 'error'
%
% License: BSD or GPL version 3, see LICENSE_{BSD,GPLv3}.txt
%
% -- this function is part of JSONLab toolbox (http://neurojson.org/jsonlab)
%

opt = varargin2struct(varargin{:});
skipped = {};

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
opt.virtualerror = strcmpi(jsonopt('virtual', 'skip', opt), 'error');
% a handle object, so the skipped checks from all recursive calls are collected
opt.skipped = containers.Map('KeyType', 'double', 'ValueType', 'any');

[valid, errors] = validatedata(data, schema, '$', opt);
skipped = values(opt.skipped);

% errors are collected as records and returned as strings unless asked
if strcmpi(jsonopt('errorformat', 'string', opt), 'struct')
    errors = torecords(errors);
    skipped = torecords(skipped);
else
    errors = cellfun(@(e) e.message, errors, 'UniformOutput', false);
    skipped = cellfun(@(e) e.message, skipped, 'UniformOutput', false);
end

%% -------------------------------------------------------------------------
function recs = torecords(reclist)
% convert a cell array of error records to a 1xN struct array

recs = struct('path', {}, 'keyword', {}, 'message', {}, 'property', {});
if ~isempty(reclist)
    recs = [reclist{:}];
end

%% -------------------------------------------------------------------------
function [valid, errors] = validatedata(data, schema, path, varargin)

opt = varargin{1};
rootschema = opt.rootschema;
valid = true;
errors = {};
vinfo = virtualarray(data);
isvirtual = ~isempty(vinfo);

if islogical(schema) && isscalar(schema)
    valid = schema;
    if ~valid
        errors{end + 1} = errrecord(path, 'false', [path ': schema is false']);
    end
    return
end
if ~isnonemptyschema(schema)
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
            errors{end + 1} = errrecord(path, '$ref', sprintf('%s: cannot resolve $ref "%s"', path, ref));
        end
    end
    return
end

% type
if hasschemakey(schema, 'type')
    schematype = getschemavalue(schema, 'type');
    if iscell(schematype)
        match = false;
        undecided = false;
        for i = 1:length(schematype)
            res = checktype(data, schematype{i}, vinfo);
            match = match || res > 0;
            undecided = undecided || res < 0;
        end
        if ~match && undecided
            [valid, errors] = skipcheck(path, 'type', opt, valid, errors);
        elseif ~match
            valid = false;
            errors{end + 1} = errrecord(path, 'type', sprintf('%s: type mismatch', path));
        end
    else
        res = checktype(data, schematype, vinfo);
        if res < 0
            [valid, errors] = skipcheck(path, 'type', opt, valid, errors);
        elseif ~res
            valid = false;
            errors{end + 1} = errrecord(path, 'type', sprintf('%s: expected %s, got %s', path, schematype, gettype(data, vinfo)));
        end
    end
end

% enum and const compare values, which a virtual array does not have
if isvirtual
    for key = {'enum', 'const'}
        if hasschemakey(schema, key{1})
            [valid, errors] = skipcheck(path, key{1}, opt, valid, errors);
        end
    end
end

% enum
if hasschemakey(schema, 'enum') && ~isvirtual
    enumvalues = getschemavalue(schema, 'enum');
    if ~iscell(enumvalues)
        enumvalues = num2cell(enumvalues); % loadjson returns a numeric enum as an array
    end
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
        errors{end + 1} = errrecord(path, 'enum', [path ': not in enum']);
    end
end

% const
if hasschemakey(schema, 'const') && ~isvirtual && ~isequal(data, getschemavalue(schema, 'const'))
    valid = false;
    errors{end + 1} = errrecord(path, 'const', [path ': const mismatch']);
end

% numeric
if isnumeric(data) && isscalar(data)
    [isvalid, errmsg] = validatenumeric(data, schema, path);
    if ~isvalid
        valid = false;
        errors = [errors errmsg];
    end
elseif isvirtual && prod(vinfo.size) == 1
    for key = {'minimum', 'maximum', 'exclusiveMinimum', 'exclusiveMaximum', 'multipleOf'}
        if hasschemakey(schema, key{1})
            [valid, errors] = skipcheck(path, key{1}, opt, valid, errors);
        end
    end
end

% binary type and dimensions
if isnumeric(data) || islogical(data) || isvirtual
    [isvalid, errmsg] = validatebinary(data, schema, path, vinfo);
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
elseif isvirtual && prod(vinfo.size) ~= 1
    [valid, errors] = validatevirtualarray(vinfo, schema, path, opt, valid, errors);
end

% object
if (isstruct(data) || isa(data, 'containers.Map')) && ~isvirtual
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
    [ifok, undecided] = testcondition(data, getschemavalue(schema, 'if'), path, opt);
    subkey = '';
    if undecided
        [valid, errors] = skipcheck(path, 'if', opt, valid, errors);
    elseif ifok && hasschemakey(schema, 'then')
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
function tf = isnonemptyschema(schema)
% a schema object; an empty one needs no check, but testing a containers.Map
% for emptiness costs more than the keyword lookups it would save

tf = isa(schema, 'containers.Map') || (isstruct(schema) && ~isempty(fieldnames(schema)));

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
function ok = checktype(data, schematype, vinfo)
% return 1 if data matches schematype, 0 if not, and -1 if this can not be
% decided because a virtual array has no values

if nargin > 2 && ~isempty(vinfo)
    ok = checkvirtualtype(vinfo, schematype);
    return
end

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
function ok = checkvirtualtype(vinfo, schematype)

isscalararray = prod(vinfo.size) == 1;
isint = ~isempty(regexp(vinfo.cls, '^u?int\d+$', 'once'));
switch schematype
    case 'null'
        ok = prod(vinfo.size) == 0;
    case 'boolean'
        ok = strcmp(vinfo.cls, 'logical') && isscalararray;
    case 'integer'
        if ~isscalararray || strcmp(vinfo.cls, 'logical') || vinfo.iscomplex
            ok = 0;
        elseif isint
            ok = 1;
        else
            ok = -1; % a floating-point scalar may still hold an integer value
        end
    case 'number'
        ok = isscalararray && ~strcmp(vinfo.cls, 'logical');
    case 'array'
        ok = ~isscalararray;
    case {'string', 'object'}
        ok = 0;
    otherwise
        ok = 1;
end
ok = double(ok);

%% -------------------------------------------------------------------------
function typestr = gettype(data, vinfo)

if nargin > 1 && ~isempty(vinfo)
    if prod(vinfo.size) ~= 1
        typestr = 'array';
    elseif strcmp(vinfo.cls, 'logical')
        typestr = 'boolean';
    elseif ~isempty(regexp(vinfo.cls, '^u?int\d+$', 'once'))
        typestr = 'integer';
    else
        typestr = 'number';
    end
    return
end

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
    errors{end + 1} = errrecord(path, 'minimum', sprintf('%s: value < minimum', path));
end
if hasschemakey(schema, 'maximum') && data > getschemavalue(schema, 'maximum')
    valid = false;
    errors{end + 1} = errrecord(path, 'maximum', sprintf('%s: value > maximum', path));
end
if hasschemakey(schema, 'exclusiveMinimum') && data <= getschemavalue(schema, 'exclusiveMinimum')
    valid = false;
    errors{end + 1} = errrecord(path, 'exclusiveMinimum', sprintf('%s: value <= exclusiveMinimum', path));
end
if hasschemakey(schema, 'exclusiveMaximum') && data >= getschemavalue(schema, 'exclusiveMaximum')
    valid = false;
    errors{end + 1} = errrecord(path, 'exclusiveMaximum', sprintf('%s: value >= exclusiveMaximum', path));
end
if hasschemakey(schema, 'multipleOf')
    mult = getschemavalue(schema, 'multipleOf');
    if mult > 0 && abs(mod(data, mult)) > eps * abs(data)
        valid = false;
        errors{end + 1} = errrecord(path, 'multipleOf', sprintf('%s: not multipleOf %g', path, mult));
    end
end

%% -------------------------------------------------------------------------
function [valid, errors] = validatebinary(data, schema, path, vinfo)

valid = true;
errors = {};
if nargin > 3 && ~isempty(vinfo)
    datatype = vinfo.cls;
    isbinary = true;
    datasize = vinfo.size;
else
    datatype = class(data);
    isbinary = isnumeric(data) || islogical(data);
    datasize = size(data);
end
isvectordata = length(datasize) == 2 && any(datasize == 1);

% binType validation
if hasschemakey(schema, 'binType')
    % binType is one type name or a list of accepted type names
    bintype = getschemavalue(schema, 'binType');
    if iscell(bintype)
        bintypes = cellfun(@char, bintype, 'UniformOutput', false);
    else
        bintypes = {char(bintype)};
    end
    % strcmp in loops, as ismember on cell arrays is slow for these short lists
    validtypes = {'uint8', 'int8', 'uint16', 'int16', 'uint32', 'int32', 'uint64', 'int64', 'single', 'double', 'logical'};
    known = true;
    for i = 1:length(bintypes)
        known = known && any(strcmp(bintypes{i}, validtypes));
    end
    if ~known
        valid = false;
        errors{end + 1} = errrecord(path, 'binType', sprintf('%s: invalid binType "%s"', path, strjoin(bintypes, '|')));
    elseif ~isbinary || ~any(strcmp(datatype, bintypes))
        valid = false;
        errors{end + 1} = errrecord(path, 'binType', sprintf('%s: expected %s, got %s', path, strjoin(bintypes, '|'), datatype));
    end
end

% minDims/maxDims validation
actualsize = datasize;
for dimtype = {'minDims', 'maxDims'}
    if hasschemakey(schema, dimtype{1})
        dims = getschemavalue(schema, dimtype{1});
        if iscell(dims)
            dims = [dims{:}];
        end
        if (length(dims) == 1)
            if (~isvectordata)
                errors{end + 1} = errrecord(path, dimtype{1}, sprintf('%s: length of dim is %d, violates %s length of %d', path, length(actualsize), dimtype{1}, length(dims)));
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
                errors{end + 1} = errrecord(path, dimtype{1}, sprintf('%s: dim %d is %d, violates %s %d', path, i, actualsize(i), dimtype{1}, dims(i)));
            end
        end
        if ~ismin && length(actualsize) > length(dims) && any(actualsize(length(dims) + 1:end) > 1)
            valid = false;
            errors{end + 1} = errrecord(path, dimtype{1}, sprintf('%s: has %d dimensions, %s only specifies %d', path, length(datasize), dimtype{1}, length(dims)));
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
    errors{end + 1} = errrecord(path, 'minLength', [path ': string too short']);
end
if hasschemakey(schema, 'maxLength') && len > getschemavalue(schema, 'maxLength')
    valid = false;
    errors{end + 1} = errrecord(path, 'maxLength', [path ': string too long']);
end
if hasschemakey(schema, 'pattern') && isempty(regexp(str, getschemavalue(schema, 'pattern'), 'once'))
    valid = false;
    errors{end + 1} = errrecord(path, 'pattern', [path ': pattern mismatch']);
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
        errors{end + 1} = errrecord(path, 'format', [path ': invalid ' fmt]);
    end
end

%% -------------------------------------------------------------------------
function vinfo = virtualarray(data)
% return the type and size of a JData array header that holds no data, such
% as the output of loadh5 with the MaxBytes option, or [] for any other input

vinfo = [];
keys = {'_ArrayType_', '_ArraySize_', '_ArrayData_', '_ArrayZipData_', '_ArrayIsComplex_'};
if isstruct(data) && isscalar(data)
    % fields are named x0x5F_... by encodevarname in MATLAB, _..._ in Octave,
    % and x_... is accepted by jdatadecode; test _ArraySize_ first, which
    % rules out ordinary structs without building the other names
    if isfield(data, 'x0x5F_ArraySize_')
        prefix = 'x0x5F';
    elseif isfield(data, 'x_ArraySize_')
        prefix = 'x';
    elseif isfield(data, '_ArraySize_')
        prefix = '';
    else
        return
    end
    names = strcat(prefix, keys);
    if ~isfield(data, names{1}) || isfield(data, names{3}) || isfield(data, names{4})
        return
    end
    getval = @(i) data.(names{i});
    hascomplex = isfield(data, names{5});
elseif isa(data, 'containers.Map')
    if ~isKey(data, keys{1}) || ~isKey(data, keys{2}) || isKey(data, keys{3}) || isKey(data, keys{4})
        return
    end
    getval = @(i) data(keys{i});
    hascomplex = isKey(data, keys{5});
else
    return
end
arraysize = getval(2);
if iscell(arraysize)
    arraysize = [arraysize{:}];
end
if ~(ischar(getval(1)) || isa(getval(1), 'string')) || ~isnumeric(arraysize)
    return
end
arraysize = double(arraysize(:)');
if length(arraysize) == 1
    arraysize = [1 arraysize];
end
vinfo = struct('cls', char(getval(1)), 'size', arraysize, 'iscomplex', hascomplex && isequal(getval(5), true));

%% -------------------------------------------------------------------------
function [valid, errors] = validatevirtualarray(vinfo, schema, path, opt, valid, errors)
% item counts follow getarrayaccessor: the length of a vector, else the rows

if length(vinfo.size) == 2 && any(vinfo.size == 1)
    len = prod(vinfo.size);
else
    len = vinfo.size(1);
end
if hasschemakey(schema, 'minItems') && len < getschemavalue(schema, 'minItems')
    valid = false;
    errors{end + 1} = errrecord(path, 'minItems', [path ': too few items']);
end
if hasschemakey(schema, 'maxItems') && len > getschemavalue(schema, 'maxItems')
    valid = false;
    errors{end + 1} = errrecord(path, 'maxItems', [path ': too many items']);
end
for key = {'uniqueItems', 'items', 'prefixItems', 'contains'}
    if hasschemakey(schema, key{1})
        [valid, errors] = skipcheck(path, key{1}, opt, valid, errors);
    end
end

%% -------------------------------------------------------------------------
function [valid, errors] = skipcheck(path, keyword, opt, valid, errors)
% record a check that needs the values of a virtual array

rec = errrecord(path, keyword, sprintf('%s: %s not checked, array data not loaded', path, keyword));
if opt.virtualerror
    valid = false;
    errors{end + 1} = rec;
else
    opt.skipped(opt.skipped.Count + 1) = rec;
end

%% -------------------------------------------------------------------------
function [ok, undecided] = testcondition(data, subschema, path, opt)
% evaluate the subschema of if or not; it is undecided if any of its checks
% needed the values of a virtual array, whose skipped records are discarded

opt.virtualerror = false;
count = opt.skipped.Count;
ok = validatedata(data, subschema, path, opt);
undecided = opt.skipped.Count > count;
if undecided
    remove(opt.skipped, num2cell(count + 1:opt.skipped.Count));
end

%% -------------------------------------------------------------------------
function rec = errrecord(path, keyword, message, property)
% one validation error: the JSONPath of the data, the schema keyword that
% failed, the message, and for required/additionalProperties the property name

if nargin < 4
    property = '';
end
rec = struct('path', path, 'keyword', keyword, 'message', message, 'property', property);

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
    errors{end + 1} = errrecord(path, 'minItems', [path ': too few items']);
end
if hasschemakey(schema, 'maxItems') && len > getschemavalue(schema, 'maxItems')
    valid = false;
    errors{end + 1} = errrecord(path, 'maxItems', [path ': too many items']);
end
if hasschemakey(schema, 'uniqueItems') && getschemavalue(schema, 'uniqueItems')
    for i = 1:len
        for j = i + 1:len
            if isequal(getelem(i), getelem(j))
                valid = false;
                errors{end + 1} = errrecord(path, 'uniqueItems', [path ': duplicate items']);
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
        [handled, isvalid, errmsg] = validateitemsfast(data, items, path, opt);
        if handled
            if ~isvalid
                valid = false;
                errors = [errors errmsg];
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
        errors{end + 1} = errrecord(path, 'contains', [path ': contains not satisfied']);
    end
end

%% -------------------------------------------------------------------------
function [handled, valid, errors] = validateitemsfast(data, items, path, opt)
% check all elements of a numeric vector or a cell array of strings at once
% when the items schema uses only type, enum, const and the numeric range
% keywords; the errors are the same, in the same order, as checking the
% elements one by one, which is slow for long arrays. handled is false for
% any other data or schema, which the caller then checks element by element

handled = false;
valid = true;
errors = {};
if ~isvector(data)
    return
end
while (isa(items, 'containers.Map') || isstruct(items)) && hasschemakey(items, '$ref')
    ref = getschemavalue(items, '$ref');
    if ~ischar(ref) || isempty(ref) || ref(1) ~= '#'
        return
    end
    items = resolveref(ref, opt.rootschema);
end
if isa(items, 'containers.Map')
    itemkeys = keys(items);
elseif isstruct(items)
    itemkeys = cellfun(@decodevarname, fieldnames(items), 'UniformOutput', false);
else
    return
end
allowed = {'type', 'enum', 'const', 'minimum', 'maximum', 'exclusiveMinimum', 'exclusiveMaximum', ...
           'multipleOf', 'description', 'title', '$comment', 'examples', 'default'};
for i = 1:length(itemkeys)
    if ~any(strcmp(itemkeys{i}, allowed))
        return
    end
end

n = numel(data);
checks = {'type', 'enum', 'const', 'minimum', 'maximum', 'exclusiveMinimum', 'exclusiveMaximum', 'multipleOf'};
bad = false(length(checks), n);
msg = cell(1, length(checks));
if isnumeric(data) && isreal(data)
    x = double(data(:)');
    if hasschemakey(items, 'type')
        itemtype = getschemavalue(items, 'type');
        if ~ischar(itemtype) || ~any(strcmp(itemtype, {'number', 'integer'}))
            return
        end
        if strcmp(itemtype, 'integer')
            bad(1, :) = mod(x, 1) ~= 0;
            msg{1} = '%s: expected integer, got number';
        end
    end
    if hasschemakey(items, 'enum')
        enumvalues = getschemavalue(items, 'enum');
        if ~iscell(enumvalues)
            enumvalues = num2cell(enumvalues);
        end
        if ~all(cellfun(@(v) isnumeric(v) && isscalar(v), enumvalues))
            return
        end
        bad(2, :) = ~ismember(x, double([enumvalues{:}]));
        msg{2} = '%s: not in enum';
    end
    if hasschemakey(items, 'const')
        constval = getschemavalue(items, 'const');
        if ~isnumeric(constval) || ~isscalar(constval)
            return
        end
        bad(3, :) = ~(x == double(constval));
        msg{3} = '%s: const mismatch';
    end
    limits = {'minimum', @(v, l) v < l, '%s: value < minimum'; 'maximum', @(v, l) v > l, '%s: value > maximum'; ...
              'exclusiveMinimum', @(v, l) v <= l, '%s: value <= exclusiveMinimum'; ...
              'exclusiveMaximum', @(v, l) v >= l, '%s: value >= exclusiveMaximum'};
    for i = 1:size(limits, 1)
        if hasschemakey(items, limits{i, 1})
            bad(3 + i, :) = limits{i, 2}(x, double(getschemavalue(items, limits{i, 1})));
            msg{3 + i} = limits{i, 3};
        end
    end
    if hasschemakey(items, 'multipleOf')
        mult = getschemavalue(items, 'multipleOf');
        if mult > 0
            bad(8, :) = abs(mod(x, mult)) > eps * abs(x);
        end
        msg{8} = ['%s: not multipleOf ' sprintf('%g', mult)];
    end
elseif iscell(data) && all(cellfun(@ischar, data))
    if hasschemakey(items, 'type') && ~isequal(getschemavalue(items, 'type'), 'string')
        return
    end
    if hasschemakey(items, 'enum')
        enumvalues = getschemavalue(items, 'enum');
        if ~iscell(enumvalues) || ~all(cellfun(@ischar, enumvalues))
            return
        end
        bad(2, :) = ~ismember(data(:)', enumvalues);
        msg{2} = '%s: not in enum';
    end
    if hasschemakey(items, 'const')
        constval = getschemavalue(items, 'const');
        if ~ischar(constval)
            return
        end
        bad(3, :) = ~strcmp(data(:)', constval);
        msg{3} = '%s: const mismatch';
    end
else
    return
end

handled = true;
for i = find(any(bad, 1))
    elempath = sprintf('%s[%d]', path, i - 1);
    for j = find(bad(:, i))'
        valid = false;
        errors{end + 1} = errrecord(elempath, checks{j}, sprintf(msg{j}, elempath));
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
    errors{end + 1} = errrecord(path, 'minProperties', [path ': too few properties']);
end
if hasschemakey(schema, 'maxProperties') && numkeys > getschemavalue(schema, 'maxProperties')
    valid = false;
    errors{end + 1} = errrecord(path, 'maxProperties', [path ': too many properties']);
end
if hasschemakey(schema, 'required')
    reqfields = getschemavalue(schema, 'required');
    for i = 1:length(reqfields)
        if ~haskey(reqfields{i})
            valid = false;
            errors{end + 1} = errrecord(path, 'required', sprintf('%s: missing "%s"', path, reqfields{i}), reqfields{i});
        end
    end
end

% keys matched by properties or patternProperties; a mask rather than a list,
% as testing each key against a growing list is quadratic for large objects
validated = false(1, numkeys);

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
            validated(strcmp(datakeys, pname)) = true;
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
                validated(i) = true;
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
        if ~validated(i)
            if islogical(addprops) && ~addprops
                valid = false;
                errors{end + 1} = errrecord(path, 'additionalProperties', sprintf('%s: extra property "%s"', path, keyname), keyname);
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
        errors{end + 1} = errrecord(path, 'anyOf', [path ': anyOf not satisfied']);
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
        errors{end + 1} = errrecord(path, 'oneOf', sprintf('%s: oneOf matched %d', path, matchcount));
    end
end

if hasschemakey(schema, 'not')
    [isvalid, undecided] = testcondition(data, getschemavalue(schema, 'not'), path, opt);
    if undecided
        [valid, errors] = skipcheck(path, 'not', opt, valid, errors);
    elseif isvalid
        valid = false;
        errors{end + 1} = errrecord(path, 'not', [path ': not violated']);
    end
end

%% -------------------------------------------------------------------------
function output = generatedata(schema, varargin)

opt = varargin{1};
genopt = jsonopt('generate', 'requireddefaults', opt);
rootschema = opt.rootschema;

output = [];

if ~isnonemptyschema(schema)
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
    if ~iscell(enumvalues)
        enumvalues = num2cell(enumvalues); % loadjson returns a numeric enum as an array
    end
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
    if iscell(bintype)
        bintype = bintype{1}; % generate the first of the accepted types
    end
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
