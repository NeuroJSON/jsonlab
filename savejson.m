function output = savejson(rootname, obj, varargin)
%
% json=savejson(obj)
%    or
% json=savejson(rootname,obj,filename)
% json=savejson(rootname,obj,opt)
% json=savejson(rootname,obj,'param1',value1,'param2',value2,...)
%
% convert a MATLAB object (cell, struct or array) into a JSON (JavaScript
% Object Notation) string
%
% author: Qianqian Fang (q.fang <at> neu.edu)
% initially created on 2011/09/09
%
% input:
%      rootname: the name of the root-object, when set to '', the root name
%           is ignored, however, when opt.ForceRootName is set to 1 (see below),
%           the MATLAB variable name will be used as the root name.
%      obj: a MATLAB object (array, cell, cell array, struct, struct array,
%           class instance).
%      filename: a string for the file name to save the output JSON data.
%      opt: a struct for additional options, ignore to use default values.
%           opt can have the following fields (first in [.|.] is the default)
%
%           FileName [''|string]: a file name to save the output JSON data
%           FloatFormat ['%.16g'|string]: format to show each numeric element
%                         of a 1D/2D array;
%           IntFormat ['%.0f'|string]: format to display integer elements
%                         of a 1D/2D array;
%           ArrayIndent [1|0]: if 1, output explicit data array with
%                         precedent indentation; if 0, no indentation
%           ArrayToStruct[0|1]: when set to 0, savejson outputs 1D/2D
%                         array in JSON array format; if sets to 1, an
%                         array will be shown as a struct with fields
%                         "_ArrayType_", "_ArraySize_" and "_ArrayData_"; for
%                         sparse arrays, the non-zero elements will be
%                         saved to _ArrayData_ field in triplet-format i.e.
%                         (ix,iy,val) and "_ArrayIsSparse_" will be added
%                         with a value of 1; for a complex array, the
%                         _ArrayData_ array will include two columns
%                         (4 for sparse) to record the real and imaginary
%                         parts, and also "_ArrayIsComplex_":1 is added.
%           NestArray    [0|1]: If set to 1, use nested array constructs
%                         to store N-dimensional arrays; if set to 0,
%                         use the annotated array format defined in the
%                         JData Specification (Draft 1 or later).
%           ParseLogical [0|1]: if this is set to 1, logical array elem
%                         will use true/false rather than 1/0.
%           SingletArray [0|1]: if this is set to 1, arrays with a single
%                         numerical element will be shown without a square
%                         bracket, unless it is the root object; if 0, square
%                         brackets are forced for any numerical arrays.
%           SingletCell  [1|0]: if 1, always enclose a cell with "[]"
%                         even it has only one element; if 0, brackets
%                         are ignored when a cell has only 1 element.
%           EmptyArrayAsNull  [0|1]: if set to 1, convert an empty array to
%                         JSON null object; empty cells remain mapped to []
%           ForceRootName [0|1]: when set to 1 and rootname is empty, savejson
%                         will use the name of the passed obj variable as the
%                         root object name; if obj is an expression and
%                         does not have a name, 'root' will be used; if this
%                         is set to 0 and rootname is empty, the root level
%                         will be merged down to the lower level.
%           Inf ['"$1_Inf_"'|string]: a customized regular expression pattern
%                         to represent +/-Inf. The matched pattern is '([-+]*)Inf'
%                         and $1 represents the sign. For those who want to use
%                         1e999 to represent Inf, they can set opt.Inf to '$11e999'
%           NaN ['"_NaN_"'|string]: a customized regular expression pattern
%                         to represent NaN
%           JSONP [''|string]: to generate a JSONP output (JSON with padding),
%                         for example, if opt.JSONP='foo', the JSON data is
%                         wrapped inside a function call as 'foo(...);'
%           UnpackHex [1|0]: convert the 0x[hex code] output by loadjson
%                         back to the string form
%           SaveBinary [1|0]: 1 - save the JSON file in binary mode; 0 - text mode.
%           Compact [0|1]: 1- out compact JSON format (remove all newlines and tabs)
%           Compression  'zlib', 'gzip', 'lzma', 'lzip', 'lz4' or 'lz4hc': specify array
%                         compression method; currently only supports 6 methods. The
%                         data compression only applicable to numerical arrays
%                         in 3D or higher dimensions, or when ArrayToStruct
%                         is 1 for 1D or 2D arrays. If one wants to
%                         compress a long string, one must convert
%                         it to uint8 or int8 array first. The compressed
%                         array uses three extra fields
%                         "_ArrayZipType_": the opt.Compression value.
%                         "_ArrayZipSize_": a 1D integer array to
%                            store the pre-compressed (but post-processed)
%                            array dimensions, and
%                         "_ArrayZipData_": the "base64" encoded
%                             compressed binary array data.
%           CompressArraySize [300|int]: only to compress an array if the total
%                         element count is larger than this number.
%           CompressStringSize [inf|int]: only to compress a string if the total
%                         element count is larger than this number.
%           FormatVersion [3|float]: set the JSONLab output version; since
%                         v2.0, JSONLab uses JData specification Draft 1
%                         for output format, it is incompatible with all
%                         previous releases; if old output is desired,
%                         please set FormatVersion to 1.9 or earlier.
%           Encoding ['']: json file encoding. Support all encodings of
%                         fopen() function
%           Append [0|1]: if set to 1, append a new object at the end of the file.
%           Endian ['n'|'b','l']: Endianness of the output file ('n': native,
%                         'b': big endian, 'l': little-endian)
%           PreEncode [1|0]: if set to 1, call jdataencode first to preprocess
%                         the input data before saving
%           BuiltinJSON [0|1]: if set to 1, this function attempts to call
%                         jsonencode, if presents (MATLAB R2016b or Octave
%                         6) first. If jsonencode does not exist or failed,
%                         this function falls back to the jsonlab savejson
%           Whitespaces_: a struct customizing delimiters, including
%                           tab: sprintf('\t')        indentation
%                           newline: sprintf('\n')    newline between items
%                           sep: ','                  delim. between items
%                           quote: '"'                quotes for obj name
%                           array: '[]'               start/end of array
%                           obj: '{}'                 start/end of object
%                         for example, when printing a compact JSON string,
%                         the savejson function internally use
%                           struct('tab', '', 'newline', '', 'sep', ',')
%
%        opt can be replaced by a list of ('param',value) pairs. The param
%        string is equivalent to a field in opt and is case sensitive.
% output:
%      json: a string in the JSON format (see http://json.org)
%
% examples:
%      jsonmesh=struct('MeshNode',[0 0 0;1 0 0;0 1 0;1 1 0;0 0 1;1 0 1;0 1 1;1 1 1],...
%               'MeshElem',[1 2 4 8;1 3 4 8;1 2 6 8;1 5 6 8;1 5 7 8;1 3 7 8],...
%               'MeshSurf',[1 2 4;1 2 6;1 3 4;1 3 7;1 5 6;1 5 7;...
%                          2 8 4;2 8 6;3 8 4;3 8 7;5 8 6;5 8 7],...
%               'MeshCreator','FangQ','MeshTitle','T6 Cube',...
%               'SpecialData',[nan, inf, -inf]);
%      savejson('jmesh',jsonmesh)
%      savejson('',jsonmesh,'ArrayIndent',0,'FloatFormat','\t%.5g')
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

opt.compression = jsonopt('Compression', 'zlib', opt);
opt.nestarray = jsonopt('NestArray', 0, opt);
opt.compact = jsonopt('Compact', 0, opt);
opt.singletcell = jsonopt('SingletCell', 1, opt);
opt.singletarray = jsonopt('SingletArray', 0, opt);
opt.formatversion = jsonopt('FormatVersion', 3, opt);
opt.compressarraysize = jsonopt('CompressArraySize', 300, opt);
opt.compressstringsize = jsonopt('CompressStringSize', inf, opt);
opt.intformat = jsonopt('IntFormat', '%.0f', opt);
opt.floatformat = jsonopt('FloatFormat', '%.16g', opt);
opt.unpackhex = jsonopt('UnpackHex', 1, opt);
opt.arraytostruct = jsonopt('ArrayToStruct', 0, opt);
opt.parselogical = jsonopt('ParseLogical', 0, opt);
opt.arrayindent = jsonopt('ArrayIndent', 1, opt);
opt.emptyarrayasnull = jsonopt('EmptyArrayAsNull', 0, opt);
opt.inf = jsonopt('Inf', '"$1_Inf_"', opt);
opt.nan = jsonopt('NaN', '"_NaN_"', opt);
opt.num2cell_ = 0;
opt.nosubstruct_ = 0;

% Pre-compute commonly used format strings for sprintf
opt.floatformat_sep = [opt.floatformat ','];
opt.intformat_sep = [opt.intformat ','];

if (jsonopt('BuiltinJSON', 0, opt) && exist('jsonencode', 'builtin'))
    try
        obj = jdataencode(obj, 'Base64', 1, 'AnnotateArray', 1, 'UseArrayZipSize', 1, opt);
        if (isempty(rootname))
            json = jsonencode(obj);
        else
            json = jsonencode(struct(rootname, obj));
        end
        if (isempty(regexp(json, '^[{\[]', 'once')))
            json = ['[', json, ']'];
        end
        if (nargout > 0)
            output = json;
        end
        return
    catch
        warning('built-in jsonencode function failed to encode the data, fallback to savejson');
    end
end

if (jsonopt('PreEncode', 1, opt))
    obj = jdataencode(obj, 'Base64', 1, 'UseArrayZipSize', 0, opt);
end

dozip = opt.compression;
if (~isempty(dozip))
    if (~ismember(dozip, {'zlib', 'gzip', 'lzma', 'lzip', 'lz4', 'lz4hc'}) && isempty(regexp(dozip, '^blosc2', 'once')))
        error('compression method "%s" is not supported', dozip);
    end
end

rootisarray = 0;
rootlevel = 1;
forceroot = jsonopt('ForceRootName', 0, opt);
if ((isnumeric(obj) || islogical(obj) || ischar(obj) || isstruct(obj) || ...
     iscell(obj) || isobject(obj)) && isempty(rootname) && forceroot == 0)
    rootisarray = 1;
    rootlevel = 0;
else
    if (isempty(rootname))
        rootname = varname;
    end
end
if ((isa(obj, 'containers.Map') && ~strcmp(obj.KeyType, 'char')) || (isa(obj, 'dictionary') && ~strcmp(obj.types, 'string')))
    rootisarray = 0;
end
if ((isstruct(obj) || iscell(obj)) && isempty(rootname) && forceroot)
    rootname = 'root';
end

whitespaces = struct('tab', sprintf('\t'), 'newline', sprintf('\n'), 'sep', sprintf(',\n'), 'quote', '"', 'array', '[]', 'obj', '{}');
if (opt.compact == 1)
    whitespaces = struct('tab', '', 'newline', '', 'sep', ',', 'quote', '"', 'array', '[]', 'obj', '{}');
end
if (~isfield(opt, 'whitespaces_'))
    opt.whitespaces_ = whitespaces;
else
    opt.whitespaces_ = mergestruct(whitespaces, opt.whitespaces_);
end

% Pre-compute whitespace strings for performance
opt.ws_ = opt.whitespaces_;

nl = whitespaces.newline;

json = obj2json(rootname, obj, rootlevel, opt);

if (rootisarray)
    json = [json, nl];
else
    json = ['{', nl, json, nl, '}', sprintf('\n')];
end

jsonp = jsonopt('JSONP', '', opt);
if (~isempty(jsonp))
    json = [jsonp, '(', json, ');', nl];
end

% save to a file if FileName is set, suggested by Patrick Rapin
filename = jsonopt('FileName', '', opt);
if (~isempty(filename))
    if (jsonopt('UTF8', 1, opt) && exist('unicode2native', 'builtin'))
        json = unicode2native(json);
    end

    encoding = jsonopt('Encoding', '', opt);
    endian = jsonopt('Endian', 'n', opt);
    mode = 'w';
    if (jsonopt('Append', 0, opt))
        mode = 'a';
    end
    if (jsonopt('SaveBinary', 1, opt) == 1)
        if (isempty(encoding))
            fid = fopen(filename, [mode 'b'], endian);
        else
            fid = fopen(filename, [mode 'b'], endian, encoding);
        end
        fwrite(fid, json);
    else
        if (isempty(encoding))
            fid = fopen(filename, [mode 't'], endian);
        else
            fid = fopen(filename, [mode 't'], endian, encoding);
        end
        fwrite(fid, json, 'char');
    end
    fclose(fid);
end

if (nargout > 0 || isempty(filename))
    output = json;
end

%% -------------------------------------------------------------------------
function txt = obj2json(name, item, level, varargin)
% Inline type checking for most common types to reduce function call overhead
opt = varargin{1};
if (iscell(item))
    txt = cell2json(name, item, level, opt);
elseif (isstruct(item))
    txt = struct2json(name, item, level, opt);
elseif (ischar(item))
    if (~isempty(opt.compression) && numel(item) >= opt.compressstringsize)
        txt = mat2json(name, item, level, opt);
    else
        txt = str2json(name, item, level, opt);
    end
elseif (isnumeric(item) || islogical(item))
    txt = mat2json(name, item, level, opt);
elseif (isa(item, 'string') && numel(item) > 1)
    txt = cell2json(name, item, level, opt);
elseif (isa(item, 'jdict'))
    txt = obj2json(name, item.v(), level, opt);
elseif (isa(item, 'timeseries'))
    txt = mat2json(name, item, level, opt);
elseif (isa(item, 'function_handle'))
    txt = struct2json(name, functions(item), level, opt);
elseif (isa(item, 'containers.Map') || isa(item, 'dictionary'))
    txt = map2json(name, item, level, opt);
elseif (isa(item, 'categorical'))
    txt = cell2json(name, cellstr(item), level, opt);
elseif (isa(item, 'table'))
    txt = matlabtable2json(name, item, level, opt);
elseif (isa(item, 'graph') || isa(item, 'digraph'))
    txt = struct2json(name, jdataencode(item), level, opt);
elseif (isobject(item))
    txt = matlabobject2json(name, item, level, opt);
else
    txt = any2json(name, item, level, opt);
end

%% -------------------------------------------------------------------------
function txt = cell2json(name, item, level, opt)
if (~iscell(item) && ~isa(item, 'string'))
    error('input is not a cell or string array');
end
isnum2cell = opt.num2cell_;

if (isnum2cell)
    item = squeeze(item);
    if (~isvector(item))
        item = permute(item, ndims(item):-1:1);
    end
end

dim = size(item);
len = numel(item);
ws = opt.ws_;
nl = ws.newline;
bracketlevel = ~opt.singletcell;

if (len > bracketlevel)
    padding0 = repmat(ws.tab, 1, level);
    if (~isempty(name))
        txt = {[padding0, ws.quote, decodevarname(name, opt.unpackhex), ws.quote, ':', ws.array(1), nl]};
        name = '';
    else
        txt = {[padding0, ws.array(1), nl]};
    end
elseif (len == 0)
    padding0 = repmat(ws.tab, 1, level);
    if (~isempty(name))
        txt = [padding0, ws.quote, decodevarname(name, opt.unpackhex), ws.quote, ':', ws.array];
    else
        txt = [padding0, ws.array];
    end
    return
else
    txt = cell(1, len * 2);
end

if (size(item, 1) > 1)
    item = num2cell(item, 2:ndims(item))';
end

itemlen = length(item);
nextlevel = level + (dim(1) > 1) + (len > bracketlevel);

% Pre-allocate output cell array
if (len > bracketlevel)
    outcell = cell(1, itemlen * 2 + 2);
    outcell{1} = txt{1};
    idx = 2;
else
    outcell = cell(1, itemlen * 2);
    idx = 1;
end

sep1 = [',', nl];
for i = 1:itemlen
    outcell{idx} = obj2json(name, item{i}, nextlevel, opt);
    idx = idx + 1;
    if (i < itemlen)
        outcell{idx} = sep1;
        idx = idx + 1;
    end
end

if (len > bracketlevel)
    padding0 = repmat(ws.tab, 1, level);
    outcell{idx} = [nl, padding0, ws.array(2)];
    idx = idx + 1;
end
txt = [outcell{1:idx - 1}];

%% -------------------------------------------------------------------------
function txt = struct2json(name, item, level, opt)
if (~isstruct(item))
    error('input is not a struct');
end
dim = size(item);
if (ndims(squeeze(item)) > 2) % for 3D or higher dimensions, flatten to 2D for now
    item = reshape(item, dim(1), numel(item) / dim(1));
    dim = size(item);
end
len = numel(item);
forcearray = (len > 1 || (opt.singletarray == 1 && level > 0));
ws = opt.ws_;
nl = ws.newline;
tab = ws.tab;

% Pre-compute padding strings once
padding0 = repmat(tab, 1, level);
padding2 = repmat(tab, 1, level + 1);
padding1 = repmat(tab, 1, level + (dim(1) > 1) + forcearray);

% Check for ArrayType annotation once
arrayTypeField = encodevarname('_ArrayType_', opt.unpackhex);
if (isfield(item, arrayTypeField))
    opt.nosubstruct_ = 1;
end

if (isempty(item))
    if (~isempty(name))
        txt = [padding0, ws.quote, decodevarname(name, opt.unpackhex), ws.quote, ':', ws.array];
    else
        txt = [padding0, ws.array];
    end
    return
end

% Get field names once for all elements (assumes uniform struct array)
names = fieldnames(item);
numfields = length(names);

% Pre-encode field names and check ByteStream once
byteStreamField = encodevarname('_ByteStream_', opt.unpackhex);
decodedName = decodevarname(name, opt.unpackhex);

% Estimate output size and pre-allocate
estsize = len * (numfields * 4 + 10) + 20;
outcell = cell(1, estsize);
idx = 1;

if (~isempty(name))
    if (forcearray)
        outcell{idx} = [padding0, ws.quote, decodedName, ws.quote, ':', ws.array(1), nl];
        idx = idx + 1;
    end
else
    if (forcearray)
        outcell{idx} = [padding0, ws.array(1), nl];
        idx = idx + 1;
    end
end

levelInner = level + (dim(1) > 1) + 1 + forcearray;
commaNl = [',', nl];

for j = 1:dim(2)
    if (dim(1) > 1)
        outcell{idx} = [padding2, ws.array(1), nl];
        idx = idx + 1;
    end
    for i = 1:dim(1)
        if (~isempty(name) && len == 1 && ~forcearray)
            outcell{idx} = [padding1, ws.quote, decodedName, ws.quote, ':', ws.obj(1), nl];
        else
            outcell{idx} = [padding1, ws.obj(1), nl];
        end
        idx = idx + 1;

        if (numfields > 0)
            itemij = item(i, j);
            for e = 1:numfields
                fname = names{e};
                fval = itemij.(fname);
                if (opt.nosubstruct_ && ischar(fval)) || strcmp(fname, byteStreamField)
                    outcell{idx} = str2json(fname, fval, levelInner, opt);
                else
                    outcell{idx} = obj2json(fname, fval, levelInner, opt);
                end
                idx = idx + 1;
                if (e < numfields)
                    outcell{idx} = ',';
                    idx = idx + 1;
                end
                outcell{idx} = nl;
                idx = idx + 1;
            end
        end
        outcell{idx} = [padding1, ws.obj(2)];
        idx = idx + 1;
        if (i < dim(1))
            outcell{idx} = commaNl;
            idx = idx + 1;
        end
    end
    if (dim(1) > 1)
        outcell{idx} = [nl, padding2, ws.array(2)];
        idx = idx + 1;
    end
    if (j < dim(2))
        outcell{idx} = commaNl;
        idx = idx + 1;
    end
end
if (forcearray)
    outcell{idx} = [nl, padding0, ws.array(2)];
    idx = idx + 1;
end
txt = [outcell{1:idx - 1}];

%% -------------------------------------------------------------------------
function txt = map2json(name, item, level, opt)
itemtype = isa(item, 'containers.Map');
dim = size(item);

if (isa(item, 'dictionary'))
    itemtype = 2;
    dim = item.numEntries;
end
if (itemtype == 0)
    error('input is not a containers.Map or dictionary class');
end
names = keys(item);
val = values(item);

if (~iscell(names))
    names = num2cell(names, ndims(names));
end

if (~iscell(val))
    val = num2cell(val, ndims(val));
end

if ((itemtype == 1 && ~strcmp(item.KeyType, 'char')) || (itemtype == 2 && ~strcmp(item.types, 'string')))
    mm = cell(1, length(names));
    for i = 1:length(names)
        mm{i} = {names{i}, val{i}};
    end
    if (isempty(name))
        txt = obj2json('_MapData_', mm, level + 1, opt);
    else
        temp = struct(name, struct());
        if (opt.isoctave)
            temp.(name).('_MapData_') = mm;
        else
            temp.(name).('x0x5F_MapData_') = mm;
        end
        txt = obj2json(name, temp.(name), level, opt);
    end
    return
end

ws = opt.ws_;
padding0 = repmat(ws.tab, 1, level);
nl = ws.newline;

if (isempty(item))
    if (~isempty(name))
        txt = [padding0, ws.quote, decodevarname(name, opt.unpackhex), ws.quote, ':', ws.array];
    else
        txt = [padding0, ws.array];
    end
    return
end

% Pre-allocate
maxlen = dim(1) * 3 + 10;
outcell = cell(1, maxlen);
idx = 1;

if (~isempty(name))
    outcell{idx} = [padding0, ws.quote, decodevarname(name, opt.unpackhex), ws.quote, ':', ws.obj(1), nl];
else
    outcell{idx} = [padding0, ws.obj(1), nl];
end
idx = idx + 1;

for i = 1:dim(1)
    if (isempty(names{i}))
        outcell{idx} = obj2json('x0x0_', val{i}, level + 1, opt);
    else
        outcell{idx} = obj2json(names{i}, val{i}, level + 1, opt);
    end
    idx = idx + 1;
    if (i < length(names))
        outcell{idx} = ',';
        idx = idx + 1;
    end
    if (i < dim(1))
        outcell{idx} = nl;
        idx = idx + 1;
    end
end
outcell{idx} = nl;
idx = idx + 1;
outcell{idx} = padding0;
idx = idx + 1;
outcell{idx} = ws.obj(2);
idx = idx + 1;
txt = [outcell{1:idx - 1}];

%% -------------------------------------------------------------------------
function txt = str2json(name, item, level, opt)
if (~ischar(item))
    error('input is not a string');
end
item = reshape(item, max(size(item), [1 0]));
len = size(item, 1);
ws = opt.ws_;
padding1 = repmat(ws.tab, 1, level);
nl = ws.newline;
quote = ws.quote;

decodedname = decodevarname(name, opt.unpackhex);
isArrayZipData = strcmp('_ArrayZipData_', decodedname);

% Fast path for single-row strings (most common case)
if (len == 1)
    if (~isArrayZipData)
        val = escapejsonstring(item, opt);
    else
        val = item;
    end
    if (isempty(name))
        txt = [padding1, quote, val, quote];
    else
        txt = [padding1, quote, decodedname, quote, ':', quote, val, quote];
    end
    return
end

% Multi-row string handling
padding0 = repmat(ws.tab, 1, level + 1);
sep = ws.sep;

% Pre-allocate for multi-row
outcell = cell(1, len * 2 + 4);
idx = 1;

if (~isempty(name))
    outcell{idx} = [padding1, quote, decodedname, quote, ':', ws.array(1), nl];
else
    outcell{idx} = [padding1, ws.array(1), nl];
end
idx = idx + 1;

for e = 1:len
    if (~isArrayZipData)
        val = escapejsonstring(item(e, :), opt);
    else
        val = item(e, :);
    end
    outcell{idx} = [padding0, quote, val, quote];
    idx = idx + 1;
    if (e < len)
        outcell{idx} = sep;
        idx = idx + 1;
    end
end
outcell{idx} = nl;
idx = idx + 1;
outcell{idx} = padding1;
idx = idx + 1;
outcell{idx} = ws.array(2);
idx = idx + 1;
txt = [outcell{1:idx - 1}];

%% -------------------------------------------------------------------------
function txt = mat2json(name, item, level, opt)
if (~isnumeric(item) && ~islogical(item) && ~ischar(item))
    error('input is not an array');
end
ws = opt.ws_;
padding1 = repmat(ws.tab, 1, level);
padding0 = repmat(ws.tab, 1, level + 1);
nl = ws.newline;
sep = ws.sep;

dozip = opt.compression;
zipsize = opt.compressarraysize;
format = opt.formatversion;
isnest = opt.nestarray;

if (isa(item, 'timeseries'))
    if (item.TimeInfo.isUniform && item.TimeInfo.Increment == 1)
        if (ndims(item.Data) == 3 && size(item.Data, 1) == 1 && size(item.Data, 2) == 1)
            item = permute(item.Data, [2 3 1]);
        else
            item = squeeze(item.Data);
        end
    else
        item = [item.Time squeeze(item.Data)];
    end
end

if (~opt.nosubstruct_ && (((isnest == 0) && length(size(item)) > 2) || issparse(item) || ~isreal(item) || ...
                          (isempty(item) && any(size(item))) || opt.arraytostruct || (~isempty(dozip) && numel(item) > zipsize)))
    % Build header using cell array concatenation instead of sprintf
    sizestr = regexprep(mat2str(size(item)), '\s+', ',');
    classname = class(item);

    if (isempty(name))
        txt = [padding1, '{', nl, padding0, '"_ArrayType_":"', classname, '",', nl, padding0, '"_ArraySize_":', sizestr, ',', nl];
    else
        txt = [padding1, '"', decodevarname(name, opt.unpackhex), '":{', nl, padding0, '"_ArrayType_":"', classname, '",', nl, padding0, '"_ArraySize_":', sizestr, ',', nl];
    end
else
    numtxt = matdata2json(item, level + 1, opt);
    if (isempty(name))
        txt = [padding1, numtxt];
    else
        txt = [padding1, ws.quote, decodevarname(name, opt.unpackhex), ws.quote, ':', numtxt];
    end
    return
end

dataformat = '%s%s%s%s%s';

if (issparse(item))
    [ix, iy] = find(item);
    data = full(item(find(item)));
    if (~isreal(item))
        data = [real(data(:)), imag(data(:))];
        if (size(item, 1) == 1)
            % Kludge to have data's 'transposedness' match item's.
            % (Necessary for complex row vector handling below.)
            data = data';
        end
        txt = [txt, padding0, '"_ArrayIsComplex_":true', sep];
    end
    txt = [txt, padding0, '"_ArrayIsSparse_":true', sep];
    if (~isempty(dozip) && numel(data * 2) > zipsize)
        if (size(item, 1) == 1)
            % Row vector, store only column indices.
            fulldata = [iy(:), data'];
        elseif (size(item, 2) == 1)
            % Column vector, store only row indices.
            fulldata = [ix, data];
        else
            % General case, store row and column indices.
            fulldata = [ix, iy, data];
        end
        sizestr = regexprep(mat2str(size(fulldata)), '\s+', ',');
        txt = [txt, padding0, '"_ArrayZipSize_":', sizestr, sep];
        txt = [txt, padding0, '"_ArrayZipType_":"', dozip, '"', sep];
        compfun = str2func([dozip 'encode']);
        txt = [txt, padding0, '"_ArrayZipData_":"', base64encode(compfun(typecast(fulldata(:), 'uint8'))), '"', nl];
    else
        if (size(item, 1) == 1)
            % Row vector, store only column indices.
            fulldata = [iy(:), data'];
        elseif (size(item, 2) == 1)
            % Column vector, store only row indices.
            fulldata = [ix, data];
        else
            % General case, store row and column indices.
            fulldata = [ix, iy, data];
        end
        txt = [txt, padding0, '"_ArrayData_":', matdata2json(fulldata', level + 2, opt), nl];
    end
else
    if (format > 1.9)
        item = permute(item, ndims(item):-1:1);
    end
    if (~isempty(dozip) && numel(item) > zipsize)
        if (isreal(item))
            fulldata = item(:)';
            if (islogical(fulldata) || ischar(fulldata))
                fulldata = uint8(fulldata);
            end
        else
            txt = [txt, padding0, '"_ArrayIsComplex_":true', sep];
            fulldata = [real(item(:)) imag(item(:))]';
        end
        sizestr = regexprep(mat2str(size(fulldata)), '\s+', ',');
        txt = [txt, padding0, '"_ArrayZipSize_":', sizestr, sep];
        txt = [txt, padding0, '"_ArrayZipType_":"', dozip, '"', sep];
        encodeparam = {};
        if (~isempty(regexp(dozip, '^blosc2', 'once')))
            compfun = @blosc2encode;
            encodeparam = {dozip, 'nthread', jsonopt('nthread', 1, opt), 'shuffle', jsonopt('shuffle', 1, opt), 'typesize', jsonopt('typesize', length(typecast(fulldata(1), 'uint8')), opt)};
        else
            compfun = str2func([dozip 'encode']);
        end
        txt = [txt, padding0, '"_ArrayZipData_":"', char(base64encode(compfun(typecast(fulldata(:), 'uint8'), encodeparam{:}))), '"', nl];
    else
        if (isreal(item))
            txt = [txt, padding0, '"_ArrayData_":', matdata2json(item(:)', level + 2, opt), nl];
        else
            txt = [txt, padding0, '"_ArrayIsComplex_":true', sep];
            txt = [txt, padding0, '"_ArrayData_":', matdata2json([real(item(:)) imag(item(:))]', level + 2, opt), nl];
        end
    end
end

txt = [txt, padding1, ws.obj(2)];

%% -------------------------------------------------------------------------
function txt = matlabobject2json(name, item, level, opt)
try
    if numel(item) == 0 % empty object
        st = struct();
    elseif numel(item) == 1 %
        txt = str2json(name, char(item), level, opt);
        return
    else
        propertynames = properties(item);
        for p = 1:numel(propertynames)
            for o = numel(item):-1:1 % array of objects
                st(o).(propertynames{p}) = item(o).(propertynames{p});
            end
        end
    end
    txt = struct2json(name, st, level, opt);
catch
    txt = any2json(name, item, level, opt);
end

%% -------------------------------------------------------------------------
function txt = matlabtable2json(name, item, level, opt)
st = containers.Map();
st('_TableRecords_') = table2cell(item);
st('_TableRows_') = item.Properties.RowNames';
st('_TableCols_') = item.Properties.VariableNames;
if (isempty(name))
    txt = map2json(name, st, level, opt);
else
    temp = struct(name, struct());
    temp.(name) = st;
    txt = map2json(name, temp.(name), level, opt);
end

%% -------------------------------------------------------------------------
function txt = matdata2json(mat, level, opt)

ws = opt.ws_;
tab = ws.tab;
nl = ws.newline;
isnest = opt.nestarray;
format = opt.formatversion;
isnum2cell = opt.num2cell_;

if (~isvector(mat) && isnest == 1)
    if (format > 1.9 && isnum2cell == 0)
        mat = permute(mat, ndims(mat):-1:1);
    end
    opt.num2cell_ = 1;
    opt.singletcell = 0;
    txt = cell2json('', num2cell(mat, 1), level - 1, opt);
    return
elseif (isvector(mat) && isnum2cell == 1)
    mat = mat(:).';
end

if (size(mat, 1) == 1)
    pre = '';
    post = '';
    level = level - 1;
else
    pre = [ws.array(1), nl];
    post = [nl, repmat(tab, 1, level - 1), ws.array(2)];
end

if (isempty(mat))
    if (opt.emptyarrayasnull)
        txt = 'null';
    else
        txt = ws.array;
    end
    return
end

% Pre-check for special values to avoid unnecessary regexprep later
hasInf = any(isinf(mat(:)));
hasNaN = any(isnan(mat(:)));

if (isinteger(mat))
    floatformat = opt.intformat;
else
    floatformat = opt.floatformat;
end

ncols = size(mat, 2);
if (numel(mat) == 1 && opt.singletarray == 0 && level > 0)
    formatstr = [repmat([floatformat ','], 1, ncols - 1), floatformat, sprintf(',%s', nl)];
else
    formatstr = [ws.array(1), repmat([floatformat ','], 1, ncols - 1), floatformat, ws.array(2), ',', nl];
end
if (size(mat, 1) > 1 && opt.arrayindent == 1)
    formatstr = [repmat(tab, 1, level), formatstr];
end

txt = sprintf(formatstr, permute(mat, ndims(mat):-1:1));
txt(end - length(nl):end) = [];

if (islogical(mat) && (numel(mat) == 1 || opt.parselogical == 1))
    txt = strrep(strrep(txt, '1', 'true'), '0', 'false');
end

txt = [pre, txt, post];

% Only run replacement if special values exist
if (hasInf)
    txt = regexprep(txt, '([-+]*)Inf', opt.inf);
end
if (hasNaN)
    txt = strrep(txt, 'NaN', opt.nan);
end

%% -------------------------------------------------------------------------
function txt = any2json(name, item, level, opt)
st = containers.Map();
st('_DataInfo_') = struct('MATLABObjectName', name, 'MATLABObjectClass', class(item), 'MATLABObjectSize', size(item));
st('_ByteStream_') = char(base64encode(getByteStreamFromArray(item)));

if (isempty(name))
    txt = map2json(name, st, level, opt);
else
    temp = struct(name, struct());
    temp.(name) = st;
    txt = map2json(name, temp.(name), level, opt);
end

%% -------------------------------------------------------------------------
%  Optimized escapejsonstring - use strrep instead of regexprep when possible
%% -------------------------------------------------------------------------
function newstr = escapejsonstring(str, varargin)
newstr = str;
if (isempty(str))
    return
end

% Quick ASCII check - if all printable ASCII and no special chars, return early
% This is the fast path for most strings
byteval = uint8(str);
if (all(byteval >= 32 & byteval <= 126))
    % Check for characters that need escaping
    if (~any(byteval == 34 | byteval == 92))  % 34 = '"', 92 = '\'
        return
    end
end

% Use strrep for common cases (much faster than regexprep)
% Order matters: escape backslash first
newstr = strrep(newstr, '\', '\\');
newstr = strrep(newstr, '"', '\"');
newstr = strrep(newstr, sprintf('\a'), '\a');
newstr = strrep(newstr, sprintf('\b'), '\b');
newstr = strrep(newstr, sprintf('\f'), '\f');
newstr = strrep(newstr, sprintf('\n'), '\n');
newstr = strrep(newstr, sprintf('\r'), '\r');
newstr = strrep(newstr, sprintf('\t'), '\t');
newstr = strrep(newstr, sprintf('\v'), '\v');

% Handle unicode escape sequences - restore \\uXXXX to \uXXXX
% Only process if string is long enough and contains backslashes
len = length(newstr);
if (len < 6)
    return
end

% Check if there's any potential unicode escape sequence
if (~any(newstr == '\'))
    return
end

% Try fast path first (works in MATLAB and newer Octave with valid UTF-8)
try
    idx = strfind(newstr, '\\u');
    if (~isempty(idx))
        newstr = regexprep(newstr, '\\\\(u[0-9a-fA-F]{4})', '\\$1');
    end
catch
    % Fallback for Octave with invalid UTF-8: use vectorized byte operations
    newstr = escapejsonstring_unicode_fix(newstr);
end

%% -------------------------------------------------------------------------
%  Vectorized unicode escape fix for non-UTF8 safe strings (Octave compatibility)
%% -------------------------------------------------------------------------
function newstr = escapejsonstring_unicode_fix(str)
% Replace \\uXXXX with \uXXXX using vectorized operations
bytes = uint8(str);
len = length(bytes);

if (len < 6)
    newstr = str;
    return
end

% Find all positions where '\\u' occurs (bytes: 92 92 117)
% Use vectorized comparison
matches = (bytes(1:end - 2) == 92) & (bytes(2:end - 1) == 92) & (bytes(3:end) == 117);
positions = find(matches);

if (isempty(positions))
    newstr = str;
    return
end

% Filter positions that have valid hex digits following
hexchars = uint8('0123456789abcdefABCDEF');
validpos = [];
for i = 1:length(positions)
    p = positions(i);
    if (p + 6 <= len)
        if (all(ismember(bytes(p + 3:p + 6), hexchars)))
            validpos(end + 1) = p; %#ok<AGROW>
        end
    end
end

if (isempty(validpos))
    newstr = str;
    return
end

% Build result by removing extra backslashes at valid positions
% Create mask of bytes to keep (remove first backslash of each \\uXXXX)
keep = true(1, len);
keep(validpos) = false;
newstr = char(bytes(keep));
