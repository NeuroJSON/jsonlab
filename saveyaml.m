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
%           Most options from savejson are supported (see savejson help)
%
%           MultiDocument [0|1]: if set to 1 and obj is a cell array,
%                         save each cell element as a separate YAML document
%                         separated by '---'
%           Indent [2|integer]: number of spaces for indentation
%           FlowStyle [0|1]: if 1, use flow style for arrays/objects
%           FloatFormat ['%.10g'|string]: format for floating point numbers
%           EmptyArrayAsNull [0|1]: if 1, output empty arrays as null
%
% output:
%      yaml: a string in YAML format
%
% examples:
%      data=struct('name','test','values',[1 2 3]);
%      saveyaml('',data)
%      saveyaml('data',data,'output.yaml')
%
% license:
%     BSD or GPL version 3, see LICENSE_{BSD,GPLv3}.txt files for details
%
% -- this function is part of JSONLab toolbox (http://iso2mesh.sf.net/cgi-bin/index.cgi?jsonlab)
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
    yaml = ['---' sprintf('\n') joinlines(yamldocs, [sprintf('\n') '---' sprintf('\n')])];
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
function txt = obj2yaml(name, item, level, varargin)

if (iscell(item) || (isa(item, 'string') && numel(item) > 1))
    txt = cell2yaml(name, item, level, varargin{:});
elseif (isa(item, 'jdict'))
    txt = obj2yaml(name, item, level, varargin{:});
elseif (isstruct(item))
    txt = struct2yaml(name, item, level, varargin{:});
elseif (isnumeric(item) || islogical(item))
    txt = mat2yaml(name, item, level, varargin{:});
elseif (ischar(item))
    txt = str2yaml(name, item, level, varargin{:});
elseif (isa(item, 'function_handle'))
    txt = struct2yaml(name, functions(item), level, varargin{:});
elseif (isa(item, 'containers.Map') || isa(item, 'dictionary'))
    txt = map2yaml(name, item, level, varargin{:});
elseif (isa(item, 'categorical'))
    txt = cell2yaml(name, cellstr(item), level, varargin{:});
elseif (isobject(item))
    txt = matlabobject2yaml(name, item, level, varargin{:});
else
    txt = any2yaml(name, item, level, varargin{:});
end

%% -------------------------------------------------------------------------
function txt = cell2yaml(name, item, level, varargin)
if (~iscell(item) && ~isa(item, 'string'))
    error('input is not a cell or string array');
end

dim = size(item);
len = numel(item);
opt = varargin{1};
indent_str = repmat(' ', 1, level * opt.indent);

if (len == 0)
    if (~isempty(name))
        txt = sprintf('%s%s: []', indent_str, name);
    else
        txt = sprintf('%s[]', indent_str);
    end
    return
end

if (~isempty(name))
    txt = sprintf('%s%s:', indent_str, name);
    lines = cell(1, len);
    for i = 1:len
        lines{i} = obj2yaml('', item{i}, level + 1, varargin{:});
        if (isempty(regexp(strtrim(lines{i}), '^-', 'once')))
            lines{i} = sprintf('%s- %s', repmat(' ', 1, (level + 1) * opt.indent), strtrim(lines{i}));
        end
    end
    txt = sprintf('%s\n%s', txt, joinlines(lines, sprintf('\n')));
else
    lines = cell(1, len);
    for i = 1:len
        lines{i} = obj2yaml('', item{i}, level, varargin{:});
        if (isempty(regexp(strtrim(lines{i}), '^-', 'once')))
            lines{i} = sprintf('%s- %s', repmat(' ', 1, level * opt.indent), strtrim(lines{i}));
        end
    end
    txt = joinlines(lines, sprintf('\n'));
end

%% -------------------------------------------------------------------------
function txt = struct2yaml(name, item, level, varargin)
if (~isstruct(item))
    error('input is not a struct');
end

dim = size(item);
len = numel(item);
opt = varargin{1};
indent_str = repmat(' ', 1, level * opt.indent);

if (isempty(item))
    if (~isempty(name))
        txt = sprintf('%s%s: {}', indent_str, name);
    else
        txt = sprintf('%s{}', indent_str);
    end
    return
end

if (len > 1)
    % Array of structs - represent as compact list
    if (~isempty(name))
        txt = sprintf('%s%s:', indent_str, decodevarname(name, opt.unpackhex));
        listindent = (level + 1) * opt.indent;
    else
        txt = '';
        listindent = level * opt.indent;
    end

    for i = 1:len
        names = fieldnames(item(i));

        % Add list marker with first field on same line
        if (i > 1 || ~isempty(name))
            txt = sprintf('%s\n%s- %s: ', txt, repmat(' ', 1, listindent), names{1});
        else
            txt = sprintf('%s- %s: ', repmat(' ', 1, listindent), names{1});
        end

        % Format first field value inline
        firstval = item(i).(names{1});
        txt = sprintf('%s%s', txt, formatSimpleValue(firstval, opt));

        % Add remaining fields with proper indentation
        for e = 2:length(names)
            fieldval = item(i).(names{e});
            txt = sprintf('%s\n%s%s: %s', txt, repmat(' ', 1, listindent + opt.indent), ...
                          names{e}, formatSimpleValue(fieldval, opt));
        end
    end
else
    % Single struct
    names = fieldnames(item);
    if (~isempty(name))
        txt = sprintf('%s%s:', indent_str, decodevarname(name, opt.unpackhex));
        lines = cell(1, length(names));
        for e = 1:length(names)
            lines{e} = obj2yaml(names{e}, item.(names{e}), level + 1, varargin{:});
        end
        txt = sprintf('%s\n%s', txt, joinlines(lines, sprintf('\n')));
    else
        lines = cell(1, length(names));
        for e = 1:length(names)
            lines{e} = obj2yaml(names{e}, item.(names{e}), level, varargin{:});
        end
        txt = joinlines(lines, sprintf('\n'));
    end
end

%% -------------------------------------------------------------------------
function txt = map2yaml(name, item, level, varargin)
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

opt = varargin{1};
indent_str = repmat(' ', 1, level * opt.indent);

if (isempty(item))
    if (~isempty(name))
        txt = sprintf('%s%s: {}', indent_str, name);
    else
        txt = sprintf('%s{}', indent_str);
    end
    return
end

if (~isempty(name))
    txt = sprintf('%s%s:', indent_str, decodevarname(name, opt.unpackhex));
    lines = cell(1, length(names));
    for i = 1:length(names)
        if (ischar(names{i}))
            lines{i} = obj2yaml(names{i}, val{i}, level + 1, varargin{:});
        else
            lines{i} = obj2yaml(num2str(names{i}), val{i}, level + 1, varargin{:});
        end
    end
    txt = sprintf('%s\n%s', txt, joinlines(lines, sprintf('\n')));
else
    lines = cell(1, length(names));
    for i = 1:length(names)
        if (ischar(names{i}))
            lines{i} = obj2yaml(names{i}, val{i}, level, varargin{:});
        else
            lines{i} = obj2yaml(num2str(names{i}), val{i}, level, varargin{:});
        end
    end
    txt = joinlines(lines, sprintf('\n'));
end

%% -------------------------------------------------------------------------
function txt = str2yaml(name, item, level, varargin)
if (~ischar(item))
    error('input is not a string');
end

opt = varargin{1};
indent_str = repmat(' ', 1, level * opt.indent);

% Handle multiline strings (char arrays with multiple rows)
if (size(item, 1) > 1)
    if (~isempty(name))
        txt = sprintf('%s%s: |', indent_str, decodevarname(name, opt.unpackhex));
        for i = 1:size(item, 1)
            txt = sprintf('%s\n%s  %s', txt, indent_str, strtrim(item(i, :)));
        end
    else
        txt = sprintf('%s|', indent_str);
        for i = 1:size(item, 1)
            txt = sprintf('%s\n%s  %s', txt, indent_str, strtrim(item(i, :)));
        end
    end
else
    % Single line string
    item = strtrim(item);

    % Determine if quotes are needed
    need_quotes = false;
    if ~isempty(item)
        % Check for special YAML characters that require quoting
        if ~isempty(regexp(item, '[\[\]{}:,#@&*!|>''"%]', 'once'))
            need_quotes = true;
            % Check for reserved words
        elseif strcmpi(item, 'true') || strcmpi(item, 'false') || strcmpi(item, 'null')
            need_quotes = true;
            % Check if it could be parsed as a number
        elseif ~isempty(str2num(item))
            need_quotes = true;
            % Check if string contains spaces
        elseif ~isempty(strfind(item, ' '))
            need_quotes = true;
        end
    end

    if (need_quotes)
        item = escapeyamlstring(item);
        item = ['"' item '"'];
    end

    if (~isempty(name))
        txt = sprintf('%s%s: %s', indent_str, decodevarname(name, opt.unpackhex), item);
    else
        txt = sprintf('%s%s', indent_str, item);
    end
end

%% -------------------------------------------------------------------------
function txt = mat2yaml(name, item, level, varargin)
if (~isnumeric(item) && ~islogical(item))
    error('input is not an array');
end

opt = varargin{1};
indent_str = repmat(' ', 1, level * opt.indent);

if (isempty(item))
    emptyasnull = jsonopt('EmptyArrayAsNull', 0, opt);
    if (emptyasnull)
        valstr = 'null';
    else
        valstr = '[]';
    end

    if (~isempty(name))
        txt = sprintf('%s%s: %s', indent_str, decodevarname(name, opt.unpackhex), valstr);
    else
        txt = sprintf('%s%s', indent_str, valstr);
    end
    return
end

% Format numbers
if (islogical(item) && opt.parselogical)
    if (numel(item) == 1)
        if (item)
            valstr = 'true';
        else
            valstr = 'false';
        end
        if (~isempty(name))
            txt = sprintf('%s%s: %s', indent_str, decodevarname(name, opt.unpackhex), valstr);
        else
            txt = sprintf('%s%s', indent_str, valstr);
        end
        return
    end
end

% Handle scalar
if (numel(item) == 1)
    if (isinteger(item))
        valstr = sprintf(opt.intformat, item);
    else
        valstr = sprintf(opt.floatformat, item);
    end

    if (isinf(item))
        if (item > 0)
            valstr = '.inf';
        else
            valstr = '-.inf';
        end
    elseif (isnan(item))
        valstr = '.nan';
    end

    if (~isempty(name))
        txt = sprintf('%s%s: %s', indent_str, decodevarname(name, opt.unpackhex), valstr);
    else
        txt = sprintf('%s%s', indent_str, valstr);
    end
    return
end

% Handle vectors and matrices
if (isvector(item))
    % Check if row or column vector
    if (size(item, 1) == 1)
        % Row vector - use flow style
        if (isinteger(item))
            formatstr = opt.intformat;
        else
            formatstr = opt.floatformat;
        end

        valstr = ['[' sprintf([formatstr ', '], item(1:end - 1)) sprintf(formatstr, item(end)) ']'];

        if (~isempty(name))
            txt = sprintf('%s%s: %s', indent_str, decodevarname(name, opt.unpackhex), valstr);
        else
            txt = sprintf('%s%s', indent_str, valstr);
        end
    else
        % Column vector - use list style with single-element arrays
        if (~isempty(name))
            txt = sprintf('%s%s:', indent_str, decodevarname(name, opt.unpackhex));
        else
            txt = '';
        end

        if (isinteger(item))
            formatstr = opt.intformat;
        else
            formatstr = opt.floatformat;
        end

        for i = 1:length(item)
            valstr = ['[' sprintf(formatstr, item(i)) ']'];
            if (~isempty(name))
                txt = sprintf('%s\n%s- %s', txt, repmat(' ', 1, (level + 1) * opt.indent), valstr);
            else
                txt = sprintf('%s\n%s- %s', txt, repmat(' ', 1, level * opt.indent), valstr);
            end
        end
    end
else
    % 2D or higher - use nested lists
    if (~isempty(name))
        txt = sprintf('%s%s:', indent_str, decodevarname(name, opt.unpackhex));
    else
        txt = '';
    end

    for i = 1:size(item, 1)
        row = item(i, :);
        if (isinteger(row))
            formatstr = opt.intformat;
        else
            formatstr = opt.floatformat;
        end
        rowstr = ['[' sprintf([formatstr ', '], row(1:end - 1)) sprintf(formatstr, row(end)) ']'];

        if (~isempty(name))
            txt = sprintf('%s\n%s- %s', txt, repmat(' ', 1, (level + 1) * opt.indent), rowstr);
        else
            txt = sprintf('%s\n%s- %s', txt, repmat(' ', 1, level * opt.indent), rowstr);
        end
    end
end

%% -------------------------------------------------------------------------
function txt = matlabobject2yaml(name, item, level, varargin)
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
    txt = struct2yaml(name, st, level, varargin{:});
catch
    txt = any2yaml(name, item, level, varargin{:});
end

%% -------------------------------------------------------------------------
function txt = any2yaml(name, item, level, varargin)
opt = varargin{1};
indent_str = repmat(' ', 1, level * opt.indent);
txt = sprintf('%s%s: "unsupported type: %s"', indent_str, name, class(item));

%% -------------------------------------------------------------------------
function newstr = escapeyamlstring(str)
newstr = str;
if (isempty(str))
    return
end
% Escape special characters for YAML double-quoted strings
newstr = strrep(newstr, '\', '\\');
newstr = strrep(newstr, '"', '\"');
newstr = strrep(newstr, sprintf('\n'), '\n');
newstr = strrep(newstr, sprintf('\r'), '\r');
newstr = strrep(newstr, sprintf('\t'), '\t');

%% -------------------------------------------------------------------------
function valstr = formatSimpleValue(val, opt)
% Format simple scalar values (used in struct arrays)

if (isnumeric(val) && isscalar(val))
    if (isinteger(val))
        valstr = sprintf(opt.intformat, val);
    else
        valstr = sprintf(opt.floatformat, val);
    end
elseif (ischar(val))
    valstr = val;
    % Check if quotes are needed
    if (~isempty(strfind(valstr, ' ')) || ~isempty(regexp(valstr, '[\[\]{}:,#@&*!|>''"%]', 'once')) || ...
        strcmpi(valstr, 'true') || strcmpi(valstr, 'false') || strcmpi(valstr, 'null') || ~isempty(str2num(valstr)))
        valstr = ['"' strrep(valstr, '"', '\"') '"'];
    end
elseif (islogical(val) && opt.parselogical)
    if (val)
        valstr = 'true';
    else
        valstr = 'false';
    end
else
    valstr = 'null';
end

%% -------------------------------------------------------------------------

function str = joinlines(lines, sep)

str = [sprintf(['%s' sep], lines{1:end - 1}) lines{end}];
