%
%    jd = jdict(data)
%
%    A universal dictionary-like interface that enables fast multi-level subkey access and
%    JSONPath-based element indexing, such as jd.('key1').('key2') and jd.('$.key1.key2'),
%    for hierachical data structures embedding struct, containers.Map or dictionary objects
%
%    author: Qianqian Fang (q.fang <at> neu.edu)
%
%    input:
%        data: a hierachical data structure made of struct, containers.Map, dictionary, or cell arrays
%              if data is a string starting with http:// or https://,
%              loadjson(data) will be used to dynamically load the data
%
%    indexing:
%        jd.('key1').('subkey1')... can retrieve values that are recursively index keys that are
%        jd.key1.subkey1... can also retrieve the same data regardless
%              if the underlying data is struct, containers.Map or dictionary
%        jd.('key1').('subkey1').v(1) if the subkey key1 is an array, this can retrieve the first element
%        jd.('key1').('subkey1').v(1).('subsubkey1') the indexing can be further applied for deeper objects
%        jd.('$.key1.subkey1') if the indexing starts with '$' this allows a JSONPath based index
%        jd.('$.key1.subkey1[0]') using a JSONPath can also read array-based subkey element
%        jd.('$.key1.subkey1[0].subsubkey1') JSONPath can also apply further indexing over objects of diverse types
%        jd.('$.key1..subkey') JSONPath can use '..' deep-search operator to find and retrieve subkey appearing at any level below
%
%    member functions:
%        jd() or jd.v() returns the underlying hierachical data
%        jd.('cell1').v(i) or jd.('array1').v(2:3) returns specified elements if the element is a cell or array
%        jd.('key1'),('subkey1').v() returns the underlying hierachical data at the specified subkeys
%        jd.tojson() convers the underlying data to a JSON string
%        jd.tojson('compression', 'zlib', ...) convers the data to a JSON string with savejson() options
%        jd.keys() return the sub-key names of the object - if it a struct, dictionary or containers.Map - or 1:length(data) if it is an array
%        jd.len() return the length of the sub-keys
%
%        if using matlab, the .v(...) method can be replaced by bare
%        brackets .(...), but in octave, one must use .v(...)
%
%    examples:
%        obj = struct('key1', struct('subkey1',1, 'subkey2',[1,2,3]), 'subkey2', 'str');
%        obj.key1.subkey3 = {8,'test',containers.Map('subsubkey1',0)};
%
%        jd = jdict(obj);
%
%        % getting values
%        jd()                                   % return obj
%        jd.('key1').('subkey1')                % return jdict(1)
%        jd.keys.subkey1                        % return jdict(1)
%        jd.('key1').('subkey3')                % return jdict(obj.key1.subkey3)
%        jd.('key1').('subkey3')()              % return obj.key1.subkey3
%        jd.('key1').('subkey3').v(1)           % return jdict({8})
%        jd.('key1').('subkey3').('subsubkey1') % return jdict(obj.key1.subkey3(2))
%        jd.('key1').('subkey3').v(2).v()       % return {'test'}
%        jd.('$.key1.subkey1')                  % return jdict(1)
%        jd.('$.key1.subkey2')()                % return 'str'
%        jd.('$.key1.subkey2').v().v(1)         % return jdict(1)
%        jd.('$.key1.subkey2')().v(1).v()       % return 1
%        jd.('$.key1.subkey3[2].subsubkey1')    % return jdict(0)
%        jd.('$..subkey2')                      % jsonpath '..' operator runs a deep scan, return jdict({'str', [1 2 3]})
%        jd.('$..subkey2').v(2)                 % return jdict([1,2,3])
%
%        % setting values
%        jd.('subkey2') = 'newstr'              % setting obj.subkey2 to 'newstr'
%        jd.('key1').('subkey2').v(1) = 2;                    % modify indexed element
%        jd.('key1').('subkey2').v([2, 3]) = [10, 11];        % modify multiple values
%        jd.('key1').('subkey3').v(3).('subsubkey1') = 1;     % modify keyed value
%        jd.('key1').('subkey3').v(3).('subsubkey2') = 'new'; % add new key
%
%        % loading complex data from REST-API
%        jd = jdict('https://neurojson.io:7777/cotilab/NeuroCaptain_2024');
%
%        jd.('Atlas_Age_19_0')
%        jd.Atlas_Age_19_0.('Landmark_10_10').('$.._DataLink_')
%        jd.Atlas_Age_19_0.Landmark_10_10.('$.._DataLink_')()
%
%        % creating and managing hierachical data with any key value
%        jd = jdict;
%        jd.('_DataInfo_') = struct('toolbox', 'jsonlab', 'version', '3.0.0')
%        jd.('_DataInfo_').tojson()
%
%    license:
%        BSD or GPL version 3, see LICENSE_{BSD,GPLv3}.txt files for details
%
% -- this function is part of JSONLab toolbox (http://iso2mesh.sf.net/cgi-bin/index.cgi?jsonlab)
%

classdef jdict < handle
    properties
        data
    end
    methods

        function obj = jdict(val)
            if (nargin == 1)
                if (ischar(val) && ~isempty(regexp(val, '^https*://', 'once')))
                    try
                        obj.data = loadjson(val);
                    catch
                        obj.data = val;
                    end
                    return
                end
                if (isa(val, 'jdict'))
                    obj = val;
                else
                    obj.data = val;
                end
            end
        end

        % overloading the getter function
        function val = subsref(obj, idxkey)
            oplen = length(idxkey);
            val = obj.data;
            if (oplen == 1 && strcmp(idxkey.type, '()') && isempty(idxkey.subs))
                return
            end
            i = 1;
            while i <= oplen
                idx = idxkey(i);
                % disp({i, savejson(idx)});
                if (isempty(idx.subs))
                    i = i + 1;
                    continue
                end
                if (idx.type == '.' && isnumeric(idx.subs))
                    val = val(idx.subs);
                elseif ((strcmp(idx.type, '()') || idx.type == '.') && ismember(idx.subs, {'tojson', 'fromjson', 'v', 'keys', 'len'}) && i < oplen)
                    if (strcmp(idx.subs, 'v'))
                        if (iscell(val) && strcmp(idxkey(i + 1).type, '()'))
                            idxkey(i + 1).type = '{}';
                        end
                        if (~isempty(idxkey(i + 1).subs))
                            val = v(jdict(val), idxkey(i + 1));
                        end
                    else
                        fhandle = str2func(idx.subs);
                        val = fhandle(jdict(val), idxkey(i + 1).subs{:});
                    end
                    i = i + 1;
                    if (i < oplen)
                        val = jdict(val);
                    end
                elseif ((idx.type == '.' && ischar(idx.subs)) || (iscell(idx.subs) && ~isempty(idx.subs{1})))
                    onekey = idx.subs;
                    if (iscell(onekey))
                        onekey = onekey{1};
                    end
                    if (isa(val, 'jdict'))
                        val = val.data;
                    end
                    if (ischar(onekey) && ~isempty(onekey) && onekey(1) == '$')
                        val = jsonpath(val, onekey);
                    elseif (isstruct(val))
                        val = val.(onekey);
                    elseif (isa(val, 'containers.Map') || isa(val, 'dictionary'))
                        val = val(onekey);
                    else
                        error('key name "%s" not found', onekey);
                    end
                else
                    error('method not supported');
                end
                i = i + 1;
            end
            if (~(isempty(idxkey(end).subs) && strcmp(idxkey(end).type, '()')))
                val = jdict(val);
            end
        end

        % overloading the setter function, obj.('idxkey')=otherobj
        % expanded from rahnema1's sample at https://stackoverflow.com/a/79030223/4271392
        function obj = subsasgn(obj, idxkey, otherobj)
            oplen = length(idxkey);
            opcell = cell (1, oplen + 1);
            if (isempty(obj.data))
                obj.data = containers.Map();
            end
            opcell{1} = obj.data;

            for i = 1:oplen
                idx = idxkey(i);
                if (strcmp(idx.type, '.'))
                    if (ischar(idx.subs) && strcmp(idx.subs, 'v'))
                        opcell{i + 1} = opcell{i};
                        if (i < oplen && iscell(opcell{i}))
                            idxkey(i + 1).type = '{}';
                        end
                        continue
                    end
                    if (ischar(idx.subs) && ~isempty(idx.subs) && idx.subs(1) == '$')
                        error('setting values based on JSONPath indices is not yet supported');
                    end
                    if (ischar(idx.subs))
                        if (((isa(opcell{i}, 'containers.Map') || isa(opcell{i}, 'dictionary')) && ~isKey(opcell{i}, idx.subs)))
                            idx.type = '()';
                            opcell{i}(idx.subs) = containers.Map();
                        elseif (isstruct(opcell{i}) && ~isfield(opcell{i}, idx.subs))
                            opcell{i}.(idx.subs) = containers.Map();
                        end
                    end
                end
                if (exist('OCTAVE_VERSION', 'builtin') ~= 0) && (isa(opcell{i}, 'containers.Map') || isa(opcell{i}, 'dictionary'))
                    opcell{i + 1} = opcell{i}(idx.subs);
                else
                    opcell{i + 1} = subsref(opcell{i}, idx);
                end
            end

            if (exist('OCTAVE_VERSION', 'builtin') ~= 0) && (isa(opcell{i}, 'containers.Map') || isa(opcell{i}, 'dictionary'))
                opcell{i}(idx.subs) = otherobj;
                opcell{end - 1} = opcell{i};
            else
                opcell{end - 1} = subsasgn(opcell{i}, idx, otherobj);
            end

            for i = oplen - 1:-1:1
                idx = idxkey(i);
                if (ischar(idx.subs) && strcmp(idx.subs, 'v'))
                    opcell{i} = opcell{i + 1};
                    continue
                end

                if (i > 1 && ischar(idxkey(i - 1).subs) && strcmp(idxkey(i - 1).subs, 'v'))
                    if (iscell(opcell{i}) && ~isempty(idx.subs))
                        opcell{i} = subsasgn(opcell{i}, idx, opcell{i + 1});
                    else
                        opcell{i} = opcell{i + 1};
                    end
                    i = i - 1;
                else
                    opcell{i} = subsasgn(opcell{i}, idx, opcell{i + 1});
                end
            end

            obj.data = opcell{1};
        end

        function val = tojson(obj, varargin)
            val = savejson('', obj.data, 'compact', 1, varargin{:});
        end

        function obj = fromjson(obj, fname, varargin)
            obj.data = loadjd(fname, varargin{:});
        end

        function val = keys(obj)
            if (isstruct(obj.data))
                val = fieldnames(obj.data);
            elseif (isa(obj.data, 'containers.Map') || isa(obj.data, 'dictionary'))
                val = keys(obj.data);
            else
                val = 1:length(obj.data);
            end
        end

        function val = len(obj)
            val = length(obj.data);
        end

        function val = v(obj, varargin)
            if (~isempty(varargin))
                val = subsref(obj.data, varargin{:});
            else
                val = obj.data;
            end
        end

    end
end
