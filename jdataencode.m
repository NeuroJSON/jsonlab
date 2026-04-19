function jdata = jdataencode(data, varargin)
%
% jdata=jdataencode(data)
%    or
% jdata=jdataencode(data, options)
% jdata=jdataencode(data, 'Param1',value1, 'Param2',value2,...)
%
% Annotate a MATLAB struct or cell array into a JData-compliant data
% structure as defined in the JData spec: http://github.com/NeuroJSON/jdata.
% This encoded form servers as an intermediate format that allows unambiguous
% storage, exchange of complex data structures and easy-to-serialize by
% json encoders such as savejson and jsonencode (MATLAB R2016b or newer)
%
% This function implements the JData Specification Draft 3 (Jun. 2020) and
% select keywords from Draft 4 (Apr. 2026) when FormatVersion is set to 4 or above.
% New keywords in Draft 4 (FormatVersion>=4): _ArrayShape_ types range/identity/zero,
% _ArrayCoords_, _ArrayUnits_, _ArrayFillValue_, _TableIndex_, _TableSortOrder_, _DataSchema_,
% _EnumKey_/_EnumValue_/_EnumOrdered_ (categorical), _ArrayChunks_ (chunked compression)
% see http://github.com/NeuroJSON/jdata for details
%
% author: Qianqian Fang (q.fang <at> neu.edu)
%
% input:
%     data: a structure (array) or cell (array) to be encoded.
%     options: (optional) a struct or Param/value pairs for user
%              specified options (first in [.|.] is the default)
%         AnnotateArray: [0|1] - if set to 1, convert all 1D/2D matrices
%              to the annotated JData array format to preserve data types;
%              N-D (N>2), complex and sparse arrays are encoded using the
%              annotated format by default. Please set this option to 1 if
%              you intend to use MATLAB's jsonencode to convert to JSON.
%         Base64: [0|1] if set to 1, _ArrayZipData_ is assumed to
%                  be encoded with base64 format and need to be
%                  decoded first. This is needed for JSON but not
%                  UBJSON data
%         Prefix: ['x0x5F'|'x'] for JData files loaded via loadjson/loadubjson, the
%                      default JData keyword prefix is 'x0x5F'; if the
%                      json file is loaded using matlab2018's
%                      jsondecode(), the prefix is 'x'; this function
%                      attempts to automatically determine the prefix;
%                      for octave, the default value is an empty string ''.
%         UseArrayZipSize: [1|0] if set to 1, _ArrayZipSize_ will be added to
%                  store the "pre-processed" data dimensions, i.e.
%                  the original data stored in _ArrayData_, and then flaten
%                  _ArrayData_ into a row vector using row-major
%                  order; if set to 0, a 2D _ArrayData_ will be used
%         UseArrayShape: [0|1] if set to 1, a matrix will be tested by
%                  to determine if it is diagonal, triangular, banded or
%                  toeplitz, and use _ArrayShape_ to encode the matrix
%         MapAsStruct: [0|1] if set to 1, convert containers.Map into
%                  struct; otherwise, keep it as map
%         DateTime: [1|0] if set to 1, convert datetime to string
%         Compression: ['zlib'|'gzip','lzma','lz4','lz4hc'] - use zlib method
%                  to compress data array
%         CompressArraySize: [300|int]: only to compress an array if the
%                  total element count is larger than this number.
%         FormatVersion [2|float]: set the JSONLab output version; since
%                  v2.0, JSONLab uses JData specification Draft 1
%                  for output format, it is incompatible with all
%                  previous releases; if old output is desired,
%                  please set FormatVersion to 1.9 or earlier. Set
%                  to 4 to enable JData Draft 4 keywords: _ArrayShape_
%                  range/identity/zero, _ArrayCoords_, _ArrayUnits_,
%                  _ArrayFillValue_, _TableIndex_, _TableSortOrder_,
%                  _EnumKey_/_EnumValue_ (categorical), _ArrayChunks_.
%         ArrayChunks: [[]|int] when set to a positive integer and
%                  Compression is also set, split the pre-processed array
%                  buffer into 1-D segments of this many elements and
%                  compress each independently (FormatVersion>=4 only).
%                  _ArrayZipData_ then becomes a cell array of payloads.
%
% example:
%     jd=jdataencode(struct('a',rand(5)+1i*rand(5),'b',[],'c',sparse(5,5)))
%
%     encodedmat=jdataencode(single(magic(5)),'annotatearray',1,'prefix','x')
%     jdatadecode(jsondecode(jsonencode(encodedmat)))  % serialize by jsonencode
%     jdatadecode(loadjson(savejson('',encodedmat)))   % serialize by savejson
%
%     encodedtoeplitz=jdataencode(uint8(toeplitz([1,2,3,4],[1,5,6])),'usearrayshape',1,'prefix','x')
%     jdatadecode(jsondecode(jsonencode(encodedtoeplitz)))  % serialize by jsonencode
%     jdatadecode(loadjson(savejson('',encodedtoeplitz)))   % serialize by savejson
%
% license:
%     BSD or GPL version 3, see LICENSE_{BSD,GPLv3}.txt files for details
%
% -- this function is part of JSONLab toolbox (http://neurojson.org/jsonlab)
%

if (nargin == 0)
    help jdataencode;
    return
end

opt = varargin2struct(varargin{:});
if (isoctavemesh)
    opt.prefix = jsonopt('Prefix', '', opt);
else
    opt.prefix = jsonopt('Prefix', sprintf('x0x%X', '_' + 0), opt);
end
opt.compression = jsonopt('Compression', '', opt);
opt.nestarray = jsonopt('NestArray', 0, opt);
opt.formatversion = jsonopt('FormatVersion', 2, opt);
opt.compressarraysize = jsonopt('CompressArraySize', 300, opt);
opt.base64 = jsonopt('Base64', 0, opt);
opt.mapasstruct = jsonopt('MapAsStruct', 0, opt);
opt.usearrayzipsize = jsonopt('UseArrayZipSize', 1, opt);
opt.messagepack = jsonopt('MessagePack', 0, opt);
opt.usearrayshape = jsonopt('UseArrayShape', 0, opt) && exist('bandwidth');
opt.annotatearray = jsonopt('AnnotateArray', 0, opt);
opt.datetime = jsonopt('DateTime', 1, opt);
opt.arraychunks = jsonopt('ArrayChunks', [], opt);

% Performance optimization: pre-compute prefixed field names to avoid
% repeated string concatenation in hot loops
opt.N_ArrayType = [opt.prefix '_ArrayType_'];
opt.N_ArraySize = [opt.prefix '_ArraySize_'];
opt.N_ArrayData = [opt.prefix '_ArrayData_'];
opt.N_ArrayLabel = [opt.prefix '_ArrayLabel_'];
opt.N_ArrayZipSize = [opt.prefix '_ArrayZipSize_'];
opt.N_ArrayZipType = [opt.prefix '_ArrayZipType_'];
opt.N_ArrayZipData = [opt.prefix '_ArrayZipData_'];
opt.N_ArrayIsComplex = [opt.prefix '_ArrayIsComplex_'];
opt.N_ArrayIsSparse = [opt.prefix '_ArrayIsSparse_'];
opt.N_ArrayShape = [opt.prefix '_ArrayShape_'];
opt.N_TableCols = [opt.prefix '_TableCols_'];
opt.N_TableRows = [opt.prefix '_TableRows_'];
opt.N_TableRecords = [opt.prefix '_TableRecords_'];
opt.N_GraphNodes = [opt.prefix '_GraphNodes_'];
opt.N_GraphEdges = [opt.prefix '_GraphEdges_'];
opt.N_DataInfo = [opt.prefix '_DataInfo_'];
opt.N_ByteStream = [opt.prefix '_ByteStream_'];
opt.N_MapData = [opt.prefix '_MapData_'];
opt.N_ArrayCoords = [opt.prefix '_ArrayCoords_'];
opt.N_ArrayUnits = [opt.prefix '_ArrayUnits_'];
opt.N_ArrayFillValue = [opt.prefix '_ArrayFillValue_'];
opt.N_ArrayChunks = [opt.prefix '_ArrayChunks_'];
opt.N_TableIndex = [opt.prefix '_TableIndex_'];
opt.N_TableSortOrder = [opt.prefix '_TableSortOrder_'];
opt.N_DataSchema = [opt.prefix '_DataSchema_'];
opt.N_EnumKey = [opt.prefix '_EnumKey_'];
opt.N_EnumValue = [opt.prefix '_EnumValue_'];
opt.N_EnumOrdered = [opt.prefix '_EnumOrdered_'];

jdata = obj2jd(data, opt);

%% -------------------------------------------------------------------------
function newitem = obj2jd(item, opt)
newitem = item;
if (iscell(item))
    newitem = cell2jd(item, opt);
elseif (isa(item, 'jdict'))
    if (isempty(item{'kind'}))
        newitem = obj2jd(item(), opt);
    end
elseif (isstruct(item))
    newitem = struct2jd(item, opt);
elseif (isnumeric(item) || islogical(item) || isa(item, 'timeseries'))
    newitem = mat2jd(item, opt);
elseif (ischar(item) || isa(item, 'string'))
    newitem = mat2jd(item, opt);
elseif (isa(item, 'containers.Map') || isa(item, 'dictionary'))
    newitem = map2jd(item, opt);
elseif (isa(item, 'categorical'))
    if (opt.formatversion >= 4)
        newitem = cat2jd(item, opt);
    else
        newitem = cell2jd(cellstr(item), opt);
    end
elseif (isa(item, 'function_handle'))
    newitem = struct2jd(functions(item), opt);
elseif (isa(item, 'table'))
    newitem = table2jd(item, opt);
elseif (isa(item, 'digraph') || isa(item, 'graph'))
    newitem = graph2jd(item, opt);
elseif (isobject(item))
    newitem = matlabobject2jd(item, opt);
end

if (isa(item, 'jdict') && isempty(item{'kind'}))  % apply attribute and schema
    attrpath = item.getattr();
    if (~isempty(attrpath))
        newitem = jdict(newitem);

        for i = 1:length(attrpath)
            val = newitem.(attrpath{i}).v();
            if (isempty(val))
                continue
            end
            if (isnumeric(val))
                opt.annotatearray = 1;
                val = mat2jd(val, opt);
            end
            if (~(isstruct(val) && isfield(val, opt.N_ArrayType)))
                continue
            end
            attr = item.getattr(attrpath{i});
            attrname = keys(attr);
            for j = 1:length(attrname)
                if (strcmp(attrname{j}, 'dims'))
                    val.(opt.N_ArrayLabel) = attr(attrname{j});
                elseif (opt.formatversion >= 4 && strcmp(attrname{j}, 'coords'))
                    val.(opt.N_ArrayCoords) = attr(attrname{j});
                elseif (opt.formatversion >= 4 && strcmp(attrname{j}, 'units'))
                    val.(opt.N_ArrayUnits) = attr(attrname{j});
                elseif (opt.formatversion >= 4 && strcmp(attrname{j}, 'fillvalue'))
                    val.(opt.N_ArrayFillValue) = attr(attrname{j});
                else
                    val.(attrname{j}) = attr(attrname{j});
                end
                newitem.(attrpath{i}) = val;
            end
        end
    end
    % emit _DataSchema_ when schema is set and format >= 4
    itemschema = item.getschema();
    if (opt.formatversion >= 4 && ~isempty(itemschema))
        if (isa(newitem, 'jdict') && isstruct(newitem.data))
            newitem.data.(opt.N_DataSchema) = itemschema;
        elseif (isstruct(newitem))
            newitem.(opt.N_DataSchema) = itemschema;
        end
    end
end

%% -------------------------------------------------------------------------
function newitem = cell2jd(item, opt)
% Optimization: direct loop instead of cellfun for better performance
n = numel(item);
newitem = cell(size(item));
for i = 1:n
    newitem{i} = obj2jd(item{i}, opt);
end

%% -------------------------------------------------------------------------
function newitem = struct2jd(item, opt)

num = numel(item);
if (num > 1)  % struct array
    newitem = obj2jd(num2cell(item), opt);
    try
        newitem = cell2mat(newitem);
    catch
    end
elseif (num == 1) % a single struct
    names = fieldnames(item);
    newitem = struct;
    for i = 1:length(names)
        newitem.(names{i}) = obj2jd(item.(names{i}), opt);
    end
else
    newitem = item;
end

%% -------------------------------------------------------------------------
function newitem = map2jd(item, opt)

names = item.keys;
if (opt.mapasstruct)  % convert a map to struct
    newitem = struct;
    if (~strcmp(item.KeyType, 'char'))
        data = num2cell(reshape([names, item.values], length(names), 2), 2);
        for i = 1:length(names)
            data{i}{2} = obj2jd(data{i}{2}, opt);
        end
        newitem.(opt.N_MapData) = data;
    else
        for i = 1:length(names)
            newitem.([opt.prefix names{i}]) = obj2jd(item(names{i}), opt);
        end
    end
else   % keep as a map and only encode its values
    if (isa(item, 'dictionary'))
        newitem = dictionary();
    elseif (strcmp(item.KeyType, 'char'))
        newitem = containers.Map();
    else
        newitem = containers.Map('KeyType', item.KeyType, 'ValueType', 'any');
    end
    if (isa(item, 'dictionary'))
        for i = 1:length(names)
            newitem(names(i)) = obj2jd(item(names(i)), opt);
        end
    else
        for i = 1:length(names)
            newitem(names{i}) = obj2jd(item(names{i}), opt);
        end
    end
end

%% -------------------------------------------------------------------------
function newitem = mat2jd(item, opt)

zipmethod = opt.compression;
minsize = opt.compressarraysize;

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

% Range encoding for uniformly-spaced vectors (FormatVersion >= 4)
if (opt.formatversion >= 4 && opt.usearrayshape && isvector(item) && isreal(item) && ...
    ~issparse(item) && numel(item) >= 3 && ~opt.nestarray && (isempty(zipmethod) || numel(item) <= minsize) && ~opt.annotatearray)
    dv = diff(double(item(:)));
    tol = 4 * eps(max(abs(double(item(:)))) + 1) * numel(item);
    if (all(abs(dv - dv(1)) <= tol))
        newitem = struct(opt.N_ArrayType, class(item), opt.N_ArraySize, size(item));
        newitem.(opt.N_ArrayShape) = 'range';
        newitem.(opt.N_ArrayData) = [double(item(1)), double(item(end))];
        return
    end
end

% FAST PATH: Early exit for simple cases that don't need encoding
% Check usearrayshape condition: only skip if shape encoding won't apply
skipshape = ~opt.usearrayshape || ndims(item) ~= 2 || isvector(item);

if (skipshape && ...
    (isempty(item) || isa(item, 'string') || ischar(item) || opt.nestarray || ...
     ((isvector(item) || ndims(item) == 2) && isreal(item) && ~issparse(item) && ...
      ~opt.annotatearray && (isempty(zipmethod) || numel(item) <= minsize))))
    newitem = item;
    return
end

% Need full encoding - build struct with pre-computed field names
newitem = struct(opt.N_ArrayType, class(item), opt.N_ArraySize, size(item));

% 2d numerical (real/complex/sparse) arrays with _ArrayShape_ encoding enabled
if (opt.usearrayshape && ndims(item) == 2 && ~isvector(item))
    encoded = 1;

    % Zero and identity shapes (FormatVersion >= 4 only)
    if (opt.formatversion >= 4 && isreal(item) && ~issparse(item))
        if (~any(item(:)))  % all-zero matrix
            newitem.(opt.N_ArrayShape) = 'zero';
            newitem.(opt.N_ArrayData) = 0;
            return
        end
        if (size(item, 1) == size(item, 2) && size(item, 1) > 0)
            d = diag(item);
            if (all(d == d(1)) && ~any(any(item - diag(d))))  % scaled identity
                newitem.(opt.N_ArrayShape) = 'identity';
                newitem.(opt.N_ArrayData) = double(d(1));
                return
            end
        end
    end

    if (~isreal(item))
        newitem.(opt.N_ArrayIsComplex) = true;
    end
    symmtag = '';
    if (isreal(item) && issymmetric(double(item)))
        symmtag = 'symm';
        item = tril(item);
    elseif (~isreal(item) && ishermitian(double(item)))
        symmtag = 'herm';
        item = tril(item);
    end
    [lband, uband] = bandwidth(double(item));
    newitem.(opt.N_ArrayZipSize) = [lband + uband + 1, min(size(item, 1), size(item, 2))];
    if (lband + uband == 0) % isdiag
        newitem.(opt.N_ArrayShape) = 'diag';
        newitem.(opt.N_ArrayData) = diag(item).';
    elseif (uband == 0 && lband == size(item, 1) - 1) % lower triangular
        newitem.(opt.N_ArrayShape) = ['lower' symmtag];
        item = item.';
        newitem.(opt.N_ArrayData) = item(triu(true(size(item)))).';
    elseif (lband == 0 && uband == size(item, 2) - 1) % upper triangular
        newitem.(opt.N_ArrayShape) = 'upper';
        item = item.';
        newitem.(opt.N_ArrayData) = item(tril(true(size(item)))).';
    elseif (lband == 0) % upper band
        newitem.(opt.N_ArrayShape) = {'upperband', uband};
        newitem.(opt.N_ArrayData) = spdiags(item.', -uband:lband).';
    elseif (uband == 0) % lower band
        newitem.(opt.N_ArrayShape) = {sprintf('lower%sband', symmtag), lband};
        newitem.(opt.N_ArrayData) = spdiags(item.', -uband:lband).';
    elseif (uband < size(item, 2) - 1 || lband < size(item, 1) - 1) % band
        newitem.(opt.N_ArrayShape) = {'band', uband, lband};
        newitem.(opt.N_ArrayData) = spdiags(item.', -uband:lband).';
    elseif (all(toeplitz(item(:, 1), item(1, :)) == item))  % Toeplitz matrix
        newitem.(opt.N_ArrayShape) = 'toeplitz';
        newitem.(opt.N_ArrayZipSize) = [2, max(size(item))];
        newitem.(opt.N_ArrayData) = zeros(2, max(size(item)));
        newitem.(opt.N_ArrayData)(1, 1:size(item, 2)) = item(1, :);
        newitem.(opt.N_ArrayData)(2, 1:size(item, 1)) = item(:, 1).';
    else  % full matrix
        newitem = rmfield(newitem, opt.N_ArrayZipSize);
        encoded = 0;
    end

    % serialize complex data at last
    if (encoded && isstruct(newitem) && ~isreal(newitem.(opt.N_ArrayData)))
        arrdata = newitem.(opt.N_ArrayData);
        item2 = squeeze(zeros([2, size(arrdata)]));
        item2(1, :) = real(arrdata(:));
        item2(2, :) = imag(arrdata(:));
        newitem.(opt.N_ArrayZipSize) = size(item2);
        newitem.(opt.N_ArrayData) = item2;
    end

    % wrap _ArrayData_ into a single row vector
    if (encoded)
        if (isstruct(newitem) && ~isvector(newitem.(opt.N_ArrayData)))
            arrdata = newitem.(opt.N_ArrayData);
            arrdata = permute(arrdata, ndims(arrdata):-1:1);
            newitem.(opt.N_ArrayData) = arrdata(:).';
        else
            newitem = rmfield(newitem, opt.N_ArrayZipSize);
        end
        newitem.(opt.N_ArrayData) = full(newitem.(opt.N_ArrayData));
        return
    end
end

% no encoding for char arrays or non-sparse real vectors (already handled struct creation above)
if (isempty(item) || isa(item, 'string') || ischar(item) || opt.nestarray || ...
    ((isvector(item) || ndims(item) == 2) && isreal(item) && ~issparse(item) && ...
     ~opt.annotatearray))
    newitem = item;
    return
end

if (isa(item, 'logical'))
    item = uint8(item);
end

if (isreal(item))
    if (issparse(item))
        fulldata = full(item(item ~= 0));
        newitem.(opt.N_ArrayIsSparse) = true;
        newitem.(opt.N_ArrayZipSize) = [2 + (~isvector(item)), length(fulldata)];
        if (isvector(item))
            newitem.(opt.N_ArrayData) = [find(item(:))', fulldata(:)'];
        else
            [ix, iy] = find(item);
            newitem.(opt.N_ArrayData) = [ix(:)', iy(:)', fulldata(:)'];
        end
    else
        if (opt.formatversion > 1.9)
            item = permute(item, ndims(item):-1:1);
        end
        newitem.(opt.N_ArrayData) = item(:)';
    end
else
    newitem.(opt.N_ArrayIsComplex) = true;
    if (issparse(item))
        fulldata = full(item(item ~= 0));
        newitem.(opt.N_ArrayIsSparse) = true;
        newitem.(opt.N_ArrayZipSize) = [3 + (~isvector(item)), length(fulldata)];
        if (isvector(item))
            newitem.(opt.N_ArrayData) = [find(item(:))', real(fulldata(:))', imag(fulldata(:))'];
        else
            [ix, iy] = find(item);
            newitem.(opt.N_ArrayData) = [ix(:)', iy(:)', real(fulldata(:))', imag(fulldata(:))'];
        end
    else
        if (opt.formatversion > 1.9)
            item = permute(item, ndims(item):-1:1);
        end
        newitem.(opt.N_ArrayZipSize) = [2, numel(item)];
        newitem.(opt.N_ArrayData) = [real(item(:))', imag(item(:))'];
    end
end

if (opt.usearrayzipsize == 0 && isfield(newitem, opt.N_ArrayZipSize))
    data = newitem.(opt.N_ArrayData);
    data = reshape(data, fliplr(newitem.(opt.N_ArrayZipSize)));
    newitem.(opt.N_ArrayData) = permute(data, ndims(data):-1:1);
    newitem = rmfield(newitem, opt.N_ArrayZipSize);
end

if (~isempty(zipmethod) && numel(item) > minsize)
    encodeparam = {};
    if (~isempty(regexp(zipmethod, '^blosc2', 'once')))
        compfun = @blosc2encode;
        encodeparam = {zipmethod, 'nthread', jsonopt('nthread', 1, opt), ...
                       'shuffle', jsonopt('shuffle', 1, opt), ...
                       'typesize', jsonopt('typesize', length(typecast(item(1), 'uint8')), opt)};
    else
        compfun = str2func([zipmethod 'encode']);
    end
    newitem.(opt.N_ArrayZipType) = lower(zipmethod);
    if (opt.formatversion >= 4 && ~isempty(opt.arraychunks) && isfield(newitem, opt.N_ArrayData))
        chunkshape = double(opt.arraychunks(:)');
        if (numel(chunkshape) == 1)
            % 1-D chunking: split flat pre-processed buffer into equal segments
            arrdata = newitem.(opt.N_ArrayData)(:)';
            chunklen = chunkshape;
            nelem = numel(arrdata);
            nchunks = ceil(nelem / chunklen);
            zipchunks = cell(1, nchunks);
            for ci = 1:nchunks
                startidx = (ci - 1) * chunklen + 1;
                endidx = min(ci * chunklen, nelem);
                chunk = arrdata(startidx:endidx);
                zipchunks{ci} = compfun(typecast(chunk, 'uint8'), encodeparam{:});
                if (opt.base64)
                    zipchunks{ci} = char(base64encode(zipchunks{ci}));
                end
            end
            newitem.(opt.N_ArrayChunks) = [chunklen];
            if (~isfield(newitem, opt.N_ArrayZipSize))
                newitem.(opt.N_ArrayZipSize) = nelem;
            end
            newitem.(opt.N_ArrayZipData) = zipchunks;
        else
            % N-D chunking: two modes depending on array type.
            % Dense (real/complex): _ArrayChunks_ is in _ArraySize_ (original) order;
            %   tiles the row-major permuted intermediate; _ArrayZipSize_ = [1/2, N_total].
            % Non-dense (sparse/shaped): _ArrayChunks_ is in _ArrayZipSize_ (processed) order;
            %   tiles the processed _ArrayData_ matrix directly.
            isdense_chunk = ~(isfield(newitem, opt.N_ArrayIsSparse) && newitem.(opt.N_ArrayIsSparse)) && ~isfield(newitem, opt.N_ArrayShape);
            if (isdense_chunk)
                % Dense: item is already permuted to row-major.
                % chunkshape is in original _ArraySize_ order; flip to get permuted-space chunks.
                origsize = fliplr(size(item));     % original _ArraySize_ dimension order
                ndim = numel(origsize);
                chunkshape(end + 1:ndim) = origsize(numel(chunkshape) + 1:end);
                chunkshape = min(chunkshape, origsize);   % clamp against original dims
                chunkshape_perm = fliplr(chunkshape);     % chunk shape in permuted space
                arrsize_perm = size(item);
                nchunks_nd = ceil(arrsize_perm ./ chunkshape_perm);
                zipchunks = cell(1, prod(nchunks_nd));
                tidx = cell(1, ndim);
                for ci = 1:prod(nchunks_nd)
                    [tidx{:}] = ind2sub(nchunks_nd, ci);
                    ranges = cell(1, ndim);
                    for d = 1:ndim
                        r1 = (tidx{d} - 1) * chunkshape_perm(d) + 1;
                        r2 = min(tidx{d} * chunkshape_perm(d), arrsize_perm(d));
                        ranges{d} = r1:r2;
                    end
                    chunk = item(ranges{:});
                    if (~isreal(item))
                        chunk_flat = [real(chunk(:))', imag(chunk(:))'];
                        zipchunks{ci} = compfun(typecast(chunk_flat, 'uint8'), encodeparam{:});
                    else
                        zipchunks{ci} = compfun(typecast(chunk(:)', 'uint8'), encodeparam{:});
                    end
                    if (opt.base64)
                        zipchunks{ci} = char(base64encode(zipchunks{ci}));
                    end
                end
                newitem.(opt.N_ArrayChunks) = chunkshape;   % stored in original _ArraySize_ order
                if (~isreal(item))
                    newitem.(opt.N_ArrayZipSize) = [2, numel(item)];
                else
                    newitem.(opt.N_ArrayZipSize) = [1, numel(item)];
                end
            else
                % Non-dense (sparse/shaped): tile the logical _ArrayZipSize_ shape.
                % _ArrayData_ is stored as a flat row; reshape to _ArrayZipSize_ for tiling.
                % _ArrayChunks_ is in _ArrayZipSize_ coordinate space.
                procsize = double(newitem.(opt.N_ArrayZipSize));  % e.g. [3,K] for sparse
                ndim = numel(procsize);
                chunkshape(end + 1:ndim) = procsize(numel(chunkshape) + 1:end);
                chunkshape = min(chunkshape, procsize);
                nchunks_nd = ceil(procsize ./ chunkshape);
                % Reshape flat _ArrayData_ row to logical procsize (inverse of rows-concatenated)
                flatdata = newitem.(opt.N_ArrayData)(:)';
                procdata = permute(reshape(flatdata, fliplr(procsize)), ndim:-1:1);
                zipchunks = cell(1, prod(nchunks_nd));
                tidx = cell(1, ndim);
                for ci = 1:prod(nchunks_nd)
                    [tidx{:}] = ind2sub(nchunks_nd, ci);
                    ranges = cell(1, ndim);
                    for d = 1:ndim
                        r1 = (tidx{d} - 1) * chunkshape(d) + 1;
                        r2 = min(tidx{d} * chunkshape(d), procsize(d));
                        ranges{d} = r1:r2;
                    end
                    chunk = procdata(ranges{:});
                    zipchunks{ci} = compfun(typecast(chunk(:)', 'uint8'), encodeparam{:});
                    if (opt.base64)
                        zipchunks{ci} = char(base64encode(zipchunks{ci}));
                    end
                end
                newitem.(opt.N_ArrayChunks) = chunkshape;
                % _ArrayZipSize_ was already set by the sparse/shaped encoding path; keep it.
            end
            newitem.(opt.N_ArrayZipData) = zipchunks;
        end
        newitem = rmfield(newitem, opt.N_ArrayData);
    else
        if (~isfield(newitem, opt.N_ArrayZipSize))
            newitem.(opt.N_ArrayZipSize) = size(newitem.(opt.N_ArrayData));
        end
        newitem.(opt.N_ArrayZipData) = compfun(typecast(newitem.(opt.N_ArrayData)(:).', 'uint8'), encodeparam{:});
        newitem = rmfield(newitem, opt.N_ArrayData);
        if (opt.base64)
            newitem.(opt.N_ArrayZipData) = char(base64encode(newitem.(opt.N_ArrayZipData)));
        end
    end
end

if (isfield(newitem, opt.N_ArrayData) && isempty(newitem.(opt.N_ArrayData)))
    newitem.(opt.N_ArrayData) = [];
end

%% -------------------------------------------------------------------------
function newitem = cat2jd(item, opt)
% Encode a MATLAB categorical array as a JData enumeration (Draft 4)
keys = reshape(categories(item), 1, []);  % ensure 1xN row for flat JSON array
vals = uint32(item);  % 1-based codes; 0 for <undefined>
newitem = struct(opt.N_EnumKey, {keys}, opt.N_EnumValue, vals);
if (isordinal(item))
    newitem.(opt.N_EnumOrdered) = true;
end

%% -------------------------------------------------------------------------
function newitem = table2jd(item, opt)

newitem = struct;
newitem.(opt.N_TableCols) = item.Properties.VariableNames;
newitem.(opt.N_TableRows) = item.Properties.RowNames';
newitem.(opt.N_TableRecords) = table2cell(item);
if (opt.formatversion >= 4 && ~isempty(item.Properties.UserData) && isstruct(item.Properties.UserData))
    if (isfield(item.Properties.UserData, 'TableIndex'))
        newitem.(opt.N_TableIndex) = item.Properties.UserData.TableIndex;
    end
    if (isfield(item.Properties.UserData, 'TableSortOrder'))
        newitem.(opt.N_TableSortOrder) = item.Properties.UserData.TableSortOrder;
    end
end

%% -------------------------------------------------------------------------
function newitem = graph2jd(item, opt)

newitem = struct;
nodedata = table2struct(item.Nodes);
if (isfield(nodedata, 'Name'))
    nodedata = rmfield(nodedata, 'Name');
    newitem.(opt.N_GraphNodes) = containers.Map(item.Nodes.Name, num2cell(nodedata), 'UniformValues', false);
else
    newitem.(opt.N_GraphNodes) = containers.Map(1:max(item.Edges.EndNodes(:)), num2cell(nodedata), 'UniformValues', false);
end
edgenodes = num2cell(item.Edges.EndNodes);
edgedata = table2struct(item.Edges);
if (isfield(edgedata, 'EndNodes'))
    edgedata = rmfield(edgedata, 'EndNodes');
end
edgenodes(:, 3) = num2cell(edgedata);
if (isa(item, 'graph'))
    if (strcmp(opt.prefix, 'x'))
        newitem.(genvarname('_GraphEdges0_')) = edgenodes;
    else
        newitem.(encodevarname('_GraphEdges0_')) = edgenodes;
    end
else
    newitem.(opt.N_GraphEdges) = edgenodes;
end

%% -------------------------------------------------------------------------
function newitem = matlabobject2jd(item, opt)
if (~opt.datetime && (isa(item, 'datetime') || isa(item, 'duration')))
    newitem = item;
    return
end
try
    if numel(item) == 0 % empty object
        newitem = struct();
    elseif numel(item) == 1 %
        newitem = char(item);
    else
        propertynames = properties(item);
        for p = 1:numel(propertynames)
            for o = numel(item):-1:1 % array of objects
                newitem(o).(propertynames{p}) = item(o).(propertynames{p});
            end
        end
    end
catch
    newitem = any2jd(item, opt);
end

%% -------------------------------------------------------------------------
function newitem = any2jd(item, opt)
try
    newitem.(opt.N_DataInfo) = struct('MATLABObjectClass', class(item), 'MATLABObjectSize', size(item));
    newitem.(opt.N_ByteStream) = getByteStreamFromArray(item);  % use undocumented matlab function
    if (opt.base64)
        newitem.(opt.N_ByteStream) = char(base64encode(newitem.(opt.N_ByteStream)));
    end
catch
    error('any2jd: failed to convert object of type %s', class(item));
end
