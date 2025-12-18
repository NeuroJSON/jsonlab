function jsonstr = yaml2json(yamlstr)
% Convert YAML to JSON
%
% jsonstr = yaml2json(yamlstr)
%
% Convert a YAML string to JSON format for parsing with loadjson
%
% input:
%      yamlstr: a YAML string
%
% output:
%      jsonstr: a JSON string
%
% examples:
%      jsonstr = yaml2json('name: value')
%      jsonstr = yaml2json(sprintf('- a\n- b\n- c'))
%
% license:
%     BSD or GPL version 3, see LICENSE_{BSD,GPLv3}.txt files for details
%
% -- this function is part of JSONLab toolbox (http://iso2mesh.sf.net/cgi-bin/index.cgi?jsonlab)
%

lines = regexp(yamlstr, '\s*\r*\n', 'split');

% Find document separators
docstarts = [];
for i = 1:length(lines)
    if strcmp(strtrim(lines{i}), '---')
        docstarts = [docstarts i];
    end
end

if isempty(docstarts)
    jsonstr = convertLines(lines);
else
    documents = {};
    docstarts = [docstarts length(lines) + 1];
    for i = 1:length(docstarts) - 1
        doclines = lines(docstarts(i) + 1:docstarts(i + 1) - 1);
        documents{end + 1} = convertLines(doclines);
    end
    jsonstr = sprintf('%s\n', documents{:});
end

%% -------------------------------------------------------------------------
function jsonstr = convertLines(lines)
% Convert YAML lines to JSON

% Preprocess lines
items = {};
for i = 1:length(lines)
    line = lines{i};
    trimmed = strtrim(line);

    if isempty(trimmed) || trimmed(1) == '#'
        continue
    end

    % Check if entire line is a JSON literal (array or object)
    if (trimmed(1) == '[' || trimmed(1) == '{')
        jsonstr = trimmed;
        return
    end

    indent = length(line) - length(trimmed);
    islist = length(trimmed) >= 2 && strcmp(trimmed(1:2), '- ');

    if islist
        trimmed = strtrim(trimmed(3:end));
    end

    colonpos = strfind(trimmed, ':');
    if ~isempty(colonpos)
        key = strtrim(trimmed(1:colonpos(1) - 1));
        value = strtrim(trimmed(colonpos(1) + 1:end));
    else
        key = '';
        value = trimmed;
    end

    items{end + 1} = struct('indent', indent, 'islist', islist, 'key', key, 'value', value);
end

if isempty(items)
    jsonstr = '{}';
    return
end

% Build JSON recursively
[jsonstr, ~] = buildJSON(items, 1, -1);

%% -------------------------------------------------------------------------
function [jsonstr, nextidx] = buildJSON(items, startidx, parentindent)
% Recursively build JSON from parsed items

if startidx > length(items)
    jsonstr = '{}';
    nextidx = startidx;
    return
end

firstitem = items{startidx};
currentindent = firstitem.indent;

% Determine structure type
if firstitem.islist
    % Build array
    parts = {};
    idx = startidx;

    while idx <= length(items) && items{idx}.indent >= currentindent
        if items{idx}.indent == currentindent && items{idx}.islist
            % Array element
            if ~isempty(items{idx}.key)
                % Object in array - check if there are children
                if idx < length(items) && items{idx + 1}.indent > items{idx}.indent
                    % Object with children
                    objparts = {};
                    % Add the current key-value
                    if ~isempty(items{idx}.value)
                        objparts{end + 1} = ['"' items{idx}.key '":' formatVal(items{idx}.value)];
                    else
                        objparts{end + 1} = ['"' items{idx}.key '":'];
                    end
                    % Add children
                    childidx = idx + 1;
                    childindent = items{idx + 1}.indent;
                    while childidx <= length(items) && items{childidx}.indent >= childindent
                        if items{childidx}.indent == childindent && ~items{childidx}.islist
                            key = items{childidx}.key;
                            value = items{childidx}.value;
                            if isempty(value) && childidx < length(items) && items{childidx + 1}.indent > childindent
                                [subjson, childidx] = buildJSON(items, childidx + 1, childindent);
                                objparts{end + 1} = ['"' key '":' subjson];
                            else
                                objparts{end + 1} = ['"' key '":' formatVal(value)];
                                childidx = childidx + 1;
                            end
                        else
                            break
                        end
                    end
                    parts{end + 1} = ['{' sprintf('%s,', objparts{1:end - 1}) objparts{end} '}'];
                    idx = childidx;
                else
                    % Single key-value in object
                    parts{end + 1} = ['{' '"' items{idx}.key '":' formatVal(items{idx}.value) '}'];
                    idx = idx + 1;
                end
            else
                % Simple value
                parts{end + 1} = formatVal(items{idx}.value);
                idx = idx + 1;
            end
        elseif items{idx}.indent > currentindent
            % Skip - already processed as part of parent
            idx = idx + 1;
        else
            break
        end
    end
    jsonstr = ['[' sprintf('%s,', parts{1:end - 1}) parts{end} ']'];
    nextidx = idx;
else
    % Build object
    parts = {};
    idx = startidx;

    while idx <= length(items) && items{idx}.indent >= currentindent
        if items{idx}.indent == currentindent && ~items{idx}.islist
            key = items{idx}.key;
            value = items{idx}.value;

            if isempty(value) && idx < length(items) && items{idx + 1}.indent > currentindent
                % Nested structure
                [subjson, idx] = buildJSON(items, idx + 1, currentindent);
                parts{end + 1} = ['"' key '":' subjson];
            else
                % Simple key-value
                parts{end + 1} = ['"' key '":' formatVal(value)];
                idx = idx + 1;
            end
        elseif items{idx}.indent > currentindent
            % Skip - already processed
            idx = idx + 1;
        else
            break
        end
    end
    jsonstr = ['{' sprintf('%s,', parts{1:end - 1}) parts{end} '}'];
    nextidx = idx;
end

%% -------------------------------------------------------------------------
function val = formatVal(str)
% Format value for JSON

str = strtrim(str);

if isempty(str)
    val = 'null';
elseif strcmpi(str, 'true') || strcmpi(str, 'false')
    val = lower(str);
elseif strcmpi(str, 'null')
    val = 'null';
elseif length(str) >= 2 && ((str(1) == '"' && str(end) == '"') || (str(1) == '''' && str(end) == ''''))
    val = ['"' str(2:end - 1) '"'];
elseif str(1) == '['
    % Inline YAML array - need to parse and quote items
    content = str(2:end - 1); % Remove [ ]
    items = regexp(content, '\s*,\s*', 'split');
    formatted = {};
    for i = 1:length(items)
        formatted{i} = formatVal(strtrim(items{i}));
    end
    val = ['[', sprintf('%s,', formatted{1:end - 1}), formatted{end}, ']'];
elseif str(1) == '{'
    % Inline YAML object - pass through for now
    val = str;
else
    % Check if numeric
    num = str2double(str);
    if ~isnan(num) && isempty(regexp(str, '[a-zA-Z]', 'once'))
        val = str;
    else
        % String - escape and quote
        escaped = strrep(str, '\', '\\');
        escaped = strrep(escaped, '"', '\"');
        val = ['"' escaped '"'];
    end
end
