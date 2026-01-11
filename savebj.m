function output = savebj(rootname, obj, varargin)
%
% bjd=savebj(obj)
%    or
% bjd=savebj(rootname,obj,filename)
% bjd=savebj(rootname,obj,opt)
% bjd=savebj(rootname,obj,'param1',value1,'param2',value2,...)
%
% Convert a MATLAB object  (cell, struct, array, table, map, handles ...)
% into a Binary JData (BJData v1 Draft-2), Universal Binary JSON (UBJSON,
% Draft-12) or a MessagePack binary stream
%
% author: Qianqian Fang (q.fang <at> neu.edu)
% initially created on 2013/08/17
%
% By default, this function creates BJD-compliant output. The BJD
% specification is largely similar to UBJSON, with additional data types
% including uint16(u), uint32(m), uint64(M) and half-precision float (h).
% Starting from BJD Draft-2 (JSONLab 3.0 beta or later), all integer and
% floating-point numbers are stored in Little-Endian as opposed to
% Big-Endian form as in BJD Draft-1/UBJSON Draft-12 (JSONLab 2.1 or older)
%
% Format specifications:
%    Binary JData (BJD):   https://github.com/NeuroJSON/bjdata
%    UBJSON:               https://github.com/ubjson/universal-binary-json
%    MessagePack:          https://github.com/msgpack/msgpack
%
% input:
%      rootname: the name of the root-object, when set to '', the root name
%           is ignored, however, when opt.ForceRootName is set to 1 (see below),
%           the MATLAB variable name will be used as the root name.
%      obj: a MATLAB object (array, cell, cell array, struct, struct array,
%           class instance)
%      filename: a string for the file name to save the output UBJSON data
%      opt: a struct for additional options, ignore to use default values.
%           opt can have the following fields (first in [.|.] is the default)
%
%           FileName [''|string]: a file name to save the output JSON data
%           ArrayToStruct[0|1]: when set to 0, savebj outputs 1D/2D
%                         array in JSON array format; if sets to 1, an
%                         array will be shown as a struct with fields
%                         "_ArrayType_", "_ArraySize_" and "_ArrayData_"; for
%                         sparse arrays, the non-zero elements will be
%                         saved to "_ArrayData_" field in triplet-format i.e.
%                         (ix,iy,val) and "_ArrayIsSparse_":true will be added
%                         with a value of 1; for a complex array, the
%                         "_ArrayData_" array will include two rows
%                         (4 for sparse) to record the real and imaginary
%                         parts, and also "_ArrayIsComplex_":true is added.
%                         Other annotations include "_ArrayShape_" and
%                         "_ArrayOrder_", "_ArrayZipLevel_" etc.
%          NestArray    [0|1]: If set to 1, use nested array constructs
%                         to store N-dimensional arrays (compatible with
%                         UBJSON specification Draft 12); if set to 0,
%                         use the JData (v0.5) optimized N-D array header;
%                         NestArray is automatically set to 1 when
%                         MessagePack is set to 1
%          ParseLogical [1|0]: if this is set to 1, logical array elem
%                         will use true/false rather than 1/0.
%          SingletArray [0|1]: if this is set to 1, arrays with a single
%                         numerical element will be shown without a square
%                         bracket, unless it is the root object; if 0, square
%                         brackets are forced for any numerical arrays.
%          SingletCell  [1|0]: if 1, always enclose a cell with "[]"
%                         even it has only one element; if 0, brackets
%                         are ignored when a cell has only 1 element.
%          ForceRootName [0|1]: when set to 1 and rootname is empty, savebj
%                         will use the name of the passed obj variable as the
%                         root object name; if obj is an expression and
%                         does not have a name, 'root' will be used; if this
%                         is set to 0 and rootname is empty, the root level
%                         will be merged down to the lower level.
%          JSONP [''|string]: to generate a JSONP output (JSON with padding),
%                         for example, if opt.JSON='foo', the JSON data is
%                         wrapped inside a function call as 'foo(...);'
%          UnpackHex [1|0]: convert the 0x[hex code] output by loadjson
%                         back to the string form
%          Compression  'zlib', 'gzip', 'lzma', 'lzip', 'lz4' or 'lz4hc': specify array
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
%                         "_ArrayZipData_": the binary stream of
%                            the compressed binary array data WITHOUT
%                            'base64' encoding
%          CompressArraySize [100|int]: only to compress an array if the total
%                         element count is larger than this number.
%          CompressStringSize [inf|int]: only to compress a string if the total
%                         element count is larger than this number.
%          MessagePack [0|1]: output MessagePack (https://msgpack.org/)
%                         binary stream instead of BJD/UBJSON
%          UBJSON [0|1]: 0: (default)-encode data based on BJData Draft 1
%                         (supports uint16(u)/uint32(m)/uint64(M)/half(h) markers)
%                        1: encode data based on UBJSON Draft 12 (without
%                         u/m/M/h markers);all numeric values are stored in
%                         the Big-Endian byte order according to Draft-12
%          FormatVersion [2|float]: set the JSONLab output version; since
%                         v2.0, JSONLab uses JData specification Draft 3
%                         for output format, it is incompatible with releases
%                         older than v1.9.8; if old output is desired,
%                         please set FormatVersion to 1.9 or earlier.
%                         When FormatVersion>=4, BJData Draft-4 SOA format
%                         is used for struct arrays and tables with uniform
%                         column types.
%          SoAFormat ['col'|'row']: specify the SOA memory layout when
%                         FormatVersion>=4 and data qualifies for SOA.
%                         'col','c','column' - column-major (columnar)
%                         'row','r' - row-major (interleaved)
%                         Default is 'col'.
%          SoAStringThreshold [0.5|float]: for string fields, if the ratio
%                         of unique strings to total records is below this
%                         threshold, use dictionary encoding; otherwise use
%                         fixed-length or offset-table encoding.
%          KeepType [0|1]: if set to 1, use the original data type to store
%                         integers instead of converting to the integer type
%                         of the minimum length without losing accuracy (default)
%          Debug [0|1]: output binary numbers in <%g> format for debugging
%          Append [0|1]: if set to 1, append a new object at the end of the file.
%          Endian ['L'|'B']: specify the endianness of the numbers
%                         in the BJData/UBJSON input data. Default: 'L'.
%
%                         Starting from JSONLab 2.9, BJData by default uses
%                         [L] Little-Endian for both integers and floating
%                         point numbers. This is a major departure from the
%                         UBJSON specification, where 'B' - Big-Endian -
%                         format is used for integer fields. UBJSON does
%                         not specifically define Endianness for
%                         floating-point numbers, resulting in mixed
%                         implementations. JSONLab 2.0-2.1 used 'B' for
%                         integers and floating-points; JSONLab 1.x uses
%                         'B' for integers and native-endianness for
%                         floating-point numbers.
%          FileEndian ['n'|'b','l']: Endianness of the output file ('n': native,
%                         'b': big endian, 'l': little-endian)
%          PreEncode [1|0]: if set to 1, call jdataencode first to preprocess
%                         the input data before saving
%
%        opt can be replaced by a list of ('param',value) pairs. The param
%        string is equivalent to a field in opt and is case sensitive.
% output:
%      bjd: a binary string in the UBJSON format (see http://ubjson.org)
%
% examples:
%      jsonmesh=struct('MeshVertex3',[0 0 0;1 0 0;0 1 0;1 1 0;0 0 1;1 0 1;0 1 1;1 1 1],...
%               'MeshTet4',[1 2 4 8;1 3 4 8;1 2 6 8;1 5 6 8;1 5 7 8;1 3 7 8],...
%               'MeshTri3',[1 2 4;1 2 6;1 3 4;1 3 7;1 5 6;1 5 7;...
%                          2 8 4;2 8 6;3 8 4;3 8 7;5 8 6;5 8 7],...
%               'MeshCreator','FangQ','MeshTitle','T6 Cube',...
%               'SpecialData',[nan, inf, -inf]);
%      savebj(jsonmesh)
%      savebj('',jsonmesh,'debug',1)
%      savebj('',jsonmesh,'meshdata.bjd')
%      savebj('mesh1',jsonmesh,'FileName','meshdata.msgpk','MessagePack',1)
%      savebj('',jsonmesh,'ubjson',1)
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
if (length(varargin) == 1 && ischar(varargin{1}))
    opt = struct('filename', varargin{1});
else
    opt = varargin2struct(varargin{:});
end

opt.isoctave = isoctavemesh;
opt.compression = jsonopt('Compression', '', opt);
opt.nestarray = jsonopt('NestArray', 0, opt);
opt.formatversion = jsonopt('FormatVersion', 4, opt);
opt.compressarraysize = jsonopt('CompressArraySize', 100, opt);
opt.compressstringsize = jsonopt('CompressStringSize', inf, opt);
opt.singletcell = jsonopt('SingletCell', 1, opt);
opt.singletarray = jsonopt('SingletArray', 0, opt);
opt.arraytostruct = jsonopt('ArrayToStruct', 0, opt);
opt.debug = jsonopt('Debug', 0, opt);
opt.messagepack = jsonopt('MessagePack', 0, opt);
opt.num2cell_ = 0;
opt.ubjson = bitand(jsonopt('UBJSON', 0, opt), ~opt.messagepack);
opt.keeptype = jsonopt('KeepType', 0, opt);
opt.nosubstruct_ = 0;
opt.soaformat = lower(jsonopt('SoAFormat', 'col', opt));
opt.soathreshold = jsonopt('SoAThreshold', 0.5, opt);
opt.unpackhex = jsonopt('UnpackHex', 1, opt);
opt.type2byte_ = struct('uint8', 1, 'int8', 1, 'int16', 2, 'uint16', 2, ...
                        'int32', 4, 'uint32', 4, 'int64', 8, 'uint64', 8, 'single', 4, 'double', 8, 'logical', 1);

[~, ~, systemendian] = computer;
opt.flipendian_ = (systemendian ~= upper(jsonopt('Endian', 'L', opt)));

% Initialize type markers
if (~opt.messagepack)
    if (~opt.ubjson)
        opt.IM_ = 'UiuImlML';
        opt.IType_ = {'uint8', 'int8', 'uint16', 'int16', 'uint32', 'int32', 'uint64', 'int64'};
        opt.IByte_ = [1, 1, 2, 2, 4, 4, 8, 8];
        opt.FM_ = 'hdD';
        opt.FType_ = {'half', 'single', 'double'};
        opt.FByte_ = [2, 4, 8];
    else
        opt.IM_ = 'UiIlL';
        opt.IType_ = {'uint8', 'int8', 'int16', 'int32', 'int64'};
        opt.IByte_ = [1, 1, 2, 4, 8];
        opt.FM_ = 'IdD';
        opt.FType_ = {'int16', 'single', 'double'};
        opt.FByte_ = [2, 4, 8];
    end
    opt.FTM_ = 'FT';
    opt.SM_ = 'CS';
    opt.ZM_ = 'Z';
    opt.OM_ = {'{', '}'};
    opt.AM_ = {'[', ']'};
else
    opt.IM_ = char([hex2dec('cc') hex2dec('d0') hex2dec('cd') hex2dec('d1') hex2dec('ce') hex2dec('d2') hex2dec('cf') hex2dec('d3')]);
    opt.IType_ = {'uint8', 'int8', 'uint16', 'int16', 'uint32', 'int32', 'uint64', 'int64'};
    opt.IByte_ = [1, 1, 2, 2, 4, 4, 8, 8];
    opt.FM_ = char([hex2dec('cd') hex2dec('ca') hex2dec('cb')]);
    opt.FType_ = {'int16', 'single', 'double'};
    opt.FByte_ = [2, 4, 8];
    opt.FTM_ = char([hex2dec('c2') hex2dec('c3')]);
    opt.SM_ = char([hex2dec('a1') hex2dec('db')]);
    opt.ZM_ = char(hex2dec('c0'));
    opt.OM_ = {char(hex2dec('df')), ''};
    opt.AM_ = {char(hex2dec('dd')), ''};
end

% For formatversion >= 4 with SOA support, skip jdataencode for tables
skippreencode = false;
if (opt.formatversion >= 4 && ~opt.messagepack && ~opt.ubjson)
    if (isa(obj, 'table') && size(obj, 1) > 1)
        cansoa = table2soa(obj, opt);
        skippreencode = cansoa;
    end
end

if (~skippreencode && jsonopt('PreEncode', 1, opt))
    obj = jdataencode(obj, 'Base64', 0, 'UseArrayZipSize', opt.messagepack, 'DateTime', 0, opt);
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
elseif (isempty(rootname))
    rootname = varname;
end

if ((isstruct(obj) || iscell(obj)) && isempty(rootname) && forceroot)
    rootname = 'root';
end

json = obj2ubjson(rootname, obj, rootlevel, opt);

if (~rootisarray)
    if (opt.messagepack)
        json = [char(129) json opt.OM_{2}];
    else
        json = [opt.OM_{1} json opt.OM_{2}];
    end
end

jsonp = jsonopt('JSONP', '', opt);
if (~isempty(jsonp))
    json = [jsonp '(' json ')'];
end

% save to a file if FileName is set, suggested by Patrick Rapin
filename = jsonopt('FileName', '', opt);
if (~isempty(filename))
    encoding = jsonopt('Encoding', '', opt);
    fileendian = jsonopt('FileEndian', 'n', opt);
    writemode = 'w';
    if (jsonopt('Append', 0, opt))
        writemode = 'a';
    end
    if (~exist('OCTAVE_VERSION', 'builtin'))
        fid = fopen(filename, writemode, fileendian, encoding);
    else
        fid = fopen(filename, writemode, fileendian);
    end
    fwrite(fid, uint8(json));
    fclose(fid);
end

if (nargout > 0 || isempty(filename))
    output = json;
end

%% -------------------------------------------------------------------------
function txt = obj2ubjson(name, item, level, opt)

if (iscell(item) || isa(item, 'string'))
    txt = cell2ubjson(name, item, level, opt);
elseif (isstruct(item))
    txt = struct2ubjson(name, item, level, opt);
elseif (isnumeric(item) || islogical(item))
    txt = mat2ubjson(name, item, level, opt);
elseif (isa(item, 'datetime'))
    txt = ext2ubjson(name, item, 'datetime', opt);
elseif (isa(item, 'duration'))
    txt = ext2ubjson(name, item, 'duration', opt);
elseif (isa(item, 'jdict'))
    txt = jdict2ubjson(name, item, level, opt);
elseif (ischar(item))
    if (numel(item) >= opt.compressstringsize)
        txt = mat2ubjson(name, item, level, opt);
    else
        txt = str2ubjson(name, item, level, opt);
    end
elseif (isa(item, 'function_handle'))
    txt = struct2ubjson(name, functions(item), level, opt);
elseif (isa(item, 'containers.Map') || isa(item, 'dictionary'))
    txt = map2ubjson(name, item, level, opt);
elseif (isa(item, 'categorical'))
    txt = cell2ubjson(name, cellstr(item), level, opt);
elseif (isa(item, 'table'))
    txt = matlabtable2ubjson(name, item, level, opt);
elseif (isa(item, 'graph') || isa(item, 'digraph'))
    txt = struct2ubjson(name, jdataencode(item), level, opt);
elseif (isobject(item))
    txt = matlabobject2ubjson(name, item, level, opt);
elseif (~isreal(item) && isnumeric(item))
    txt = ext2ubjson(name, item, 'complex', opt);
else
    txt = any2ubjson(name, item, level, opt);
end

%% -------------------------------------------------------------------------
function txt = cell2ubjson(name, item, level, opt)
txt = '';
if (~iscell(item) && ~isa(item, 'string'))
    error('input is not a cell');
end
if (opt.num2cell_)
    item = squeeze(item);
elseif (opt.formatversion > 1.9 && ~isvector(item))
    item = permute(item, ndims(item):-1:1);
end

dim = size(item);
if (ndims(squeeze(item)) > 2)
    item = reshape(item, dim(1), numel(item) / dim(1));
    dim = size(item);
end
bracketlevel = ~opt.singletcell;
Zmarker = opt.ZM_;
Amarker = opt.AM_;
len = numel(item);

am0 = Amarker{1};
if (~strcmp(am0, '['))
    am0 = Imsgpk_(dim(2), 220, 144, opt);
end

parts = {};
partIdx = 0;

if (len > bracketlevel)
    partIdx = partIdx + 1;
    if (~isempty(name))
        parts{partIdx} = [N_(decodevarname(name, opt.unpackhex), opt) am0];
        name = '';
    else
        parts{partIdx} = am0;
    end
elseif (len == 0)
    if (~isempty(name))
        txt = [N_(decodevarname(name, opt.unpackhex), opt) Zmarker];
    else
        txt = Zmarker;
    end
    return
end
if (~strcmp(Amarker{1}, '['))
    am0 = Imsgpk_(dim(1), 220, 144, opt);
end
for j = 1:dim(2)
    if (dim(1) > 1)
        partIdx = partIdx + 1;
        parts{partIdx} = am0;
    end
    for i = 1:dim(1)
        partIdx = partIdx + 1;
        parts{partIdx} = char(obj2ubjson(name, item{i, j}, level + (len > bracketlevel), opt));
    end
    if (dim(1) > 1)
        partIdx = partIdx + 1;
        parts{partIdx} = Amarker{2};
    end
end
if (len > bracketlevel)
    partIdx = partIdx + 1;
    parts{partIdx} = Amarker{2};
end
txt = [parts{1:partIdx}];

%% -------------------------------------------------------------------------
function txt = struct2ubjson(name, item, level, opt)
txt = '';
if (~isstruct(item))
    error('input is not a struct');
end

if (opt.formatversion >= 4 && numel(item) > 1 && ~opt.messagepack && ~opt.ubjson)
    [cansoa, soainfo] = struct2soa(item, opt);
    if (cansoa)
        txt = data2soa(name, item, soainfo, opt);
        return
    end
end

dim = size(item);
if (ndims(squeeze(item)) > 2)
    item = reshape(item, dim(1), numel(item) / dim(1));
    dim = size(item);
end
len = numel(item);
forcearray = (len > 1 || (opt.singletarray == 1 && level > 0));
Amarker = opt.AM_;
Omarker = opt.OM_;

if (isfield(item, encodevarname('_ArrayType_')))
    opt.nosubstruct_ = 1;
end

am0 = Amarker{1};
if (~strcmp(am0, '['))
    am0 = Imsgpk_(dim(2), 220, 144, opt);
end

parts = {};
partIdx = 0;

if (forcearray)
    partIdx = partIdx + 1;
    if (~isempty(name))
        parts{partIdx} = [N_(decodevarname(name, opt.unpackhex), opt) am0];
    else
        parts{partIdx} = am0;
    end
end
if (~strcmp(Amarker{1}, '['))
    am0 = Imsgpk_(dim(1), 220, 144, opt);
end
for j = 1:dim(2)
    if (dim(1) > 1)
        partIdx = partIdx + 1;
        parts{partIdx} = am0;
    end
    for i = 1:dim(1)
        fnames = fieldnames(item(i, j));
        om0 = Omarker{1};
        if (~strcmp(om0, '{'))
            om0 = Imsgpk_(length(fnames), 222, 128, opt);
        end
        partIdx = partIdx + 1;
        if (~isempty(name) && len == 1 && ~forcearray)
            parts{partIdx} = [N_(decodevarname(name, opt.unpackhex), opt) om0];
        else
            parts{partIdx} = om0;
        end
        if (~isempty(fnames))
            currentItem = item(i, j);
            for e = 1:length(fnames)
                partIdx = partIdx + 1;
                parts{partIdx} = obj2ubjson(fnames{e}, currentItem.(fnames{e}), ...
                                            level + (dim(1) > 1) + 1 + forcearray, opt);
            end
        end
        partIdx = partIdx + 1;
        parts{partIdx} = Omarker{2};
    end
    if (dim(1) > 1)
        partIdx = partIdx + 1;
        parts{partIdx} = Amarker{2};
    end
end
if (forcearray)
    partIdx = partIdx + 1;
    parts{partIdx} = Amarker{2};
end
txt = [parts{1:partIdx}];

%% -------------------------------------------------------------------------
function [cansoa, soainfo] = struct2soa(item, opt)
% Check if struct array can be encoded as SOA
% Supports: scalar numerics, logicals, strings, nested structs,
%           and fixed-size numeric/logical arrays

cansoa = false;
soainfo = struct('names', {{}}, 'nrecords', 0, 'types', {{}}, 'markers', {{}}, ...
                 'strmeta', {{}}, 'substruct', {{}}, 'arraymeta', {{}});

if (~isstruct(item) || numel(item) <= 1)
    return
end

names = fieldnames(item);
if (isempty(names))
    return
end

nfields = length(names);
nrecords = numel(item);
types = cell(1, nfields);
markers = cell(1, nfields);
strmeta = cell(1, nfields);
substruct = cell(1, nfields);
arraymeta = cell(1, nfields);

for f = 1:nfields
    % Collect all values for this field
    allvals = {item.(names{f})};

    % Find first non-empty value to determine type
    val1 = [];
    for r = 1:nrecords
        if (~isempty(allvals{r}))
            val1 = allvals{r};
            break
        end
    end

    % If all values are empty, treat as empty string field
    if (isempty(val1))
        types{f} = 'string';
        markers{f} = '';
        continue
    end

    if (isvector(val1) && ~isscalar(val1) && (isnumeric(val1) || islogical(val1)))
        % Fixed-size numeric/logical array - must verify ALL records have same size
        arrsize = numel(val1);
        if (islogical(val1))
            elemtype = 'logical';
            elemmarker = 'T';
        else
            [elemtype, elemmarker] = soatype(val1(1), opt);
        end
        if (isempty(elemtype))
            return
        end

        % Check ALL records (including first one)
        for r = 1:nrecords
            valr = allvals{r};
            if isempty(valr)
                % Empty is OK, will be filled with zeros
                continue
            end
            if (~isvector(valr) || numel(valr) ~= arrsize)
                return  % Size mismatch - cannot use SOA
            end
            if (~strcmp(class(valr), class(val1)))
                return  % Type mismatch - cannot use SOA
            end
        end
        types{f} = 'fixedarray';
        markers{f} = ['[' repmat(elemmarker, 1, arrsize) ']'];
        arraymeta{f} = struct('size', arrsize, 'type', elemtype, 'marker', elemmarker);

    elseif (isscalar(val1) && (isnumeric(val1) || islogical(val1)))
        % Scalar numeric or logical
        [types{f}, markers{f}] = soatype(val1, opt);
        if (isempty(types{f}))
            return
        end
        % Verify uniformity - all must be scalar of same type (or empty)
        for r = 1:nrecords
            valr = allvals{r};
            if isempty(valr)
                continue  % Empty is OK
            end
            if (~isscalar(valr))
                return  % Must be scalar
            end
            if (~strcmp(class(valr), class(val1)) && ~(islogical(val1) && islogical(valr)))
                return  % Type mismatch
            end
        end

    elseif (ischar(val1) && (isrow(val1) || isempty(val1)))
        % String field - verify ALL are char row vectors or empty
        for r = 1:nrecords
            valr = allvals{r};
            if isempty(valr)
                continue  % Empty is OK
            end
            if (~ischar(valr))
                return  % Must be char
            end
            if (~isempty(valr) && ~isrow(valr))
                return  % Must be row vector
            end
        end
        types{f} = 'string';
        markers{f} = '';

    elseif (isstruct(val1) && isscalar(val1))
        % Embedded struct - verify ALL have same field names
        subnames = fieldnames(val1);
        if (isempty(subnames))
            return
        end
        for r = 1:nrecords
            valr = allvals{r};
            if (~isstruct(valr) || ~isscalar(valr) || ~isequal(fieldnames(valr), subnames))
                return
            end
        end
        [cansub, subinfo] = struct2soa([allvals{:}]', opt);
        if (~cansub)
            return
        end
        types{f} = 'substruct';
        markers{f} = '';
        substruct{f} = subinfo;
    else
        return  % Unsupported type
    end
end

soainfo.names = names;
soainfo.nrecords = nrecords;
soainfo.types = types;
soainfo.markers = markers;
soainfo.strmeta = strmeta;
soainfo.substruct = substruct;
soainfo.arraymeta = arraymeta;
cansoa = true;

%% -------------------------------------------------------------------------
function [cansoa, soainfo] = table2soa(item, opt)
% Check if table can be encoded as SOA
% Now supports fixed-size array columns
cansoa = false;
soainfo = struct('names', {{}}, 'nrecords', 0, 'types', {{}}, 'markers', {{}}, ...
                 'strmeta', {{}}, 'substruct', {{}}, 'arraymeta', {{}});

varnames = item.Properties.VariableNames;
ncols = length(varnames);
nrows = size(item, 1);

if (nrows <= 1 || ncols == 0)
    return
end

types = cell(1, ncols);
markers = cell(1, ncols);
strmeta = cell(1, ncols);
substruct = cell(1, ncols);
arraymeta = cell(1, ncols);

for c = 1:ncols
    coldata = item{:, c};

    if (ismatrix(coldata) && size(coldata, 2) > 1 && (isnumeric(coldata) || islogical(coldata)))
        % Fixed-size array column (NxM matrix)
        arrsize = size(coldata, 2);
        if (islogical(coldata))
            elemtype = 'logical';
            elemmarker = 'T';
        else
            % Use soatype to get proper marker for element type
            [elemtype, elemmarker] = soatype(coldata(1), opt);
            if (isempty(elemtype))
                [elemtype, elemmarker] = findmintype(double(coldata(:)), opt);
            end
        end
        if (isempty(elemtype))
            return
        end
        types{c} = 'fixedarray';
        markers{c} = ['[' repmat(elemmarker, 1, arrsize) ']'];
        arraymeta{c} = struct('size', arrsize, 'type', elemtype, 'marker', elemmarker);

    elseif (isvector(coldata) && (isnumeric(coldata) || islogical(coldata)))
        if (islogical(coldata))
            types{c} = 'logical';
            markers{c} = 'T';
        else
            [types{c}, markers{c}] = findmintype(double(coldata(:)), opt);
            if (isempty(types{c}))
                return
            end
        end
    elseif (iscell(coldata) && all(cellfun(@(x) ischar(x) && (isempty(x) || isrow(x)), coldata)))
        [types{c}, markers{c}, strmeta{c}] = soastrtype(coldata(:)', opt);
    else
        return
    end
end

soainfo.names = varnames;
soainfo.nrecords = nrows;
soainfo.types = types;
soainfo.markers = markers;
soainfo.strmeta = strmeta;
soainfo.substruct = substruct;
soainfo.arraymeta = arraymeta;
cansoa = true;

%% -------------------------------------------------------------------------
function [strtype, marker, meta] = soastrtype(allstrings, opt)
nrecords = length(allstrings);
meta = struct('fixedlen', 0, 'dict', {{}}, 'offsettype', '');

% Ensure all are char
for i = 1:nrecords
    if isempty(allstrings{i}) || ~ischar(allstrings{i})
        allstrings{i} = '';
    end
end

[nunique, idx] = unique(allstrings, 'first');
uniquestrings = allstrings(sort(idx));
nunique = length(uniquestrings);
lens = cellfun(@length, allstrings);
maxlen = max([lens, 0]);
force_offset = (opt.soathreshold == 0);

% Dictionary encoding
if nunique / nrecords <= opt.soathreshold && nunique <= 65535 && ~force_offset
    strtype = 'dictstring';
    meta.dict = uniquestrings;
    meta.offsettype = mininttype(nunique);
    marker = ['[$S#' I_(int32(nunique), opt)];
    for i = 1:nunique
        marker = [marker I_(int32(length(uniquestrings{i})), opt) uniquestrings{i}];
    end
    return
end

% Fixed-length encoding
if maxlen <= 255 && ~force_offset
    strtype = 'fixedstring';
    meta.fixedlen = max(maxlen, 1);  % minimum 1 for all-empty case
    marker = ['S' I_(int32(meta.fixedlen), opt)];
    return
end

% Offset-table encoding
strtype = 'offsetstring';
meta.offsettype = mininttype(sum(lens));
marker = ['[$' meta.offsettype ']'];

%% -------------------------------------------------------------------------
function [payload, deferred] = soapayload(item, soainfo, istable, isrowmajor, opt)
names = soainfo.names;
nfields = length(names);
nrecords = soainfo.nrecords;
types = soainfo.types;
strmeta = soainfo.strmeta;
substruct = soainfo.substruct;
arraymeta = soainfo.arraymeta;

payloadparts = cell(1, nfields);
deferred = {};

for f = 1:nfields
    if (istable)
        coldata = item{:, names{f}};
        if (~iscell(coldata))
            if (isnumeric(coldata) || islogical(coldata))
                if strcmp(types{f}, 'fixedarray')
                    coldata = num2cell(coldata, 2);  % Keep rows together
                else
                    coldata = num2cell(coldata);
                end
            else
                coldata = cellstr(coldata);
            end
        end
        coldata = fillempties(coldata, types{f}, arraymeta{f});
    else
        coldata = {item.(names{f})};
        coldata = fillempties(coldata, types{f}, arraymeta{f});
    end

    switch types{f}
        case 'logical'
            boolchars = repmat('F', 1, nrecords);
            boolchars([coldata{:}] ~= 0) = 'T';
            payloadparts{f} = boolchars;

        case 'fixedarray'
            am = arraymeta{f};
            if (iscell(coldata))
                mat = cell2mat(cellfun(@(x) x(:)', coldata, 'UniformOutput', false)');
            else
                mat = coldata;
            end
            if (strcmp(am.type, 'logical'))
                bools = repmat('F', size(mat));
                bools(mat ~= 0) = 'T';
                payloadparts{f} = reshape(bools', 1, []);
            else
                mat = cast(mat, am.type);  % Remove the transpose here
                if (opt.flipendian_)
                    mat = swapbytes(mat);
                end
                payloadparts{f} = char(typecast(reshape(mat', 1, []), 'uint8'));  % Transpose and flatten in one step
            end

        case 'fixedstring'
            fixedlen = strmeta{f}.fixedlen;
            strbytes = char(zeros(1, nrecords * fixedlen));
            for r = 1:nrecords
                s = coldata{r};
                if ~ischar(s)
                    s = '';
                end
                slen = min(length(s), fixedlen);
                if (slen > 0)
                    strbytes((r - 1) * fixedlen + (1:slen)) = s(1:slen);
                end
            end
            payloadparts{f} = strbytes;

        case 'dictstring'
            [~, indices] = ismember(coldata, strmeta{f}.dict);
            payloadparts{f} = intbytes(indices - 1, strmeta{f}.offsettype, opt);

        case 'offsetstring'
            indices = uint32(0:nrecords - 1);
            payloadparts{f} = intbytes(indices, strmeta{f}.offsettype, opt);
            [offsetdata, strbuf] = buildoffsettable(coldata, strmeta{f}.offsettype, opt);
            deferred{end + 1} = [offsetdata strbuf];

        case 'substruct'
            subdata = [coldata{:}]';
            % Pass the same isrowmajor value to nested struct
            % - Column-major outer -> column-major nested (for direct storage)
            % - Row-major outer -> row-major nested (for interleave to work)
            [subpayload, subdeferred] = soapayload(subdata, substruct{f}, false, isrowmajor, opt);
            payloadparts{f} = subpayload;
            deferred = [deferred subdeferred];

        otherwise
            numdata = cellfun(@(x) cast(x, types{f}), coldata);
            if (opt.flipendian_)
                numdata = swapbytes(numdata);
            end
            payloadparts{f} = char(typecast(numdata(:)', 'uint8'));
    end
end

if (isrowmajor && nfields > 0)
    payload = interleave(payloadparts, types, strmeta, substruct, arraymeta, nrecords, opt);
else
    payload = [payloadparts{:}];
end

%% -------------------------------------------------------------------------
function coldata = fillempties(coldata, typename, arraymeta)
if nargin < 3
    arraymeta = [];
end
for i = 1:length(coldata)
    if isempty(coldata{i})
        switch typename
            case 'logical'
                coldata{i} = false;
            case 'fixedarray'
                if strcmp(arraymeta.type, 'logical')
                    coldata{i} = false(1, arraymeta.size);
                else
                    coldata{i} = zeros(1, arraymeta.size, arraymeta.type);
                end
            case {'fixedstring', 'dictstring', 'offsetstring', 'string'}
                coldata{i} = '';
            otherwise
                coldata{i} = 0;  % integers and floats default to 0
        end
    end
end

%% -------------------------------------------------------------------------
function payload = interleave(payloadparts, types, strmeta, substruct, arraymeta, nrecords, opt)
nfields = length(types);
bytesizes = zeros(1, nfields);
for f = 1:nfields
    bytesizes(f) = getfieldbytes(types{f}, strmeta{f}, substruct{f}, arraymeta{f}, opt);
end

totalbytes = sum(bytesizes) * nrecords;
payload = char(zeros(1, totalbytes));

pos = 1;
for r = 1:nrecords
    for f = 1:nfields
        bsize = bytesizes(f);
        if bsize > 0
            srcstart = (r - 1) * bsize + 1;
            payload(pos:pos + bsize - 1) = payloadparts{f}(srcstart:srcstart + bsize - 1);
            pos = pos + bsize;
        end
    end
end

%% -------------------------------------------------------------------------
function nbytes = getfieldbytes(typename, strmeta, substruct, arraymeta, opt)
switch typename
    case 'logical'
        nbytes = 1;
    case 'fixedarray'
        am = arraymeta;
        if strcmp(am.type, 'logical')
            nbytes = am.size;
        else
            nbytes = am.size * opt.type2byte_.(am.type);
        end
    case 'fixedstring'
        nbytes = strmeta.fixedlen;
    case {'dictstring', 'offsetstring'}
        nbytes = opt.type2byte_.(typeformarker(strmeta.offsettype));
    case 'substruct'
        nbytes = calcstructsize(substruct, opt);
    otherwise
        nbytes = opt.type2byte_.(typename);
end

%% -------------------------------------------------------------------------
function nbytes = calcstructsize(soainfo, opt)
nbytes = 0;
for f = 1:length(soainfo.types)
    nbytes = nbytes + getfieldbytes(soainfo.types{f}, soainfo.strmeta{f}, ...
                                    soainfo.substruct{f}, soainfo.arraymeta{f}, opt);
end

%% -------------------------------------------------------------------------
function soainfo = resolvestrtypes(item, soainfo, istable, opt)
% Resolve deferred string types and build all markers
for f = 1:length(soainfo.types)
    if (strcmp(soainfo.types{f}, 'string'))
        if (istable)
            coldata = item{:, soainfo.names{f}};
            if (~iscell(coldata))
                coldata = cellstr(coldata);
            end
            allstrings = coldata(:)';
        else
            allstrings = {item.(soainfo.names{f})};
        end
        allstrings = cellfun(@(x) char(x), allstrings, 'UniformOutput', false);
        [soainfo.types{f}, soainfo.markers{f}, soainfo.strmeta{f}] = soastrtype(allstrings, opt);
    elseif (strcmp(soainfo.types{f}, 'substruct'))
        if (istable)
            coldata = item{:, soainfo.names{f}};
        else
            coldata = {item.(soainfo.names{f})};
        end
        soainfo.substruct{f} = resolvestrtypes([coldata{:}]', soainfo.substruct{f}, false, opt);
        soainfo.markers{f} = buildschema(soainfo.substruct{f}, opt);
    end
end

%% -------------------------------------------------------------------------
function [typename, marker] = soatype(val, opt)
% Get type name and marker for a scalar value
typename = '';
marker = '';
if (islogical(val))
    typename = 'logical';
    marker = 'T';
else
    idx = find(ismember(opt.IType_, class(val)), 1);
    if (~isempty(idx))
        typename = opt.IType_{idx};
        marker = opt.IM_(idx);
    else
        idx = find(ismember(opt.FType_, class(val)), 1);
        if (~isempty(idx))
            typename = opt.FType_{idx};
            marker = opt.FM_(idx);
        end
    end
end

%% -------------------------------------------------------------------------
function otype = mininttype(maxval)
% Select smallest unsigned integer type marker for value
if (maxval <= 255)
    otype = 'U';
elseif (maxval <= 65535)
    otype = 'u';
elseif (maxval <= 4294967295)
    otype = 'm';
else
    otype = 'M';
end

%% -------------------------------------------------------------------------
function schema = buildschema(soainfo, opt)
% Build schema string for SOA header
parts = cell(1, length(soainfo.names) + 2);
parts{1} = '{';
for i = 1:length(soainfo.names)
    parts{i + 1} = [I_(int32(length(soainfo.names{i})), opt) soainfo.names{i} soainfo.markers{i}];
end
parts{end} = '}';
schema = [parts{:}];

%% -------------------------------------------------------------------------
function txt = data2soa(name, item, soainfo, opt)
% SOA encoder for struct arrays and tables
nrecords = soainfo.nrecords;
isrowmajor = ismember(opt.soaformat, {'row', 'r'});
istable = isa(item, 'table');

% Get original dimensions before any modifications
if (~istable)
    origdim = size(item);
    isnd = (length(origdim) >= 2 && min(origdim) > 1);  % True 2D+ array (not a vector)

    if isnd
        % For ND arrays, permute from column-major to row-major before flattening
        % MATLAB stores in column-major, BJData expects row-major
        item = permute(item, length(origdim):-1:1);
    end
    item = item(:);
end

% Resolve string types and build markers
soainfo = resolvestrtypes(item, soainfo, istable, opt);

% Build schema and header
schema = buildschema(soainfo, opt);

% Build count/dimension string
if (~istable && exist('isnd', 'var') && isnd)
    % ND case: dimension array [d1 d2 ...]
    countstr = '[';
    for d = 1:length(origdim)
        countstr = [countstr I_(int32(origdim(d)), opt)];
    end
    countstr = [countstr ']'];
else
    % 1D case: just count
    countstr = I_(int32(nrecords), opt);
end

if (isrowmajor)
    header = ['[$' schema '#' countstr];
else
    header = ['{$' schema '#' countstr];
end
if (~isempty(name))
    header = [N_(decodevarname(name, opt.unpackhex), opt) header];
end

% Build payload
[payload, deferred] = soapayload(item, soainfo, istable, isrowmajor, opt);

txt = [header payload deferred{:}];

%% -------------------------------------------------------------------------
function bytes = intbytes(data, otype, opt)
% Convert integer data to bytes with proper type and endianness
switch otype
    case 'U'
        data = uint8(data);
    case 'u'
        data = uint16(data);
    case 'm'
        data = uint32(data);
    otherwise
        data = uint64(data);
end
if (opt.flipendian_)
    data = swapbytes(data);
end
bytes = char(typecast(data(:)', 'uint8'));

%% -------------------------------------------------------------------------
function [offsetdata, strbuf] = buildoffsettable(coldata, offsettype, opt)
nrecords = length(coldata);
lens = cellfun(@length, coldata);
offsets = [0, cumsum(lens)];
strbuf = [coldata{:}];
offsetdata = intbytes(offsets, offsettype, opt);

%% -------------------------------------------------------------------------
function typename = typeformarker(marker)
types = struct('U', 'uint8', 'u', 'uint16', 'm', 'uint32', 'M', 'uint64');
if isfield(types, marker)
    typename = types.(marker);
else
    typename = 'uint64';
end

%% -------------------------------------------------------------------------
function [basetype, marker] = findmintype(data, opt)
% Find minimum precision type for numeric data
basetype = '';
marker = '';

if (all(isfinite(data)) && all(data == floor(data)))
    minval = min(data);
    maxval = max(data);
    ranges = {[0 255], [0 65535], [0 4294967295], [0 18446744073709551615], ...
              [-128 127], [-32768 32767], [-2147483648 2147483647], [-9223372036854775808 9223372036854775807]};
    itypes = {'uint8', 'uint16', 'uint32', 'uint64', 'int8', 'int16', 'int32', 'int64'};
    for i = 1:length(itypes)
        idx = find(ismember(opt.IType_, itypes{i}), 1);
        if (~isempty(idx) && minval >= ranges{i}(1) && maxval <= ranges{i}(2))
            basetype = itypes{i};
            marker = opt.IM_(idx);
            return
        end
    end
end

idx = find(ismember(opt.FType_, 'single'), 1);
if (~isempty(idx))
    sdata = single(data);
    if (all(double(sdata) == data | (isnan(data) & isnan(sdata)) | (isinf(data) & isinf(sdata) & sign(data) == sign(sdata))))
        basetype = 'single';
        marker = opt.FM_(idx);
        return
    end
end

idx = find(ismember(opt.FType_, 'double'), 1);
if (~isempty(idx))
    basetype = 'double';
    marker = opt.FM_(idx);
end

%% -------------------------------------------------------------------------
function txt = map2ubjson(name, item, level, opt)
txt = '';
if (isa(item, 'dictionary'))
    dim = item.numEntries;
else
    dim = size(item);
end

names = keys(item);
val = values(item);
if (~iscell(names))
    names = num2cell(names, ndims(names));
end
if (~iscell(val))
    val = num2cell(val, ndims(val));
end

Omarker = opt.OM_;
om0 = Omarker{1};
if (~strcmp(om0, '{'))
    om0 = Imsgpk_(length(names), 222, 128, opt);
end

parts = cell(1, dim(1) + 3);
partIdx = 1;
if (~isempty(name))
    parts{partIdx} = [N_(decodevarname(name, opt.unpackhex), opt) om0];
else
    parts{partIdx} = om0;
end
for i = 1:dim(1)
    if (~isempty(names{i}))
        partIdx = partIdx + 1;
        parts{partIdx} = obj2ubjson(names{i}, val{i}, level + (dim(1) > 1), opt);
    end
end
partIdx = partIdx + 1;
parts{partIdx} = Omarker{2};
txt = [parts{1:partIdx}];

if (isa(txt, 'string') && length(txt) > 1)
    txt = sprintf('%s', txt);
end

%% -------------------------------------------------------------------------
function txt = str2ubjson(name, item, level, opt)
txt = '';
if (~ischar(item))
    error('input is not a string');
end
item = reshape(item, max(size(item), [1 0]));
len = size(item, 1);
Amarker = opt.AM_;

am0 = Amarker{1};
if (~strcmp(am0, '['))
    am0 = Imsgpk_(len, 220, 144, opt);
end

if (len == 1)
    sval = S_(item(1, :), opt);
    if (~isempty(name))
        txt = [N_(decodevarname(name, opt.unpackhex), opt), sval];
    else
        txt = sval;
    end
    return
end

parts = cell(1, len + 2);
partIdx = 1;
if (~isempty(name))
    parts{partIdx} = [N_(decodevarname(name, opt.unpackhex), opt) am0];
else
    parts{partIdx} = am0;
end
for e = 1:len
    partIdx = partIdx + 1;
    parts{partIdx} = S_(item(e, :), opt);
end
partIdx = partIdx + 1;
parts{partIdx} = Amarker{2};
txt = [parts{1:partIdx}];

%% -------------------------------------------------------------------------
function txt = mat2ubjson(name, item, level, opt)
if (~isnumeric(item) && ~islogical(item) && ~ischar(item))
    error('input is not an array');
end

dozip = opt.compression;
zipsize = opt.compressarraysize;
format = opt.formatversion;
Zmarker = opt.ZM_;
FTmarker = opt.FTM_;
Imarker = opt.IM_;
Omarker = opt.OM_;
isnest = opt.nestarray;
ismsgpack = opt.messagepack;

if (ismsgpack)
    isnest = 1;
end

if (~opt.nosubstruct_ && ((length(size(item)) > 2 && isnest == 0) || ...
                          issparse(item) || ~isreal(item) || opt.arraytostruct || ...
                          (~isempty(dozip) && numel(item) > zipsize)))
    cid = I_(uint32(max(size(item))), opt);
    if (isempty(name))
        txt = [Omarker{1} N_('_ArrayType_', opt), S_(class(item), opt), N_('_ArraySize_', opt), I_a(size(item), cid(1), opt)];
    elseif (isempty(item))
        txt = [N_(decodevarname(name, opt.unpackhex), opt), Zmarker];
        return
    else
        txt = [N_(decodevarname(name, opt.unpackhex), opt), Omarker{1}, N_('_ArrayType_', opt), S_(class(item), opt), N_('_ArraySize_', opt), I_a(size(item), cid(1), opt)];
    end
    childcount = 2;
else
    if (isempty(name))
        txt = matdata2ubjson(item, level + 1, opt);
    elseif (numel(item) == 1 && opt.singletarray == 0)
        txt = [N_(decodevarname(name, opt.unpackhex), opt) char(matdata2ubjson(item, level + 1, opt))];
    else
        txt = [N_(decodevarname(name, opt.unpackhex), opt), char(matdata2ubjson(item, level + 1, opt))];
    end
    return
end

if (issparse(item))
    [ix, iy] = find(item);
    data = full(item(find(item)));
    if (~isreal(item))
        data = [real(data(:)), imag(data(:))];
        if (size(item, 1) == 1)
            data = data';
        end
        txt = [txt, N_('_ArrayIsComplex_', opt), FTmarker(2)];
        childcount = childcount + 1;
    end
    txt = [txt, N_('_ArrayIsSparse_', opt), FTmarker(2)];
    childcount = childcount + 1;
    if (size(item, 1) == 1)
        fulldata = [iy(:), data'];
    elseif (size(item, 2) == 1)
        fulldata = [ix, data];
    else
        fulldata = [ix, iy, data];
    end
    if (~isempty(dozip) && numel(data * 2) > zipsize)
        cid = I_(uint32(max(size(fulldata))), opt);
        txt = [txt, N_('_ArrayZipSize_', opt), I_a(size(fulldata), cid(1), opt)];
        txt = [txt, N_('_ArrayZipType_', opt), S_(dozip, opt)];
        compfun = str2func([dozip 'encode']);
        txt = [txt, N_('_ArrayZipData_', opt), I_a(compfun(typecast(fulldata(:), 'uint8')), Imarker(1), opt)];
        childcount = childcount + 3;
    else
        if (ismsgpack)
            cid = I_(uint32(max(size(fulldata))), opt);
            txt = [txt, N_('_ArrayZipSize_', opt), I_a(size(fulldata), cid(1), opt)];
            childcount = childcount + 1;
        end
        opt.ArrayToStruct = 0;
        txt = [txt, N_('_ArrayData_', opt), cell2ubjson('', num2cell(fulldata', 2)', level + 2, opt)];
        childcount = childcount + 1;
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
            txt = [txt, N_('_ArrayIsComplex_', opt), FTmarker(2)];
            childcount = childcount + 1;
            fulldata = [real(item(:)) imag(item(:))];
        end
        cid = I_(uint32(max(size(fulldata))), opt);
        txt = [txt, N_('_ArrayZipSize_', opt), I_a(size(fulldata), cid(1), opt)];
        txt = [txt, N_('_ArrayZipType_', opt), S_(dozip, opt)];
        if (~isempty(regexp(dozip, '^blosc2', 'once')))
            compfun = @blosc2encode;
            encodeparam = {dozip, 'nthread', jsonopt('nthread', 1, opt), 'shuffle', jsonopt('shuffle', 1, opt), 'typesize', jsonopt('typesize', length(typecast(fulldata(1), 'uint8')), opt)};
        else
            compfun = str2func([dozip 'encode']);
            encodeparam = {};
        end
        txt = [txt, N_('_ArrayZipData_', opt), I_a(compfun(typecast(fulldata(:), 'uint8'), encodeparam{:}), Imarker(1), opt)];
        childcount = childcount + 3;
    else
        if (ismsgpack)
            cid = I_(uint32(length(item(:))), opt);
            txt = [txt, N_('_ArrayZipSize_', opt), I_a([~isreal(item) + 1 length(item(:))], cid(1), opt)];
            childcount = childcount + 1;
        end
        if (isreal(item))
            txt = [txt, N_('_ArrayData_', opt), matdata2ubjson(item(:)', level + 2, opt)];
            childcount = childcount + 1;
        else
            txt = [txt, N_('_ArrayIsComplex_', opt), FTmarker(2)];
            txt = [txt, N_('_ArrayData_', opt), matdata2ubjson([real(item(:)) imag(item(:))]', level + 2, opt)];
            childcount = childcount + 2;
        end
    end
end
if (Omarker{1} ~= '{')
    idx = find(txt == Omarker{1}, 1, 'first');
    if (~isempty(idx))
        txt = [txt(1:idx - 1) Imsgpk_(childcount, 222, 128, opt) txt(idx + 1:end)];
    end
end
txt = [txt, Omarker{2}];

%% -------------------------------------------------------------------------
function txt = matlabtable2ubjson(name, item, level, opt)
if (opt.formatversion >= 4 && ~opt.messagepack && ~opt.ubjson && size(item, 1) > 1)
    [cansoa, soainfo] = table2soa(item, opt);
    if (cansoa)
        txt = data2soa(name, item, soainfo, opt);
        return
    end
end

st = containers.Map();
st('_TableRecords_') = table2cell(item);
st('_TableRows_') = item.Properties.RowNames';
st('_TableCols_') = item.Properties.VariableNames;
if (isempty(name))
    txt = map2ubjson(name, st, level, opt);
else
    temp = struct(name, struct());
    temp.(name) = st;
    txt = map2ubjson(name, temp.(name), level, opt);
end

%% -------------------------------------------------------------------------
function txt = matlabobject2ubjson(name, item, level, opt)
try
    if numel(item) == 0
        st = struct();
    elseif numel(item) == 1
        txt = str2ubjson(name, char(item), level, opt);
        return
    else
        propertynames = properties(item);
        for p = 1:numel(propertynames)
            for o = numel(item):-1:1
                st(o).(propertynames{p}) = item(o).(propertynames{p});
            end
        end
    end
    txt = struct2ubjson(name, st, level, opt);
catch
    txt = any2ubjson(name, item, level, opt);
end

%% -------------------------------------------------------------------------
function txt = matdata2ubjson(mat, level, opt)
Zmarker = opt.ZM_;
if (isempty(mat))
    txt = Zmarker;
    return
end

FTmarker = opt.FTM_;
Imarker = opt.IM_;
Fmarker = opt.FM_;
Amarker = opt.AM_;
isnest = opt.nestarray;
ismsgpack = opt.messagepack;
format = opt.formatversion;

if (ismsgpack)
    isnest = 1;
end

if (~isvector(mat) && isnest == 1)
    if (format > 1.9 && opt.num2cell_ == 0)
        mat = permute(mat, ndims(mat):-1:1);
    end
    opt.num2cell_ = 1;
end

if (isa(mat, 'integer') || isinteger(mat) || (~opt.keeptype && isfloat(mat) && all(mod(mat(:), 1) == 0)))
    if (~isvector(mat) && isnest == 1)
        txt = cell2ubjson('', num2cell(mat, 1), level, opt);
    elseif (~ismsgpack || size(mat, 1) == 1)
        if (opt.keeptype)
            itype = class(mat);
            idx = find(ismember(opt.IType_, itype), 1);
            if (isempty(idx))
                idx = find(ismember(opt.IType_, itype(2:end)), 1);
            end
            type = Imarker(idx);
            if (numel(mat) == 1)
                opt.inttype_ = idx;
            end
        elseif (~any(mat < 0))
            cid = opt.IType_;
            type = Imarker(end);
            maxdata = max(double(mat(:)));
            for i = 1:length(cid)
                if (maxdata == cast(maxdata, cid{i}))
                    type = Imarker(i);
                    break
                end
            end
        else
            cid = opt.IType_;
            type = Imarker(end);
            mindata = min(double(mat(:)));
            maxdata = max(double(mat(:)));
            for i = 1:length(cid)
                if (maxdata == cast(maxdata, cid{i}) && mindata == cast(mindata, cid{i}))
                    type = Imarker(i);
                    break
                end
            end
        end
        if (numel(mat) == 1)
            if (mat < 0)
                txt = I_(int64(mat), opt);
            else
                txt = I_(uint64(mat), opt);
            end
        else
            rowmat = permute(mat, ndims(mat):-1:1);
            txt = I_a(rowmat(:), type, size(mat), opt);
        end
    else
        txt = cell2ubjson('', num2cell(mat, 2), level, opt);
    end
elseif (islogical(mat))
    if (numel(mat) == 1)
        txt = FTmarker(mat + 1);
    elseif (~isvector(mat) && isnest == 1)
        txt = cell2ubjson('', num2cell(uint8(mat), 1), level, opt);
    else
        rowmat = permute(mat, ndims(mat):-1:1);
        txt = I_a(uint8(rowmat(:)), Imarker(1), size(mat), opt);
    end
else
    am0 = Amarker{1};
    if (am0 ~= '[')
        am0 = char(145);
    end
    if (numel(mat) == 1)
        if (opt.singletarray == 1)
            txt = [am0 D_(mat, opt) Amarker{2}];
        else
            txt = D_(mat, opt);
        end
    elseif (~isvector(mat) && isnest == 1)
        txt = cell2ubjson('', num2cell(mat, 1), level, opt);
    else
        rowmat = permute(mat, ndims(mat):-1:1);
        txt = D_a(rowmat(:), Fmarker(isa(rowmat, 'double') + 2), size(mat), opt);
    end
end

%% -------------------------------------------------------------------------
function val = N_(str, opt)
str = char(str);
if (~opt.messagepack)
    val = [I_(int32(length(str)), opt) str];
else
    val = S_(str, opt);
end

%% -------------------------------------------------------------------------
function val = S_(str, opt)
if (length(str) == 1)
    if (opt.debug)
        val = [opt.SM_(1) sprintf('<%d>', str)];
    else
        val = [opt.SM_(1) str];
    end
elseif (opt.messagepack)
    val = [Imsgpk_(length(str), 218, 160, opt) str];
else
    val = ['S' I_(int32(length(str)), opt) str];
end

%% -------------------------------------------------------------------------
function val = Imsgpk_(num, base1, base0, opt)
if (num < 16)
    val = char(uint8(num) + uint8(base0));
    return
end
val = I_(uint32(num), opt);
if (val(1) > char(210))
    num = uint32(num);
    val = [char(210) data2byte(endiancheck(cast(num, 'uint32'), opt), 'uint8')];
elseif (val(1) < char(209))
    num = uint16(num);
    val = [char(209) data2byte(endiancheck(cast(num, 'uint16'), opt), 'uint8')];
end
val(1) = char(val(1) - 209 + base1);

%% -------------------------------------------------------------------------
function val = I_(num, opt)
if (~isinteger(num))
    error('input is not an integer');
end

Imarker = opt.IM_;
cid = opt.IType_;
isdebug = opt.debug;
doswap = opt.flipendian_;

if (isfield(opt, 'inttype_'))
    idx = opt.inttype_;
    casted = cast(num, cid{idx});
    if (doswap)
        casted = swapbytes(casted);
    end
    if (isdebug)
        val = [Imarker(idx) sprintf('<%.0f>', num)];
    else
        val = [Imarker(idx) char(typecast(casted, 'uint8'))];
    end
    return
end

if (Imarker(1) ~= 'U')
    if (num >= 0 && num < 127)
        val = uint8(num);
        return
    end
    if (num < 0 && num >= -31)
        val = typecast(int8(num), 'uint8');
        return
    end
end

numval = double(num);
for i = 1:length(cid)
    casted = cast(numval, cid{i});
    if (double(casted) == numval)
        if (doswap)
            casted = swapbytes(casted);
        end
        if (isdebug)
            val = [Imarker(i) sprintf('<%.0f>', num)];
        else
            val = [Imarker(i) char(typecast(casted, 'uint8'))];
        end
        return
    end
end

val = S_(sprintf('%.0f', num), opt);
if (Imarker(1) == 'U')
    val(1) = 'H';
end

%% -------------------------------------------------------------------------
function val = D_(num, opt)
if (~isfloat(num))
    error('input is not a float');
end
if (opt.debug)
    output = sprintf('<%g>', num);
else
    output = data2byte(endiancheck(num, opt), 'uint8');
end
Fmarker = opt.FM_;

if (isa(num, 'half'))
    val = [Fmarker(1) output(:)'];
elseif (isa(num, 'single'))
    val = [Fmarker(2) output(:)'];
else
    val = [Fmarker(3) output(:)'];
end

%% -------------------------------------------------------------------------
function data = I_a(num, type, dim, opt)
if (isstruct(dim))
    opt = dim;
end
Imarker = opt.IM_;
Amarker = opt.AM_;

if (Imarker(1) ~= 'U' && type <= 127)
    type = char(204);
end
id = find(ismember(Imarker, type));
if (id == 0)
    error('unsupported integer array');
end

cid = opt.IType_;
data = data2byte(endiancheck(cast(num, cid{id}), opt), 'uint8');
blen = opt.IByte_(id);

if (opt.debug)
    output = sprintf('<%g>', num);
else
    output = data(:);
end

if (opt.nestarray == 0 && numel(num) > 1 && Imarker(1) == 'U')
    if (nargin >= 4 && ~isstruct(dim) && (length(dim) == 1 || (length(dim) >= 2 && prod(dim) ~= dim(2))))
        cid = I_(uint32(max(dim)), opt);
        data = ['$' type '#' I_a(dim, cid(1), opt) output(:)'];
    else
        data = ['$' type '#' I_(int32(numel(data) / blen), opt) output(:)'];
    end
    data = ['[' data(:)'];
else
    am0 = Amarker{1};
    if (Imarker(1) ~= 'U')
        Amarker = {char(hex2dec('dd')), ''};
        am0 = Imsgpk_(numel(num), 220, 144, opt);
    end
    if (opt.debug)
        data = sprintf([type '<%g>'], num);
    else
        data = reshape(data, blen, numel(data) / blen);
        data(2:blen + 1, :) = data;
        data(1, :) = type;
    end
    data = [am0 data(:)' Amarker{2}];
end

%% -------------------------------------------------------------------------
function data = D_a(num, type, dim, opt)
Fmarker = opt.FM_;
Amarker = opt.AM_;

id = find(ismember(Fmarker, type));
if (id == 0)
    error('unsupported float array');
end

data = data2byte(endiancheck(cast(num, opt.FType_{id}), opt), 'uint8');
blen = opt.FByte_(id);

if (opt.debug)
    output = sprintf('<%g>', num);
else
    output = data(:);
end

if (opt.nestarray == 0 && numel(num) > 1 && Fmarker(end) == 'D')
    if (nargin >= 4 && (length(dim) == 1 || (length(dim) >= 2 && prod(dim) ~= dim(2))))
        cid = I_(uint32(max(dim)), opt);
        data = ['$' type '#' I_a(dim, cid(1), opt) output(:)'];
    else
        data = ['$' type '#' I_(int32(numel(data) / blen), opt) output(:)'];
    end
    data = ['[' data];
else
    am0 = Amarker{1};
    if (Fmarker(end) ~= 'D')
        Amarker = {char(hex2dec('dd')), ''};
        am0 = Imsgpk_(numel(num), 220, 144, opt);
    end
    if (opt.debug)
        data = sprintf([type '<%g>'], num);
    else
        data = reshape(data, blen, length(data) / blen);
        data(2:(blen + 1), :) = data;
        data(1, :) = type;
    end
    data = [am0 data(:)' Amarker{2}];
end

%% -------------------------------------------------------------------------
function txt = any2ubjson(name, item, level, opt)
st = containers.Map();
st('_DataInfo_') = struct('MATLABObjectClass', class(item), 'MATLABObjectSize', size(item));
st('_ByteStream_') = getByteStreamFromArray(item);

if (isempty(name))
    txt = map2ubjson(name, st, level, opt);
else
    temp = struct(name, struct());
    temp.(name) = st;
    txt = map2ubjson(name, temp.(name), level, opt);
end

%% -------------------------------------------------------------------------
function bytes = data2byte(varargin)
bytes = typecast(varargin{:});
bytes = char(bytes(:)');

%% -------------------------------------------------------------------------
function newdata = endiancheck(data, opt)
if (opt.flipendian_)
    newdata = swapbytes(data);
else
    newdata = data;
end

%% -------------------------------------------------------------------------
function txt = ext2ubjson(name, item, dtype, opt)
% Unified extension encoder for datetime, duration, complex
if opt.messagepack || opt.ubjson
    switch dtype
        case 'datetime'
            txt = str2ubjson(name, char(item), 0, opt);
        case 'duration'
            txt = mat2ubjson(name, seconds(item), 0, opt);
        case 'complex'
            txt = struct2ubjson(name, struct('re', real(item), 'im', imag(item)), 0, opt);
    end
    return
end

if numel(item) > 1
    parts = cell(1, numel(item) + 2);
    parts{1} = opt.AM_{1};
    for i = 1:numel(item)
        parts{i + 1} = encode_ext_scalar(item(i), dtype, opt);
    end
    parts{end} = opt.AM_{2};
    txt = [parts{:}];
else
    txt = encode_ext_scalar(item, dtype, opt);
end
if ~isempty(name)
    txt = [N_(decodevarname(name, opt.unpackhex), opt) txt];
end

%% -------------------------------------------------------------------------
function txt = encode_ext_scalar(val, dtype, opt)
% Unified encoder for datetime, duration, complex scalars
% Returns 'Z' for NaT/NaN, otherwise [E][typeid][len][payload]
switch dtype
    case 'datetime'
        if isnat(val)
            txt = opt.ZM_;
            return
        end
        tz = val.TimeZone;
        if isempty(tz)
            val.TimeZone = 'UTC';
        end
        pt = posixtime(val);
        hasTime = hour(val) || minute(val) || second(val);
        if ~hasTime && isempty(tz)
            typeid = 4;
            payload = [typecast(int16(year(val)), 'uint8'), uint8([month(val), day(val)])];
        elseif mod(second(val), 1) ~= 0 || pt < 0 || pt > 4294967295
            typeid = 6;
            payload = typecast(int64(round(pt * 1e6)), 'uint8');
        else
            typeid = 1;
            payload = typecast(uint32(pt), 'uint8');
        end
    case 'duration'
        if isnan(val)
            txt = opt.ZM_;
            return
        end
        typeid = 7;
        payload = typecast(int64(round(seconds(val) * 1e6)), 'uint8');
    case 'complex'
        if isa(val, 'single')
            typeid = 8;
            payload = [typecast(single(real(val)), 'uint8'), typecast(single(imag(val)), 'uint8')];
        else
            typeid = 9;
            payload = [typecast(double(real(val)), 'uint8'), typecast(double(imag(val)), 'uint8')];
        end
end
% Apply endian swap based on typeid
if opt.flipendian_
    n = length(payload);
    if typeid == 4  % date: only swap first 2 bytes (int16)
        payload(1:2) = payload(2:-1:1);
    elseif typeid == 8  % complex64: swap two 4-byte floats
        payload = [payload(4:-1:1), payload(8:-1:5)];
    elseif typeid == 9  % complex128: swap two 8-byte floats
        payload = [payload(8:-1:1), payload(16:-1:9)];
    elseif n > 1  % all others: simple reversal
        payload = payload(n:-1:1);
    end
end
txt = ['E' I_(uint8(typeid), opt) I_(uint8(length(payload)), opt) char(payload)];

%% -------------------------------------------------------------------------
function txt = jdict2ubjson(name, item, level, opt)
% Handle jdict objects - check schema for special types
if ~isa(item, 'jdict')
    txt = struct2ubjson(name, item, level, opt);
    return
end
s = item.schema;
if item.getattr('$', '') && strcmp(s.format, 'uuid')
    % UUID string
    if opt.messagepack || opt.ubjson
        txt = str2ubjson(name, char(item), level, opt);
        return
    end
    uuidstr = char(item);
    hexstr = strrep(uuidstr, '-', '');
    payload = uint8(zeros(1, 16));
    for i = 1:16
        payload(i) = hex2dec(hexstr(2 * i - 1:2 * i));
    end
    txt = ['E' I_(uint8(10), opt) I_(uint8(16), opt) char(payload)];
    if ~isempty(name)
        txt = [N_(decodevarname(name, opt.unpackhex), opt) txt];
    end
elseif isfield(s, 'type') && strcmp(s.type, 'bytes')
    % Raw extension bytes
    payload = uint8(item.data);
    typeid = uint32(0);
    if isfield(s, 'exttype')
        typeid = uint32(s.exttype);
    end
    txt = ['E' I_(typeid, opt) I_(uint32(length(payload)), opt) char(payload)];
    if ~isempty(name)
        txt = [N_(decodevarname(name, opt.unpackhex), opt) txt];
    end
else
    % Generic jdict - encode as struct
    txt = struct2ubjson(name, struct(item), level, opt);
end
