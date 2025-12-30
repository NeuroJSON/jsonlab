function [data, mmap] = loadyaml(fname, varargin)
%
% data=loadyaml(fname,opt)
%    or
% [data, mmap]=loadyaml(fname,'param1',value1,'param2',value2,...)
%
% parse a YAML file or string and return a MATLAB data structure
%
% authors: Qianqian Fang (q.fang <at> neu.edu)
% created on 2025/01/01
%
% input:
%      fname: input file name; if fname contains valid YAML syntax,
%             fname will be interpreted as a YAML string
%      opt: same options as loadjson (see loadjson help for details)
%
% output:
%      dat: a cell array or struct converted from YAML
%      mmap: (optional) memory-mapping table (see loadjson documentation)
%
% license:
%     BSD or GPL version 3, see LICENSE_{BSD,GPLv3}.txt files for details
%
% -- this function is part of JSONLab toolbox (http://neurojson.org/jsonlab)
%

opt = varargin2struct(varargin{:});
webopt = jsonopt('WebOptions', {}, opt);

if (~isempty(regexp(fname, '^\s*(http|https|ftp|file)://', 'once')))
    yamlstr = urlread(fname, webopt{:});
elseif (exist(fname, 'file') && ~exist(fname, 'dir'))
    try
        encoding = jsonopt('Encoding', '', opt);
        if (isempty(encoding))
            yamlstr = fileread(fname);
        else
            fid = fopen(fname, 'r', 'n', encoding);
            yamlstr = fread(fid, '*char')';
            fclose(fid);
        end
    catch
        try
            yamlstr = urlread(fname, webopt{:});
        catch
            yamlstr = urlread(['file://', fullfile(pwd, fname)]);
        end
    end
else
    yamlstr = fname;
end

if (jsonopt('Raw', 0, opt))
    data = yamlstr;
    if (nargout > 1)
        mmap = {};
    end
    return
end

opt.simplifycell = jsonopt('SimplifyCell', 1, opt);
opt.simplifycellarray = jsonopt('SimplifyCellArray', opt.simplifycell, opt);
opt.usemap = jsonopt('UseMap', 0, opt);
opt.unpackhex = jsonopt('UnpackHex', 1, opt);
opt.fastarrayparser = jsonopt('FastArrayParser', 1, opt);

if (ischar(yamlstr))
    inputstr = uint8(yamlstr);
else
    inputstr = yamlstr;
end
inputlen = length(inputstr);

newlines = find(inputstr == 10);
if (isempty(newlines) || newlines(end) ~= inputlen)
    newlines = [newlines, inputlen + 1];
end
numlines = length(newlines);
linestarts = [1, newlines(1:end - 1) + 1];

% Check for multi-document YAML
docstarts = [];
for i = 1:numlines
    ls = linestarts(i);
    le = newlines(i) - 1;
    if (le >= ls + 2 && inputstr(ls) == 45 && inputstr(ls + 1) == 45 && inputstr(ls + 2) == 45)
        isdoc = true;
        for j = ls + 3:le
            c = inputstr(j);
            if (c ~= 32 && c ~= 9 && c ~= 13)
                isdoc = false;
                break
            end
        end
        if (isdoc)
            docstarts = [docstarts, i];
        end
    end
end

if (~isempty(docstarts))
    docstarts = [docstarts, numlines + 1];
    documents = cell(1, length(docstarts) - 1);
    for d = 1:length(docstarts) - 1
        documents{d} = yaml_parse_lines(inputstr, linestarts, newlines, docstarts(d) + 1, docstarts(d + 1) - 1, opt);
    end
    data = documents{1};
    if (length(documents) > 1)
        data = documents;
    end
else
    data = yaml_parse_lines(inputstr, linestarts, newlines, 1, numlines, opt);
end

if (jsonopt('JDataDecode', 1, opt) == 1)
    try
        data = jdatadecode(data, 'Base64', 1, 'Recursive', 1, opt);
    catch
    end
end

if (nargout > 1)
    mmap = {};
end

%% =========================================================================
function data = yaml_parse_lines(inputstr, linestarts, newlines, startline, endline, opt)

maxlines = endline - startline + 1;
tok_indent = zeros(1, maxlines, 'int32');
tok_contentindent = zeros(1, maxlines, 'int32');
tok_islist = false(1, maxlines);
tok_keystart = zeros(1, maxlines, 'int32');
tok_keyend = zeros(1, maxlines, 'int32');
tok_valstart = zeros(1, maxlines, 'int32');
tok_valend = zeros(1, maxlines, 'int32');
tokencount = 0;

for i = startline:endline
    ls = linestarts(i);
    le = newlines(i) - 1;
    if (le >= ls && inputstr(le) == 13)
        le = le - 1;
    end
    if (le < ls)
        continue
    end

    indent = 0;
    pos = ls;
    while (pos <= le)
        c = inputstr(pos);
        if (c == 32)
            indent = indent + 1;
            pos = pos + 1;
        elseif (c == 9)
            indent = indent + 2;
            pos = pos + 1;
        else
            break
        end
    end
    if (pos > le)
        continue
    end
    if (inputstr(pos) == 35)
        continue
    end
    if (le - pos >= 2 && inputstr(pos) == 45 && inputstr(pos + 1) == 45 && inputstr(pos + 2) == 45)
        continue
    end
    if (le - pos >= 2 && inputstr(pos) == 46 && inputstr(pos + 1) == 46 && inputstr(pos + 2) == 46)
        continue
    end

    contentstart = pos;
    islist = false;
    contentindent = indent;

    if (inputstr(pos) == 45)
        if (pos == le)
            islist = true;
            contentstart = le + 1;
            contentindent = indent + 2;
        elseif (inputstr(pos + 1) == 32 || inputstr(pos + 1) == 9)
            islist = true;
            contentindent = indent + 2;
            pos = pos + 2;
            while (pos <= le && (inputstr(pos) == 32 || inputstr(pos) == 9))
                pos = pos + 1;
            end
            contentstart = pos;

            if (pos <= le && inputstr(pos) == 45 && (pos == le || inputstr(pos + 1) == 32 || inputstr(pos + 1) == 9))
                tokencount = tokencount + 1;
                tok_indent(tokencount) = indent;
                tok_contentindent(tokencount) = contentindent;
                tok_islist(tokencount) = true;
                tok_keystart(tokencount) = 0;
                tok_keyend(tokencount) = 0;
                tok_valstart(tokencount) = 0;
                tok_valend(tokencount) = 0;

                indent = contentindent;
                contentindent = indent + 2;
                pos = pos + 1;
                if (pos <= le && (inputstr(pos) == 32 || inputstr(pos) == 9))
                    pos = pos + 1;
                end
                while (pos <= le && (inputstr(pos) == 32 || inputstr(pos) == 9))
                    pos = pos + 1;
                end
                contentstart = pos;
            end
        end
    end

    keystart = 0;
    keyend = 0;
    valstart = 0;
    valend = 0;
    if (contentstart <= le)
        colonpos = yaml_find_colon(inputstr, contentstart, le);
        if (colonpos > 0)
            keystart = contentstart;
            keyend = colonpos - 1;
            while (keyend >= keystart && (inputstr(keyend) == 32 || inputstr(keyend) == 9))
                keyend = keyend - 1;
            end
            valstart = colonpos + 1;
            while (valstart <= le && (inputstr(valstart) == 32 || inputstr(valstart) == 9))
                valstart = valstart + 1;
            end
            if (valstart <= le)
                valend = yaml_remove_comment_end(inputstr, valstart, le);
            end
        else
            valstart = contentstart;
            valend = le;
        end
    end

    tokencount = tokencount + 1;
    tok_indent(tokencount) = indent;
    tok_contentindent(tokencount) = contentindent;
    tok_islist(tokencount) = islist;
    tok_keystart(tokencount) = keystart;
    tok_keyend(tokencount) = keyend;
    tok_valstart(tokencount) = valstart;
    tok_valend(tokencount) = valend;
end

if (tokencount == 0)
    data = [];
    return
end

tok_indent = tok_indent(1:tokencount);
tok_contentindent = tok_contentindent(1:tokencount);
tok_islist = tok_islist(1:tokencount);
tok_keystart = tok_keystart(1:tokencount);
tok_keyend = tok_keyend(1:tokencount);
tok_valstart = tok_valstart(1:tokencount);
tok_valend = tok_valend(1:tokencount);

[data, nextidx_] = yaml_build_structure(inputstr, tok_indent, tok_contentindent, tok_islist, ...
                                        tok_keystart, tok_keyend, tok_valstart, tok_valend, 1, tokencount, -1, opt); %#ok<ASGLU>

%% =========================================================================
function colonpos = yaml_find_colon(inputstr, startpos, endpos)
colonpos = 0;
indouble = false;
insingle = false;
i = startpos;
while (i <= endpos)
    c = inputstr(i);
    if (c == 92 && i < endpos)
        i = i + 2;
        continue
    end
    if (c == 34 && ~insingle)
        indouble = ~indouble;
    elseif (c == 39 && ~indouble)
        insingle = ~insingle;
    elseif (c == 58 && ~indouble && ~insingle)
        if (i == endpos || inputstr(i + 1) == 32 || inputstr(i + 1) == 9)
            colonpos = i;
            return
        end
    end
    i = i + 1;
end

%% =========================================================================
function valend = yaml_remove_comment_end(inputstr, valstart, valend)
indouble = false;
insingle = false;
i = valstart;
while (i <= valend)
    c = inputstr(i);
    if (c == 92 && i < valend)
        i = i + 2;
        continue
    end
    if (c == 34 && ~insingle)
        indouble = ~indouble;
    elseif (c == 39 && ~indouble)
        insingle = ~insingle;
    elseif (c == 35 && ~indouble && ~insingle)
        valend = i - 1;
        while (valend >= valstart && (inputstr(valend) == 32 || inputstr(valend) == 9))
            valend = valend - 1;
        end
        return
    end
    i = i + 1;
end

%% =========================================================================
function [result, nextidx] = yaml_build_structure(inputstr, tok_indent, tok_contentindent, tok_islist, ...
                                                  tok_keystart, tok_keyend, tok_valstart, tok_valend, startidx, endidx, minindent_, opt)

if (startidx > endidx)
    result = [];
    nextidx = startidx;
    return
end

if (tok_islist(startidx))
    [result, nextidx] = yaml_build_array(inputstr, tok_indent, tok_contentindent, tok_islist, ...
                                         tok_keystart, tok_keyend, tok_valstart, tok_valend, startidx, endidx, tok_indent(startidx), opt);
else
    [result, nextidx] = yaml_build_object(inputstr, tok_indent, tok_contentindent, tok_islist, ...
                                          tok_keystart, tok_keyend, tok_valstart, tok_valend, startidx, endidx, tok_indent(startidx), opt);
end

%% =========================================================================
function [result, nextidx] = yaml_build_array(inputstr, tok_indent, tok_contentindent, tok_islist, ...
                                              tok_keystart, tok_keyend, tok_valstart, tok_valend, startidx, endidx, baseindent, opt)

result = {};
idx = startidx;

while (idx <= endidx)
    if (tok_indent(idx) < baseindent)
        break
    end
    if (tok_indent(idx) > baseindent)
        idx = idx + 1;
        continue
    end
    if (~tok_islist(idx))
        break
    end

    if (tok_keystart(idx) > 0)
        [obj, idx] = yaml_build_list_object(inputstr, tok_indent, tok_contentindent, tok_islist, ...
                                            tok_keystart, tok_keyend, tok_valstart, tok_valend, idx, endidx, baseindent, opt);
        result{end + 1} = obj;
    elseif (tok_valstart(idx) > 0 && tok_valstart(idx) <= tok_valend(idx))
        result{end + 1} = yaml_parse_value(inputstr, tok_valstart(idx), tok_valend(idx), opt);
        idx = idx + 1;
    else
        idx = idx + 1;
        if (idx <= endidx && tok_indent(idx) > baseindent)
            [nested, idx] = yaml_build_structure(inputstr, tok_indent, tok_contentindent, tok_islist, ...
                                                 tok_keystart, tok_keyend, tok_valstart, tok_valend, idx, endidx, baseindent, opt);
            result{end + 1} = nested;
        else
            result{end + 1} = [];
        end
    end
end

if (opt.simplifycell && ~isempty(result))
    result = yaml_simplify_cell(result);
end
nextidx = idx;

%% =========================================================================
function [result, nextidx] = yaml_build_list_object(inputstr, tok_indent, tok_contentindent, tok_islist, ...
                                                    tok_keystart, tok_keyend, tok_valstart, tok_valend, startidx, endidx, listindent, opt)

result = struct();
contentindent = tok_contentindent(startidx);
key = char(inputstr(tok_keystart(startidx):tok_keyend(startidx)));
idx = startidx + 1;

if (tok_valstart(startidx) > tok_valend(startidx))
    if (idx <= endidx)
        if (tok_islist(idx) && tok_indent(idx) == contentindent)
            [val, idx] = yaml_build_array(inputstr, tok_indent, tok_contentindent, tok_islist, ...
                                          tok_keystart, tok_keyend, tok_valstart, tok_valend, idx, endidx, tok_indent(idx), opt);
        elseif (tok_indent(idx) > contentindent)
            [val, idx] = yaml_build_structure(inputstr, tok_indent, tok_contentindent, tok_islist, ...
                                              tok_keystart, tok_keyend, tok_valstart, tok_valend, idx, endidx, contentindent, opt);
        else
            val = [];
        end
    else
        val = [];
    end
else
    val = yaml_parse_value(inputstr, tok_valstart(startidx), tok_valend(startidx), opt);
end
result.(encodevarname(key, opt)) = val;

while (idx <= endidx)
    if (tok_indent(idx) <= listindent)
        break
    end
    if (tok_islist(idx) && tok_indent(idx) <= listindent + 2)
        break
    end

    if (tok_indent(idx) == contentindent && ~tok_islist(idx) && tok_keystart(idx) > 0)
        fkey = char(inputstr(tok_keystart(idx):tok_keyend(idx)));
        if (tok_valstart(idx) > tok_valend(idx))
            if (idx + 1 <= endidx)
                if (tok_islist(idx + 1) && tok_indent(idx + 1) == contentindent)
                    [val, idx] = yaml_build_array(inputstr, tok_indent, tok_contentindent, tok_islist, ...
                                                  tok_keystart, tok_keyend, tok_valstart, tok_valend, idx + 1, endidx, tok_indent(idx + 1), opt);
                elseif (tok_indent(idx + 1) > contentindent)
                    [val, idx] = yaml_build_structure(inputstr, tok_indent, tok_contentindent, tok_islist, ...
                                                      tok_keystart, tok_keyend, tok_valstart, tok_valend, idx + 1, endidx, contentindent, opt);
                else
                    val = [];
                    idx = idx + 1;
                end
            else
                val = [];
                idx = idx + 1;
            end
        else
            val = yaml_parse_value(inputstr, tok_valstart(idx), tok_valend(idx), opt);
            idx = idx + 1;
        end
        result.(encodevarname(fkey, opt)) = val;
    elseif (tok_indent(idx) > contentindent)
        idx = idx + 1;
    else
        break
    end
end
nextidx = idx;

%% =========================================================================
function [result, nextidx] = yaml_build_object(inputstr, tok_indent, tok_contentindent, tok_islist, ...
                                               tok_keystart, tok_keyend, tok_valstart, tok_valend, startidx, endidx, baseindent, opt)

result = struct();
idx = startidx;

while (idx <= endidx)
    if (tok_indent(idx) < baseindent)
        break
    end
    if (tok_islist(idx) && tok_indent(idx) == baseindent)
        break
    end
    if (tok_indent(idx) > baseindent)
        idx = idx + 1;
        continue
    end

    if (~tok_islist(idx) && tok_keystart(idx) > 0)
        key = char(inputstr(tok_keystart(idx):tok_keyend(idx)));
        if (tok_valstart(idx) > tok_valend(idx))
            if (idx + 1 <= endidx && tok_indent(idx + 1) > baseindent)
                [val, idx] = yaml_build_structure(inputstr, tok_indent, tok_contentindent, tok_islist, ...
                                                  tok_keystart, tok_keyend, tok_valstart, tok_valend, idx + 1, endidx, baseindent, opt);
            else
                val = [];
                idx = idx + 1;
            end
        else
            val = yaml_parse_value(inputstr, tok_valstart(idx), tok_valend(idx), opt);
            idx = idx + 1;
        end
        result.(encodevarname(key, opt)) = val;
    else
        idx = idx + 1;
    end
end
nextidx = idx;

%% =========================================================================
function val = yaml_parse_value(inputstr, valstart, valend, opt)

if (valstart > valend)
    val = [];
    return
end

c1 = inputstr(valstart);
cend = inputstr(valend);
len = valend - valstart + 1;

if (c1 == 34 && cend == 34 && len >= 2)
    val = yaml_unescape_string(char(inputstr(valstart + 1:valend - 1)));
    return
elseif (c1 == 39 && cend == 39 && len >= 2)
    val = char(inputstr(valstart + 1:valend - 1));
    return
end

if (c1 == 91 && cend == 93)
    str = char(inputstr(valstart:valend));
    if (opt.fastarrayparser)
        val = yaml_parse_inline_array_fast(str(2:end - 1), opt);
    else
        val = yaml_parse_inline_array(str(2:end - 1), opt);
    end
    return
end

if (c1 == 123 && cend == 125)
    val = yaml_parse_inline_object(char(inputstr(valstart + 1:valend - 1)), opt);
    return
end

str = char(inputstr(valstart:valend));

if (len == 2)
    if (strcmp(str, '[]'))
        val = {};
        return
    end
    if (strcmp(str, '{}'))
        val = struct();
        return
    end
end

if (len <= 5)
    strl = lower(str);
    if (strcmp(strl, 'true') || strcmp(strl, 'yes') || strcmp(strl, 'on'))
        val = true;
        return
    end
    if (strcmp(strl, 'false') || strcmp(strl, 'no') || strcmp(strl, 'off'))
        val = false;
        return
    end
    if (strcmp(strl, 'null') || strcmp(str, '~'))
        val = [];
        return
    end
    if (strcmp(strl, '.inf'))
        val = Inf;
        return
    end
    if (strcmp(strl, '.nan'))
        val = NaN;
        return
    end
end

if (len == 5 && (strcmpi(str, '+.inf') || strcmpi(str, '-.inf')))
    if (str(1) == '-')
        val = -Inf;
    else
        val = Inf;
    end
    return
end

num = str2double(str);
if (~isnan(num))
    val = num;
    return
end
if (strcmpi(str, 'nan'))
    val = NaN;
    return
end

if (len > 2 && str(1) == '0' && (str(2) == 'x' || str(2) == 'X'))
    try
        val = hex2dec(str(3:end));
        return
    catch
    end
end

val = str;

%% =========================================================================
function val = yaml_parse_inline_array_fast(str, opt)

str = strtrim(str);
if (isempty(str))
    val = {};
    return
end

if (~any(str == '"') && ~any(str == ''''))
    if (any(str == '['))
        [val, success] = yaml_fast_parse_nested_numeric(str);
        if (success)
            return
        end
    else
        [val, success] = yaml_fast_parse_1d_numeric(str);
        if (success)
            return
        end
    end
end

val = yaml_parse_inline_array(str, opt);

%% =========================================================================
function [val, success] = yaml_fast_parse_1d_numeric(str)
success = false;
val = {};
str(str == ' ') = '';
if (isempty(str))
    return
end
[nums, count_, errmsg_, nextidx] = sscanf(str, '%f,', [1, inf]); %#ok<ASGLU>
if (~isempty(nums) && nextidx >= length(str) - 1)
    val = nums;
    success = true;
end

%% =========================================================================
function [val, success] = yaml_fast_parse_nested_numeric(str)
success = false;
val = {};

teststr = str;
teststr(teststr == '[' | teststr == ']' | teststr == ',') = ' ';
[nums, count] = sscanf(teststr, '%f', inf);
if (count == 0)
    return
end

[dims, isvalid] = yaml_detect_array_dims(str);
if (~isvalid || isempty(dims) || prod(dims) ~= count)
    return
end

try
    if (length(dims) == 1)
        val = nums(:)';
    elseif (length(dims) == 2)
        val = reshape(nums, [dims(2), dims(1)])';
    else
        val = reshape(nums, fliplr(dims));
        val = permute(val, length(dims):-1:1);
    end
    success = true;
catch
end

%% =========================================================================
function [dims, isvalid] = yaml_detect_array_dims(str)
dims = [];
isvalid = false;
len = length(str);
if (len == 0)
    return
end

depth = 0;
maxdepth = 0;
for i = 1:len
    if (str(i) == '[')
        depth = depth + 1;
        if (depth > maxdepth)
            maxdepth = depth;
        end
    elseif (str(i) == ']')
        depth = depth - 1;
    end
end
if (depth ~= 0 || maxdepth == 0)
    return
end

elem_counts = zeros(1, maxdepth);
current_counts = zeros(1, maxdepth);
first_at_depth = true(1, maxdepth);
depth = 0;

for i = 1:len
    c = str(i);
    if (c == '[')
        depth = depth + 1;
        current_counts(depth) = 1;
    elseif (c == ']')
        if (first_at_depth(depth))
            elem_counts(depth) = current_counts(depth);
            first_at_depth(depth) = false;
        elseif (elem_counts(depth) ~= current_counts(depth))
            return
        end
        depth = depth - 1;
    elseif (c == ',' && depth > 0)
        current_counts(depth) = current_counts(depth) + 1;
    end
end

dims = elem_counts(1:maxdepth);
isvalid = all(dims > 0);

%% =========================================================================
function val = yaml_parse_inline_array(str, opt)
str = strtrim(str);
if (isempty(str))
    val = {};
    return
end

items = yaml_split_items(str);
n = length(items);
val = cell(1, n);
for i = 1:n
    item = strtrim(items{i});
    if (~isempty(item) && item(1) == '[' && item(end) == ']')
        if (opt.fastarrayparser)
            val{i} = yaml_parse_inline_array_fast(item(2:end - 1), opt);
        else
            val{i} = yaml_parse_inline_array(item(2:end - 1), opt);
        end
    else
        val{i} = yaml_parse_value_str(item, opt);
    end
end

if (opt.simplifycell && ~isempty(val))
    val = yaml_simplify_cell(val);
end

%% =========================================================================
function val = yaml_parse_inline_object(str, opt)
str = strtrim(str);
val = struct();
if (isempty(str))
    return
end

items = yaml_split_items(str);
for i = 1:length(items)
    item = strtrim(items{i});
    colonpos = strfind(item, ':');
    if (~isempty(colonpos))
        key = strtrim(item(1:colonpos(1) - 1));
        value = strtrim(item(colonpos(1) + 1:end));
        if (length(key) >= 2 && ((key(1) == '"' && key(end) == '"') || (key(1) == '''' && key(end) == '''')))
            key = key(2:end - 1);
        end
        val.(encodevarname(key, opt)) = yaml_parse_value_str(value, opt);
    end
end

%% =========================================================================
function val = yaml_parse_value_str(str, opt)
if (isempty(str))
    val = [];
    return
end

c1 = str(1);
cend = str(end);
len = length(str);

if (c1 == '"' && cend == '"' && len >= 2)
    val = yaml_unescape_string(str(2:end - 1));
    return
elseif (c1 == '''' && cend == '''' && len >= 2)
    val = str(2:end - 1);
    return
end

if (strcmp(str, '[]'))
    val = {};
    return
end
if (strcmp(str, '{}'))
    val = struct();
    return
end

strl = lower(str);
if (strcmp(strl, 'true') || strcmp(strl, 'yes'))
    val = true;
    return
end
if (strcmp(strl, 'false') || strcmp(strl, 'no'))
    val = false;
    return
end
if (strcmp(strl, 'null') || strcmp(str, '~'))
    val = [];
    return
end

if (c1 == '[' && cend == ']')
    if (opt.fastarrayparser)
        val = yaml_parse_inline_array_fast(str(2:end - 1), opt);
    else
        val = yaml_parse_inline_array(str(2:end - 1), opt);
    end
    return
end
if (c1 == '{' && cend == '}')
    val = yaml_parse_inline_object(str(2:end - 1), opt);
    return
end

num = str2double(str);
if (~isnan(num))
    val = num;
    return
end

val = str;

%% =========================================================================
function items = yaml_split_items(str)
items = {};
current = '';
depth = 0;
indouble = false;
insingle = false;
len = length(str);
i = 1;

while (i <= len)
    c = str(i);
    if (c == '\' && i < len)
        current = [current, c, str(i + 1)];
        i = i + 2;
        continue
    elseif (c == '"' && ~insingle)
        indouble = ~indouble;
    elseif (c == '''' && ~indouble)
        insingle = ~insingle;
    elseif (~indouble && ~insingle)
        if (c == '[' || c == '{')
            depth = depth + 1;
        elseif (c == ']' || c == '}')
            depth = depth - 1;
        elseif (c == ',' && depth == 0)
            items{end + 1} = current;
            current = '';
            i = i + 1;
            continue
        end
    end
    current = [current, c];
    i = i + 1;
end
if (~isempty(current))
    items{end + 1} = current;
end

%% =========================================================================
function str = yaml_unescape_string(str)
if (isempty(str) || ~any(str == '\'))
    return
end

% Handle \xHH and \uHHHH first before we mess with backslashes
% Use strfind and manual replacement (works in Octave 5.2)
str = yaml_unescape_hex(str, 'x', 2);  % \xHH - 2 hex digits
str = yaml_unescape_hex(str, 'u', 4);  % \uHHHH - 4 hex digits

% Now handle standard escapes using strrep
str = strrep(str, '\\', char(1));  % Temporarily replace \\
str = strrep(str, '\"', '"');
str = strrep(str, '\/', '/');
str = strrep(str, '\a', char(7));
str = strrep(str, '\b', char(8));
str = strrep(str, '\t', char(9));
str = strrep(str, '\n', char(10));
str = strrep(str, '\v', char(11));
str = strrep(str, '\f', char(12));
str = strrep(str, '\r', char(13));
str = strrep(str, '\e', char(27));
str = strrep(str, '\0', char(0));
str = strrep(str, char(1), '\');  % Restore single backslash

%% =========================================================================
function str = yaml_unescape_hex(str, prefix, numdigits)
% Handle \xHH or \uHHHH escape sequences
% prefix: 'x' for \xHH, 'u' for \uHHHH
% numdigits: 2 for \xHH, 4 for \uHHHH
hexchars = '0123456789abcdefABCDEF';
esclen = 2 + numdigits;  % \x + HH or \u + HHHH
pattern = ['\' prefix];
idx = strfind(str, pattern);
while ~isempty(idx)
    p = idx(1);
    if p + esclen - 1 <= length(str)
        hexpart = str(p + 2:p + 1 + numdigits);
        if all(ismember(hexpart, hexchars))
            charval = char(hex2dec(hexpart));
            str = [str(1:p - 1) charval str(p + esclen:end)];
            % Find next occurrence from the beginning (string length changed)
            idx = strfind(str, pattern);
            continue
        end
    end
    % Invalid escape or not enough chars, skip this one and check rest
    idx = idx(idx > p);
end

%% =========================================================================
function result = yaml_simplify_cell(cellarray)
result = cellarray;
if (isempty(cellarray))
    return
end
n = length(cellarray);

allscalar = true;
for i = 1:n
    if (~isnumeric(cellarray{i}) || numel(cellarray{i}) ~= 1)
        allscalar = false;
        break
    end
end
if (allscalar)
    result = [cellarray{:}];
    return
end

allnumvec = true;
firstLen = 0;
for i = 1:n
    c = cellarray{i};
    if (~isnumeric(c) || ~isvector(c) || isempty(c))
        allnumvec = false;
        break
    end
    if (i == 1)
        firstLen = numel(c);
    elseif (numel(c) ~= firstLen)
        allnumvec = false;
        break
    end
end
if (allnumvec && firstLen > 0)
    result = zeros(n, firstLen);
    for i = 1:n
        result(i, :) = cellarray{i}(:)';
    end
    return
end

allstruct = true;
for i = 1:n
    if (~isstruct(cellarray{i}))
        allstruct = false;
        break
    end
end
if (allstruct && n > 0)
    fn1 = sort(fieldnames(cellarray{1}));
    same = true;
    for i = 2:n
        if (~isequal(fn1, sort(fieldnames(cellarray{i}))))
            same = false;
            break
        end
    end
    if (same)
        result = [cellarray{:}];
    end
end
