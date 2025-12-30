function output = saveyaml(rootname, obj, varargin)
%
% yaml=saveyaml(obj)
%    or
% yaml=saveyaml(rootname,obj,filename)
% yaml=saveyaml(rootname,obj,opt)
% yaml=saveyaml(rootname,obj,'param1',value1,'param2',value2,...)
%
% convert a MATLAB object (cell, struct or array) into YAML format
%
% author: Qianqian Fang (q.fang <at> neu.edu)
% created on 2025/01/01
%
% input:
%      rootname: the name of the root-object, when set to '', the root name
%           is ignored, however, when opt.ForceRootName is set to 1,
%           the MATLAB variable name will be used as the root name.
%      obj: a MATLAB object (array, cell, cell array, struct, struct array).
%      filename: a string for the file name to save the output YAML data.
%      opt: a struct for additional options, ignore to use default values.
%
% output:
%      yaml: a string in YAML format
%
% license:
%     BSD or GPL version 3, see LICENSE_{BSD,GPLv3}.txt files for details
%
% -- this function is part of JSONLab toolbox (http://neurojson.org/jsonlab)
%

if (nargin == 1)
    varname = inputname(1);
    obj = rootname;
    rootname = varname;
else
    varname = inputname(2);
end

if (length(varargin) == 1 && (ischar(varargin{1}) || isa(varargin{1}, 'string')))
    opt = struct('filename', varargin{1});
else
    opt = varargin2struct(varargin{:});
end

opt.isoctave = isoctavemesh;
opt.indent = jsonopt('Indent', 2, opt);
opt.flowstyle = jsonopt('FlowStyle', 0, opt);
opt.multidocument = jsonopt('MultiDocument', 0, opt);
opt.floatformat = jsonopt('FloatFormat', '%.10g', opt);
opt.intformat = jsonopt('IntFormat', '%.0f', opt);
opt.parselogical = jsonopt('ParseLogical', 1, opt);
opt.singletarray = jsonopt('SingletArray', 0, opt);
opt.unpackhex = jsonopt('UnpackHex', 1, opt);
opt.indent_base = repmat(' ', 1, opt.indent);

rootisarray = 0;
rootlevel = 0;
forceroot = jsonopt('ForceRootName', 0, opt);

if (jsonopt('PreEncode', 1, opt))
    obj = jdataencode(obj, 'Base64', 1, 'UseArrayZipSize', 0, opt);
end

if ((isnumeric(obj) || islogical(obj) || ischar(obj) || isstruct(obj) || ...
     iscell(obj) || isobject(obj)) && isempty(rootname) && forceroot == 0)
    rootisarray = 1;
else
    if (isempty(rootname))
        rootname = varname;
    end
end

if ((isstruct(obj) || iscell(obj)) && isempty(rootname) && forceroot)
    rootname = 'root';
end

% Handle multi-document YAML
if (opt.multidocument && iscell(obj))
    yamldocs = cell(1, numel(obj));
    for i = 1:numel(obj)
        yamldocs{i} = obj2yaml('', obj{i}, rootlevel, opt);
    end
    yaml = ['---', sprintf('\n'), strjoin(yamldocs, [sprintf('\n'), '---', sprintf('\n')])];
else
    yaml = obj2yaml(rootname, obj, rootlevel, opt);
end

% Save to file if FileName is set
filename = jsonopt('FileName', '', opt);
if (~isempty(filename))
    encoding = jsonopt('Encoding', '', opt);
    endian = jsonopt('Endian', 'n', opt);
    if (isempty(encoding))
        fid = fopen(filename, 'wt', endian);
    else
        fid = fopen(filename, 'wt', endian, encoding);
    end
    fwrite(fid, yaml, 'char');
    fclose(fid);
end

if (nargout > 0 || isempty(filename))
    output = yaml;
end

%% -------------------------------------------------------------------------
function txt = obj2yaml(name, item, level, opt)

if (iscell(item) || (isa(item, 'string') && numel(item) > 1))
    txt = cell2yaml(name, item, level, opt);
elseif (isstruct(item))
    txt = struct2yaml(name, item, level, opt);
elseif (isnumeric(item) || islogical(item))
    txt = mat2yaml(name, item, level, opt);
elseif (ischar(item))
    txt = str2yaml(name, item, level, opt);
elseif (isa(item, 'function_handle'))
    txt = struct2yaml(name, functions(item), level, opt);
elseif (isa(item, 'containers.Map') || isa(item, 'dictionary'))
    txt = map2yaml(name, item, level, opt);
elseif (isa(item, 'categorical'))
    txt = cell2yaml(name, cellstr(item), level, opt);
elseif (isobject(item))
    txt = matlabobject2yaml(name, item, level, opt);
else
    txt = any2yaml(name, item, level, opt);
end

%% -------------------------------------------------------------------------
function txt = cell2yaml(name, item, level, opt)
if (~iscell(item) && ~isa(item, 'string'))
    error('input is not a cell or string array');
end

len = numel(item);
indent_str = repmat(' ', 1, level * opt.indent);
nl = sprintf('\n');

if (len == 0)
    if (~isempty(name))
        txt = [indent_str, decodevarname(name, opt.unpackhex), ': []'];
    else
        txt = [indent_str, '[]'];
    end
    return
end

listlevel = level;
if (~isempty(name))
    listlevel = level + 1;
end
listindent = repmat(' ', 1, listlevel * opt.indent);

lines = {};
if (~isempty(name))
    lines{end + 1} = [indent_str, decodevarname(name, opt.unpackhex), ':'];
end

for i = 1:len
    lineitem = obj2yaml('', item{i}, listlevel, opt);
    itemlines = regexp(lineitem, '\r?\n', 'split');

    firstline = strtrim(itemlines{1});
    if isempty(firstline)
        lines{end + 1} = [listindent, '-'];
    else
        lines{end + 1} = [listindent, '- ', firstline];
    end

    for j = 2:length(itemlines)
        origline = itemlines{j};
        if ~isempty(origline)
            stripped = strtrim(origline);
            if ~isempty(stripped)
                origspaces = length(origline) - length(stripped);
                newspaces = origspaces + 2;
                lines{end + 1} = [repmat(' ', 1, newspaces), stripped];
            end
        end
    end
end

txt = strjoin(lines, nl);

%% -------------------------------------------------------------------------
function txt = struct2yaml(name, item, level, opt)
if (~isstruct(item))
    error('input is not a struct');
end

len = numel(item);
indent_str = repmat(' ', 1, level * opt.indent);
nl = sprintf('\n');

if (isempty(item))
    if (~isempty(name))
        txt = [indent_str, decodevarname(name, opt.unpackhex), ': {}'];
    else
        txt = [indent_str, '{}'];
    end
    return
end

if (len > 1)
    % Array of structs - represent as list
    if (~isempty(name))
        header = [indent_str, decodevarname(name, opt.unpackhex), ':'];
        listindent = (level + 1) * opt.indent;
    else
        header = '';
        listindent = level * opt.indent;
    end

    listpad = repmat(' ', 1, listindent);

    names = fieldnames(item(1));
    numfields = length(names);

    lines = {};
    if ~isempty(header)
        lines{end + 1} = header;
    end

    for i = 1:len
        % First field with list marker
        firstfieldname = names{1};
        firstval = item(i).(firstfieldname);
        firstlevel = (listindent / opt.indent) + 1;
        [firstvalstr, iscomplex] = formatFieldValue(firstval, firstlevel, opt);

        if iscomplex
            % Complex value needs to go on next line
            lines{end + 1} = [listpad, '- ', firstfieldname, ':'];
            % Add the complex value lines with proper indentation
            lines{end + 1} = firstvalstr;
        else
            lines{end + 1} = [listpad, '- ', firstfieldname, ': ', firstvalstr];
        end

        % Remaining fields
        fieldpad = repmat(' ', 1, listindent + opt.indent);
        for e = 2:numfields
            fieldname = names{e};
            fieldval = item(i).(fieldname);
            fieldlevel = (listindent / opt.indent) + 2;
            [fieldvalstr, iscomplex] = formatFieldValue(fieldval, fieldlevel, opt);

            if iscomplex
                lines{end + 1} = [fieldpad, fieldname, ':'];
                lines{end + 1} = fieldvalstr;
            else
                lines{end + 1} = [fieldpad, fieldname, ': ', fieldvalstr];
            end
        end
    end
    txt = strjoin(lines, nl);
else
    % Single struct
    names = fieldnames(item);
    numfields = length(names);
    if (~isempty(name))
        lines = cell(1, numfields + 1);
        lines{1} = [indent_str, decodevarname(name, opt.unpackhex), ':'];
        for e = 1:numfields
            lines{e + 1} = obj2yaml(names{e}, item.(names{e}), level + 1, opt);
        end
        txt = strjoin(lines, nl);
    else
        lines = cell(1, numfields);
        for e = 1:numfields
            lines{e} = obj2yaml(names{e}, item.(names{e}), level, opt);
        end
        txt = strjoin(lines, nl);
    end
end

%% -------------------------------------------------------------------------
function [valstr, iscomplex] = formatFieldValue(val, level, opt)
% Format a field value, returning whether it's complex (needs own line)
% level is the indentation level (not spaces, but level number)
iscomplex = false;

if isempty(val)
    if iscell(val)
        valstr = '[]';
    elseif isstruct(val)
        valstr = '{}';
    else
        valstr = 'null';
    end
elseif isstruct(val)
    if numel(val) >= 1
        % Struct or struct array - complex, needs its own lines
        iscomplex = true;
        valstr = obj2yaml('', val, level, opt);
    else
        valstr = '{}';
    end
elseif iscell(val)
    if numel(val) == 0
        valstr = '[]';
    else
        % Non-empty cell - complex
        iscomplex = true;
        valstr = obj2yaml('', val, level, opt);
    end
elseif isnumeric(val) || islogical(val)
    if numel(val) == 0
        valstr = 'null';
    elseif numel(val) == 1
        valstr = formatScalar(val, opt);
    else
        % Array - use flow style
        valstr = formatFlowArray(val, opt);
    end
elseif ischar(val)
    valstr = formatString(val);
else
    valstr = 'null';
end

%% -------------------------------------------------------------------------
function valstr = formatScalar(val, opt)
if islogical(val) && opt.parselogical
    if val
        valstr = 'true';
    else
        valstr = 'false';
    end
elseif isinf(val)
    if val > 0
        valstr = '.inf';
    else
        valstr = '-.inf';
    end
elseif isnan(val)
    valstr = '.nan';
elseif isinteger(val)
    valstr = sprintf(opt.intformat, val);
else
    valstr = sprintf(opt.floatformat, val);
end

%% -------------------------------------------------------------------------
function valstr = formatFlowArray(val, opt)
% Format numeric array in flow style [a, b, c]
if isinteger(val)
    fmtstr = opt.intformat;
else
    fmtstr = opt.floatformat;
end

if isvector(val)
    vals = cell(1, numel(val));
    for i = 1:numel(val)
        vals{i} = sprintf(fmtstr, val(i));
    end
    valstr = ['[', strjoin(vals, ', '), ']'];
else
    % Matrix - format as nested arrays
    rows = cell(1, size(val, 1));
    for i = 1:size(val, 1)
        rowvals = cell(1, size(val, 2));
        for j = 1:size(val, 2)
            rowvals{j} = sprintf(fmtstr, val(i, j));
        end
        rows{i} = ['[', strjoin(rowvals, ', '), ']'];
    end
    valstr = ['[', strjoin(rows, ', '), ']'];
end

%% -------------------------------------------------------------------------
function valstr = formatString(str)
str = strtrim(str);
need_quotes = false;

if ~isempty(str)
    c1 = str(1);
    if c1 == '[' || c1 == '{' || c1 == '>' || c1 == '|' || c1 == '!' || ...
       c1 == '&' || c1 == '*' || c1 == '''' || c1 == '"'
        need_quotes = true;
    elseif any(str == ' ' | str == ':' | str == '#' | str == '[' | str == ']' | ...
               str == '{' | str == '}' | str == ',' | str == '"' | str == '''')
        need_quotes = true;
    else
        strl = lower(str);
        if strcmp(strl, 'true') || strcmp(strl, 'false') || strcmp(strl, 'null') || ...
           strcmp(strl, 'yes') || strcmp(strl, 'no') || strcmp(strl, 'on') || strcmp(strl, 'off')
            need_quotes = true;
        elseif lookslikenumber(str)
            need_quotes = true;
        end
    end
end

if need_quotes
    valstr = ['"', escapeyamlstring(str), '"'];
else
    valstr = str;
end

%% -------------------------------------------------------------------------
function txt = map2yaml(name, item, level, opt)
itemtype = isa(item, 'containers.Map');
if (isa(item, 'dictionary'))
    itemtype = 2;
end
if (itemtype == 0)
    error('input is not a containers.Map or dictionary class');
end

names = keys(item);
val = values(item);

if (~iscell(names))
    names = num2cell(names);
end
if (~iscell(val))
    val = num2cell(val);
end

indent_str = repmat(' ', 1, level * opt.indent);
nl = sprintf('\n');

if (isempty(item))
    if (~isempty(name))
        txt = [indent_str, name, ': {}'];
    else
        txt = [indent_str, '{}'];
    end
    return
end

numkeys = length(names);
if (~isempty(name))
    lines = cell(1, numkeys + 1);
    lines{1} = [indent_str, decodevarname(name, opt.unpackhex), ':'];
    for i = 1:numkeys
        if (ischar(names{i}))
            lines{i + 1} = obj2yaml(names{i}, val{i}, level + 1, opt);
        else
            lines{i + 1} = obj2yaml(num2str(names{i}), val{i}, level + 1, opt);
        end
    end
    txt = strjoin(lines, nl);
else
    lines = cell(1, numkeys);
    for i = 1:numkeys
        if (ischar(names{i}))
            lines{i} = obj2yaml(names{i}, val{i}, level, opt);
        else
            lines{i} = obj2yaml(num2str(names{i}), val{i}, level, opt);
        end
    end
    txt = strjoin(lines, nl);
end

%% -------------------------------------------------------------------------
function txt = str2yaml(name, item, level, opt)
if (~ischar(item))
    error('input is not a string');
end

indent_str = repmat(' ', 1, level * opt.indent);
nl = sprintf('\n');

nrows = size(item, 1);
if (nrows > 1)
    indent2 = [indent_str, '  '];
    if (~isempty(name))
        lines = cell(1, nrows + 1);
        lines{1} = [indent_str, decodevarname(name, opt.unpackhex), ': |'];
        for i = 1:nrows
            lines{i + 1} = [indent2, strtrim(item(i, :))];
        end
        txt = strjoin(lines, nl);
    else
        lines = cell(1, nrows + 1);
        lines{1} = [indent_str, '|'];
        for i = 1:nrows
            lines{i + 1} = [indent2, strtrim(item(i, :))];
        end
        txt = strjoin(lines, nl);
    end
else
    item = strtrim(item);
    need_quotes = false;
    if ~isempty(item)
        c1 = item(1);
        if c1 == '[' || c1 == '{' || c1 == '>' || c1 == '|' || c1 == '!' || c1 == '&' || c1 == '*'
            need_quotes = true;
        elseif any(item == ' ')
            need_quotes = true;
        elseif any(item == ':' | item == '#' | item == '[' | item == ']' | ...
                   item == '{' | item == '}' | item == ',' | item == '&' | ...
                   item == '*' | item == '!' | item == '|' | item == '>' | ...
                   item == '''' | item == '"' | item == '%' | item == '@' | ...
                   item == 10 | item == 13 | item == 9)
            need_quotes = true;
        else
            iteml = lower(item);
            if strcmp(iteml, 'true') || strcmp(iteml, 'false') || strcmp(iteml, 'null') || ...
               strcmp(iteml, 'yes') || strcmp(iteml, 'no') || strcmp(iteml, 'on') || strcmp(iteml, 'off')
                need_quotes = true;
            elseif lookslikenumber(item)
                need_quotes = true;
            end
        end
    end

    if (need_quotes)
        item = escapeyamlstring(item);
        item = ['"', item, '"'];
    end

    if (~isempty(name))
        txt = [indent_str, decodevarname(name, opt.unpackhex), ': ', item];
    else
        txt = [indent_str, item];
    end
end

%% -------------------------------------------------------------------------
function tf = lookslikenumber(s)
if isempty(s)
    tf = false;
    return
end

c = s(1);
if ~((c >= '0' && c <= '9') || c == '+' || c == '-' || c == '.' || c == 'i' || c == 'I' || c == 'n' || c == 'N')
    tf = false;
    return
end

len = length(s);
if len <= 4
    sl = lower(s);
    if strcmp(sl, '.inf') || strcmp(sl, '.nan') || strcmp(sl, 'inf') || strcmp(sl, 'nan')
        tf = true;
        return
    end
end
if len <= 5
    sl = lower(s);
    if strcmp(sl, '-.inf') || strcmp(sl, '+.inf') || strcmp(sl, '-inf') || strcmp(sl, '+inf')
        tf = true;
        return
    end
end

numpattern = '^[+-]?((\d+\.?\d*|\d*\.\d+)([eE][+-]?\d+)?|0[xX][0-9a-fA-F]+)$';
tf = ~isempty(regexp(s, numpattern, 'once'));

%% -------------------------------------------------------------------------
function txt = mat2yaml(name, item, level, opt)
if (~isnumeric(item) && ~islogical(item))
    error('input is not an array');
end

indent_str = repmat(' ', 1, level * opt.indent);
nl = sprintf('\n');

if (isempty(item))
    emptyasnull = jsonopt('EmptyArrayAsNull', 0, opt);
    if (emptyasnull)
        valstr = 'null';
    else
        valstr = '[]';
    end

    if (~isempty(name))
        txt = [indent_str, decodevarname(name, opt.unpackhex), ': ', valstr];
    else
        txt = [indent_str, valstr];
    end
    return
end

if (islogical(item) && opt.parselogical)
    if (numel(item) == 1)
        if (item)
            valstr = 'true';
        else
            valstr = 'false';
        end
        if (~isempty(name))
            txt = [indent_str, decodevarname(name, opt.unpackhex), ': ', valstr];
        else
            txt = [indent_str, valstr];
        end
        return
    end
end

if (numel(item) == 1)
    if (isinf(item))
        if (item > 0)
            valstr = '.inf';
        else
            valstr = '-.inf';
        end
    elseif (isnan(item))
        valstr = '.nan';
    elseif (isinteger(item))
        valstr = sprintf(opt.intformat, item);
    else
        valstr = sprintf(opt.floatformat, item);
    end

    if (~isempty(name))
        txt = [indent_str, decodevarname(name, opt.unpackhex), ': ', valstr];
    else
        txt = [indent_str, valstr];
    end
    return
end

if (isinteger(item))
    fmtstr = opt.intformat;
else
    fmtstr = opt.floatformat;
end
fmtstr_sep = [fmtstr, ', '];

if (isvector(item))
    if (size(item, 1) == 1)
        % Row vector - use flow style
        if length(item) > 1
            valstr = ['[', sprintf(fmtstr_sep, item(1:end - 1)), sprintf(fmtstr, item(end)), ']'];
        else
            valstr = ['[', sprintf(fmtstr, item(1)), ']'];
        end

        if (~isempty(name))
            txt = [indent_str, decodevarname(name, opt.unpackhex), ': ', valstr];
        else
            txt = [indent_str, valstr];
        end
    else
        % Column vector - use list style
        n = length(item);
        if (~isempty(name))
            lines = cell(1, n + 1);
            lines{1} = [indent_str, decodevarname(name, opt.unpackhex), ':'];
            nextpad = repmat(' ', 1, (level + 1) * opt.indent);
            for i = 1:n
                lines{i + 1} = [nextpad, '- [', sprintf(fmtstr, item(i)), ']'];
            end
        else
            lines = cell(1, n);
            nextpad = repmat(' ', 1, level * opt.indent);
            for i = 1:n
                lines{i} = [nextpad, '- [', sprintf(fmtstr, item(i)), ']'];
            end
        end
        txt = strjoin(lines, nl);
    end
else
    nrows = size(item, 1);
    ncols = size(item, 2);
    if (~isempty(name))
        lines = cell(1, nrows + 1);
        lines{1} = [indent_str, decodevarname(name, opt.unpackhex), ':'];
        nextpad = repmat(' ', 1, (level + 1) * opt.indent);
        for i = 1:nrows
            row = item(i, :);
            if ncols > 1
                rowstr = ['[', sprintf(fmtstr_sep, row(1:end - 1)), sprintf(fmtstr, row(end)), ']'];
            else
                rowstr = ['[', sprintf(fmtstr, row(1)), ']'];
            end
            lines{i + 1} = [nextpad, '- ', rowstr];
        end
    else
        lines = cell(1, nrows);
        nextpad = repmat(' ', 1, level * opt.indent);
        for i = 1:nrows
            row = item(i, :);
            if ncols > 1
                rowstr = ['[', sprintf(fmtstr_sep, row(1:end - 1)), sprintf(fmtstr, row(end)), ']'];
            else
                rowstr = ['[', sprintf(fmtstr, row(1)), ']'];
            end
            lines{i} = [nextpad, '- ', rowstr];
        end
    end
    txt = strjoin(lines, nl);
end

%% -------------------------------------------------------------------------
function txt = matlabobject2yaml(name, item, level, opt)
try
    if numel(item) == 0
        st = struct();
    else
        propertynames = properties(item);
        for p = 1:numel(propertynames)
            for o = numel(item):-1:1
                st(o).(propertynames{p}) = item(o).(propertynames{p});
            end
        end
    end
    txt = struct2yaml(name, st, level, opt);
catch
    txt = any2yaml(name, item, level, opt);
end

%% -------------------------------------------------------------------------
function txt = any2yaml(name, item, level, opt)
indent_str = repmat(' ', 1, level * opt.indent);
txt = [indent_str, name, ': "unsupported type: ', class(item), '"'];

%% -------------------------------------------------------------------------
function newstr = escapeyamlstring(str)
newstr = str;
if (isempty(str))
    return
end

bytes = uint8(str);
if ~any(bytes == 92 | bytes == 34 | bytes < 32)
    return
end

newstr = strrep(newstr, '\', '\\');
newstr = strrep(newstr, '"', '\"');
newstr = strrep(newstr, sprintf('\n'), '\n');
newstr = strrep(newstr, sprintf('\r'), '\r');
newstr = strrep(newstr, sprintf('\t'), '\t');
