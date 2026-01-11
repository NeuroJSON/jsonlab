function [data, mmap] = loadbj(fname, varargin)
%
% data=loadbj(fname,opt)
%    or
% [data, mmap]=loadbj(fname,'param1',value1,'param2',value2,...)
%
% Parse a Binary JData (BJData v1 Draft-2, defined in https://github.com/NeuroJSON/bjdata)
% file or memory buffer and convert into a MATLAB data structure
%
% By default, this function parses BJD-compliant output. The BJD
% specification is largely similar to UBJSON, with additional data types
% including uint16(u), uint32(m), uint64(M) and half-precision float (h).
% Starting from BJD Draft-2 (JSONLab 3.0 beta or later), all integer and
% floating-point numbers are parsed in Little-Endian as opposed to
% Big-Endian form as in BJD Draft-1/UBJSON Draft-12 (JSONLab 2.0 or older)
%
% authors:Qianqian Fang (q.fang <at> neu.edu)
% initially created on 2013/08/01
%
% input:
%      fname: input file name, if fname contains "{}" or "[]", fname
%             will be interpreted as a BJData/UBJSON string
%      opt: a struct to store parsing options, opt can be replaced by
%           a list of ('param',value) pairs - the param string is equivalent
%           to a field in opt. opt can have the following
%           fields (first in [.|.] is the default)
%
%           SimplifyCell [1|0]: if set to 1, loadbj will call cell2mat
%                         for each element of the JSON data, and group
%                         arrays based on the cell2mat rules.
%           Endian ['L'|'B']: specify the endianness of the numbers
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
%           NameIsString [0|1]: for UBJSON Specification Draft 8 or
%                         earlier versions (JSONLab 1.0 final or earlier),
%                         the "name" tag is treated as a string. To load
%                         these UBJSON data, you need to manually set this
%                         flag to 1.
%           UseMap [0|1]: if set to 1, loadbj uses a containers.Map to
%                         store map objects; otherwise use a struct object
%           ObjectID [0|integer or list]: if set to a positive number,
%                         it returns the specified JSON object by index
%                         in a multi-JSON document; if set to a vector,
%                         it returns a list of specified objects.
%           FormatVersion [2|float]: set the JSONLab format version; since
%                         v2.0, JSONLab uses JData specification Draft 1
%                         for output format, it is incompatible with all
%                         previous releases; if old output is desired,
%                         please set FormatVersion to 1.9 or earlier.
%           MmapOnly [0|1]: if set to 1, this function only returns mmap
%           MMapInclude 'str1' or  {'str1','str2',..}: if provided, the
%                         returned mmap will be filtered by only keeping
%                         entries containing any one of the string patterns
%                         provided in a cell
%           MMapExclude 'str1' or  {'str1','str2',..}: if provided, the
%                         returned mmap will be filtered by removing
%                         entries containing any one of the string patterns
%                         provided in a cell
%
% output:
%      dat: a cell array, where {...} blocks are converted into cell arrays,
%           and [...] are converted to arrays
%      mmap: (optional) a cell array in the form of
%           {{jsonpath1,[start,length]}, {jsonpath2,[start,length]}, ...}
%           where jsonpath_i is a string in the form of JSONPath, and
%           start is an integer referring to the offset from the beginning
%           of the stream, and length is the JSON object string length.
%           For more details, please see the help section of loadjson.m
%
%           The format of the mmap table returned from this function
%           follows the JSON-Mmap Specification Draft 1 [3] defined by the
%           NeuroJSON project, see https://neurojson.org/jsonmmap/draft1/
%
% examples:
%      obj=struct('string','value','array',[1 2 3]);
%      ubjdata=savebj('obj',obj);
%      dat=loadbj(ubjdata)
%      dat=loadbj(['examples' filesep 'example1.bjd'])
%      dat=loadbj(['examples' filesep 'example1.bjd'],'SimplifyCell',0)
%
% license:
%     BSD or GPL version 3, see LICENSE_{BSD,GPLv3}.txt files for details
%
% -- this function is part of JSONLab toolbox (http://neurojson.org/jsonlab)
%

opt = varargin2struct(varargin{:});

if (length(fname) < 4096 && exist(fname, 'file') && ~exist(fname, 'dir'))
    fid = fopen(fname, 'rb');
    inputstr = fread(fid, jsonopt('MaxBuffer', inf, opt), 'uint8=>char')';
    fclose(fid);
elseif (all(fname < 128) && ~isempty(regexpi(fname, '^\s*(http|https|ftp|file)://')))
    if (exist('webread'))
        inputstr = char(webread(fname, weboptions('ContentType', 'binary')))';
    else
        inputstr = urlread(fname);
    end
else
    inputstr = fname;
end

inputlen = length(inputstr);
opt.inputlen_ = inputlen;
opt.inputstr_ = inputstr;

opt.simplifycell = jsonopt('SimplifyCell', 1, opt);
opt.simplifycellarray = jsonopt('SimplifyCellArray', 0, opt);
opt.usemap = jsonopt('UseMap', 0, opt);
opt.nameisstring = jsonopt('NameIsString', 0, opt);
opt.mmaponly = jsonopt('MmapOnly', 0, opt);

% SoA schema parsing state
opt.inschema_ = false;
opt.schemammap_ = {};

[os, maxelem, systemendian] = computer;
opt.flipendian_ = (systemendian ~= upper(jsonopt('Endian', 'L', opt)));

% Precompute type lookup table for parse_number - major optimization
% Maps ASCII codes to [type_index, byte_length]
% Types: 'iUIulmLMhdD' -> indices 1-11
opt.typemap_ = zeros(256, 2, 'uint8');
typechars = 'iUIulmLMhdD';
bytelen = [1, 1, 2, 2, 4, 4, 8, 8, 2, 4, 8];
for i = 1:11
    opt.typemap_(uint8(typechars(i)), :) = [i, bytelen(i)];
end

% Precompute type strings
if exist('half', 'builtin')
    opt.typestr_ = {'int8', 'uint8', 'int16', 'uint16', 'int32', 'uint32', 'int64', 'uint64', 'half', 'single', 'double'};
else
    opt.typestr_ = {'int8', 'uint8', 'int16', 'uint16', 'int32', 'uint32', 'int64', 'uint64', 'uint16', 'single', 'double'};
end
opt.bytelen_ = bytelen;

objid = jsonopt('ObjectID', 0, opt);
maxobjid = max(objid);
if (maxobjid == 0)
    maxobjid = inf;
end

opt.jsonpath_ = '$';
needmmap = (nargout > 1 || opt.mmaponly);
if needmmap
    mmap = {};
end

pos = 1;
jsoncount = 1;

while pos <= inputlen
    [cc, pos] = skip_markers(pos, opt);
    switch cc
        case '{'
            if needmmap
                mmap{end + 1} = {opt.jsonpath_, pos};
                [data{jsoncount}, pos, newmmap] = parse_object(pos, opt);
                if (pos < 0)
                    opt.usemap = 1;
                    [data{jsoncount}, pos, newmmap] = parse_object(-pos, opt);
                end
                mmap{end}{2} = [mmap{end}{2}, pos - mmap{end}{2}];
                mmap = [mmap(:); newmmap(:)];
            else
                [data{jsoncount}, pos] = parse_object(pos, opt);
                if (pos < 0)
                    opt.usemap = 1;
                    [data{jsoncount}, pos] = parse_object(-pos, opt);
                end
            end
        case '['
            if needmmap
                mmap{end + 1} = {opt.jsonpath_, pos};
                [data{jsoncount}, pos, newmmap] = parse_array(pos, opt);
                mmap{end}{2} = [mmap{end}{2}, pos - mmap{end}{2}];
                mmap = [mmap(:); newmmap(:)];
            else
                [data{jsoncount}, pos] = parse_array(pos, opt);
            end
        case {'S', 'C', 'B', 'H', 'i', 'U', 'I', 'u', 'l', 'm', 'L', 'M', 'h', 'd', 'D', 'T', 'F', 'Z', 'N', 'E'}
            [data{jsoncount}, pos] = parse_value(pos, [], opt);
        otherwise
            error_pos('Root level structure must start with a valid marker "{[SCBHiUIulmLMhdDTFZN"', opt, pos);
    end
    if jsoncount >= maxobjid
        break
    end
    opt.jsonpath_ = sprintf('$%d', jsoncount);
    jsoncount = jsoncount + 1;
end

if (length(objid) > 1 || min(objid) > 1)
    data = data(objid(objid <= length(data)));
end

jsoncount = length(data);
if (jsoncount == 1 && iscell(data))
    data = data{1};
end
if needmmap
    mmap = mmap';
    mmap = filterjsonmmap(mmap, jsonopt('MMapExclude', {}, opt), 0);
    mmap = filterjsonmmap(mmap, jsonopt('MMapInclude', {}, opt), 1);
end
if (jsonopt('JDataDecode', 1, varargin{:}) == 1)
    try
        data = jdatadecode(data, 'Base64', 0, 'Recursive', 1, varargin{:});
    catch ME
        warning(['Failed to decode embedded JData annotations, ' ...
                 'return raw JSON data\n\njdatadecode error: %s\n%s\nCall stack:\n%s\n'], ...
                ME.identifier, ME.message, char(savejson('', ME.stack)));
    end
end
if opt.mmaponly
    data = mmap;
end

%% -------------------------------------------------------------------------
%% shared helper functions
%% -------------------------------------------------------------------------

function [cc, pos] = skip_markers(pos, opt)
% Skip N markers and return current character
inputstr = opt.inputstr_;
cc = inputstr(pos);
while cc == 'N'
    pos = pos + 1;
    cc = inputstr(pos);
end

%% -------------------------------------------------------------------------

function [bytelen, pos] = parse_length(pos, opt)
% Parse length value (common pattern in parse_name and parseStr)
inputstr = opt.inputstr_;
if inputstr(pos) == 'U'
    bytelen = double(uint8(inputstr(pos + 1)));
    pos = pos + 2;
else
    [val, pos] = parse_number(pos, opt);
    bytelen = double(val);
end

%% -------------------------------------------------------------------------

function [cid, bytelen] = gettypeinfo(typemarker, opt)
% Get type string and byte length for a type marker
info = opt.typemap_(uint8(typemarker), :);
cid = opt.typestr_{info(1)};
bytelen = double(info(2));

%% -------------------------------------------------------------------------

function data = swapbytes_array(data, bytelen, count, doswap)
% Swap bytes for multi-byte types if needed
if doswap && bytelen > 1
    data = reshape(data, bytelen, count);
    data = data(bytelen:-1:1, :);
    data = data(:);
end

%% -------------------------------------------------------------------------

function object = assign_field_values(object, jpath, values, count)
% Assign values to struct array field by path
iscellval = iscell(values);
for i = 1:count
    if iscellval
        object(i) = setfield_by_path(object(i), jpath, values{i});
    else
        object(i) = setfield_by_path(object(i), jpath, values(i));
    end
end

%% -------------------------------------------------------------------------
%% main parser functions
%% -------------------------------------------------------------------------

function [data, adv] = parse_block(pos, type, count, opt)
inputstr = opt.inputstr_;
if (count >= 0 && ~isempty(type))
    id = opt.typemap_(uint8(type), 1);
    if id == 0 || type == 'S' || type == 'H' || type == '{' || type == '['
        adv = 0;
        switch type
            case {'S', 'H', '{', '['}
                data = cell(1, count);
                adv = pos;
                for i = 1:count
                    [data{i}, pos] = parse_value(pos, type, opt);
                end
                adv = pos - adv;
            case {'C', 'B'}
                data = inputstr(pos:pos + count - 1);
                adv = count;
            case {'T', 'F', 'N'}
                error_pos(sprintf('For security reasons, optimized type %c is disabled at position %%d', type), opt, pos);
            otherwise
                error_pos(sprintf('Unsupported optimized type %c at position %%d', type), opt, pos);
        end
        return
    end
end
[cid, len] = gettypeinfo(type, opt);
datastr = inputstr(pos:pos + len * count - 1);
newdata = uint8(datastr);
newdata = swapbytes_array(newdata, len, count, opt.flipendian_);
data = typecast(newdata, cid);
adv = double(len * count);

%% -------------------------------------------------------------------------

function [object, pos, mmap] = parse_array(pos, opt)
% JSON array is written in row-major order
needmmap = (nargout > 2);
if needmmap
    mmap = {};
    origpath = opt.jsonpath_;
end

inputstr = opt.inputstr_;
inputlen = opt.inputlen_;

pos = pos + 1;  % skip '['
object = cell(0, 1);
dim = [];
iscolumn = 0;
type = '';
count = -1;

if pos > inputlen
    return
end

[cc, pos] = skip_markers(pos, opt);

if cc == '$'
    type = inputstr(pos + 1);

    % === SoA: [$ followed by { triggers row-major SoA parsing ===
    if type == '{'
        [object, pos] = parse_soa(pos + 1, 'row', opt);
        return
    end

    pos = pos + 2;
    [cc, pos] = skip_markers(pos, opt);
end

if cc == '#'
    pos = pos + 1;
    if pos <= inputlen
        [cc, pos] = skip_markers(pos, opt);
    end
    if cc == '['
        if (isfield(opt, 'noembedding_') && opt.noembedding_ == 1)
            error_pos('ND array size specifier does not support embedding', opt, pos);
        end
        opt.noembedding_ = 1;
        if (pos + 1 < inputlen && inputstr(pos + 1) == '[')
            iscolumn = 1;
        end
        [dim, pos] = parse_array(pos, opt);
        count = prod(double(dim));
        opt.noembedding_ = 0;
    else
        [val, pos] = parse_number(pos, opt);
        count = double(val);
    end
    if pos <= inputlen
        [cc, pos] = skip_markers(pos, opt);
    end
end

if ~isempty(type)
    if count >= 0
        [object, adv] = parse_block(pos, type, count, opt);
        if (~isempty(dim) && length(dim) > 1)
            if iscolumn == 0
                object = permute(reshape(object, fliplr(dim(:)')), length(dim):-1:1);
            else
                object = reshape(object, dim);
            end
        end
        pos = pos + adv;
        return
    else
        endpos = match_bracket(inputstr, pos);
        [~, len] = gettypeinfo(type, opt);
        count = (endpos - pos) / len;
        [object, adv] = parse_block(pos, type, count, opt);
        pos = pos + adv;
        pos = pos + 1;  % skip ']'
        return
    end
end

if cc ~= ']'
    while 1
        if needmmap
            opt.jsonpath_ = [origpath sprintf('[%d]', length(object))];
            mmap{end + 1} = {opt.jsonpath_, pos};
            [val, pos, newmmap] = parse_value(pos, [], opt);
            mmap{end}{2} = [mmap{end}{2}, pos - mmap{end}{2}];
            mmap = [mmap(:); newmmap(:)];
        else
            [val, pos] = parse_value(pos, [], opt);
        end
        object{end + 1} = val;
        if count > 0 && length(object) >= count
            break
        end
        if pos > inputlen
            break
        end
        [cc, pos] = skip_markers(pos, opt);
        if cc == ']' || (count > 0 && length(object) >= count)
            break
        end
    end
end

if opt.simplifycell
    if (iscell(object) && ~isempty(object) && isnumeric(object{1}))
        if (all(cellfun(@(e) isequal(size(object{1}), size(e)), object(2:end))))
            try
                oldobj = object;
                if (iscell(object) && length(object) > 1 && ndims(object{1}) >= 2)
                    catdim = size(object{1});
                    catdim = ndims(object{1}) - (catdim(end) == 1) + 1;
                    object = cat(catdim, object{:});
                    object = permute(object, ndims(object):-1:1);
                else
                    object = cell2mat(object')';
                end
                if (iscell(oldobj) && isstruct(object) && numel(object) > 1 && opt.simplifycellarray == 0)
                    object = oldobj;
                end
            catch
            end
        end
    end
    if (~iscell(object) && size(object, 1) > 1 && ndims(object) == 2)
        object = object';
    end
end

if count == -1
    pos = pos + 1;  % skip ']'
end

%% -------------------------------------------------------------------------

function [str, pos] = parse_name(pos, opt)
[bytelen, pos] = parse_length(pos, opt);
endpos = pos + bytelen - 1;
if opt.inputlen_ >= endpos
    str = opt.inputstr_(pos:endpos);
    pos = endpos + 1;
else
    error_pos('End of file while expecting end of name', opt, pos);
end

%% -------------------------------------------------------------------------

function [str, pos, opt] = parseStr(pos, type, opt)
inputstr = opt.inputstr_;
if isempty(type)
    type = inputstr(pos);
    if type ~= 'S' && type ~= 'C' && type ~= 'B' && type ~= 'H'
        error_pos('String starting with S expected at position %d', opt, pos);
    else
        pos = pos + 1;
    end
end

if type == 'C' || type == 'B'
    if opt.inschema_
        % Schema mode: record type info, skip payload
        opt.schemammap_{end + 1} = {opt.jsonpath_, struct('t', type, 'b', 1, 'd', '')};
        str = '';
    else
        str = inputstr(pos);
        pos = pos + 1;
    end
    return
end

% S or H type: read length
[bytelen, pos] = parse_length(pos, opt);

if opt.inschema_
    % Schema mode: fixed-length string S <int> <len>
    opt.schemammap_{end + 1} = {opt.jsonpath_, struct('t', type, 'b', bytelen, 'd', '', 'enc', 'fixed')};
    str = '';
    return
end

endpos = pos + bytelen - 1;
if opt.inputlen_ >= endpos
    str = inputstr(pos:endpos);
    pos = endpos + 1;
else
    error_pos('End of file while expecting end of inputstr', opt, pos);
end

%% -------------------------------------------------------------------------

function [num, pos] = parse_number(pos, opt)
inputstr = opt.inputstr_;
typecode = inputstr(pos);
pos = pos + 1;

% Fast path for most common types
if typecode == 'U'  % uint8 - most common for string lengths
    num = uint8(inputstr(pos));
    pos = pos + 1;
    return
elseif typecode == 'i'  % int8
    num = typecast(uint8(inputstr(pos)), 'int8');
    pos = pos + 1;
    return
elseif typecode == 'I'  % int16
    newdata = uint8(inputstr(pos:pos + 1));
    if opt.flipendian_
        newdata = newdata(2:-1:1);
    end
    num = typecast(newdata, 'int16');
    pos = pos + 2;
    return
elseif typecode == 'l'  % int32
    newdata = uint8(inputstr(pos:pos + 3));
    if opt.flipendian_
        newdata = newdata(4:-1:1);
    end
    num = typecast(newdata, 'int32');
    pos = pos + 4;
    return
end

% General path for less common types
[cid, len] = gettypeinfo(typecode, opt);
if len == 0
    error_pos('expecting a number at position %d', opt, pos - 1);
end
newdata = uint8(inputstr(pos:pos + len - 1));
if opt.flipendian_ && len > 1
    newdata = newdata(len:-1:1);
end
num = typecast(newdata, cid);
pos = pos + len;

%% -------------------------------------------------------------------------

function [val, pos, mmap, opt] = parse_value(pos, type, opt)
needmmap = (nargout > 2);
if needmmap
    mmap = {};
end

inputstr = opt.inputstr_;

if length(type) == 1
    cc = type;
else
    [cc, pos] = skip_markers(pos, opt);
end

switch cc
    case {'S', 'C', 'B', 'H'}
        [val, pos, opt] = parseStr(pos, type, opt);
    case '['
        if opt.inschema_
            % Schema mode: check for string encoding markers [$S# or [$<type>]
            [val, pos, opt] = parse_schema_array(pos, opt);
        elseif needmmap
            [val, pos, mmap] = parse_array(pos, opt);
        else
            [val, pos] = parse_array(pos, opt);
        end
    case '{'
        if needmmap
            [val, pos, mmap, opt] = parse_object(pos, opt);
        else
            [val, pos, ~, opt] = parse_object(pos, opt);
        end
        if pos < 0
            opt.usemap = 1;
            if needmmap
                [val, pos, mmap, opt] = parse_object(-pos, opt);
            else
                [val, pos, ~, opt] = parse_object(-pos, opt);
            end
        end
    case {'i', 'U', 'I', 'u', 'l', 'm', 'L', 'M', 'h', 'd', 'D'}
        if opt.inschema_
            % Schema mode: record type info, skip payload
            [cid, len] = gettypeinfo(cc, opt);
            opt.schemammap_{end + 1} = {opt.jsonpath_, struct('t', cc, 'b', len, 'd', cast([], cid))};
            val = [];
            pos = pos + 1;  % skip type marker only
        else
            [val, pos] = parse_number(pos, opt);
        end
    case 'T'
        if opt.inschema_
            opt.schemammap_{end + 1} = {opt.jsonpath_, struct('t', 'T', 'b', 1, 'd', true(0, 1))};
            val = [];
        else
            val = true;
        end
        pos = pos + 1;
    case 'F'
        if opt.inschema_
            opt.schemammap_{end + 1} = {opt.jsonpath_, struct('t', 'F', 'b', 1, 'd', true(0, 1))};
            val = [];
        else
            val = false;
        end
        pos = pos + 1;
    case {'Z', 'N'}
        if opt.inschema_
            opt.schemammap_{end + 1} = {opt.jsonpath_, struct('t', cc, 'b', 0, 'd', [])};
        end
        val = [];
        pos = pos + 1;
    case 'E'
        [val, pos] = parse_extension(pos, opt);
    otherwise
        error_pos('Value expected at position %d', opt, pos);
end

%% -------------------------------------------------------------------------

function [val, pos, opt] = parse_schema_array(pos, opt)
% Parse array in schema: [type type ...] or [$S#...] or [$<type>]
inputstr = opt.inputstr_;
pos = pos + 1;  % skip '['

basepath = opt.jsonpath_;

% Check for optimized array marker [$
if inputstr(pos) == '$'
    pos = pos + 1;
    typemarker = inputstr(pos);
    pos = pos + 1;

    if typemarker == 'S' || typemarker == 'H'
        % Dictionary-based: [$S#<count>S<len>str1 S<len>str2...
        if inputstr(pos) ~= '#'
            error_pos('Expected # after [$S in schema', opt, pos);
        end
        pos = pos + 1;
        [dictcount, pos] = parse_number(pos, opt);
        dictcount = double(dictcount);

        % Read dictionary strings (temporarily disable schema mode)
        dict = cell(1, dictcount);
        opt.inschema_ = false;
        for i = 1:dictcount
            if inputstr(pos) == 'S' || inputstr(pos) == 'H'
                [dict{i}, pos, opt] = parseStr(pos, [], opt);
            else
                [dict{i}, pos, opt] = parseStr(pos, typemarker, opt);
            end
        end
        opt.inschema_ = true;

        % Determine index type based on dict size
        if dictcount <= 255
            idxtype = 'U';
            idxbytes = 1;
        elseif dictcount <= 65535
            idxtype = 'u';
            idxbytes = 2;
        elseif dictcount <= 4294967295
            idxtype = 'm';
            idxbytes = 4;
        else
            idxtype = 'M';
            idxbytes = 8;
        end

        opt.schemammap_{end + 1} = {basepath, struct('t', typemarker, 'b', idxbytes, ...
                                                     'd', '', 'enc', 'dict', 'dict', {dict}, 'idxtype', idxtype)};
        val = [];
        return

    elseif any(typemarker == 'iUIulmLM')
        % Offset-table-based: [$<int-type>]
        if inputstr(pos) ~= ']'
            error_pos('Expected ] after [$<type> in schema', opt, pos);
        end
        pos = pos + 1;

        idxbytes = double(opt.typemap_(uint8(typemarker), 2));
        opt.schemammap_{end + 1} = {basepath, struct('t', 'S', 'b', idxbytes, ...
                                                     'd', '', 'enc', 'offset', 'idxtype', typemarker)};
        val = [];
        return
    else
        error_pos('Unexpected type after [$ in schema', opt, pos - 1);
    end
end

% Regular fixed array: [type type ...]
totalbytes = 0;
idx = 0;

while inputstr(pos) ~= ']'
    idx = idx + 1;
    opt.jsonpath_ = sprintf('%s[%d]', basepath, idx - 1);
    [~, pos, ~, opt] = parse_value(pos, [], opt);
    if ~isempty(opt.schemammap_)
        totalbytes = totalbytes + opt.schemammap_{end}{2}.b;
    end
end
pos = pos + 1;  % skip ']'

% Replace individual entries with single array entry
nremove = idx;
if nremove > 0
    arraymmap = opt.schemammap_(end - nremove + 1:end);
    opt.schemammap_(end - nremove + 1:end) = [];
    opt.schemammap_{end + 1} = {basepath, struct('t', 'array', 'b', totalbytes, 'd', {arraymmap})};
end

opt.jsonpath_ = basepath;
val = [];

%% -------------------------------------------------------------------------

function pos = error_pos(msg, opt, pos)
inputstr = opt.inputstr_;
poShow = max(min([pos - 15 pos - 1 pos pos + 20], length(inputstr)), 1);
if poShow(3) == poShow(2)
    poShow(3:4) = poShow(2) + [0 -1];
end
msg = [sprintf(msg, pos) ': ' ...
       inputstr(poShow(1):poShow(2)) '<e>' inputstr(poShow(3):poShow(4))];
error('JSONLAB:BJData:InvalidFormat', msg);

%% -------------------------------------------------------------------------

function [object, pos, mmap, opt] = parse_object(pos, opt)
oldpos = pos;
needmmap = (nargout > 2);
if needmmap
    mmap = {};
    origpath = opt.jsonpath_;
end

inputstr = opt.inputstr_;
inputlen = opt.inputlen_;

pos = pos + 1;  % skip '{'
usemap = opt.usemap;
if usemap
    object = containers.Map();
else
    object = [];
end
count = -1;
type = [];

if pos > inputlen
    return
end

[cc, pos] = skip_markers(pos, opt);

if cc == '$'
    type = inputstr(pos + 1);

    % === SoA: {$ followed by { triggers column-major SoA parsing ===
    if type == '{'
        [object, pos] = parse_soa(pos + 1, 'column', opt);
        return
    end

    pos = pos + 2;
    [cc, pos] = skip_markers(pos, opt);
end

if cc == '#'
    pos = pos + 1;
    [val, pos] = parse_number(pos, opt);
    count = double(val);
    if pos <= inputlen
        [cc, pos] = skip_markers(pos, opt);
    end
end

if cc ~= '}'
    num = 0;
    while 1
        if opt.nameisstring
            [str, pos, opt] = parseStr(pos, [], opt);
        else
            [str, pos] = parse_name(pos, opt);
        end
        if ~opt.inschema_ && length(str) > 63
            pos = -oldpos;
            object = [];
            return
        end
        if isempty(str)
            str = 'x0x0_';  % empty name is valid in BJData/UBJSON
        end
        if needmmap
            opt.jsonpath_ = [origpath, '.', str];
            mmap{end + 1} = {opt.jsonpath_, pos};
            [val, pos, newmmap, opt] = parse_value(pos, [], opt);
            mmap{end}{2} = [mmap{end}{2}, pos - mmap{end}{2}];
            mmap = [mmap(:); newmmap(:)];
        else
            % Update jsonpath for schema mmap
            if opt.inschema_
                opt.jsonpath_ = [opt.jsonpath_, '.', str];
            end
            [val, pos, ~, opt] = parse_value(pos, type, opt);
            if opt.inschema_
                % Restore jsonpath after parsing
                opt.jsonpath_ = opt.jsonpath_(1:end - length(str) - 1);
            end
        end
        num = num + 1;
        if usemap
            object(str) = val;
        else
            if ~opt.inschema_
                str = encodevarname(str, opt);
                if length(str) > 63
                    pos = -oldpos;
                    object = [];
                    return
                end
            end
            object.(str) = val;
        end
        if pos > inputlen
            break
        end
        [cc, pos] = skip_markers(pos, opt);
        if (count >= 0 && num >= count) || cc == '}'
            break
        end
    end
end

if count == -1
    pos = pos + 1;  % skip '}'
end

%% -------------------------------------------------------------------------
%% SoA parsing functions
%% -------------------------------------------------------------------------

function [object, pos] = parse_soa(pos, layout, opt)
% Parse SoA container: pos at '{' of schema
% layout: 'row' (from [$) or 'column' (from {$)

inputstr = opt.inputstr_;

% Parse schema with inschema_ flag
opt.inschema_ = true;
opt.schemammap_ = {};
basepath = opt.jsonpath_;
opt.jsonpath_ = '$';
[schema, pos, ~, opt] = parse_object(pos, opt);
opt.inschema_ = false;
schemammap = opt.schemammap_;
opt.jsonpath_ = basepath;

% Skip N markers
while pos <= opt.inputlen_ && inputstr(pos) == 'N'
    pos = pos + 1;
end

% Parse # count
if inputstr(pos) ~= '#'
    error_pos('Expected # after schema', opt, pos);
end
pos = pos + 1;

% Parse count (1D or ND)
if inputstr(pos) == '['
    opt.noembedding_ = 1;
    [dim, pos] = parse_array(pos, opt);
    opt.noembedding_ = 0;
    count = prod(double(dim));
    dim = double(dim(:)');
else
    [val, pos] = parse_number(pos, opt);
    count = double(val);
    dim = count;
end

% Calculate fixed bytes per record
recordbytes = 0;
for i = 1:length(schemammap)
    recordbytes = recordbytes + schemammap{i}{2}.b;
end

% Read fixed payload
totalbytes = recordbytes * count;
payload = uint8(inputstr(pos:pos + totalbytes - 1));
pos = pos + totalbytes;

% Read deferred offset-table fields
for i = 1:length(schemammap)
    finfo = schemammap{i}{2};
    if isfield(finfo, 'enc') && strcmp(finfo.enc, 'offset')
        idxtype = finfo.idxtype;

        % Read (count+1) offsets
        [offsets, adv] = parse_block(pos, idxtype, count + 1, opt);
        pos = pos + adv;
        offsets = double(offsets);

        % Read string buffer
        buflen = offsets(end);
        if buflen > 0
            strbuf = inputstr(pos:pos + buflen - 1);
            pos = pos + buflen;
        else
            strbuf = '';
        end

        schemammap{i}{2}.offsets = offsets;
        schemammap{i}{2}.strbuf = strbuf;
    end
end

% Create struct array from payload
object = soa_payload_to_struct(schema, schemammap, payload, count, recordbytes, layout, opt);

% Reshape for ND arrays
if length(dim) > 1
    % Data was stored in row-major order after permutation
    % First reshape with dimensions in reversed order (row-major layout)
    object = reshape(object, fliplr(dim));
    % Then permute back to column-major for MATLAB
    object = permute(object, length(dim):-1:1);
end

%% -------------------------------------------------------------------------

function object = soa_payload_to_struct(schema, schemammap, payload, count, recordbytes, layout, opt)
% Convert payload to struct array

template = schema;
object = repmat(template, count, 1);

if count == 0
    return
end

nfields = length(schemammap);

if strcmp(layout, 'column')
    % Column-major: all values of field1, then all values of field2, ...
    bytepos = 1;
    for f = 1:nfields
        jpath = schemammap{f}{1};
        finfo = schemammap{f}{2};
        nbytes = finfo.b * count;

        if nbytes > 0
            fdata = payload(bytepos:bytepos + nbytes - 1);
        else
            fdata = [];
        end
        values = decode_soa_column(fdata, finfo, count, opt);
        object = assign_field_values(object, jpath, values, count);
        bytepos = bytepos + nbytes;
    end
else
    % Row-major: interleaved records
    fieldoffsets = zeros(1, nfields);
    fieldbytes = zeros(1, nfields);
    offset = 0;
    for f = 1:nfields
        fieldoffsets(f) = offset;
        fieldbytes(f) = schemammap{f}{2}.b;
        offset = offset + fieldbytes(f);
    end

    for f = 1:nfields
        jpath = schemammap{f}{1};
        finfo = schemammap{f}{2};
        fbytes = fieldbytes(f);

        if fbytes == 0
            values = cell(count, 1);
            [values{:}] = deal([]);
        else
            % Extract interleaved data into contiguous array
            fdata = zeros(fbytes * count, 1, 'uint8');
            for i = 1:count
                srcpos = (i - 1) * recordbytes + fieldoffsets(f) + 1;
                dstpos = (i - 1) * fbytes + 1;
                fdata(dstpos:dstpos + fbytes - 1) = payload(srcpos:srcpos + fbytes - 1);
            end
            values = decode_soa_column(fdata, finfo, count, opt);
        end
        object = assign_field_values(object, jpath, values, count);
    end
end

%% -------------------------------------------------------------------------

function obj = setfield_by_path(obj, jpath, value)
% Set field value using JSONPath-like path (e.g., '$.field' or '$.parent.child')
if length(jpath) >= 2 && strcmp(jpath(1:2), '$.')
    jpath = jpath(3:end);
elseif ~isempty(jpath) && jpath(1) == '$'
    jpath = jpath(2:end);
end

if isempty(jpath)
    obj = value;
    return
end

dotpos = strfind(jpath, '.');
if isempty(dotpos)
    obj.(jpath) = value;
else
    fieldname = jpath(1:dotpos(1) - 1);
    remaining = jpath(dotpos(1) + 1:end);
    obj.(fieldname) = setfield_by_path(obj.(fieldname), remaining, value);
end

%% -------------------------------------------------------------------------
%% SoA decoding functions
%% -------------------------------------------------------------------------

function values = decode_soa_column(fdata, finfo, count, opt)
% Decode contiguous field data to array of values

typemarker = finfo.t;
nbytes = finfo.b;

if nbytes == 0
    values = cell(count, 1);
    [values{:}] = deal([]);
    return
end

% Fixed array type
if strcmp(typemarker, 'array')
    values = decode_fixed_array(fdata, finfo.d, count, nbytes, opt);
    return
end

% Boolean
if typemarker == 'T' || typemarker == 'F'
    values = (fdata == uint8('T'));
    return
end

% Numeric
if any(typemarker == 'iUIulmLMhdD')
    cid = class(finfo.d);
    fdata = swapbytes_array(fdata, nbytes, count, opt.flipendian_);
    values = typecast(fdata, cid);
    return
end

% String (S or H)
enc = '';
if isfield(finfo, 'enc')
    enc = finfo.enc;
end

if isempty(enc) || strcmp(enc, 'fixed')
    values = decode_fixed_string(fdata, nbytes, count);
elseif strcmp(enc, 'dict')
    [cid, idxbytes] = gettypeinfo(finfo.idxtype, opt);
    fdata = swapbytes_array(fdata, idxbytes, count, opt.flipendian_);
    values = finfo.dict(double(typecast(fdata, cid)) + 1)';
else  % offset
    values = decode_offset_string(fdata, finfo, count, opt);
end

%% -------------------------------------------------------------------------

function values = decode_fixed_array(fdata, arraymmap, count, nbytes, opt)
% Decode fixed-size array field
values = cell(count, 1);
elemcount = length(arraymmap);
for i = 1:count
    arrval = [];
    pos = (i - 1) * nbytes + 1;
    for e = 1:elemcount
        einfo = arraymmap{e}{2};
        ebytes = einfo.b;
        edata = fdata(pos:pos + ebytes - 1);
        pos = pos + ebytes;
        etype = einfo.t;
        if any(etype == 'iUIulmLMhdD')
            if opt.flipendian_ && ebytes > 1
                edata = edata(ebytes:-1:1);
            end
            arrval = [arrval, typecast(edata, class(einfo.d))];
        else  % T or F
            arrval = [arrval, edata(1) == uint8('T')];
        end
    end
    values{i} = arrval;
end

%% -------------------------------------------------------------------------

function values = decode_fixed_string(fdata, nbytes, count)
% Decode fixed-length string field
values = cell(count, 1);
strmat = char(reshape(fdata, nbytes, count)');
for i = 1:count
    str = strmat(i, :);
    nullpos = find(str == 0, 1);
    if isempty(nullpos)
        values{i} = str;
    elseif nullpos == 1
        values{i} = '';  % Return proper 0x0 empty string
    else
        values{i} = str(1:nullpos - 1);
    end
end

%% -------------------------------------------------------------------------

function values = decode_offset_string(fdata, finfo, count, opt)
% Decode offset-table string field
[cid, idxbytes] = gettypeinfo(finfo.idxtype, opt);
fdata = swapbytes_array(fdata, idxbytes, count, opt.flipendian_);
recindices = double(typecast(fdata, cid));
offsets = finfo.offsets;
strbuf = finfo.strbuf;
values = cell(count, 1);
for i = 1:count
    idx = recindices(i);
    spos = offsets(idx + 1) + 1;
    epos = offsets(idx + 2);
    if epos >= spos
        values{i} = strbuf(spos:epos);
    else
        values{i} = '';
    end
end

%% -------------------------------------------------------------------------

function [val, pos] = parse_extension(pos, opt)
% Parse BJData Extension: [E][type-id][byte-length][payload]
pos = pos + 1;
[typeid, pos] = parse_number(pos, opt);
[bytelen, pos] = parse_number(pos, opt);
typeid = double(typeid);
bytelen = double(bytelen);

if bytelen > 0
    payload = uint8(opt.inputstr_(pos:pos + bytelen - 1));
    pos = pos + bytelen;
else
    payload = uint8([]);
end

% Swap bytes for Little-Endian (UUID excluded - Big-Endian per RFC 4122)
doswap = opt.flipendian_ && typeid ~= 10;
sw = @(d) d(end:-1:1);  % byte reversal helper

switch typeid
    case 1  % epoch_s: uint32
        if doswap
            payload = sw(payload);
        end
        val = datetime(double(typecast(payload, 'uint32')), 'ConvertFrom', 'posixtime', 'TimeZone', 'UTC');
    case {2, 6}  % epoch_us, datetime_us: int64
        if doswap
            payload = sw(payload);
        end
        val = datetime(double(typecast(payload, 'int64')) / 1e6, 'ConvertFrom', 'posixtime', 'TimeZone', 'UTC');
    case 3  % epoch_ns: int64 + uint32
        if doswap
            payload = [sw(payload(1:8)), sw(payload(9:12))];
        end
        val = datetime(double(typecast(payload(1:8), 'int64')) + double(typecast(payload(9:12), 'uint32')) / 1e9, ...
                       'ConvertFrom', 'posixtime', 'TimeZone', 'UTC');
    case 4  % date: int16 + 2*uint8
        if doswap
            payload(1:2) = sw(payload(1:2));
        end
        val = datetime(double(typecast(payload(1:2), 'int16')), double(payload(3)), double(payload(4)));
    case 5  % time_s: 3*uint8 + reserved
        val = duration(double(payload(1)), double(payload(2)), double(payload(3)));
    case 7  % timedelta_us: int64
        if doswap
            payload = sw(payload);
        end
        val = duration(0, 0, double(typecast(payload, 'int64')) / 1e6);
    case 8  % complex64: 2*float32
        if doswap
            payload = [sw(payload(1:4)), sw(payload(5:8))];
        end
        p = typecast(payload, 'single');
        val = complex(double(p(1)), double(p(2)));
    case 9  % complex128: 2*float64
        if doswap
            payload = [sw(payload(1:8)), sw(payload(9:16))];
        end
        p = typecast(payload, 'double');
        val = complex(p(1), p(2));
    case 10 % uuid: 16 bytes Big-Endian
        h = lower(reshape(dec2hex(payload, 2)', 1, []));
        val = jdict([h(1:8) '-' h(9:12) '-' h(13:16) '-' h(17:20) '-' h(21:32)], ...
                    'schema', struct('type', 'string', 'format', 'uuid'));
    otherwise % unknown extension
        val = jdict(payload, 'schema', struct('type', 'bytes', 'exttype', int32(typeid)));
end
