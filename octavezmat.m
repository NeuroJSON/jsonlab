function varargout = octavezmat(varargin)
%
% output = octavezmat(input, iscompress, zipmethod)
%    or
% [output, info] = octavezmat(input, iscompress, zipmethod)
% unzipdata = octavezmat(zipdata, info)
%
% File-based zlib/gzip compression for Octave when Java is not available
%
% Author: Qianqian Fang (q.fang <at> neu.edu)
%
% input:
%      input: the input data, can be a string, a numerical vector or array
%      iscompress: (optional) if iscompress is 1, compress the input,
%             if 0, decompress the input. Default value is 1.
%             if one defines iscompress as the info struct (2nd output),
%             it will perform decompression and recover the original input.
%      method: (optional) compression method:
%             'zlib': zlib compression (default)
%             'gzip': gzip compression
%
% output:
%      output: the compressed/decompressed byte stream as uint8 vector
%      info: (optional) a struct with 'type', 'size', 'method', 'status'
%
% examples:
%      [bytes, info] = octavezmat(eye(10), 1, 'zlib');
%      orig = octavezmat(bytes, info);
%
% license:
%     BSD or GPL version 3, see LICENSE_{BSD,GPLv3}.txt files for details
%
% -- this function is part of JSONLab toolbox (http://neurojson.org/jsonlab)
%

if (nargin < 1)
    fprintf(1, 'Format: output = octavezmat(data, iscompress, zipmethod)\n');
    return
end

iscompress = 1;
zipmethod = 'zlib';

data = varargin{1};

% Handle info struct input for decompression
inputinfo = [];
if (nargin >= 2)
    if (isstruct(varargin{2}))
        inputinfo = varargin{2};
        iscompress = 0;
        if (isfield(inputinfo, 'method'))
            zipmethod = inputinfo.method;
        end
    else
        iscompress = varargin{2};
    end
end

if (nargin >= 3)
    zipmethod = varargin{3};
end

% Store original info
origtype = class(data);
origsize = size(data);

% Convert to uint8
if (ischar(data))
    data = uint8(data);
elseif (islogical(data))
    data = uint8(data);
elseif (isa(data, 'string'))
    data = uint8(char(data));
else
    data = typecast(data(:), 'uint8');
end
data = data(:)';

% Normalize method name
if (strcmp(zipmethod, 'deflate'))
    zipmethod = 'zlib';
end

% Dispatch to appropriate file-based function
if (iscompress)
    if (strcmp(zipmethod, 'zlib'))
        varargout{1} = file_zlib_encode(data);
    elseif (strcmp(zipmethod, 'gzip'))
        varargout{1} = file_gzip_encode(data);
    else
        error('Unsupported method: %s', zipmethod);
    end
else
    if (strcmp(zipmethod, 'zlib'))
        varargout{1} = file_zlib_decode(data);
    elseif (strcmp(zipmethod, 'gzip'))
        varargout{1} = file_gzip_decode(data);
    else
        error('Unsupported method: %s', zipmethod);
    end
end

% Build info struct
if (nargout > 1)
    varargout{2} = struct('type', origtype, 'size', origsize, ...
                          'method', zipmethod, 'status', 0);
end

% Restore original type and shape if decompressing with info
if (~isempty(inputinfo) && isfield(inputinfo, 'type'))
    if (strcmp(inputinfo.type, 'logical'))
        varargout{1} = logical(varargout{1});
    elseif (strcmp(inputinfo.type, 'char'))
        varargout{1} = char(varargout{1});
    else
        varargout{1} = typecast(varargout{1}, inputinfo.type);
    end
    varargout{1} = reshape(varargout{1}, inputinfo.size);
end

% ==========================================================================
% File-based ZLIB compression/decompression
% ==========================================================================

function compressed = file_zlib_encode(data)
% ZLIB compression using file-based zip

data = uint8(data(:))';
fname = tempname;
tmpfile = fname;
zipfile = [fname '.zip'];

fd = fopen(tmpfile, 'wb');
fwrite(fd, data, 'uint8');
fclose(fd);

zip(zipfile, tmpfile);
delete(tmpfile);

fd = fopen(zipfile, 'rb');
zipdata = fread(fd, [1 inf], 'uint8=>uint8');
fclose(fd);
delete(zipfile);

% Extract raw DEFLATE from ZIP and wrap in ZLIB format
deflate_data = extract_deflate_from_zip(zipdata);
compressed = wrap_zlib(deflate_data, data);

% --------------------------------------------------------------------------
function data = file_zlib_decode(compressed)
% ZLIB decompression using file-based unzip

compressed = uint8(compressed(:))';

% Strip ZLIB header (2 bytes) and Adler-32 trailer (4 bytes) to get raw DEFLATE
if (length(compressed) > 6)
    deflate_data = compressed(3:end - 4);
else
    deflate_data = compressed;
end

fname = tempname;
zipfile = [fname '.zip'];

% Use unique output directory to avoid file conflicts
outdir = tempname;
mkdir(outdir);

% Create ZIP with CRC=0 (unzip will warn but still extract)
zipdata = wrap_deflate_in_zip(deflate_data, [], uint32(0));

fd = fopen(zipfile, 'wb');
fwrite(fd, zipdata, 'uint8');
fclose(fd);

% Try to unzip - may produce CRC warning but should still extract
try
    unzip(zipfile, outdir);
catch
    % Even if unzip throws error, file might still be extracted
end

if (exist(zipfile, 'file'))
    delete(zipfile);
end

% Look for the output file - it's named 'data' in our ZIP (from wrap_deflate_in_zip)
outfile = fullfile(outdir, 'data');

if (exist(outfile, 'file') ~= 2)
    % Try to find any file in outdir
    d = dir(outdir);
    for i = 1:length(d)
        if (~d(i).isdir)
            outfile = fullfile(outdir, d(i).name);
            break
        end
    end
end

if (exist(outfile, 'file') ~= 2)
    if (exist(outdir, 'dir'))
        rmdir(outdir, 's');
    end
    error('failed to decompress zlib data');
end

fd = fopen(outfile, 'rb');
if (fd < 0)
    if (exist(outdir, 'dir'))
        rmdir(outdir, 's');
    end
    error('failed to open decompressed file');
end
data = fread(fd, [1 inf], 'uint8=>uint8');
fclose(fd);

% Cleanup
if (exist(outdir, 'dir'))
    delete(fullfile(outdir, '*'));
    rmdir(outdir);
end

% ==========================================================================
% File-based GZIP compression/decompression
% ==========================================================================

function compressed = file_gzip_encode(data)
% GZIP compression using file I/O with 'wbz' mode

data = uint8(data(:))';
fname = tempname;
gzfile = [fname '.gz'];

fd = fopen(gzfile, 'wbz');
fwrite(fd, data, 'uint8');
fclose(fd);

fd = fopen(gzfile, 'rb');
compressed = fread(fd, [1 inf], 'uint8=>uint8');
fclose(fd);
delete(gzfile);

% --------------------------------------------------------------------------
function data = file_gzip_decode(compressed)
% GZIP decompression using file I/O with 'rbz' mode

compressed = uint8(compressed(:))';
fname = tempname;
gzfile = [fname '.gz'];

fd = fopen(gzfile, 'wb');
fwrite(fd, compressed, 'uint8');
fclose(fd);

fd = fopen(gzfile, 'rbz');
data = fread(fd, [1 inf], 'uint8=>uint8');
fclose(fd);
delete(gzfile);

% ==========================================================================
% ZIP format helper functions
% ==========================================================================

function deflate_data = extract_deflate_from_zip(zipdata)
% Extract raw DEFLATE stream from ZIP archive

deflate_data = zipdata;
if (length(zipdata) > 30 && zipdata(1) == 80 && zipdata(2) == 75 && ...
    zipdata(3) == 3 && zipdata(4) == 4)
    fname_len = double(zipdata(27)) + double(zipdata(28)) * 256;
    extra_len = double(zipdata(29)) + double(zipdata(30)) * 256;
    comp_size = double(zipdata(19)) + double(zipdata(20)) * 256 + ...
                double(zipdata(21)) * 65536 + double(zipdata(22)) * 16777216;
    data_start = 31 + fname_len + extra_len;
    if (data_start + comp_size - 1 <= length(zipdata))
        deflate_data = zipdata(data_start:data_start + comp_size - 1);
    end
end

% --------------------------------------------------------------------------
function zlib_data = wrap_zlib(deflate_data, original_data)
% Wrap raw DEFLATE in ZLIB format (header + deflate + adler32)

header = uint8([120, 156]);  % 0x78 0x9C = default compression
checksum = adler32(original_data);
trailer = uint8([bitand(bitshift(checksum, -24), 255), ...
                 bitand(bitshift(checksum, -16), 255), ...
                 bitand(bitshift(checksum, -8), 255), ...
                 bitand(checksum, 255)]);
zlib_data = [header, deflate_data(:)', trailer];

% --------------------------------------------------------------------------
function checksum = adler32(data)
% Compute Adler-32 checksum

data = uint8(data(:))';
a = uint32(1);
b = uint32(0);
MOD = uint32(65521);

for i = 1:length(data)
    a = mod(a + uint32(data(i)), MOD);
    b = mod(b + a, MOD);
end
checksum = uint32(bitor(bitshift(b, 16), a));

% --------------------------------------------------------------------------
function crc = crc32(data)
% Compute CRC-32 checksum

data = uint8(data(:))';
crc = uint32(4294967295);  % 0xFFFFFFFF

% CRC-32 polynomial table
persistent crc_table
if (isempty(crc_table))
    crc_table = zeros(1, 256, 'uint32');
    poly = uint32(3988292384);  % 0xEDB88320
    for i = 0:255
        c = uint32(i);
        for j = 1:8
            if (bitand(c, 1))
                c = bitxor(bitshift(c, -1), poly);
            else
                c = bitshift(c, -1);
            end
        end
        crc_table(i + 1) = c;
    end
end

for i = 1:length(data)
    idx = bitand(bitxor(crc, uint32(data(i))), 255) + 1;
    crc = bitxor(bitshift(crc, -8), crc_table(idx));
end

crc = bitxor(crc, uint32(4294967295));  % final XOR

% --------------------------------------------------------------------------
function zipdata = wrap_deflate_in_zip(deflate_data, orig_data, crc32val)
% Wrap raw DEFLATE data in a minimal ZIP archive

deflate_data = uint8(deflate_data(:))';
comp_size = length(deflate_data);

if (nargin < 2 || isempty(orig_data))
    uncomp_size = comp_size * 10;
else
    uncomp_size = length(orig_data);
end

if (nargin < 3 || isempty(crc32val))
    crc32val = uint32(0);
end

filename = uint8('data');
fname_len = length(filename);

lh = uint8(zeros(1, 30));
lh(1:4) = [80, 75, 3, 4];
lh(5:6) = [20, 0];
lh(7:8) = [0, 0];
lh(9:10) = [8, 0];
lh(11:14) = [0, 0, 0, 0];
lh(15:18) = typecast(crc32val, 'uint8');
lh(19:22) = typecast(uint32(comp_size), 'uint8');
lh(23:26) = typecast(uint32(uncomp_size), 'uint8');
lh(27:28) = typecast(uint16(fname_len), 'uint8');
lh(29:30) = [0, 0];

ch = uint8(zeros(1, 46));
ch(1:4) = [80, 75, 1, 2];
ch(5:6) = [20, 0];
ch(7:8) = [20, 0];
ch(9:10) = [0, 0];
ch(11:12) = [8, 0];
ch(13:16) = [0, 0, 0, 0];
ch(17:20) = typecast(crc32val, 'uint8');
ch(21:24) = typecast(uint32(comp_size), 'uint8');
ch(25:28) = typecast(uint32(uncomp_size), 'uint8');
ch(29:30) = typecast(uint16(fname_len), 'uint8');
ch(31:46) = zeros(1, 16, 'uint8');

local_size = 30 + fname_len + comp_size;
central_size = 46 + fname_len;

ec = uint8(zeros(1, 22));
ec(1:4) = [80, 75, 5, 6];
ec(5:8) = [0, 0, 0, 0];
ec(9:10) = [1, 0];
ec(11:12) = [1, 0];
ec(13:16) = typecast(uint32(central_size), 'uint8');
ec(17:20) = typecast(uint32(local_size), 'uint8');
ec(21:22) = [0, 0];

zipdata = [lh, filename, deflate_data, ch, filename, ec];
