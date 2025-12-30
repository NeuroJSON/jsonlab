function newdata = jdatadecode(data, varargin)
%
% newdata=jdatadecode(data,opt,...)
%
% Convert all JData object (in the form of a struct array) into an array
% (accepts JData objects loaded from either loadjson/loadubjson or
% jsondecode for MATLAB R2016b or later)
%
% This function implements the JData Specification Draft 3 (Jun. 2020)
% see http://github.com/NeuroJSON/jdata for details
%
% authors:Qianqian Fang (q.fang <at> neu.edu)
%
% input:
%      data: a struct array. If data contains JData keywords in the first
%            level children, these fields are parsed and regrouped into a
%            data object (arrays, trees, graphs etc) based on JData
%            specification. The JData keywords are
%               "_ArrayType_", "_ArraySize_", "_ArrayData_"
%               "_ArrayIsSparse_", "_ArrayIsComplex_",
%               "_ArrayZipType_", "_ArrayZipSize", "_ArrayZipData_"
%      opt: (optional) a list of 'Param',value pairs for additional options
%           The supported options include
%               Recursive: [1|0] if set to 1, will apply the conversion to
%                            every child; 0 to disable
%               Base64: [0|1] if set to 1, _ArrayZipData_ is assumed to
%                         be encoded with base64 format and need to be
%                         decoded first. This is needed for JSON but not
%                         UBJSON data
%               Prefix: ['x0x5F'|'x'] for JData files loaded via loadjson/loadubjson, the
%                         default JData keyword prefix is 'x0x5F'; if the
%                         json file is loaded using matlab2018's
%                         jsondecode(), the prefix is 'x'; this function
%                         attempts to automatically determine the prefix;
%                         for octave, the default value is an empty string ''.
%               FullArrayShape: [0|1] if set to 1, converting _ArrayShape_
%                         objects to full matrices, otherwise, stay sparse
%               MaxLinkLevel: [0|int] When expanding _DataLink_ pointers,
%                         this sets the maximum level of recursion
%               FormatVersion: [2|float]: set the JSONLab output version;
%                         since v2.0, JSONLab uses JData specification Draft 1
%                         for output format, it is incompatible with all
%                         previous releases; if old output is desired,
%                         please set FormatVersion to 1
%
% output:
%      newdata: the converted data if the input data does contain a JData
%               structure; otherwise, the same as the input.
%
% examples:
%      obj={[],{'test'},true,struct('sparse',sparse(2,3),'magic',uint8(magic(5)))}
%      jdata=jdatadecode(jdataencode(obj))
%      isequaln(obj,jdata)
%
% license:
%     BSD or GPL version 3, see LICENSE_{BSD,GPLv3}.txt files for details
%
% -- this function is part of JSONLab toolbox (http://neurojson.org/jsonlab)
%

newdata = data;
if (nargin == 2 && isstruct(varargin{1}))
    opt = varargin{1};
elseif (nargin > 2)
    opt = varargin2struct(varargin{:});
else
    opt = struct;
end

% Cache options to avoid repeated jsonopt calls
if ~isfield(opt, 'fullarrayshape_')
    opt.fullarrayshape_ = jsonopt('FullArrayShape', 0, opt);
    opt.maxlinklevel_ = jsonopt('MaxLinkLevel', 0, opt);
    opt.needbase64_ = jsonopt('Base64', 0, opt);
    opt.format_ = jsonopt('FormatVersion', 2, opt);
    opt.recursive_ = jsonopt('Recursive', 1, opt);

    % Determine prefix once and cache prefixed field names
    persistent isaliasaliased
    if isempty(isaliasaliased)
        isaliasaliased = isoctavemesh;
    end
    if isaliasaliased
        prefix = jsonopt('Prefix', '', opt);
    else
        prefix = jsonopt('Prefix', 'x0x5F', opt);
    end
    opt.prefix_ = prefix;

    % Pre-compute all prefixed field names
    opt.N_ArrayType_ = [prefix '_ArrayType_'];
    opt.N_ArraySize_ = [prefix '_ArraySize_'];
    opt.N_ArrayData_ = [prefix '_ArrayData_'];
    opt.N_ArrayZipSize_ = [prefix '_ArrayZipSize_'];
    opt.N_ArrayZipData_ = [prefix '_ArrayZipData_'];
    opt.N_ArrayZipType_ = [prefix '_ArrayZipType_'];
    opt.N_ArrayIsComplex_ = [prefix '_ArrayIsComplex_'];
    opt.N_ArrayIsSparse_ = [prefix '_ArrayIsSparse_'];
    opt.N_ArrayShape_ = [prefix '_ArrayShape_'];
    opt.N_ArrayOrder_ = [prefix '_ArrayOrder_'];
    opt.N_ArrayLabel_ = [prefix '_ArrayLabel_'];
    opt.N_TableRecords_ = [prefix '_TableRecords_'];
    opt.N_TableRows_ = [prefix '_TableRows_'];
    opt.N_TableCols_ = [prefix '_TableCols_'];
    opt.N_MapData_ = [prefix '_MapData_'];
    opt.N_GraphNodes_ = [prefix '_GraphNodes_'];
    opt.N_GraphEdges_ = [prefix '_GraphEdges_'];
    opt.N_GraphEdges0_ = [prefix '_GraphEdges0_'];
    opt.N_GraphMatrix_ = [prefix '_GraphMatrix_'];
    opt.N_ByteStream_ = [prefix '_ByteStream_'];
    opt.N_DataInfo_ = [prefix '_DataInfo_'];
    opt.N_DataLink_ = [prefix '_DataLink_'];
end

%% process non-structure inputs
if (~isstruct(data))
    if (iscell(data))
        newdata = cellfun(@(x) jdatadecode(x, opt), data, 'UniformOutput', false);
    elseif (isa(data, 'containers.Map'))
        newdata = containers.Map('KeyType', data.KeyType, 'ValueType', 'any');
        names = data.keys;
        for i = 1:length(names)
            newdata(names{i}) = jdatadecode(data(names{i}), opt);
        end
    end
    return
end

%% assume the input is a struct below
fn = fieldnames(data);
len = length(data);
prefix = opt.prefix_;
needbase64 = opt.needbase64_;
format = opt.format_;

% Check for alternate prefix
if (~isfield(data, opt.N_ArrayType_) && isfield(data, 'x_ArrayType_'))
    prefix = 'x';
    opt.prefix_ = 'x';
    % Update cached field names
    opt.N_ArrayType_ = 'x_ArrayType_';
    opt.N_ArraySize_ = 'x_ArraySize_';
    opt.N_ArrayData_ = 'x_ArrayData_';
    opt.N_ArrayZipSize_ = 'x_ArrayZipSize_';
    opt.N_ArrayZipData_ = 'x_ArrayZipData_';
    opt.N_ArrayZipType_ = 'x_ArrayZipType_';
    opt.N_ArrayIsComplex_ = 'x_ArrayIsComplex_';
    opt.N_ArrayIsSparse_ = 'x_ArrayIsSparse_';
    opt.N_ArrayShape_ = 'x_ArrayShape_';
    opt.N_ArrayOrder_ = 'x_ArrayOrder_';
    opt.N_ArrayLabel_ = 'x_ArrayLabel_';
end

%% recursively process subfields
if (opt.recursive_ == 1)
    for i = 1:length(fn) % depth-first
        for j = 1:len
            if (isstruct(data(j).(fn{i})) || isa(data(j).(fn{i}), 'containers.Map'))
                newdata(j).(fn{i}) = jdatadecode(data(j).(fn{i}), opt);
            elseif (iscell(data(j).(fn{i})))
                newdata(j).(fn{i}) = cellfun(@(x) jdatadecode(x, opt), newdata(j).(fn{i}), 'UniformOutput', false);
            end
        end
    end
end

% Use cached field names
N_ArrayType = opt.N_ArrayType_;
N_ArrayData = opt.N_ArrayData_;
N_ArrayZipData = opt.N_ArrayZipData_;
N_ArrayZipSize = opt.N_ArrayZipSize_;
N_ArrayZipType = opt.N_ArrayZipType_;
N_ArraySize = opt.N_ArraySize_;
N_ArrayIsComplex = opt.N_ArrayIsComplex_;
N_ArrayIsSparse = opt.N_ArrayIsSparse_;
N_ArrayShape = opt.N_ArrayShape_;
N_ArrayOrder = opt.N_ArrayOrder_;
N_ArrayLabel = opt.N_ArrayLabel_;

%% handle array data
if (isfield(data, N_ArrayType) && (isfield(data, N_ArrayData) || (isfield(data, N_ArrayZipData) && ~isstruct(data.(N_ArrayZipData)))))
    newdata = cell(len, 1);
    for j = 1:len
        if (isfield(data, N_ArrayZipSize) && isfield(data, N_ArrayZipData))
            zipmethod = 'zip';
            if (isstruct(data(j).(N_ArrayZipSize)))
                data(j).(N_ArrayZipSize) = jdatadecode(data(j).(N_ArrayZipSize), opt);
            end
            dims = data(j).(N_ArrayZipSize)(:)';
            if (length(dims) == 1)
                dims = [1 dims];
            end
            if (isfield(data, N_ArrayZipType))
                zipmethod = data(j).(N_ArrayZipType);
            end
            if (ismember(zipmethod, {'zlib', 'gzip', 'lzma', 'lzip', 'lz4', 'lz4hc', 'base64'}) || ~isempty(regexp(zipmethod, '^blosc2', 'once')))
                decodeparam = {};
                if (~isempty(regexp(zipmethod, '^blosc2', 'once')))
                    decompfun = @blosc2decode;
                    decodeparam = {zipmethod};
                else
                    decompfun = str2func([zipmethod 'decode']);
                end
                arraytype = data(j).(N_ArrayType);
                chartype = 0;
                if (strcmp(arraytype, 'char') || strcmp(arraytype, 'logical'))
                    chartype = 1;
                    arraytype = 'uint8';
                end
                if (needbase64 && strcmp(zipmethod, 'base64') == 0)
                    ndata = reshape(typecast(decompfun(base64decode(data(j).(N_ArrayZipData)), decodeparam{:}), arraytype), dims);
                else
                    ndata = reshape(typecast(decompfun(data(j).(N_ArrayZipData), decodeparam{:}), arraytype), dims);
                end
                if (chartype)
                    ndata = char(ndata);
                end
            else
                error('compression method is not supported');
            end
        else
            if (isstruct(data(j).(N_ArrayData)))
                data(j).(N_ArrayData) = jdatadecode(data(j).(N_ArrayData), opt);
            end
            if (isstruct(data(j).(N_ArrayData)) && isfield(data(j).(N_ArrayData), N_ArrayType))
                data(j).(N_ArrayData) = jdatadecode(data(j).(N_ArrayData), varargin{:});
            end
            if (iscell(data(j).(N_ArrayData)))
                data(j).(N_ArrayData) = cell2mat(cellfun(@(x) double(x(:)), data(j).(N_ArrayData), 'uniformoutput', 0)).';
            end
            ndata = cast(data(j).(N_ArrayData), char(data(j).(N_ArrayType)));
        end
        if (isfield(data, N_ArrayZipSize))
            if (isstruct(data(j).(N_ArrayZipSize)))
                data(j).(N_ArrayZipSize) = jdatadecode(data(j).(N_ArrayZipSize), opt);
            end
            dims = data(j).(N_ArrayZipSize)(:)';
            if (iscell(dims))
                dims = cell2mat(dims);
            end
            if (length(dims) == 1)
                dims = [1 dims];
            end
            ndata = reshape(ndata(:), fliplr(dims));
            ndata = permute(ndata, ndims(ndata):-1:1);
        end
        iscpx = 0;
        if (isfield(data, N_ArrayIsComplex) && isstruct(data(j).(N_ArrayIsComplex)))
            data(j).(N_ArrayIsComplex) = jdatadecode(data(j).(N_ArrayIsComplex), opt);
        end
        if (isfield(data, N_ArrayIsComplex) && data(j).(N_ArrayIsComplex))
            iscpx = 1;
        end
        iscol = 0;
        if (isfield(data, N_ArrayOrder))
            arrayorder = data(j).(N_ArrayOrder);
            if (~isempty(arrayorder) && (arrayorder(1) == 'c' || arrayorder(1) == 'C'))
                iscol = 1;
            end
        end
        if (isfield(data, N_ArrayIsSparse) && isstruct(data(j).(N_ArrayIsSparse)))
            data(j).(N_ArrayIsSparse) = jdatadecode(data(j).(N_ArrayIsSparse), opt);
        end
        if (isfield(data, N_ArrayIsSparse) && data(j).(N_ArrayIsSparse))
            if (isfield(data, N_ArraySize))
                if (isstruct(data(j).(N_ArraySize)))
                    data(j).(N_ArraySize) = jdatadecode(data(j).(N_ArraySize), opt);
                end
                dim = data(j).(N_ArraySize)(:)';
                if (iscell(dim))
                    dim = cell2mat(dim);
                end
                dim = double(dim);
                if (length(dim) == 1)
                    dim = [1 dim];
                end
                if (iscpx)
                    ndata(end - 1, :) = complex(ndata(end - 1, :), ndata(end, :));
                end
                if isempty(ndata)
                    % All-zeros sparse
                    ndata = sparse(dim(1), prod(dim(2:end)));
                elseif dim(1) == 1
                    % Sparse row vector
                    ndata = sparse(1, ndata(1, :), ndata(2, :), dim(1), prod(dim(2:end)));
                elseif dim(2) == 1
                    % Sparse column vector
                    ndata = sparse(ndata(1, :), 1, ndata(2, :), dim(1), prod(dim(2:end)));
                else
                    % Generic sparse array.
                    ndata = sparse(ndata(1, :), ndata(2, :), ndata(3, :), dim(1), prod(dim(2:end)));
                end
            else
                if (iscpx && size(ndata, 2) == 4)
                    ndata(3, :) = complex(ndata(3, :), ndata(4, :));
                end
                ndata = sparse(ndata(1, :), ndata(2, :), ndata(3, :));
            end
        elseif (isfield(data, N_ArrayShape))
            if (isstruct(data(j).(N_ArrayShape)))
                data(j).(N_ArrayShape) = jdatadecode(data(j).(N_ArrayShape), opt);
            end
            if (iscpx)
                if (size(ndata, 1) == 2)
                    dim = size(ndata);
                    dim(end + 1) = 1;
                    arraydata = reshape(complex(ndata(1, :), ndata(2, :)), dim(2:end));
                else
                    error('The first dimension must be 2 for complex-valued arrays');
                end
            else
                arraydata = data.(N_ArrayData);
            end
            shapeid = data.(N_ArrayShape);
            if (isfield(data, N_ArrayZipSize))
                datasize = data.(N_ArrayZipSize);
                if (iscell(datasize))
                    datasize = cell2mat(datasize);
                end
                datasize = double(datasize);
                if (iscpx)
                    datasize = datasize(2:end);
                end
            else
                datasize = size(arraydata);
            end
            if (isstruct(data(j).(N_ArraySize)))
                data(j).(N_ArraySize) = jdatadecode(data(j).(N_ArraySize), opt);
            end
            arraysize = data.(N_ArraySize);

            if (iscell(arraysize))
                arraysize = cell2mat(arraysize);
            end
            arraysize = double(arraysize);
            if (ischar(shapeid))
                shapeid = {shapeid};
            end
            arraydata = double(arraydata).';
            if (strcmpi(shapeid{1}, 'diag'))
                ndata = spdiags(arraydata(:), 0, arraysize(1), arraysize(2));
            elseif (strcmpi(shapeid{1}, 'upper') || strcmpi(shapeid{1}, 'uppersymm'))
                ndata = zeros(arraysize);
                ndata(triu(true(size(ndata)))') = arraydata(:);
                if (strcmpi(shapeid{1}, 'uppersymm'))
                    ndata(triu(true(size(ndata)))) = arraydata(:);
                end
                ndata = ndata.';
            elseif (strcmpi(shapeid{1}, 'lower') || strcmpi(shapeid{1}, 'lowersymm'))
                ndata = zeros(arraysize);
                ndata(tril(true(size(ndata)))') = arraydata(:);
                if (strcmpi(shapeid{1}, 'lowersymm'))
                    ndata(tril(true(size(ndata)))) = arraydata(:);
                end
                ndata = ndata.';
            elseif (strcmpi(shapeid{1}, 'upperband') || strcmpi(shapeid{1}, 'uppersymmband'))
                if (length(shapeid) > 1 && isvector(arraydata))
                    datasize = double([shapeid{2} + 1, prod(datasize) / (shapeid{2} + 1)]);
                end
                ndata = spdiags(reshape(arraydata, min(arraysize), datasize(1)), -datasize(1) + 1:0, arraysize(2), arraysize(1)).';
                if (strcmpi(shapeid{1}, 'uppersymmband'))
                    diagonal = diag(ndata);
                    ndata = ndata + ndata.';
                    ndata(1:arraysize(1) + 1:end) = diagonal;
                end
            elseif (strcmpi(shapeid{1}, 'lowerband') || strcmpi(shapeid{1}, 'lowersymmband'))
                if (length(shapeid) > 1 && isvector(arraydata))
                    datasize = double([shapeid{2} + 1, prod(datasize) / (shapeid{2} + 1)]);
                end
                ndata = spdiags(reshape(arraydata, min(arraysize), datasize(1)), 0:datasize(1) - 1, arraysize(2), arraysize(1)).';
                if (strcmpi(shapeid{1}, 'lowersymmband'))
                    diagonal = diag(ndata);
                    ndata = ndata + ndata.';
                    ndata(1:arraysize(1) + 1:end) = diagonal;
                end
            elseif (strcmpi(shapeid{1}, 'band'))
                if (length(shapeid) > 1 && isvector(arraydata))
                    datasize = double([shapeid{2} + shapeid{3} + 1, prod(datasize) / (shapeid{2} + shapeid{3} + 1)]);
                end
                ndata = spdiags(reshape(arraydata, min(arraysize), datasize(1)), double(shapeid{2}):-1:-double(shapeid{3}), arraysize(1), arraysize(2));
            elseif (strcmpi(shapeid{1}, 'toeplitz'))
                arraydata = reshape(arraydata, flipud(datasize(:))');
                ndata = toeplitz(arraydata(1:arraysize(1), 2), arraydata(1:arraysize(2), 1));
            end
            if (opt.fullarrayshape_ && issparse(ndata))
                ndata = cast(full(ndata), data(j).(N_ArrayType));
            end
        elseif (isfield(data, N_ArraySize))
            if (isstruct(data(j).(N_ArraySize)))
                data(j).(N_ArraySize) = jdatadecode(data(j).(N_ArraySize), opt);
            end
            if (iscpx)
                ndata = complex(ndata(1, :), ndata(2, :));
            end
            if (format > 1.9 && iscol == 0)
                data(j).(N_ArraySize) = data(j).(N_ArraySize)(end:-1:1);
            end
            dims = data(j).(N_ArraySize)(:)';
            if (iscell(dims))
                dims = cell2mat(dims);
            end
            if (length(dims) == 1)
                dims = [1 dims];
            end
            ndata = reshape(ndata(:), dims(:)');
            if (format > 1.9 && iscol == 0)
                ndata = permute(ndata, ndims(ndata):-1:1);
            end
        end
        newdata{j} = ndata;
    end
    if (len == 1)
        newdata = newdata{1};
    end
    if (isfield(data, N_ArrayLabel))
        newdata = jdict(newdata);
        newdata.setattr('dims', data(j).(N_ArrayLabel));
    end
end

%% handle table data
N_TableRecords = opt.N_TableRecords_;
if (isfield(data, N_TableRecords))
    newdata = cell(len, 1);
    N_TableRows = opt.N_TableRows_;
    N_TableCols = opt.N_TableCols_;
    for j = 1:len
        ndata = data(j).(N_TableRecords);
        if (iscell(ndata))
            if (iscell(ndata{1}))
                rownum = length(ndata);
                colnum = length(ndata{1});
                nd = cell(rownum, colnum);
                for i1 = 1:rownum
                    for i2 = 1:colnum
                        nd{i1, i2} = ndata{i1}{i2};
                    end
                end
                newdata{j} = cell2table(nd);
            else
                newdata{j} = cell2table(ndata);
            end
        else
            newdata{j} = array2table(ndata);
        end
        if (isfield(data(j), N_TableRows) && ~isempty(data(j).(N_TableRows)))
            newdata{j}.Properties.RowNames = data(j).(N_TableRows)(:);
        end
        if (isfield(data(j), N_TableCols) && ~isempty(data(j).(N_TableCols)))
            newdata{j}.Properties.VariableNames = data(j).(N_TableCols);
        end
    end
    if (len == 1)
        newdata = newdata{1};
    end
end

%% handle map data
N_MapData = opt.N_MapData_;
if (isfield(data, N_MapData))
    newdata = cell(len, 1);
    for j = 1:len
        key = cell(1, length(data(j).(N_MapData)));
        val = cell(size(key));
        for k = 1:length(data(j).(N_MapData))
            key{k} = data(j).(N_MapData){k}{1};
            val{k} = jdatadecode(data(j).(N_MapData){k}{2}, opt);
        end
        ndata = containers.Map(key, val);
        newdata{j} = ndata;
    end
    if (len == 1)
        newdata = newdata{1};
    end
end

%% handle graph data
N_GraphNodes = opt.N_GraphNodes_;
if (isfield(data, N_GraphNodes) && exist('graph', 'file') && exist('digraph', 'file'))
    newdata = cell(len, 1);
    isdirected = 1;
    N_GraphEdges = opt.N_GraphEdges_;
    N_GraphEdges0 = opt.N_GraphEdges0_;
    N_GraphMatrix = opt.N_GraphMatrix_;
    for j = 1:len
        nodedata = data(j).(N_GraphNodes);
        if (isstruct(nodedata))
            nodetable = struct2table(nodedata);
        elseif (isa(nodedata, 'containers.Map'))
            nodetable = [keys(nodedata); values(nodedata)];
            if (strcmp(nodedata.KeyType, 'char'))
                nodetable = table(nodetable(1, :)', nodetable(2, :)', 'VariableNames', {'Name', 'Data'});
            else
                nodetable = table(nodetable(2, :)', 'VariableNames', {'Data'});
            end
        else
            nodetable = table;
        end

        if (isfield(data, N_GraphEdges))
            edgedata = data(j).(N_GraphEdges);
        elseif (isfield(data, N_GraphEdges0))
            edgedata = data(j).(N_GraphEdges0);
            isdirected = 0;
        elseif (isfield(data, N_GraphMatrix))
            edgedata = jdatadecode(data(j).(N_GraphMatrix), varargin{:});
        end

        if (exist('edgedata', 'var'))
            if (iscell(edgedata))
                endnodes = edgedata(:, 1:2);
                endnodes = reshape([endnodes{:}], size(edgedata, 1), 2);
                weight = cell2mat(edgedata(:, 3:end));
                edgetable = table(endnodes, [weight.Weight]', 'VariableNames', {'EndNodes', 'Weight'});

                if (isdirected)
                    newdata{j} = digraph(edgetable, nodetable);
                else
                    newdata{j} = graph(edgetable, nodetable);
                end
            elseif (ndims(edgedata) == 2 && isstruct(nodetable))
                newdata{j} = digraph(edgedata, fieldnames(nodetable));
            end
        end
    end
    if (len == 1)
        newdata = newdata{1};
    end
end

%% handle bytestream and arbitrary matlab objects
N_ByteStream = opt.N_ByteStream_;
N_DataInfo = opt.N_DataInfo_;
if (isfield(data, N_ByteStream) && isfield(data, N_DataInfo))
    newdata = cell(len, 1);
    for j = 1:len
        if (isfield(data(j).(N_DataInfo), 'MATLABObjectClass'))
            if (needbase64)
                newdata{j} = getArrayFromByteStream(base64decode(data(j).(N_ByteStream)));
            else
                newdata{j} = getArrayFromByteStream(data(j).(N_ByteStream));
            end
        end
    end
    if (len == 1)
        newdata = newdata{1};
    end
end

%% handle data link
N_DataLink = opt.N_DataLink_;
if (opt.maxlinklevel_ > 0 && isfield(data, N_DataLink))
    if (ischar(data.(N_DataLink)))
        datalink = data.(N_DataLink);
        if (regexp(datalink, '\:\$'))
            ref = regexp(datalink, '^(?<proto>[a-zA-Z]+://)*(?<path>.+)(?<delim>\:)()*(?<jsonpath>(?<=:)\$\d*\.*.*)*', 'names');
        else
            ref = regexp(datalink, '^(?<proto>[a-zA-Z]+://)*(?<path>.+)(?<delim>\:)*(?<jsonpath>(?<=:)\$\d*\..*)*', 'names');
        end
        if (~isempty(ref.path))
            uripath = [ref.proto ref.path];
            [newdata, fname] = jdlink(uripath);
            if (exist(fname, 'file'))
                opt.maxlinklevel_ = opt.maxlinklevel_ - 1;
                if (~isempty(ref.jsonpath))
                    newdata = jsonpath(newdata, ref.jsonpath);
                end
            end
        end
    end
end

end
