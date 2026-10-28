function varargout = loadh5(filename, varargin)
%
%    [data, meta] = loadh5(filename)
%    [data, meta] = loadh5(root_id)
%    [data, meta] = loadh5(filename, rootpath)
%    [data, meta] = loadh5(filename, rootpath, options)
%    [data, meta] = loadh5(filename, options)
%    [data, meta] = loadh5(filename, 'Param1',value1, 'Param2',value2,...)
%    [data, meta, storage] = loadh5(...)
%
%    Load data in an HDF5 file to a MATLAB structure.
%
%    author: Qianqian Fang (q.fang <at> neu.edu)
%
%    input
%        filename
%            Name of the file to load data from
%        root_id: an HDF5 handle (of type 'H5ML.id' in MATLAB)
%        rootpath : (optional)
%            Root path to read part of the HDF5 file to load
%        options: (optional) a struct or Param/value pairs for user specified options
%            Order: 'creation' - creation order (default), or 'alphabet' - alphabetic
%            Regroup: [0|1]: if 1, call regrouph5() to combine indexed
%                  groups into a cell array
%            PackHex: [1|0]: convert invalid characters in the group/dataset
%                  names to 0x[hex code] by calling encodevarname.m;
%                  if set to 0, call getvarname
%            ComplexFormat: {'realKey','imagKey'}: use 'realKey' and 'imagKey'
%                  as possible keywords for the real and the imaginary part
%                  of a complex array, respectively (sparse arrays not supported);
%                  a common list of keypairs is used even without this option
%            Transpose: [1|0] - if set to 1 (default), the row-majored HDF5
%                  datasets are transposed (to column-major) so that the
%                  output MATLAB array has the same dimensions as in the
%                  HDF5 dataset header.
%            MaxBytes: [inf|number] - a numeric (integer, floating-point or
%                  complex) dataset larger than this many bytes is not read;
%                  it is returned as a struct header made of the JData keywords
%                  _ArrayType_, _ArraySize_, _ArrayIsComplex_ (complex data
%                  only) and _DataLink_ ('filename:$.path.to.dataset', a
%                  JSONPath into the output of loadh5(filename)), plus
%                  _H5Rank_, the dataset rank in the file (0 for a scalar).
%                  _ArraySize_ is the size the array would have if loaded.
%                  Use 0 to read only the structure, types and dimensions;
%                  strings and other non-numeric datasets are always read.
%
%    output
%        data: a structure (array) or cell (array)
%        meta: optional output to store the attributes stored in the file
%        storage: optional output, a struct array with one element per group
%            or dataset, holding its HDF5 storage without reading any extra
%            data: path (the HDF5 path), isgroup, nlinks (members of a
%            group), class ('float', 'integer', 'string', 'compound' or
%            'other'), bytes (element size), signed, varstring (variable
%            length string; NaN if the HDF5 interface can not tell, as in
%            oct-hdf5), rank (0 for a scalar) and dims (the dataspace size
%            in the order of the HDF5 header)
%
%    example:
%        a={rand(2), struct('va',1,'vb','string'), 1+2i};
%        saveh5(a,'test.h5');
%        a2=loadh5('test.h5')
%        a3=loadh5('test.h5','regroup',1)
%        isequaln(a,a3.a)
%        a4=loadh5('test.h5','/a1')
%        a5=loadh5('test.h5','MaxBytes',0)    % headers only, no data read
%
%    This function was adapted from h5load.m by Pauli Virtanen <pav at iki.fi>
%    This file is part of EasyH5 Toolbox: https://github.com/NeuroJSON/easyh5
%
%    License: GPLv3 or 3-clause BSD license, see https://github.com/NeuroJSON/easyh5 for details
%

path = '';
opt = struct;
if (bitand(length(varargin), 1) == 0)
    opt = varargin2struct(varargin{:});
elseif (length(varargin) >= 3)
    path = varargin{1};
    opt = varargin2struct(varargin{2:end});
elseif (length(varargin) == 1)
    % loadh5(filename, options) with an option struct, or loadh5(filename, rootpath)
    if (isstruct(varargin{1}))
        opt = varargin{1};
    else
        path = varargin{1};
    end
end

opt.dotranspose = jsonopt('Transpose', 1, opt);
opt.stringarray = jsonopt('StringArray', 0, opt);
opt.maxbytes = jsonopt('MaxBytes', inf, opt);
opt.packhex = jsonopt('PackHex', 1, opt);
opt.isoctave = exist('OCTAVE_VERSION', 'builtin') ~= 0;
opt.filename = ''; % for _DataLink_; H5F.get_name is not in every HDF5 interface
if (ischar(filename))
    opt.filename = filename;
end
opt.rootpath = path;

if (exist('OCTAVE_VERSION', 'builtin') ~= 0 && exist('h5info') == 0)
    try
        try
            pkg load oct-hdf5;
        catch
            [varargout{1:nargout}] = load(filename, '-hdf5');
            if (opt.dotranspose)
                varargout{1} = transposemat(varargout{1});
            end
            return
        end
    catch
        error(['To use EasyH5 in Octave, one must install oct-hdf5 first using\n\t' ...
               'pkg install https://github.com/NeuroJSON/oct-hdf5/archive/refs/tags/git20260830.zip\n%s'], '');
    end
end

if (isa(filename, 'H5ML.id'))
    loc = filename;
else
    try
        loc = H5F.open(filename, 'H5F_ACC_RDONLY', 'H5P_DEFAULT');
    catch ME
        error('fail to open file');
    end
end

if (~(isfield(opt, 'complexformat') && iscellstr(opt.complexformat) && numel(opt.complexformat) == 2))
    opt.complexformat = {'Real', 'Imag'};
end

opt.releaseid = 0;
vers = ver('MATLAB');
if (~isempty(vers))
    opt.releaseid = datenum(vers(1).Date);
end

if ((isfield(opt, 'order') && strcmpi(opt.order, 'alphabet'))  || opt.releaseid < datenum('1-Jan-2015'))
    opt.order = 'H5_INDEX_NAME';
else
    opt.order = 'H5_INDEX_CRT_ORDER';
end

% the storage records are returned by load_one and load_member
nout = min(nargout, 2);
opt.storageinfo = (nargout >= 3);
records = {};

try
    if (nargin > 1 && ~isempty(path))
        rootpath = regexprep(['/' path], '/+', '/');
        rootpath = regexprep(rootpath, '/$', '');
        try
            rootgid = H5G.open(loc, path, 0);
            [data, meta, records] = load_one(rootgid, opt, rootpath);
            outputs = {data, meta};
            varargout(1:nout) = outputs(1:nout);
            H5G.close(rootgid);
        catch
            [gname, dname] = fileparts(path);
            rootgid = H5G.open(loc, gname, 0);
            [name, value, attr, records] = load_member(rootgid, dname, opt, regexprep(fileparts(rootpath), '^/$', ''));
            if (nargout > 0)
                varargout{1} = members2struct({name}, {value});
            elseif (nargout > 1)
                varargout{2} = members2struct({name}, {attr});
            end
            H5G.close(rootgid);
        end
    else
        [data, meta, records] = load_one(loc, opt, '');
        outputs = {data, meta};
        varargout(1:nout) = outputs(1:nout);
    end
    H5F.close(loc);
catch ME
    H5F.close(loc);
    rethrow(ME);
end

if (opt.storageinfo)
    varargout{3} = struct('path', {}, 'isgroup', {}, 'nlinks', {}, 'class', {}, 'bytes', {}, ...
                          'signed', {}, 'varstring', {}, 'rank', {}, 'dims', {});
    if (~isempty(records))
        varargout{3} = [records{:}];
    end
end

if (jsonopt('Regroup', 0, opt))
    if (nargout >= 1)
        varargout{1} = regrouph5(varargout{1});
    elseif (nargout >= 2)
        varargout{2} = regrouph5(varargout{2});
    end
end

if (isfield(opt, 'jdata') && opt.jdata && nargout >= 1)
    varargout{1} = jdatadecode(varargout{1}, 'Base64', 0, opt);
end

% --------------------------------------------------------------------------
function [data, meta, records] = load_one(loc, opt, grouppath)
% load the members of a group; H5L.iterate only collects their names, and the
% members are then read in a loop and converted to a struct at once, as
% carrying the loaded data through every callback grows quadratically with
% the number of members

try
    [~, ~, objnames] = H5L.iterate(loc, opt.order, 'H5_ITER_INC', 0, @collect_name, {});
catch ME
    if (strcmp(opt.order, 'H5_INDEX_CRT_ORDER'))
        [~, ~, objnames] = H5L.iterate(loc, 'H5_INDEX_NAME', 'H5_ITER_INC', 0, @collect_name, {});
    else
        rethrow(ME);
    end
end
records = {};
if (opt.storageinfo && ~isempty(grouppath))
    records = {struct('path', grouppath, 'isgroup', true, 'nlinks', length(objnames), ...
                      'class', '', 'bytes', 0, 'signed', true, 'varstring', false, 'rank', 0, 'dims', [])};
end

names = cell(1, length(objnames));
vals = cell(1, length(objnames));
metas = cell(1, length(objnames));
recs = cell(1, length(objnames));
for i = 1:length(objnames)
    [names{i}, vals{i}, metas{i}, recs{i}] = load_member(loc, objnames{i}, opt, grouppath);
end
if (opt.storageinfo)
    records = [records recs{:}];
end
keep = ~cellfun(@isempty, names); % neither a group nor a dataset
data = members2struct(names(keep), vals(keep));
meta = members2struct(names(keep), metas(keep));

% --------------------------------------------------------------------------
function [status, linknames] = collect_name(~, objname, linknames)
status = 0;
linknames{end + 1} = objname;

% --------------------------------------------------------------------------
function s = members2struct(names, values)

if (isempty(names))
    s = struct();
    return
end
try
    s = cell2struct(values(:), names(:), 1);
catch
    s = struct(); % names that map to the same field: the last one is kept
    for i = 1:length(names)
        s.(names{i}) = values{i};
    end
end

% --------------------------------------------------------------------------
function [name, sub_data, attr, records] = load_member(group_id, objname, opt, grouppath)
% load one member of a group; name is empty if it is neither a group nor a
% dataset. records is a cell array of the storage records of the member and,
% for a group, of everything in it
name = '';
sub_data = [];
attr = struct();
records = {};

encodename = opt.packhex;

try

    % objtype index; in MATLAB, H5O.open and H5O.get_info give the type and
    % the number of attributes at once, and the object id serves as the group
    % or dataset id, so datasets without attributes skip H5A.iterate
    if (opt.isoctave)
        info = H5O.get_info_by_name(group_id, objname, 0);
        obj_loc = [];
    else
        obj_loc = H5O.open(group_id, objname, 'H5P_DEFAULT');
        info = H5O.get_info(obj_loc);
    end
    nattrs = 1;
    if (isfield(info, 'num_attrs'))
        nattrs = info.num_attrs;
    end

    objtype = info.type;
    objtype = objtype + 1;

    if objtype == 1
        % Group
        name = regexprep(objname, '.*/', '');

        if (isempty(obj_loc))
            group_loc = H5G.open(group_id, name, 0);
            closeobj = @H5G.close;
        else
            group_loc = obj_loc;
            closeobj = @H5O.close;
        end
        try
            [sub_data, attr, records] = load_one(group_loc, opt, [grouppath '/' name]);
            closeobj(group_loc);
        catch ME
            closeobj(group_loc);
            rethrow(ME);
        end
        if (encodename)
            name = encodevarname(name);
        else
            name = genvarname(name);
        end

    elseif objtype == 2
        % Dataset
        name = regexprep(objname, '.*/', '');

        if (isempty(obj_loc))
            dataset_loc = H5D.open(group_id, name);
            closeobj = @H5D.close;
        else
            dataset_loc = obj_loc;
            closeobj = @H5O.close;
        end
        try
            rec = [];
            if (opt.storageinfo)
                rec = dataset_record(dataset_loc, [grouppath '/' name]);
            end
            isheader = false;
            if (~isinf(opt.maxbytes))
                sub_data = dataset_header(dataset_loc, opt, rec);
                isheader = ~isempty(sub_data);
            end
            if (~isheader)
                sub_data = H5D.read(dataset_loc, ...
                                    'H5ML_DEFAULT', 'H5S_ALL', 'H5S_ALL', 'H5P_DEFAULT');
            end
            if (~isempty(rec))
                records = {record_type(rec, dataset_loc, sub_data)};
            end
            if (nattrs > 0)
                try
                    [status, count, attr] = H5A.iterate(dataset_loc, 'H5_INDEX_NAME', 'H5_ITER_INC', 0, @getattribute, attr);
                catch
                    attr = [];
                end
            end
            closeobj(dataset_loc);
        catch exc
            closeobj(dataset_loc);
            rethrow(exc);
        end
        if (~isheader)
            if (ischar(sub_data) && numel(sub_data) > 1 && sub_data(end) == 0)
                sub_data = sub_data(1:end - 1);
            end

            if ((isnumeric(sub_data) && opt.dotranspose) || (iscell(sub_data) && length(sub_data) > 1))
                sub_data = permute(sub_data, ndims(sub_data):-1:1);
            end
            wascompound = isstruct(sub_data);
            sub_data = fix_data(sub_data, attr, opt);
            if (wascompound && isnumeric(sub_data) && opt.dotranspose)
                % complex and sparse arrays are transposed by saveh5 before their
                % Real/Imag parts and SparseIndex are computed, so they reach this
                % point as a compound type and miss the transpose applied above;
                % undo it now that fix_data has rebuilt the numeric array
                sub_data = permute(sub_data, ndims(sub_data):-1:1);
            end
        end
        if (encodename)
            name = encodevarname(name);
        else
            name = genvarname(name);
        end
    elseif (~isempty(obj_loc))
        H5O.close(obj_loc); % a named datatype or another object type
    end
catch ME
    rethrow(ME);
end

% --------------------------------------------------------------------------
function rec = dataset_record(dset, h5path)
% the storage record of a dataset with its dataspace; record_type fills in the
% type once the dataset is read. [] if the backend lacks these functions

persistent template % copying a struct is faster than building one
if (isempty(template))
    template = struct('path', '', 'isgroup', false, 'nlinks', 0, 'class', 'other', 'bytes', 0, ...
                      'signed', true, 'varstring', false, 'rank', 0, 'dims', []);
end
rec = template;
rec.path = h5path;
try
    sid = H5D.get_space(dset);
    [rec.rank, dims] = H5S.get_simple_extent_dims(sid);
    rec.dims = double(dims(:)');
    H5S.close(sid);
catch
    rec = [];
end

% --------------------------------------------------------------------------
function rec = record_type(rec, dset, raw)
% the type of a storage record, taken from the class H5D.read returned (or
% the header dataset_header made); only strings and compound types query the
% HDF5 type, to tell variable from fixed length strings

persistent consts
if (isempty(consts))
    consts = cellfun(@H5ML.get_constant_value, {'H5T_STRING', 'H5T_COMPOUND'});
end
if (isstruct(raw) && isfield(raw, encodevarname('_ArrayType_')))
    if (isfield(raw, encodevarname('_ArrayIsComplex_')))
        rec.class = 'compound';
        return
    end
    raw = zeros(1, 0, raw.(encodevarname('_ArrayType_')));
end
if (isnumeric(raw))
    if (isfloat(raw))
        rec.class = 'float';
    else
        rec.class = 'integer';
        rec.signed = intmin(class(raw)) < 0;
    end
    rec.bytes = numel(typecast(zeros(1, 1, class(raw)), 'uint8'));
    return
end
try
    tid = H5D.get_type(dset);
catch
    return
end
try
    tclass = H5T.get_class(tid);
    rec.bytes = H5T.get_size(tid);
    if (tclass == consts(1))
        rec.class = 'string';
        try
            rec.varstring = H5T.is_variable_str(tid);
        catch
            rec.varstring = NaN; % not available in oct-hdf5
        end
    elseif (tclass == consts(2))
        rec.class = 'compound';
    end
catch
end
H5T.close(tid);

% --------------------------------------------------------------------------
function hdr = dataset_header(dset, opt, rec)
% Return a JData header for a numeric dataset larger than opt.maxbytes using
% only the dataset metadata, or [] if the dataset should be read instead;
% rec, if given, is the dataset_record of dset, whose dataspace is reused

hdr = [];
try
    if (nargin > 2 && ~isempty(rec))
        rank = rec.rank;
        dims = rec.dims;
    else
        space = H5D.get_space(dset);
        [rank, dims] = H5S.get_simple_extent_dims(space);
        H5S.close(space);
        dims = double(dims(:)');
    end
    % no numeric element exceeds 16 bytes (complex double), so small datasets
    % are sent to H5D.read without querying their type
    if (prod(dims) * 16 <= opt.maxbytes)
        return
    end
    dtype = H5D.get_type(dset);
catch
    % fall back to reading the dataset if the backend lacks these functions
    return
end
try
    tclass = H5T.get_class(dtype);
    iscomplex = false;
    if (tclass == H5ML.get_constant_value('H5T_COMPOUND'))
        % complex arrays are stored as a compound of two floating-point members
        if (H5T.get_nmembers(dtype) ~= 2 || ...
            ~iscomplexpair({H5T.get_member_name(dtype, 0), H5T.get_member_name(dtype, 1)}, opt))
            H5T.close(dtype);
            return
        end
        elemtype = H5T.get_member_type(dtype, 0);
        tclass = H5T.get_class(elemtype);
        iscomplex = true;
    else
        elemtype = H5T.copy(dtype);
    end
    elemsize = H5T.get_size(elemtype);
    if (tclass == H5ML.get_constant_value('H5T_FLOAT'))
        if (elemsize == 4)
            arraytype = 'single';
        else
            arraytype = 'double';
        end
    elseif (tclass == H5ML.get_constant_value('H5T_INTEGER') && ~iscomplex)
        arraytype = sprintf('int%d', 8 * elemsize);
        if (H5T.get_sign(elemtype) == H5ML.get_constant_value('H5T_SGN_NONE'))
            arraytype = ['u' arraytype];
        end
    else
        arraytype = '';
    end
    H5T.close(elemtype);
    datasize = H5T.get_size(dtype);
    H5T.close(dtype);
catch
    return
end
if (isempty(arraytype))
    return
end
if (prod(dims) * datasize <= opt.maxbytes)
    return
end

% the size the array has when loaded: scalars and 1-D datasets are row vectors
% and the transpose option decides the order of the remaining dimensions
if (rank <= 1)
    arraysize = [1 prod(dims)];
    if (~opt.dotranspose)
        arraysize = fliplr(arraysize);
    end
elseif (opt.dotranspose)
    arraysize = dims;
else
    arraysize = fliplr(dims);
end

% field names follow encodevarname, as for a dataset named _ArrayType_ etc.,
% so that jdatadecode and jsonschema recognize the header
hdr = struct(encodevarname('_ArrayType_'), arraytype, encodevarname('_ArraySize_'), arraysize);
if (iscomplex)
    hdr.(encodevarname('_ArrayIsComplex_')) = true;
end
hdr.(encodevarname('_H5Rank_')) = double(rank);
fname = opt.filename;
if (isempty(fname))
    try
        fname = H5F.get_name(dset);
    catch
    end
end
hdr.(encodevarname('_DataLink_')) = [fname ':' h5path2jsonpath(H5I.get_name(dset))];

% --------------------------------------------------------------------------
function jpath = h5path2jsonpath(h5path)
% convert an HDF5 object path to the JSONPath of the same object in the
% loaded data; names that are not plain identifiers use the bracket notation

names = regexp(h5path, '[^/]+', 'match');
jpath = '$';
for i = 1:length(names)
    if (isempty(regexp(names{i}, '^[A-Za-z][A-Za-z0-9_]*$', 'once')))
        jpath = [jpath '[''' names{i} ''']'];
    else
        jpath = [jpath '.' names{i}];
    end
end

% --------------------------------------------------------------------------
function tf = iscomplexpair(names, opt)
% test whether two compound member names hold the real and imaginary parts

pairs = {opt.complexformat, {'Real', 'Imag'}, {'real', 'imag'}, {'Re', 'Im'}, {'re', 'im'}, {'r', 'i'}};
tf = false;
for i = 1:length(pairs)
    if (isempty(setxor(names, pairs{i})))
        tf = true;
        return
    end
end

% --------------------------------------------------------------------------
function data = fix_data(data, attr, opt)
% Fix some common types of data to more friendly form.

persistent hasstring % exist() is slow, and fix_data runs for every dataset

if isstruct(data)
    fields = fieldnames(data);

    if (length(intersect(fields, {'SparseIndex', opt.complexformat{1}})) == 2)
        if isnumeric(data.SparseIndex) && isnumeric(data.(opt.complexformat{1}))
            if (nargin > 1 && isstruct(attr))
                if (isfield(attr, 'SparseArraySize'))
                    spd = sparse(1, prod(attr.SparseArraySize));
                    if (isfield(data, opt.complexformat{2}))
                        spd(data.SparseIndex) = complex(data.(opt.complexformat{1}), data.(opt.complexformat{2}));
                    else
                        spd(data.SparseIndex) = data.(opt.complexformat{1});
                    end
                    data = reshape(spd, attr.SparseArraySize(:)');
                    return
                end
            end
        end
    else
        if (numel(opt.complexformat) == 2 && length(intersect(fields, opt.complexformat)) == 2)
            if isnumeric(data.(opt.complexformat{1})) && isnumeric(data.(opt.complexformat{2}))
                data = data.(opt.complexformat{1}) + 1j * data.(opt.complexformat{2});
            end
        else
            % if complexformat is not specified or not found, try some common complex number storage formats
            if (length(intersect(fields, {'Real', 'Imag'})) == 2)
                if isnumeric(data.Real) && isnumeric(data.Imag)
                    data = data.Real + 1j * data.Imag;
                end
            elseif (length(intersect(fields, {'real', 'imag'})) == 2)
                if isnumeric(data.real) && isnumeric(data.imag)
                    data = data.real + 1j * data.imag;
                end
            elseif (length(intersect(fields, {'Re', 'Im'})) == 2)
                if isnumeric(data.Re) && isnumeric(data.Im)
                    data = data.Re + 1j * data.Im;
                end
            elseif (length(intersect(fields, {'re', 'im'})) == 2)
                if isnumeric(data.re) && isnumeric(data.im)
                    data = data.re + 1j * data.im;
                end
            elseif (length(intersect(fields, {'r', 'i'})) == 2)
                if isnumeric(data.r) && isnumeric(data.i)
                    data = data.r + 1j * data.i;
                end
            end
        end
    end
end

if (isa(data, 'uint8') || isa(data, 'int8'))
    if (nargin > 1 && isstruct(attr))
        if (isfield(attr, 'MATLABObjectClass'))
            data = getArrayFromByteStream(data); % use undocumented function
        end
    end
end

% handeling string arrays (or cell of char strings)
if (iscell(data) && opt.stringarray && all(cellfun(@ischar, data)))
    if (isempty(hasstring))
        hasstring = exist('string') > 0;
    end
    if (hasstring)
        data = string(data);
    end
end

% --------------------------------------------------------------------------
function [status, dataout] = getattribute(loc_id, attr_name, info, datain)
status = 0;
attr_id = H5A.open(loc_id, attr_name, 'H5P_DEFAULT');
datain.(attr_name) = H5A.read(attr_id, 'H5ML_DEFAULT');
H5A.close(attr_id);
dataout = datain;
