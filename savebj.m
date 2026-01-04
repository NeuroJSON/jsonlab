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
opt.unpackhex = jsonopt('UnpackHex', 1, opt);

[os, maxelem, systemendian] = computer;
opt.flipendian_ = (systemendian ~= upper(jsonopt('Endian', 'L', opt)));

% Initialize type markers before SOA check
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
    opt.FM_ = char([hex2dec('cd') hex2dec('ca') hex2dec('cb')]); % MsgPack does not have half-precision, map to uint16
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
        [cansoa, ~] = cantableencodeassoa(obj, opt);
        if (cansoa)
            skippreencode = true;
        end
    end
end

if (~skippreencode && jsonopt('PreEncode', 1, opt))
    obj = jdataencode(obj, 'Base64', 0, 'UseArrayZipSize', opt.messagepack, opt);
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
else
    txt = any2ubjson(name, item, level, opt);
end

%% -------------------------------------------------------------------------
function txt = cell2ubjson(name, item, level, opt)
txt = '';
if (~iscell(item) && ~isa(item, 'string'))
    error('input is not a cell');
end
isnum2cell = opt.num2cell_;
if (isnum2cell)
    item = squeeze(item);
else
    format = opt.formatversion;
    if (format > 1.9 && ~isvector(item))
        item = permute(item, ndims(item):-1:1);
    end
end

dim = size(item);
if (ndims(squeeze(item)) > 2) % for 3D or higher dimensions, flatten to 2D for now
    item = reshape(item, dim(1), numel(item) / dim(1));
    dim = size(item);
end
bracketlevel = ~opt.singletcell;
Zmarker = opt.ZM_;
Imarker = opt.IM_;
Amarker = opt.AM_;

if (~strcmp(Amarker{1}, '['))
    am0 = Imsgpk_(dim(2), 220, 144, opt);
else
    am0 = Amarker{1};
end
len = numel(item); % let's handle 1D cell first

% Performance optimization: use cell array to accumulate parts
parts = {};
partIdx = 0;

if (len > bracketlevel)
    if (~isempty(name))
        partIdx = partIdx + 1;
        parts{partIdx} = [N_(decodevarname(name, opt.unpackhex), opt) am0];
        name = '';
    else
        partIdx = partIdx + 1;
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
    [cansoa, soainfo] = canencodeassoa(item, opt);
    if (cansoa)
        txt = data2soa(name, item, soainfo, opt);
        return
    end
end

dim = size(item);
if (ndims(squeeze(item)) > 2) % for 3D or higher dimensions, flatten to 2D for now
    item = reshape(item, dim(1), numel(item) / dim(1));
    dim = size(item);
end
len = numel(item);
forcearray = (len > 1 || (opt.singletarray == 1 && level > 0));
Imarker = opt.IM_;
Amarker = opt.AM_;
Omarker = opt.OM_;

if (isfield(item, encodevarname('_ArrayType_')))
    opt.nosubstruct_ = 1;
end

if (~strcmp(Amarker{1}, '['))
    am0 = Imsgpk_(dim(2), 220, 144, opt);
else
    am0 = Amarker{1};
end

% Performance optimization: use cell array to accumulate parts
parts = {};
partIdx = 0;

if (~isempty(name))
    if (forcearray)
        partIdx = partIdx + 1;
        parts{partIdx} = [N_(decodevarname(name, opt.unpackhex), opt) am0];
    end
else
    if (forcearray)
        partIdx = partIdx + 1;
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
        names = fieldnames(item(i, j));
        if (~strcmp(Omarker{1}, '{'))
            om0 = Imsgpk_(length(names), 222, 128, opt);
        else
            om0 = Omarker{1};
        end
        if (~isempty(name) && len == 1 && ~forcearray)
            partIdx = partIdx + 1;
            parts{partIdx} = [N_(decodevarname(name, opt.unpackhex), opt) om0];
        else
            partIdx = partIdx + 1;
            parts{partIdx} = om0;
        end
        if (~isempty(names))
            % Performance optimization: cache struct to avoid repeated indexing
            currentItem = item(i, j);
            for e = 1:length(names)
                partIdx = partIdx + 1;
                parts{partIdx} = obj2ubjson(names{e}, currentItem.(names{e}), ...
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
function [cansoa, soainfo] = canencodeassoa(item, opt)
% Check if struct array can be encoded as SOA (all fields are same-type scalars)
cansoa = false;
soainfo = struct('names', {{}}, 'nrecords', 0, 'types', {{}}, 'markers', {{}});

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

for f = 1:nfields
    val1 = item(1).(names{f});
    if (~isscalar(val1) || ~(isnumeric(val1) || islogical(val1)))
        return
    end

    if (islogical(val1))
        types{f} = 'logical';
        markers{f} = 'T';
    else
        idx = find(ismember(opt.IType_, class(val1)));
        if (~isempty(idx))
            types{f} = opt.IType_{idx};
            markers{f} = opt.IM_(idx);
        else
            idx = find(ismember(opt.FType_, class(val1)));
            if (isempty(idx))
                return
            end
            types{f} = opt.FType_{idx};
            markers{f} = opt.FM_(idx);
        end
    end

    for r = 2:nrecords
        valr = item(r).(names{f});
        if (~isscalar(valr) || ~strcmp(class(valr), class(val1)))
            if (~(islogical(val1) && islogical(valr)))
                return
            end
        end
    end
end

soainfo.names = names;
soainfo.nrecords = nrecords;
soainfo.types = types;
soainfo.markers = markers;
cansoa = true;

%% -------------------------------------------------------------------------
function txt = data2soa(name, item, soainfo, opt)
% Unified SOA encoder for both struct arrays and tables
names = soainfo.names;
nfields = length(names);
nrecords = soainfo.nrecords;
markers = soainfo.markers;
types = soainfo.types;
istable = isa(item, 'table');
isrowmajor = ismember(opt.soaformat, {'row', 'r'});

% Build schema
schemaparts = cell(1, nfields + 1);
schemaparts{1} = '{';
for f = 1:nfields
    schemaparts{f + 1} = [I_(int32(length(names{f})), opt) names{f} markers{f}];
end
schema = [schemaparts{:} '}'];

% Build count - use ND dimensions if not a vector
dim = size(item);
if istable
    % Tables are always 2D with rows as records
    countstr = I_(int32(nrecords), opt);
else
    % For struct arrays, preserve ND shape
    if length(dim) > 1 && ~isvector(item)
        % ND array - output as [dim1 dim2 ...] with explicit brackets
        countstr = '[';
        for d = 1:length(dim)
            countstr = [countstr I_(int32(dim(d)), opt)];
        end
        countstr = [countstr ']'];
    else
        countstr = I_(int32(nrecords), opt);
    end
end

% Build header
if (isrowmajor)
    header = ['[$' schema '#' countstr];
else
    header = ['{$' schema '#' countstr];
end
if (~isempty(name))
    header = [N_(decodevarname(name, opt.unpackhex), opt) header];
end

% Build payload - flatten item for iteration
if ~istable
    item = item(:);
end

payloadparts = cell(1, nfields);
for f = 1:nfields
    if (istable)
        coldata = item{:, names{f}};
        coldata = cast(coldata(:), types{f});
    else
        coldata = arrayfun(@(x) cast(x.(names{f}), types{f}), item(:));
    end
    if (strcmp(types{f}, 'logical'))
        boolchars = repmat('F', 1, nrecords);
        boolchars(coldata ~= 0) = 'T';
        payloadparts{f} = boolchars;
    else
        if (opt.flipendian_)
            coldata = swapbytes(coldata);
        end
        payloadparts{f} = char(typecast(coldata(:)', 'uint8'));
    end
end

if (isrowmajor)
    % Interleave: reshape each column and concatenate horizontally
    bytesizes = cellfun(@(t) numel(typecast(cast(0, t), 'uint8')), types);
    bytesizes(strcmp(types, 'logical')) = 1;
    totalbytes = sum(bytesizes) * nrecords;
    payload = char(zeros(1, totalbytes));
    pos = 1;
    for r = 1:nrecords
        for f = 1:nfields
            bsize = bytesizes(f);
            payload(pos:pos + bsize - 1) = payloadparts{f}((r - 1) * bsize + 1:r * bsize);
            pos = pos + bsize;
        end
    end
else
    payload = [payloadparts{:}];
end

txt = [header payload];

%% -------------------------------------------------------------------------
function txt = map2ubjson(name, item, level, opt)
txt = '';
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

Omarker = opt.OM_;

if (~strcmp(Omarker{1}, '{'))
    om0 = Imsgpk_(length(names), 222, 128, opt);
else
    om0 = Omarker{1};
end

% Performance optimization: use cell array to accumulate parts
parts = cell(1, dim(1) + 3);
partIdx = 0;

if (~isempty(name))
    partIdx = partIdx + 1;
    parts{partIdx} = [N_(decodevarname(name, opt.unpackhex), opt) om0];
else
    partIdx = partIdx + 1;
    parts{partIdx} = om0;
end
for i = 1:dim(1)
    if (~isempty(names{i}))
        partIdx = partIdx + 1;
        parts{partIdx} = obj2ubjson(names{i}, val{i}, ...
                                    level + (dim(1) > 1), opt);
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

if (~strcmp(Amarker{1}, '['))
    am0 = Imsgpk_(len, 220, 144, opt);
else
    am0 = Amarker{1};
end

% Performance optimization: fast path for single string (most common case)
if (len == 1)
    val = item(1, :);
    sval = S_(val, opt);
    if (~isempty(name))
        txt = [N_(decodevarname(name, opt.unpackhex), opt), sval];
    else
        txt = sval;
    end
    return
end

% Multiple strings: use cell array to accumulate parts
parts = cell(1, len + 3);
partIdx = 0;

if (~isempty(name))
    partIdx = partIdx + 1;
    parts{partIdx} = [N_(decodevarname(name, opt.unpackhex), opt) am0];
else
    partIdx = partIdx + 1;
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
    else
        if (isempty(item))
            txt = [N_(decodevarname(name, opt.unpackhex), opt), Zmarker];
            return
        else
            txt = [N_(decodevarname(name, opt.unpackhex), opt), Omarker{1}, N_('_ArrayType_', opt), S_(class(item), opt), N_('_ArraySize_', opt), I_a(size(item), cid(1), opt)];
        end
    end
    childcount = 2;
else
    if (isempty(name))
        txt = matdata2ubjson(item, level + 1, opt);
    else
        if (numel(item) == 1 && opt.singletarray == 0)
            numtxt = matdata2ubjson(item, level + 1, opt);
            txt = [N_(decodevarname(name, opt.unpackhex), opt) char(numtxt)];
        else
            txt = [N_(decodevarname(name, opt.unpackhex), opt), char(matdata2ubjson(item, level + 1, opt))];
        end
    end
    return
end
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
        txt = [txt, N_('_ArrayIsComplex_', opt), FTmarker(2)];
        childcount = childcount + 1;
    end
    txt = [txt, N_('_ArrayIsSparse_', opt), FTmarker(2)];
    childcount = childcount + 1;
    if (~isempty(dozip) && numel(data * 2) > zipsize)
        if (size(item, 1) == 1)
            fulldata = [iy(:), data'];
        elseif (size(item, 2) == 1)
            fulldata = [ix, data];
        else
            fulldata = [ix, iy, data];
        end
        cid = I_(uint32(max(size(fulldata))), opt);
        txt = [txt, N_('_ArrayZipSize_', opt), I_a(size(fulldata), cid(1), opt)];
        txt = [txt, N_('_ArrayZipType_', opt), S_(dozip, opt)];
        compfun = str2func([dozip 'encode']);
        txt = [txt, N_('_ArrayZipData_', opt), I_a(compfun(typecast(fulldata(:), 'uint8')), Imarker(1), opt)];
        childcount = childcount + 3;
    else
        if (size(item, 1) == 1)
            fulldata = [iy(:), data'];
        elseif (size(item, 2) == 1)
            fulldata = [ix, data];
        else
            fulldata = [ix, iy, data];
        end
        if (ismsgpack)
            cid = I_(uint32(max(size(fulldata))), opt);
            txt = [txt, N_('_ArrayZipSize_', opt), I_a(size(fulldata), cid(1), opt)];
            childcount = childcount + 1;
        end
        opt.ArrayToStruct = 0;
        txt = [txt, N_('_ArrayData_', opt), ...
               cell2ubjson('', num2cell(fulldata', 2)', level + 2, opt)];
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
        encodeparam = {};
        if (~isempty(regexp(dozip, '^blosc2', 'once')))
            compfun = @blosc2encode;
            encodeparam = {dozip, 'nthread', jsonopt('nthread', 1, opt), 'shuffle', jsonopt('shuffle', 1, opt), 'typesize', jsonopt('typesize', length(typecast(fulldata(1), 'uint8')), opt)};
        else
            compfun = str2func([dozip 'encode']);
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
            txt = [txt, N_('_ArrayData_', opt), ...
                   matdata2ubjson(item(:)', level + 2, opt)];
            childcount = childcount + 1;
        else
            txt = [txt, N_('_ArrayIsComplex_', opt), FTmarker(2)];
            txt = [txt, N_('_ArrayData_', opt), ...
                   matdata2ubjson([real(item(:)) imag(item(:))]', level + 2, opt)];
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
    [cansoa, soainfo] = cantableencodeassoa(item, opt);
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
function [cansoa, soainfo] = cantableencodeassoa(item, opt)
% Check if table can be encoded as SOA with auto type detection
cansoa = false;
soainfo = struct('names', {{}}, 'nrecords', 0, 'types', {{}}, 'markers', {{}});

varnames = item.Properties.VariableNames;
ncols = length(varnames);
nrows = size(item, 1);

if (nrows <= 1 || ncols == 0)
    return
end

types = cell(1, ncols);
markers = cell(1, ncols);

for c = 1:ncols
    coldata = item{:, c};
    if (~isvector(coldata) || ~(isnumeric(coldata) || islogical(coldata)))
        return
    end

    if (islogical(coldata))
        types{c} = 'logical';
        markers{c} = 'T';
    else
        [types{c}, markers{c}] = findmintype(double(coldata(:)), opt);
        if (isempty(types{c}))
            return
        end
    end
end

soainfo.names = varnames;
soainfo.nrecords = nrows;
soainfo.types = types;
soainfo.markers = markers;
cansoa = true;

%% -------------------------------------------------------------------------
function [basetype, marker] = findmintype(data, opt)
% Find minimum precision type for numeric data
basetype = '';
marker = '';

isallint = all(isfinite(data)) && all(data == floor(data));
if (isallint)
    minval = min(data);
    maxval = max(data);
    ranges = {[0 255], [0 65535], [0 4294967295], [0 18446744073709551615], ...
              [-128 127], [-32768 32767], [-2147483648 2147483647], [-9223372036854775808 9223372036854775807]};
    itypes = {'uint8', 'uint16', 'uint32', 'uint64', 'int8', 'int16', 'int32', 'int64'};
    for i = 1:length(itypes)
        idx = find(ismember(opt.IType_, itypes{i}));
        if (~isempty(idx) && minval >= ranges{i}(1) && maxval <= ranges{i}(2))
            basetype = itypes{i};
            marker = opt.IM_(idx);
            return
        end
    end
end

idx = find(ismember(opt.FType_, 'single'));
if (~isempty(idx))
    sdata = single(data);
    if (all(double(sdata) == data | (isnan(data) & isnan(sdata)) | (isinf(data) & isinf(sdata) & sign(data) == sign(sdata))))
        basetype = 'single';
        marker = opt.FM_(idx);
        return
    end
end

idx = find(ismember(opt.FType_, 'double'));
if (~isempty(idx))
    basetype = 'double';
    marker = opt.FM_(idx);
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
isnum2cell = opt.num2cell_;

if (ismsgpack)
    isnest = 1;
end

if (~isvector(mat) && isnest == 1)
    if (format > 1.9 && isnum2cell == 0)
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
            idx = find(ismember(opt.IType_, itype));
            if (isempty(idx))
                idx = find(ismember(opt.IType_, itype(2:end)));
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
    logicalval = FTmarker;
    if (numel(mat) == 1)
        txt = logicalval(mat + 1);
    else
        if (~isvector(mat) && isnest == 1)
            txt = cell2ubjson('', num2cell(uint8(mat), 1), level, opt);
        else
            rowmat = permute(mat, ndims(mat):-1:1);
            txt = I_a(uint8(rowmat(:)), Imarker(1), size(mat), opt);
        end
    end
else
    am0 = Amarker{1};
    if (Amarker{1} ~= '[')
        am0 = char(145);
    end
    if (numel(mat) == 1)
        if (opt.singletarray == 1)
            txt = [am0 D_(mat, opt) Amarker{2}];
        else
            txt = D_(mat, opt);
        end
    else
        if (~isvector(mat) && isnest == 1)
            txt = cell2ubjson('', num2cell(mat, 1), level, opt);
        else
            rowmat = permute(mat, ndims(mat):-1:1);
            txt = D_a(rowmat(:), Fmarker(isa(rowmat, 'double') + 2), size(mat), opt);
        end
    end
end

%% -------------------------------------------------------------------------
function val = N_(str, opt)
ismsgpack = opt.messagepack;
str = char(str);
if (~ismsgpack)
    val = [I_(int32(length(str)), opt) str];
else
    val = S_(str, opt);
end

%% -------------------------------------------------------------------------
function val = S_(str, opt)
ismsgpack = opt.messagepack;
isdebug = opt.debug;
Smarker = opt.SM_;
if (length(str) == 1)
    if (isdebug)
        val = [Smarker(1) sprintf('<%d>', str)];
    else
        val = [Smarker(1) str];
    end
else
    if (ismsgpack)
        val = [Imsgpk_(length(str), 218, 160, opt) str];
    else
        val = ['S' I_(int32(length(str)), opt) str];
    end
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
    if (isdebug)
        val = [Imarker(idx) sprintf('<%.0f>', num)];
    else
        casted = cast(num, cid{idx});
        if (doswap)
            casted = swapbytes(casted);
        end
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
        if (isdebug)
            val = [Imarker(i) sprintf('<%.0f>', num)];
        else
            if (doswap)
                casted = swapbytes(casted);
            end
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
isdebug = opt.debug;
if (isdebug)
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

% based on Mo UBJSON specs, all integer types are stored in big endian format

cid = opt.IType_;
data = data2byte(endiancheck(cast(num, cid{id}), opt), 'uint8');
blen = opt.IByte_(id);

isnest = opt.nestarray;
isdebug = opt.debug;
if (isdebug)
    output = sprintf('<%g>', num);
else
    output = data(:);
end

if (isnest == 0 && numel(num) > 1 && Imarker(1) == 'U')
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
    if (isdebug)
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

isnest = opt.nestarray;
isdebug = opt.debug;
if (isdebug)
    output = sprintf('<%g>', num);
else
    output = data(:);
end

if (isnest == 0 && numel(num) > 1 && Fmarker(end) == 'D')
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
    if (isdebug)
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
