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
%        data: an array, or hierachical data structure made of struct,
%               containers.Map, dictionary, or cell arrays; if data is a
%               string starting with http:// or https://, loadjson(data)
%               will be used to dynamically load the data
%
%    constructors:
%        jd = jdict creates an empty jdict object (like an empty struct or containers.Map)
%        jd = jdict(data) wraps any matlab data (array, cell, struct, dictionary, ...) into a new jdict object
%        jd = jdict(data, 'param1', value1, 'param2', value2, ...) use param/value pairs to initilize jd.flags
%        jd = jdict(data, 'attr', attrmap) initilize data attributes using a containers.Map with JSONPath as keys
%        jd = jdict(data, 'schema', jschema) initilize data's JSON schema using a containers.Map object jschema
%
%    member functions:
%        jd.('cell1').v(i) or jd.('array1').v(2:3) returns specified elements if the element is a cell or array
%        jd.('key1').('subkey1').v() returns the underlying hierachical data at the specified subkeys
%        jd.tojson() convers the underlying data to a JSON string
%        jd.tojson('compression', 'zlib', ...) convers the data to a JSON string with savejson() options
%        jd.keys() returns the sub-key names of the object - if it a struct, dictionary or containers.Map - or 1:length(data) if it is an array
%        jd.len() returns the length of the sub-keys
%        jd.size() returns the dimension vector
%        jd.isKey(key) tests if a string-based key exists in the data, or number-based key is within the data array length
%        jd{'attrname'} gets/sets attributes using curly bracket indexing; jd{'attrname'}=val only works in MATLAB; use setattr() in octave
%        jd.setattr(jsonpath, attrname, value) sets attribute at any path
%        jd.getattr(jsonpath, attrname) gets attribute from any path
%        jd.setschema(schema) sets a JSON Schema for validation (struct, JSON string, URL, or file path)
%        jd.getschema() returns the current schema; jd.getschema('json') returns as JSON string
%        jd.validate() validates data against schema; [valid, errors] = jd.validate() returns error details
%
%        if using matlab, the .v(...) method can be replaced by bare
%        brackets .(...), but in octave, one must use .v(...)
%
%    indexing:
%        jd.('key1').('subkey1')... can retrieve values that are recursively index keys
%        jd.key1.subkey1... can also retrieve the same data regardless
%              if the underlying data is struct, containers.Map or dictionary
%        jd.('key1').('subkey1').v(1) if the subkey key1 is an array, this can retrieve the first element
%        jd.('key1').('subkey1').v(1).('subsubkey1') the indexing can be further applied for deeper objects
%        jd.('$.key1.subkey1') if the indexing starts with '$' this allows a JSONPath based index
%        jd.('$.key1.subkey1[0]') using a JSONPath can also read array-based subkey element
%        jd.('$.key1.subkey1[0].subsubkey1') JSONPath can also apply further indexing over objects of diverse types
%        jd.('$.key1..subkey') JSONPath can use '..' deep-search operator to find and retrieve subkey appearing at any level below
%
%    attributes:
%        jd.key1.getattr() lists all attributes of the current key
%        jd.key1.getattr('attrname') returns the attribute's value
%        jd.key1.setattr('attrname', val) sets the attribute for the current key
%        jd.key1{'attrname'} does the same as .getattr('attrname')
%        jd.key1{'attrname'}=val does the same as .setattr('attrname', val)
%        jd.key1{'dims'}={'x','y','z'} sets xarray-like dimension labels
%               if jd.key1 is an ND array (length must match)
%        jd.key1.x(1).y(2), after setting dims attribute, one can retrieve
%               ND array slices using the defined label names
%
%    JSON-schema and validation:
%        jd.setschema('/path/to/schema.json') defines the schema of the data
%        jd.validate() test the data with the schema and report disagreements
%        jd.key1{':type'}='integer' defines schema-attributes: all
%               schema-attribute names has the following format
%                             ':'+json_schema_keyword
%               supported json_schema_keyword include:
%                'type', 'enum', 'const', 'default', 'minimum', 'maximum',
%                'exclusiveMinimum', 'exclusiveMaximum', 'multipleOf',
%                'minLength', 'maxLength', 'pattern', 'format', 'items',
%                'minItems', 'maxItems', 'uniqueItems', 'contains',
%                'prefixItems', 'properties', 'required',
%                'additionalProperties', 'minProperties', 'maxProperties',
%                'patternProperties', 'propertyNames', 'dependentRequired',
%                'dependentSchemas', 'allOf', 'anyOf', 'oneOf', 'not',
%                'if', 'then', 'else', 'title', 'description', 'examples',
%                '$comment', '$ref', '$defs', 'definitions'
%        schema = jd.attr2schema('title', 'Nested Example') exports the
%               schema-attributes as a JSON schema object
%
%    examples:
%
%        jd = jdict;
%        jd.key1 = struct('subkey1',1, 'subkey2',[1,2,3]);
%        jd.key2 = 'str';
%        jd.key1.subkey3 = {8,'test',containers.Map('special key',10)};
%
%        % getting values
%        jd()                                   % return obj
%        jd.key1.subkey1                        % return jdict(1)
%        jd.('key1').('subkey1')                % same as above
%        jd.key1.('subkey1')                    % same as above
%        jd.key1.subkey3                        % return jdict(obj.key1.subkey3)
%        jd.key1.subkey3()                      % return obj.key1.subkey3
%        jd.key1.subkey3.v(1)                   % return jdict(8)
%        jd.key1.subkey3.v(3).('special key')   % return jdict(10)
%        jd.key1.subkey3.v(2).v()               % return 'test'
%        jd.('$.key1.subkey1')                  % return jdict(1)
%        jd.('$.key1.subkey2')()                % return 'str'
%        jd.('$.key1.subkey2').v().v(1)         % return jdict(1)
%        jd.('$.key1.subkey2')().v(1).v()       % return 1
%        jd.('$.key1.subkey3[2].subsubkey1')    % return jdict(0)
%        jd.('$..subkey2')                      % jsonpath '..' operator runs a deep scan, return jdict({'str', [1 2 3]})
%        jd.('$..subkey2').v(2)                 % return jdict([1,2,3])
%
%        % setting values
%        jd.subkey2 = 'newstr'                  % setting obj.subkey2 to 'newstr'
%        jd.key1.subkey2.v(1) = 2;              % modify indexed element
%        jd.key1.subkey2.v([2, 3]) = [10, 11];  % modify multiple values
%        jd.key1.subkey3.v(3).('special key') = 1;    % modify keyed value
%        jd.key1.newkey = 'new';                % add new key
%
%        % attributes
%        jd.vol = zeros(2,3,4);                 % set 3d arrays
%        jd.vol{'dims'} = {'x','y','z'};        % set dimension labels (MATLAB-only)
%        jd.vol.setattr('dims', {'x','y','z'}); % set attribute in Octave
%        jd.vol{'dims'}                         % print dimension names
%        jd.vol{'units'} = 'mm';                % set any custom attributes
%        jd.vol.getattr('units')                % retrieve attributes
%        jd.vol.getattr()                       % list all attributes of vol
%
%        % schema and schema-attributes
%        jd.subkey2.setattr(':type', 'string')
%        jd.subkey2.setattr(':minLength', 2)
%        jd.subkey2.setattr(':default', 'NA')
%        schema = jd.attr2schema()
%        jd.setschema(schema)
%        err = jd.validate()
%
%        % JSON Schema validation
%        jd = jdict(struct('name','John','age',30));
%        schema = struct('type','object',...
%            'properties',struct('name',struct('type','string'),...
%                                'age',struct('type','integer','minimum',0)),...
%            'required',{{'name','age'}});
%        jd.setschema(schema);
%        err = jd.validate();        % validate data against schema
%        jd.getschema('json')                   % get schema as JSON string
%
%        % loading complex data from REST-API
%        jd = jdict('https://neurojson.io:7777/cotilab/NeuroCaptain_2025');
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
% -- this function is part of JSONLab toolbox (http://neurojson.org/jsonlab)
%

classdef jdict < handle
    properties
        data    % underlying data: any matlab data (array, struct, cell, containers.Map, dictionary etc), retrieve via .v()
        attr    % data attributes, stored via a containers.Map with JSONPath-based keys, retrieve via .getattr() or {}
        schema  % JSON Schema for validation (struct), set via .setschema(), retrieve via .getschema()
    end
    properties (Access = private)
        flags__          % additional options, will be passed to jsonlab utility functions such as savejson/loadjson
        currentpath__    % internal variable tracking the current path when lookup embedded data at current depth
        root__           % reference to root jdict object for validated assignment
    end
    methods

        % constructor: initialize a jdict object
        function obj = jdict(val, varargin)
            obj.flags__ = getflags_();
            obj.attr = containers.Map();
            obj.schema = [];
            obj.currentpath__ = char(36);
            obj.root__ = obj;
            if (nargin >= 1)
                if (~isempty(varargin))
                    allflags = [varargin(1:2:end); varargin(2:2:end)];
                    obj.flags__ = mergestruct_(obj.flags__, struct(allflags{:}));
                    if (isfield(obj.flags__, 'attr'))
                        obj.attr = obj.flags__.attr;
                    end
                    if (isfield(obj.flags__, 'schema'))
                        obj.schema = obj.flags__.schema;
                    end
                end
                if (ischar(val) && ~isempty(regexpi(val, '^https*://', 'once')))
                    try
                        obj.data = obj.call_('loadjson', val);
                    catch
                        obj.data = val;
                    end
                    return
                end
                if (isa(val, 'jdict'))
                    obj.data = val.data;
                    obj.attr = val.attr;
                    obj.schema = val.schema;
                    obj.currentpath__ = val.currentpath__;
                    obj.flags__ = val.flags__;
                else
                    obj.data = val;
                end
            end
        end

        % overloaded numel to prevent subsref from outputting many outputs
        function n = numel(obj, varargin)
            if (obj.flags__.isoctave_)
                n = 1;
            else
                n = max(1, (nargin > 1) + numel(obj.data) * (nargin == 1));
            end
        end

        % overloaded indexing operator: handling assignments at arbitrary depths
        function varargout = subsref(obj, idxkey)
            % overloading the getter function jd.('key').('subkey')

            oplen = length(idxkey);
            varargout = cell(1, max(1, nargout));

            % handle {} indexing for attributes
            if (oplen == 1 && strcmp(idxkey(1).type, '{}'))
                if (iscell(idxkey(1).subs) && length(idxkey(1).subs) == 1 && ischar(idxkey(1).subs{1}))
                    varargout{1} = obj.getattr(obj.currentpath__, idxkey(1).subs{1});
                    return
                end
            end

            val = obj.data;
            trackpath = obj.currentpath__;

            if (oplen == 1 && strcmp(idxkey(1).type, '()') && isempty(idxkey(1).subs))
                varargout{1} = val;
                return
            end
            i = 1;
            while i <= oplen
                idx = idxkey(i);
                if (isempty(idx.subs))
                    i = i + 1;
                    continue
                end

                % handle {} attribute access in navigation chain
                if (strcmp(idx.type, '{}') && iscell(idx.subs) && length(idx.subs) == 1 && ischar(idx.subs{1}))
                    val = obj.getattr(trackpath, idx.subs{1});
                    i = i + 1;
                    continue
                end

                if (strcmp(idx.type, '.') && isnumeric(idx.subs))
                    val = val(idx.subs);
                elseif ((strcmp(idx.type, '()') || strcmp(idx.type, '.')) && ischar(idx.subs) && ismember(idx.subs, {'tojson', 'fromjson', 'v', 'isKey', 'keys', 'len', 'size', 'setattr', 'getattr', 'setschema', 'getschema', 'validate', 'attr2schema'}) && i < oplen && strcmp(idxkey(i + 1).type, '()'))
                    if (strcmp(idx.subs, 'v'))
                        if (iscell(val) && strcmp(idxkey(i + 1).type, '()'))
                            idxkey(i + 1).type = '{}';
                        end
                        if (~isempty(idxkey(i + 1).subs))
                            tempobj = jdict(val);
                            tempobj.attr = obj.attr;
                            tempobj.schema = obj.schema;
                            tempobj.currentpath__ = trackpath;
                            val = v(tempobj, idxkey(i + 1));
                        elseif (isa(val, 'jdict'))
                            val = val.data;
                        end
                    else
                        tempobj = jdict(val);
                        tempobj.attr = obj.attr;
                        tempobj.schema = obj.schema;
                        tempobj.currentpath__ = trackpath;
                        if (obj.flags__.isoctave_ && regexp(OCTAVE_VERSION, '^5\.'))
                            val = membercall_(tempobj, idx.subs, idxkey(i + 1).subs{:});
                        else
                            fhandle = str2func(idx.subs);
                            val = fhandle(tempobj, idxkey(i + 1).subs{:});
                        end
                        if (i == oplen - 1 && ismember(idx.subs, {'isKey', 'tojson', 'getattr', 'getschema', 'setschema', 'validate', 'attr2schema'}))
                            if (strcmp(idx.subs, 'setschema'))
                                obj.schema = tempobj.schema;
                            end
                            varargout{1} = val;
                            return
                        end
                    end
                    i = i + 1;
                    if (i < oplen)
                        tempobj = jdict(val);
                        tempobj.attr = obj.attr;
                        tempobj.schema = obj.schema;
                        tempobj.currentpath__ = trackpath;
                        val = tempobj;
                    end
                elseif ((strcmp(idx.type, '.') && ischar(idx.subs)) || (iscell(idx.subs) && ~isempty(idx.subs{1})))
                    onekey = idx.subs;
                    if (iscell(onekey))
                        onekey = onekey{1};
                    end
                    if (isa(val, 'jdict'))
                        val = val.data;
                    end

                    % check if dimension-based indexing
                    dims = obj.getattr(trackpath, 'dims');
                    if (~isempty(dims) && iscell(dims) && i < oplen && strcmp(idxkey(i + 1).type, '()'))
                        dimpos = find(strcmp(dims, onekey));
                        if (~isempty(dimpos) && ~isempty(idxkey(i + 1).subs))
                            nddata = length(dims);
                            indices = repmat({':'}, 1, nddata);
                            indices{dimpos(1)} = idxkey(i + 1).subs{1};
                            subsargs = struct('type', '()', 'subs', {indices});
                            val = subsref(val, subsargs);
                            newobj = jdict(val);
                            newobj.attr = obj.attr;
                            newobj.schema = obj.schema;
                            newobj.currentpath__ = trackpath;
                            newobj.root__ = obj.root__;
                            val = newobj;
                            i = i + 2;
                            continue
                        end
                    end
                    escapedonekey = esckey_(onekey);
                    if (ischar(onekey) && ~isempty(onekey) && onekey(1) == char(36))
                        val = obj.call_('jsonpath', val, onekey);
                        trackpath = escapedonekey;
                    elseif (isstruct(val))
                        % check if struct array - if so, get field from all elements
                        hasfield = isfield(val, onekey);
                        if (numel(val) > 1 && hasfield)
                            % struct array - extract field from all elements
                            val = {val.(onekey)};
                            if (all(cellfun(@isnumeric, val)) && all(cellfun(@(x) isequal(size(x), size(val{1})), val)))
                                % try to concatenate if all same size numeric
                                try
                                    val = cat(ndims(val{1}) + 1, val{:});
                                catch
                                    % keep as cell if concatenation fails
                                end
                            end
                            trackpath = [trackpath '.' escapedonekey];
                            % check if next operation is () for indexing the result
                            if (i < oplen && strcmp(idxkey(i + 1).type, '()') && ~isempty(idxkey(i + 1).subs))
                                subsargs = struct('type', '()', 'subs', idxkey(i + 1).subs);
                                val = subsref(val, subsargs);
                                i = i + 2;
                                continue
                            end
                        elseif hasfield
                            % single struct with existing field
                            val = val.(onekey);
                            trackpath = [trackpath '.' escapedonekey];
                        else
                            % field does not exist - return empty for <= assignment
                            val = [];
                            trackpath = [trackpath '.' escapedonekey];
                        end
                    elseif (ismap_(obj.flags__, val))
                        if isKey(val, onekey)
                            val = val(onekey);
                        else
                            % key does not exist - return empty for <= assignment
                            val = [];
                        end
                        trackpath = [trackpath '.' escapedonekey];
                    else
                        % data is empty or other type - return empty for <= assignment
                        val = [];
                        trackpath = [trackpath '.' escapedonekey];
                    end
                else
                    error('method not supported');
                end
                i = i + 1;
            end

            if ((strcmp(idxkey(end).type, '{}') && iscell(idxkey(end).subs) && length(idxkey(end).subs) == 1 && ischar(idxkey(end).subs{1})))
                varargout{1} = val;
                return
            elseif (~(isempty(idxkey(end).subs) && (strcmp(idxkey(end).type, '()') || strcmp(idxkey(end).type, '{}'))))
                newobj = jdict(val);
                attrkeys = keys(obj.attr);
                newobj.attr = containers.Map();
                for i = 1:length(attrkeys)
                    if (strncmp(attrkeys{i}, trackpath, length(trackpath)))
                        newobj.attr(strrep(attrkeys{i}, trackpath, char(36))) = obj.attr(attrkeys{i});
                    end
                end
                newobj.schema = obj.schema;
                newobj.currentpath__ = trackpath;
                newobj.root__ = obj.root__;
                val = newobj;
            end
            varargout{1} = val;
        end

        % overloaded assignment operator: handling assignments at arbitrary depths
        function obj = subsasgn(obj, idxkey, otherobj)
            % overloading the setter function, obj.('key').('subkey')=otherobj
            % expanded from rahnema1's sample at https://stackoverflow.com/a/79030223/4271392

            % handle curly bracket indexing for setting attributes
            oplen = length(idxkey);
            if (oplen == 1 && strcmp(idxkey(1).type, '{}'))
                if (iscell(idxkey(1).subs) && ~isempty(idxkey(1).subs))
                    attrn = idxkey(1).subs{1};
                    if (ischar(attrn))
                        obj.setattr(obj.currentpath__, attrn, otherobj);
                        return
                    end
                end
            end

            % handle compound indexing like jd.('a'){'dims'} = value
            if (oplen >= 2 && strcmp(idxkey(oplen).type, '{}'))
                if (iscell(idxkey(oplen).subs) && ~isempty(idxkey(oplen).subs))
                    attrn = idxkey(oplen).subs{1};
                    if (ischar(attrn))
                        % Build the path by navigating through keys
                        temppath = obj.currentpath__;
                        for i = 1:oplen - 1
                            idx = idxkey(i);
                            if (strcmp(idx.type, '.') || strcmp(idx.type, '()'))
                                if (iscell(idx.subs))
                                    onekey = idx.subs{1};
                                else
                                    onekey = idx.subs;
                                end
                                escapedonekey = esckey_(onekey);
                                if (ischar(onekey) && ~isempty(onekey))
                                    if (onekey(1) ~= char(36))
                                        temppath = [temppath '.' escapedonekey];
                                    else
                                        temppath = escapedonekey;
                                    end
                                end
                            end
                        end
                        % set attribute on original object with computed path
                        obj.setattr(temppath, attrn, otherobj);
                        return
                    end
                end
            end

            % handle dimension-based assignment like jd.time(1:10) = newval
            if (oplen >= 2 && strcmp(idxkey(oplen).type, '()'))
                if (strcmp(idxkey(oplen - 1).type, '.') && ischar(idxkey(oplen - 1).subs))
                    dimname = idxkey(oplen - 1).subs;
                    % build path to the data
                    temppath = obj.currentpath__;
                    for i = 1:oplen - 2
                        idx = idxkey(i);
                        if (strcmp(idx.type, '.') || strcmp(idx.type, '()'))
                            if (iscell(idx.subs))
                                onekey = idx.subs{1};
                            else
                                onekey = idx.subs;
                            end
                            escapedonekey = esckey_(onekey);
                            if (ischar(onekey) && ~isempty(onekey))
                                if (onekey(1) ~= char(36))
                                    temppath = [temppath '.' escapedonekey];
                                else
                                    temppath = escapedonekey;
                                end
                            end
                        end
                    end
                    % check if dimname is in dims
                    dims = obj.getattr(temppath, 'dims');
                    if (~isempty(dims) && iscell(dims))
                        dimpos = find(strcmp(dims, dimname));
                        if (~isempty(dimpos) && ~isempty(idxkey(oplen).subs))
                            % build full indices
                            nddata = length(dims);
                            indices = repmat({':'}, 1, nddata);
                            indices{dimpos(1)} = idxkey(oplen).subs{1};
                            % perform assignment
                            subsargs = struct('type', '()', 'subs', {indices});
                            if (oplen > 2)
                                % need to assign back through the chain
                                subidx = idxkey(1:oplen - 2);
                                tempdata = subsref(obj.data, subidx);
                                tempdata = subsasgn(tempdata, subsargs, otherobj);
                                obj.data = subsasgn(obj.data, subidx, tempdata);
                            else
                                obj.data = subsasgn(obj.data, subsargs, otherobj);
                            end
                            return
                        end
                    end
                end
            end

            % Fast path: single-level assignment like jd.key = value
            if (oplen == 1 && strcmp(idxkey(1).type, '.') && ischar(idxkey(1).subs))
                fieldname = idxkey(1).subs;
                % Skip if JSONPath
                if (isempty(fieldname) || fieldname(1) ~= char(36))
                    if (isempty(obj.data))
                        obj.data = struct();
                    end
                    if isstruct(obj.data)
                        try
                            obj.data.(fieldname) = otherobj;
                            return
                        catch
                            % Field name invalid for struct, convert to Map
                            fnames = fieldnames(obj.data);
                            if (~isempty(fnames))
                                obj.data = containers.Map(fnames, struct2cell(obj.data), 'UniformValues', 0);
                            else
                                obj.data = containers.Map;
                            end
                            obj.data(fieldname) = otherobj;
                            return
                        end
                    elseif ismap_(obj.flags__, obj.data)
                        obj.data(fieldname) = otherobj;
                        return
                    end
                end
            end

            % Fast path: single numeric index like jd.(1) = value
            if (oplen == 1 && strcmp(idxkey(1).type, '.') && isnumeric(idxkey(1).subs))
                newidx = idxkey(1).subs;
                if isstruct(obj.data) && isstruct(otherobj)
                    fnames = fieldnames(obj.data);
                    if isempty(fnames) || numel(obj.data) == 0
                        objfnames = fieldnames(otherobj);
                        if newidx == 1
                            obj.data = otherobj;
                        else
                            for fi = 1:length(objfnames)
                                obj.data(newidx).(objfnames{fi}) = otherobj.(objfnames{fi});
                            end
                        end
                    else
                        if newidx > numel(obj.data)
                            for fi = 1:length(fnames)
                                obj.data(newidx).(fnames{fi}) = [];
                            end
                        end
                        reordered = struct();
                        for fi = 1:length(fnames)
                            if isfield(otherobj, fnames{fi})
                                reordered.(fnames{fi}) = otherobj.(fnames{fi});
                            else
                                reordered.(fnames{fi}) = [];
                            end
                        end
                        obj.data(newidx) = reordered;
                    end
                elseif iscell(obj.data)
                    obj.data{newidx} = otherobj;
                else
                    obj.data(newidx) = otherobj;
                end
                return
            end

            oplen = length(idxkey);
            opcell = cell(1, oplen + 1);
            if (isempty(obj.data))
                obj.data = obj.newkey_();
            end
            opcell{1} = obj.data;

            % forward value extraction loop
            for i = 1:oplen
                idx = idxkey(i);
                if (strcmp(idx.type, '.'))
                    % Handle numeric indexing: person.(1), person.(2), etc.
                    if isnumeric(idx.subs)
                        newidx = idx.subs;
                        if isstruct(opcell{i}) && isscalar(newidx) && newidx > numel(opcell{i})
                            fnames = fieldnames(opcell{i});
                            for fi = 1:length(fnames)
                                opcell{i}(newidx).(fnames{fi}) = [];
                            end
                        elseif iscell(opcell{i}) && isscalar(newidx) && newidx > numel(opcell{i})
                            opcell{i}{newidx} = [];
                        end
                        if iscell(opcell{i})
                            opcell{i + 1} = opcell{i}{newidx};
                        else
                            opcell{i + 1} = opcell{i}(newidx);
                        end
                        continue
                    end
                    if (ischar(idx.subs) && strcmp(idx.subs, 'v') && i < oplen && strcmp(idxkey(i + 1).type, '()'))
                        % expand struct or cell when using .v(index) more
                        % than the length
                        nextsubs = idxkey(i + 1).subs;
                        if iscell(nextsubs)
                            nextsubs = nextsubs{1};
                        end
                        if isnumeric(nextsubs) && isscalar(nextsubs)
                            if isstruct(opcell{i}) && nextsubs > numel(opcell{i})
                                fnames = fieldnames(opcell{i});
                                if (~isempty(fnames))
                                    for fi = 1:length(fnames)
                                        opcell{i}(nextsubs).(fnames{fi}) = [];
                                    end
                                end
                            elseif iscell(opcell{i}) && nextsubs > numel(opcell{i})
                                opcell{i}{nextsubs} = [];
                            end
                        end
                        opcell{i + 1} = opcell{i};
                        if iscell(opcell{i})
                            idxkey(i + 1).type = '{}';
                        end
                        continue
                    end
                    if (ischar(idx.subs) && ~(~isempty(idx.subs) && idx.subs(1) == char(36)))
                        % Handle empty or non-struct/map data
                        if isempty(opcell{i}) || (~isstruct(opcell{i}) && ~ismap_(obj.flags__, opcell{i}))
                            opcell{i} = obj.newkey_();
                        end
                        if (ismap_(obj.flags__, opcell{i}) && ~isKey(opcell{i}, idx.subs))
                            idx.type = '()';
                            opcell{i}(idx.subs) = obj.newkey_();
                        elseif (isstruct(opcell{i}) && ~isfield(opcell{i}, idx.subs))
                            try
                                opcell{i}.(idx.subs) = obj.newkey_();
                            catch
                                fnames = fieldnames(opcell{i});
                                if (~isempty(fnames))
                                    opcell{i} = containers.Map(fnames, struct2cell(opcell{i}), 'UniformValues', 0);
                                else
                                    opcell{i} = containers.Map;
                                end
                                opcell{i}(idx.subs) = obj.newkey_();
                            end
                        end
                    end
                end
                if (ischar(idx.subs) && ~isempty(idx.subs) && idx.subs(1) == char(36))
                    opcell{i + 1} = obj.call_('jsonpath', opcell{i}, idx.subs);
                elseif (ismap_(obj.flags__, opcell{i}))
                    opcell{i + 1} = opcell{i}(idx.subs);
                else
                    opcell{i + 1} = subsref(opcell{i}, idx);
                end
            end

            if (oplen >= 2 && ischar(idxkey(oplen - 1).subs) && strcmp(idxkey(oplen - 1).subs, 'v') && strcmp(idxkey(oplen).type, '()'))
                % Handle .v(index) = value at any depth
                nextsubs = idxkey(oplen).subs;
                if iscell(nextsubs)
                    nextsubs = nextsubs{1};
                end
                if iscell(opcell{oplen})
                    opcell{oplen}{nextsubs} = otherobj;
                elseif isstruct(opcell{oplen}) && isempty(fieldnames(opcell{oplen}))
                    % Empty struct with no fields - just replace
                    opcell{oplen} = otherobj;
                else
                    opcell{oplen}(nextsubs) = otherobj;
                end
                opcell{oplen + 1} = opcell{oplen};
            elseif (obj.flags__.isoctave_) && (ismap_(obj.flags__, opcell{oplen}))
                opcell{oplen}(idx.subs) = otherobj;
                opcell{oplen + 1} = opcell{oplen};
            else
                if (ischar(idx.subs) && ~isempty(idx.subs) && idx.subs(1) == char(36))
                    opcell{oplen + 1} = obj.call_('jsonpath', opcell{oplen}, idx.subs, otherobj);
                else
                    if (ismap_(obj.flags__, opcell{oplen}))
                        idx = struct('type', '()', 'subs', idx.subs);
                    end
                    try
                        opcell{oplen + 1} = subsasgn(opcell{oplen}, idx, otherobj);
                    catch
                        opcell{oplen}.(idx.subs) = otherobj;
                        opcell{oplen + 1} = opcell{oplen};
                    end
                end
            end

            % Propagate result for backward loop
            opcell{oplen} = opcell{oplen + 1};

            % backward assignment along the reversed path
            for i = oplen - 1:-1:1
                idx = idxkey(i);
                if (ischar(idx.subs) && strcmp(idx.type, '.') && ismap_(obj.flags__, opcell{i}))
                    idx.type = '()';
                end

                % Handle numeric indexing in backward loop
                if (strcmp(idx.type, '.') && isnumeric(idx.subs))
                    newidx = idx.subs;
                    if iscell(opcell{i})
                        opcell{i}{newidx} = opcell{i + 1};
                    else
                        opcell{i}(newidx) = opcell{i + 1};
                    end
                    continue
                end

                if (ischar(idx.subs) && strcmp(idx.subs, 'v') && i < oplen && ismember(idxkey(i + 1).type, {'()', '{}'}))
                    opcell{i} = opcell{i + 1};
                    continue
                end

                if (i > 1 && ischar(idxkey(i - 1).subs) && strcmp(idxkey(i - 1).subs, 'v'))
                    if (~isempty(idx.subs) && (iscell(opcell{i}) || (isstruct(opcell{i}) && ~isempty(fieldnames(opcell{i})))))
                        % Add missing fields to opcell{i} if opcell{i+1} has more fields
                        if isstruct(opcell{i}) && isstruct(opcell{i + 1})
                            newfields = fieldnames(opcell{i + 1});
                            for fi = 1:length(newfields)
                                if ~isfield(opcell{i}, newfields{fi})
                                    [opcell{i}.(newfields{fi})] = deal([]);
                                end
                            end
                        end
                        opcell{i} = subsasgn(opcell{i}, idx, opcell{i + 1});
                    else
                        opcell{i} = opcell{i + 1};
                    end
                elseif (ischar(idx.subs) && ~isempty(idx.subs) && idx.subs(1) == char(36))
                    opcell{i} = obj.call_('jsonpath', opcell{i}, idx.subs, opcell{i + 1});
                else
                    try
                        if (obj.flags__.isoctave_) && (ismap_(obj.flags__, opcell{i}))
                            opcell{i}(idx.subs) = opcell{i + 1};
                        else
                            opcell{i} = subsasgn(opcell{i}, idx, opcell{i + 1});
                        end
                    catch
                        opcell{i}.(idx.subs) = opcell{i + 1};
                    end
                end
            end

            obj.data = opcell{1};
        end

        % export data to json, binary JSON, or other over a dozen formats
        function val = tojson(obj, varargin)
            % printing underlying data to compact-formed JSON string
            val = obj.call_('savejd', '', obj, 'compact', 1, varargin{:});
        end

        % load data from over a dozen data formats, including json and binary json
        function obj = fromjson(obj, fname, varargin)
            obj.data = obj.call_('loadjd', fname, varargin{:});
        end

        function val = keys(obj)
            if (isstruct(obj.data))
                val = builtin('fieldnames', obj.data);
            elseif (ismap_(obj.flags__, obj.data))
                val = keys(obj.data);
            else
                val = 1:length(obj.data);
            end
        end

        function val = fieldnames(obj)
            val = keys(obj);
        end

        % test if a key or index exists
        function val = isKey(obj, key)
            % list subfields at the current level
            if (isstruct(obj.data))
                val = isfield(obj.data, key);
            elseif (ismap_(obj.flags__, obj.data))
                val = isKey(obj.data, key);
            else
                val = (key < length(obj.data));
            end
        end

        % return the number of subfields or array length
        function val = len(obj)
            % return the number of subfields at the current level
            if (isstruct(obj.data))
                val = length(fieldnames(obj.data));
            else
                val = length(obj.data);
            end
        end

        % return the dimension vector
        function val = size(obj)
            % return the dimension vector of the data
            val = size(obj.data);
        end

        % return the enclosed data
        function val = v(obj, varargin)
            if (~isempty(varargin))
                val = subsref(obj.data, varargin{:});
            else
                val = obj.data;
            end
        end

        % internal: insert new key if does not exist
        function val = newkey_(obj)
            val = struct;
        end

        function val = membercall_(obj, method, varargin)
            switch method
                case 'tojson'
                    val = tojson(obj);
                case 'fromjson'
                    val = fromjson(obj, varargin{:});
                case 'v'
                    val = v(obj);
                case 'isKey'
                    val = isKey(obj, varargin{:});
                case 'keys'
                    val = keys(obj);
                case 'len'
                    val = len(obj);
                case 'size'
                    val = size(obj);
                case 'setattr'
                    val = setattr(obj, varargin{:});
                case 'getattr'
                    val = getattr(obj, varargin{:});
                case 'setschema'
                    val = setschema(obj, varargin{:});
                case 'getschema'
                    val = getschema(obj, varargin{:});
                case 'validate'
                    val = validate(obj, varargin{:});
                case 'attr2schema'
                    val = attr2schema(obj, varargin{:});
            end
        end

        % internal: call member functions or external functions
        function varargout = call_(obj, func, varargin)
            % interface to external functions and dependencies
            if (~obj.flags__.builtinjson)
                if (~exist('loadjson', 'file'))
                    error('you must first install jsonlab (https://github.com/NeuroJSON/jsonlab) or set "BuildinJSON" flag to 1');
                end
                fhandle = str2func(func);
                [varargout{1:nargout}] = fhandle(varargin{:});
            else
                if (~exist('jsonencode', 'builtin') && ~strcmp(func, 'jsonpath'))
                    error('jsonencode/jsondecode are not available, please install jsonlab (https://github.com/NeuroJSON/jsonlab) and set "BuiltinJSON" flag to 0');
                end
                switch func
                    case 'loadjson'
                        [varargout{1:nargout}] = jsondecode(webread(varargin{:}));
                    case 'savejson'
                        [varargout{1:nargout}] = jsonencode(varargin{:});
                    case 'jsonpath'
                        error('please install jsonlab (https://github.com/NeuroJSON/jsonlab) and set "BuiltinJSON" flag to 0');
                end
            end
        end

        % set specified data attributes
        function attr = setattr(obj, jsonpath, attrname, attrvalue)
            if (nargin == 3)
                attrvalue = attrname;
                attrname = jsonpath;
                jsonpath = obj.currentpath__;
            end
            if (~isKey(obj.attr, jsonpath))
                obj.attr(jsonpath) = containers.Map();
            end
            attrmap = obj.attr(jsonpath);
            attrmap(attrname) = attrvalue;
            obj.attr(jsonpath) = attrmap;
            attr = obj.attr;
        end

        % return specified data attributes, if not specified, list all attributes
        function val = getattr(obj, jsonpath, attrname)
            val = [];
            if (nargin == 1)
                if (~isKey(obj.attr, obj.currentpath__) && strcmp(obj.currentpath__, char(36)))
                    val = keys(obj.attr);    % list root-level attr keys
                elseif (isKey(obj.attr, obj.currentpath__))
                    val = keys(obj.attr(obj.currentpath__));
                end
                return
            end
            if (nargin == 2)
                if (~isempty(jsonpath) && jsonpath(1) ~= char(36))
                    attrname = jsonpath;
                    jsonpath = obj.currentpath__;
                else
                    attrname = '';
                end
            end
            if (~isKey(obj.attr, jsonpath))
                return
            end
            attrmap = obj.attr(jsonpath);
            if (isempty(attrname))
                val = attrmap;
            elseif (isKey(attrmap, attrname))
                val = attrmap(attrname);
            end
        end

        % set JSON Schema for data validation
        function obj = setschema(obj, schemadata)

            if (nargin < 2 || isempty(schemadata))
                obj.schema = [];
                return
            end

            if (isa(schemadata, 'containers.Map'))
                obj.schema = schemadata;
            elseif (ischar(schemadata) || isa(schemadata, 'string') || isstruct(schemadata))
                if (isstruct(schemadata))
                    schemadata = savejson('', schemadata);
                end
                % load as containers.Map to preserve special keys like $ref
                obj.schema = obj.call_('loadjson', char(schemadata), 'usemap', 1);
            else
                error('Schema must be a containers.Map, JSON string, URL, or file path');
            end
        end

        % get the current JSON Schema
        function schemaOut = getschema(obj, format)
            if (isempty(obj.schema))
                schemaOut = [];
                return
            end

            if (nargin >= 2 && (strcmpi(format, 'json') || strcmpi(format, 'string')))
                schemaOut = obj.call_('savejson', '', obj.schema, 'compact', 1);
            else
                schemaOut = obj.schema;
            end
        end

        % validate data against JSON Schema
        function errors = validate(obj, schemadata)
            if nargin >= 2 && ~isempty(schemadata)
                obj.setschema(schemadata);
            end

            if isempty(obj.schema)
                error('No schema available. Use setschema() first or provide schema as argument.');
            end

            subschema = obj.call_('jsonschema', obj.schema, [], ...
                                  'getsubschema', obj.currentpath__);

            if isempty(subschema)
                errors = {};
                return
            end

            [temp, errors] = obj.call_('jsonschema', obj.data, subschema, ...
                                       'rootschema', obj.schema);
        end

        % convert attributes to JSON Schema
        function schema = attr2schema(obj, varargin)
            opt = varargin2struct(varargin{:});
            schematitle = jsonopt('title', '', opt);
            schemadesc = jsonopt('description', '', opt);

            schemaKeywords = {'type', 'enum', 'const', 'default', ...
                              'minimum', 'maximum', 'exclusiveMinimum', 'exclusiveMaximum', 'multipleOf', ...
                              'minLength', 'maxLength', 'pattern', 'format', ...
                              'items', 'minItems', 'maxItems', 'uniqueItems', 'contains', 'prefixItems', ...
                              'properties', 'required', 'additionalProperties', 'minProperties', 'maxProperties', ...
                              'patternProperties', 'propertyNames', 'dependentRequired', 'dependentSchemas', ...
                              'allOf', 'anyOf', 'oneOf', 'not', 'if', 'then', 'else', ...
                              'title', 'description', 'examples', '$comment', '$ref', '$defs', 'definitions'};

            schema = struct;

            % Add title/description at root
            if strcmp(obj.currentpath__, char(36))
                if ~isempty(schematitle)
                    schema.('title') = schematitle;
                end
                if ~isempty(schemadesc)
                    schema.('description') = schemadesc;
                end
            end

            % Get all attribute paths
            allpaths = keys(obj.attr);
            basepath = obj.currentpath__;
            baselen = length(basepath);

            % Extract schema attributes at current path
            pathAttrs = obj.getattr(basepath);
            if ~isempty(pathAttrs) && isa(pathAttrs, 'containers.Map')
                attrkeys = keys(pathAttrs);
                for i = 1:length(attrkeys)
                    aname = attrkeys{i};
                    if length(aname) > 1 && aname(1) == ':'
                        keyword = aname(2:end);
                        for j = 1:length(schemaKeywords)
                            if strcmp(keyword, schemaKeywords{j})
                                schema.(keyword) = pathAttrs(aname);
                                break
                            end
                        end
                    end
                end
            end

            % Find direct children paths
            childpaths = {};
            for i = 1:length(allpaths)
                p = allpaths{i};
                if length(p) > baselen && strncmp(p, basepath, baselen)
                    if strcmp(basepath, char(36))
                        if length(p) > 2 && p(2) == '.'
                            remainder = p(3:end);
                        else
                            continue
                        end
                    else
                        if length(p) > baselen + 1 && p(baselen + 1) == '.'
                            remainder = p((baselen + 2):end);
                        else
                            continue
                        end
                    end
                    % Check if direct child (no unescaped dots)
                    unescaped = strrep(remainder, '\.', '');
                    if isempty(strfind(unescaped, '.'))
                        childpaths{end + 1} = p;
                    end
                end
            end

            % Build properties from child paths
            if ~isempty(childpaths)
                if ~isfield(schema, 'type')
                    schema.('type') = 'object';
                end

                objproperties = struct;
                for i = 1:length(childpaths)
                    childpath = childpaths{i};

                    % Extract property name from path
                    if strcmp(basepath, char(36))
                        propname = childpath(3:end);
                    else
                        propname = childpath((baselen + 2):end);
                    end
                    % Unescape dots in property name
                    propname = strrep(propname, '\.', '.');

                    % Recursively build child schema
                    tempobj = jdict();
                    tempobj.attr = obj.attr;
                    tempobj.currentpath__ = childpath;
                    objproperties.(propname) = attr2schema(tempobj);
                end
                schema.('properties') = objproperties;
            end

            % Only set default type to 'object' at root level if there are properties
            if ~isfield(schema, 'type')
                if ~isempty(childpaths)
                    schema.('type') = 'object';
                elseif strcmp(obj.currentpath__, char(36))
                    schema.('type') = 'object';
                end
            end
        end

        % overload <= operator for schema-validated assignment
        function result = le(obj, value)
            % validate against schema if defined
            if ~isempty(obj.schema)
                subschema = obj.call_('jsonschema', obj.schema, [], ...
                                      'getsubschema', obj.currentpath__);

                % if subschema found for this path, validate
                if ~isempty(subschema)
                    [valid, errs] = obj.call_('jsonschema', value, subschema, ...
                                              'rootschema', obj.schema);
                    if ~valid
                        errmsg = sprintf('Schema validation failed for "%s":', ...
                                         obj.currentpath__);
                        for i = 1:length(errs)
                            errmsg = [errmsg ' ' errs{i} ';'];
                        end
                        error(errmsg);
                    end
                end
            end

            % assign via root object
            if strcmp(obj.currentpath__, char(36))
                obj.root__.data = value;
            else
                % parse currentpath__ to build index keys
                % remove leading $. if present
                path = obj.currentpath__;
                if length(path) > 2 && path(1) == char(36) && path(2) == '.'
                    path = path(3:end);
                elseif path(1) == char(36)
                    path = path(2:end);
                end

                % split by unescaped dots
                parts = {};
                current = '';
                k = 1;
                while k <= length(path)
                    if k < length(path) && path(k) == '\' && path(k + 1) == '.'
                        current = [current '.'];
                        k = k + 2;
                    elseif path(k) == '.'
                        if ~isempty(current)
                            parts{end + 1} = current;
                        end
                        current = '';
                        k = k + 1;
                    else
                        current = [current path(k)];
                        k = k + 1;
                    end
                end
                if ~isempty(current)
                    parts{end + 1} = current;
                end

                % build idxkey array for subsasgn
                idxkey = struct('type', {}, 'subs', {});
                for k = 1:length(parts)
                    idxkey(k).type = '.';
                    idxkey(k).subs = parts{k};
                end

                % call subsasgn on root object
                subsasgn(obj.root__, idxkey, value);
            end
            result = obj.root__;
        end

    end
end

%% ========================================================================
%% Helper functions (outside class for persistent caching)
%% ========================================================================

% cached platform flags - called once per session
function flags = getflags_()
    persistent cachedflags
    if isempty(cachedflags)
        cachedflags = struct();
        cachedflags.builtinjson = 0;
        cachedflags.isoctave_ = exist('OCTAVE_VERSION', 'builtin') ~= 0;
        try
            containers.Map();
            cachedflags.hasmap_ = true;
        catch
            cachedflags.hasmap_ = false;
        end
        try
            dictionary();
            cachedflags.hasdict_ = true;
        catch
            cachedflags.hasdict_ = false;
        end
    end
    flags = cachedflags;
end

% merge two structs
function s = mergestruct_(base, override)
    s = base;
    fnames = fieldnames(override);
    for i = 1:length(fnames)
        s.(fnames{i}) = override.(fnames{i});
    end
end

% check if value is a map type
function tf = ismap_(flags, val)
    tf = isa(val, 'containers.Map') || (flags.hasdict_ && isa(val, 'dictionary'));
end

% escape dots in key for JSONPath
function escaped = esckey_(key)
    escaped = regexprep(key, '(?<=[^\\]|^)\.', '\\.');
end
