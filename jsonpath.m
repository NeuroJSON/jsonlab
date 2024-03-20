function obj = jsonpath(root, jsonpath)
%
%    obj=jsonpath(root, jsonpath)
%
%    Query and retrieve elements from matlab data structures using JSONPath
%
%    author: Qianqian Fang (q.fang <at> neu.edu)
%
%    input:
%        root: a matlab data structure like an array, cell, struct, etc
%        jsonpath: a string in the format of JSONPath, see loadjson help
%
%    output:
%        obj: if the specified element exist, obj returns the result
%
%    example:
%        jsonpath(struct('a',[1,2,3]), '$.a[1]')      % returns 2
%
% license:
%     BSD or GPL version 3, see LICENSE_{BSD,GPLv3}.txt files for details
%
% -- this function is part of JSONLab toolbox (http://iso2mesh.sf.net/cgi-bin/index.cgi?jsonlab)
%

obj = root;
jsonpath = regexprep(jsonpath, '([^.])(\[[0-9:]+\])', '$1.$2');
[pat, paths] = regexp(jsonpath, '(\.{0,2}[^\s\.]+)', 'match', 'tokens');
if (~isempty(pat) && ~isempty(paths))
    for i = 1:length(paths)
        [obj, isfound] = getonelevel(obj, paths, i);
        if (~isfound)
            return
        end
    end
end

%% scan function

function [obj, isfound] = getonelevel(input, paths, pathid)

pathname = paths{pathid};
if (iscell(pathname))
    pathname = pathname{1};
end

deepscan = ~isempty(regexp(pathname, '^\.\.', 'once'));

pathname = regexprep(pathname, '^\.+', '');

if (strcmp(pathname, '$'))
    obj = input;
elseif (regexp(pathname, '$\d+'))
    obj = input(str2double(pathname(2:end)) + 1);
elseif (regexp(pathname, '^\[[0-9:]+\]$'))
    arraystr = pathname(2:end - 1);
    if (find(arraystr == ':'))
        [arraystr, arrayrange] = regexp(arraystr, '(\d*):(\d*)', 'match', 'tokens');
        arrayrange = arrayrange{1};
        if (~isempty(arrayrange{1}))
            arrayrange{1} = str2double(arrayrange{1}) + 1;
        else
            arrayrange{1} = 1;
        end
        if (~isempty(arrayrange{2}))
            arrayrange{2} = str2double(arrayrange{2}) + 1;
        else
            arrayrange{2} = length(input);
        end
    else
        arrayrange = str2double(arraystr) + 1;
        arrayrange = {arrayrange, arrayrange};
    end
    if (iscell(input))
        obj = {input{arrayrange{1}:arrayrange{2}}};
    else
        obj = input(arrayrange{1}:arrayrange{2});
    end
elseif (isstruct(input))
    stpath = encodevarname(pathname);
    if (deepscan)
        if (isfield(input, stpath))
            obj = {input.(stpath)};
        end
        items = fieldnames(input);
        for idx = 1:length(items)
            [val, isfound] = getonelevel(input.(items{idx}), [paths{:} {['..' pathname]}], pathid + 1);
            if (isfound)
                if (~exist('obj', 'var'))
                    obj = {};
                end
                obj = [obj{:}, val];
            end
        end
    else
        obj = input.(stpath);
    end
elseif (isa(input, 'containers.Map'))
    if (deepscan)
        if (isKey(input, pathname))
            obj = {input(pathname)};
        end
        items = keys(input);
        for idx = 1:length(items)
            [val, isfound] = getonelevel(input(items{idx}), [paths{:} {['..' pathname]}], pathid + 1);
            if (isfound)
                if (~exist('obj', 'var'))
                    obj = {};
                end
                obj = [obj{:}, val];
            end
        end
    else
        obj = input(pathname);
    end
elseif (isa(input, 'table'))
    obj = input(:, pathname);
elseif (~deepscan)
    error('json path segment "%s" can not be found in the input object\n', pathname);
end

if (~exist('obj', 'var'))
    isfound = false;
    obj = [];
elseif (nargout > 1)
    isfound = true;
end
