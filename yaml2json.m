function jsonstr = yaml2json(yamlstr)
% Convert YAML to JSON
%
% jsonstr = yaml2json(yamlstr)
%
% license:
%     BSD or GPL version 3, see LICENSE_{BSD,GPLv3}.txt files for details
%
% -- this function is part of JSONLab toolbox (http://neurojson.org/jsonlab)
%

lines = regexp(yamlstr, '\r?\n', 'split');

% Find document separators
docstarts = [];
for i = 1:length(lines)
    if (strcmp(strtrim(lines{i}), '---'))
        docstarts = [docstarts i];
    end
end

if (isempty(docstarts))
    jsonstr = line2json(lines);
else
    documents = {};
    docstarts = [docstarts length(lines) + 1];
    for i = 1:length(docstarts) - 1
        doclines = lines(docstarts(i) + 1:docstarts(i + 1) - 1);
        documents{end + 1} = line2json(doclines);
    end
    jsonstr = cell2str_join(documents, sprintf('\n'));
end

%% -------------------------------------------------------------------------
function result = cell2str_join(cellarray, delim)
% Join cell array of strings with delimiter (compatible with R2010)
if (isempty(cellarray))
    result = '';
    return
end
result = cellarray{1};
for i = 2:length(cellarray)
    result = [result, delim, cellarray{i}];
end

%% -------------------------------------------------------------------------
function jsonstr = line2json(lines)

items = {};
for i = 1:length(lines)
    line = lines{i};
    if (isempty(line))
        continue
    end

    trimmed = strtrim(line);
    if (isempty(trimmed) || trimmed(1) == '#')
        continue
    end

    % Calculate indent
    indent = 0;
    for j = 1:length(line)
        if (line(j) == ' ')
            indent = indent + 1;
        elseif (line(j) == char(9))
            indent = indent + 2;
        else
            break
        end
    end

    % Check if JSON literal at root
    if (isempty(items) && indent == 0 && (trimmed(1) == '[' || trimmed(1) == '{'))
        if (is_complete_json(trimmed))
            jsonstr = trimmed;
            return
        end
    end

    % Check for list item
    islist = false;
    contentindent = indent;
    if (length(trimmed) >= 1 && trimmed(1) == '-')
        if (length(trimmed) == 1)
            islist = true;
            trimmed = '';
            contentindent = indent + 2;
        elseif (length(trimmed) >= 2 && (trimmed(2) == ' ' || trimmed(2) == char(9)))
            islist = true;
            contentindent = indent + 2;
            trimmed = strtrim(trimmed(3:end));
        end
    end

    % Find key:value
    colonpos = find_colon(trimmed);
    if (colonpos > 0)
        key = strtrim(trimmed(1:colonpos - 1));
        value = strtrim(trimmed(colonpos + 1:end));
        value = remove_comment(value);
    else
        key = '';
        value = trimmed;
    end

    item = struct();
    item.indent = indent;
    item.contentindent = contentindent;
    item.islist = islist;
    item.key = key;
    item.value = value;
    items{end + 1} = item;
end

if (isempty(items))
    jsonstr = '{}';
    return
end

[jsonstr, nextidx_] = build_structure(items, 1, -1); %#ok<ASGLU>

%% -------------------------------------------------------------------------
function str = remove_comment(str)
indouble = false;
insingle = false;
i = 1;
while (i <= length(str))
    c = str(i);
    if (c == '\' && i < length(str))
        i = i + 2;
        continue
    elseif (c == '"' && ~insingle)
        indouble = ~indouble;
    elseif (c == '''' && ~indouble)
        insingle = ~insingle;
    elseif (c == '#' && ~indouble && ~insingle)
        str = strtrim(str(1:i - 1));
        return
    end
    i = i + 1;
end

%% -------------------------------------------------------------------------
function pos = find_colon(str)
pos = 0;
indouble = false;
insingle = false;
i = 1;
len = length(str);
while (i <= len)
    c = str(i);
    if (c == '\' && i < len)
        i = i + 2;
        continue
    elseif (c == '"' && ~insingle)
        indouble = ~indouble;
    elseif (c == '''' && ~indouble)
        insingle = ~insingle;
    elseif (c == ':' && ~indouble && ~insingle)
        if (i == len || str(i + 1) == ' ' || str(i + 1) == char(9))
            pos = i;
            return
        end
    end
    i = i + 1;
end

%% -------------------------------------------------------------------------
function [jsonstr, nextidx] = build_structure(items, startidx, minindent_) %#ok<INUSD>
if (startidx > length(items))
    jsonstr = 'null';
    nextidx = startidx;
    return
end

item = items{startidx};
if (item.islist)
    [jsonstr, nextidx] = build_array(items, startidx, item.indent);
else
    [jsonstr, nextidx] = build_object(items, startidx, item.indent);
end

%% -------------------------------------------------------------------------
function [jsonstr, nextidx] = build_array(items, startidx, baseindent)
parts = {};
idx = startidx;

while (idx <= length(items))
    item = items{idx};

    if (item.indent < baseindent)
        break
    end

    if (item.indent > baseindent)
        idx = idx + 1;
        continue
    end

    if (~item.islist)
        break
    end

    % Process this list item
    if (~isempty(item.key))
        [objjson, idx] = build_list_object(items, idx, baseindent);
        parts{end + 1} = objjson;
    elseif (~isempty(item.value))
        parts{end + 1} = val2json(item.value);
        idx = idx + 1;
    else
        idx = idx + 1;
        if (idx <= length(items) && items{idx}.indent > baseindent)
            [subjson, idx] = build_structure(items, idx, baseindent);
            parts{end + 1} = subjson;
        else
            parts{end + 1} = 'null';
        end
    end
end

if (isempty(parts))
    jsonstr = '[]';
else
    jsonstr = ['[' cell2str_join(parts, ',') ']'];
end
nextidx = idx;

%% -------------------------------------------------------------------------
function [jsonstr, nextidx] = build_list_object(items, startidx, listindent)
item = items{startidx};
objparts = {};
contentindent = item.contentindent;

key = item.key;
value = item.value;
idx = startidx + 1;

% Handle first key's value
if (isempty(value))
    if (idx <= length(items))
        nextitem = items{idx};
        % KEY CHECK: is next item a list at contentindent?
        if (nextitem.islist && nextitem.indent == contentindent)
            [subjson, idx] = build_array(items, idx, nextitem.indent);
            objparts{end + 1} = ['"' escape_key(key) '":' subjson];
        elseif (nextitem.indent > contentindent)
            [subjson, idx] = build_structure(items, idx, contentindent);
            objparts{end + 1} = ['"' escape_key(key) '":' subjson];
        elseif (nextitem.indent == contentindent && ~nextitem.islist && ~isempty(nextitem.key))
            objparts{end + 1} = ['"' escape_key(key) '":null'];
        else
            objparts{end + 1} = ['"' escape_key(key) '":null'];
        end
    else
        objparts{end + 1} = ['"' escape_key(key) '":null'];
    end
else
    objparts{end + 1} = ['"' escape_key(key) '":' val2json(value)];
end

% Collect remaining fields
while (idx <= length(items))
    nextitem = items{idx};

    if (nextitem.indent <= listindent)
        break
    end

    if (nextitem.islist && nextitem.indent <= listindent + 2)
        break
    end

    if (nextitem.indent == contentindent && ~nextitem.islist && ~isempty(nextitem.key))
        fkey = nextitem.key;
        fval = nextitem.value;

        if (isempty(fval))
            if (idx + 1 <= length(items))
                nextafter = items{idx + 1};
                if (nextafter.islist && nextafter.indent == contentindent)
                    [subjson, idx] = build_array(items, idx + 1, nextafter.indent);
                    objparts{end + 1} = ['"' escape_key(fkey) '":' subjson];
                elseif (nextafter.indent > contentindent)
                    [subjson, idx] = build_structure(items, idx + 1, contentindent);
                    objparts{end + 1} = ['"' escape_key(fkey) '":' subjson];
                else
                    objparts{end + 1} = ['"' escape_key(fkey) '":null'];
                    idx = idx + 1;
                end
            else
                objparts{end + 1} = ['"' escape_key(fkey) '":null'];
                idx = idx + 1;
            end
        else
            objparts{end + 1} = ['"' escape_key(fkey) '":' val2json(fval)];
            idx = idx + 1;
        end
    elseif (nextitem.indent > contentindent)
        idx = idx + 1;
    else
        break
    end
end

jsonstr = ['{' cell2str_join(objparts, ',') '}'];
nextidx = idx;

%% -------------------------------------------------------------------------
function [jsonstr, nextidx] = build_object(items, startidx, baseindent)
parts = {};
idx = startidx;

while (idx <= length(items))
    item = items{idx};

    if (item.indent < baseindent)
        break
    end

    if (item.islist && item.indent == baseindent)
        break
    end

    if (item.indent > baseindent)
        idx = idx + 1;
        continue
    end

    if (~item.islist && ~isempty(item.key))
        key = item.key;
        value = item.value;

        if (isempty(value))
            if (idx + 1 <= length(items) && items{idx + 1}.indent > baseindent)
                [subjson, idx] = build_structure(items, idx + 1, baseindent);
                parts{end + 1} = ['"' escape_key(key) '":' subjson];
            else
                parts{end + 1} = ['"' escape_key(key) '":null'];
                idx = idx + 1;
            end
        else
            parts{end + 1} = ['"' escape_key(key) '":' val2json(value)];
            idx = idx + 1;
        end
    else
        idx = idx + 1;
    end
end

if (isempty(parts))
    jsonstr = '{}';
else
    jsonstr = ['{' cell2str_join(parts, ',') '}'];
end
nextidx = idx;

%% -------------------------------------------------------------------------
function key = escape_key(str)
str = strtrim(str);
if (length(str) >= 2 && ((str(1) == '"' && str(end) == '"') || (str(1) == '''' && str(end) == '''')))
    str = str(2:end - 1);
end
key = strrep(str, '\', '\\');
key = strrep(key, '"', '\"');

%% -------------------------------------------------------------------------
function tf = is_complete_json(str)
len = length(str);
if (len < 2)
    tf = false;
    return
end
c1 = str(1);
cend = str(end);
if (~((c1 == '[' && cend == ']') || (c1 == '{' && cend == '}')))
    tf = false;
    return
end
depth = 0;
indouble = false;
for i = 1:len
    c = str(i);
    if (c == '\' && i < len)
        continue
    end
    if (c == '"' && ~indouble)
        indouble = true;
    elseif (c == '"' && indouble)
        indouble = false;
    elseif (~indouble)
        if (c == '[' || c == '{')
            depth = depth + 1;
        elseif (c == ']' || c == '}')
            depth = depth - 1;
        end
    end
end
tf = (depth == 0);

%% -------------------------------------------------------------------------
function val = val2json(str)
str = strtrim(str);

if (isempty(str))
    val = 'null';
    return
end
if (strcmp(str, '[]'))
    val = '[]';
    return
end
if (strcmp(str, '{}'))
    val = '{}';
    return
end

% Quoted string
if (length(str) >= 2)
    if (str(1) == '"' && str(end) == '"')
        inner = str(2:end - 1);
        inner = fix_json_escapes(inner);
        val = ['"' inner '"'];
        return
    elseif (str(1) == '''' && str(end) == '''')
        inner = str(2:end - 1);
        inner = escape_json_string(inner);
        val = ['"' inner '"'];
        return
    end
end

% Boolean/null
strl = lower(str);
if (strcmp(strl, 'true') || strcmp(strl, 'false'))
    val = strl;
    return
end
if (strcmp(strl, 'null') || strcmp(str, '~'))
    val = 'null';
    return
end
if (strcmp(strl, 'yes') || strcmp(strl, 'on'))
    val = 'true';
    return
end
if (strcmp(strl, 'no') || strcmp(strl, 'off'))
    val = 'false';
    return
end

% Special floats
if (strcmp(strl, '.inf') || strcmp(strl, '+.inf'))
    val = '1e999';
    return
end
if (strcmp(strl, '-.inf'))
    val = '-1e999';
    return
end
if (strcmp(strl, '.nan'))
    val = '"_NaN_"';
    return
end

% Inline array
if (str(1) == '[' && str(end) == ']')
    content = str(2:end - 1);
    if (isempty(strtrim(content)))
        val = '[]';
        return
    end
    arrItems = split_array(content);
    formatted = cell(1, length(arrItems));
    for i = 1:length(arrItems)
        formatted{i} = val2json(strtrim(arrItems{i}));
    end
    val = ['[' cell2str_join(formatted, ',') ']'];
    return
end

% Inline object
if (str(1) == '{' && str(end) == '}')
    val = str;
    return
end

% Numeric
if (~isempty(regexp(str, '^[+-]?(\d+\.?\d*|\d*\.\d+)([eE][+-]?\d+)?$', 'once')))
    val = str;
    return
end

% Hex
if (~isempty(regexp(str, '^0[xX][0-9a-fA-F]+$', 'once')))
    val = num2str(hex2dec(str(3:end)));
    return
end

% Default: string
escaped = escape_json_string(str);
val = ['"' escaped '"'];

%% -------------------------------------------------------------------------
function escaped = escape_json_string(str)
escaped = '';
i = 1;
len = length(str);
while (i <= len)
    c = str(i);
    if (c == '\')
        if (i < len)
            nc = str(i + 1);
            if (any(nc == '"\/')  || any(nc == 'bfnrt'))
                escaped = [escaped, c, nc];
                i = i + 2;
            elseif (nc == 'u' && i + 5 <= len)
                escaped = [escaped, str(i:i + 5)];
                i = i + 6;
            else
                escaped = [escaped, '\\'];
                i = i + 1;
            end
        else
            escaped = [escaped, '\\'];
            i = i + 1;
        end
    elseif (c == '"')
        escaped = [escaped, '\"'];
        i = i + 1;
    elseif (c == sprintf('\n'))
        escaped = [escaped, '\n'];
        i = i + 1;
    elseif (c == sprintf('\r'))
        escaped = [escaped, '\r'];
        i = i + 1;
    elseif (c == sprintf('\t'))
        escaped = [escaped, '\t'];
        i = i + 1;
    else
        escaped = [escaped, c];
        i = i + 1;
    end
end

%% -------------------------------------------------------------------------
function escaped = fix_json_escapes(str)
escaped = '';
i = 1;
len = length(str);
while (i <= len)
    c = str(i);
    if (c == '\')
        if (i < len)
            nc = str(i + 1);
            if (any(nc == '"\/')  || any(nc == 'bfnrt'))
                escaped = [escaped, c, nc];
                i = i + 2;
            elseif (nc == 'u' && i + 5 <= len)
                hex = str(i + 2:i + 5);
                if (all(isstrprop(hex, 'xdigit')))
                    escaped = [escaped, str(i:i + 5)];
                    i = i + 6;
                else
                    escaped = [escaped, '\\'];
                    i = i + 1;
                end
            else
                escaped = [escaped, '\\'];
                i = i + 1;
            end
        else
            escaped = [escaped, '\\'];
            i = i + 1;
        end
    else
        escaped = [escaped, c];
        i = i + 1;
    end
end

%% -------------------------------------------------------------------------
function items = split_array(str)
items = {};
current = '';
depth = 0;
indouble = false;
insingle = false;
i = 1;
len = length(str);

while (i <= len)
    c = str(i);
    if (c == '\' && i < len)
        current = [current c str(i + 1)];
        i = i + 2;
        continue
    elseif (c == '"' && ~insingle)
        indouble = ~indouble;
        current = [current c];
    elseif (c == '''' && ~indouble)
        insingle = ~insingle;
        current = [current c];
    elseif ((c == '[' || c == '{') && ~indouble && ~insingle)
        depth = depth + 1;
        current = [current c];
    elseif ((c == ']' || c == '}') && ~indouble && ~insingle)
        depth = depth - 1;
        current = [current c];
    elseif (c == ',' && depth == 0 && ~indouble && ~insingle)
        items{end + 1} = strtrim(current);
        current = '';
    else
        current = [current c];
    end
    i = i + 1;
end

if (~isempty(strtrim(current)))
    items{end + 1} = strtrim(current);
end
