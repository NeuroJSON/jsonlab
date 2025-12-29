function varargout = zlibdecode(varargin)
%
% output = zlibdecode(input)
%    or
% output = zlibdecode(input,info)
%
% Decompressing a ZLIB-compressed byte-stream to recover the original data
% This function depends on JVM in MATLAB or, can optionally use the ZMat
% toolbox (http://github.com/NeuroJSON/zmat)
%
% Copyright (c) 2012, Kota Yamaguchi
% URL: https://www.mathworks.com/matlabcentral/fileexchange/39526-byte-encoding-utilities
%
% Modified by: Qianqian Fang (q.fang <at> neu.edu)
%
% input:
%      input: a string, int8/uint8 vector or numerical array to store ZLIB-compressed data
%      info (optional): a struct produced by the zmat/zlibencode function during
%            compression; if not given, the inputs/outputs will be treated as a
%            1-D vector
%
% output:
%      output: the decompressed byte stream stored in a uint8 vector; if info is
%            given, output will restore the original data's type and dimensions
%
% examples:
%      [bytes, info]=zlibencode(eye(10));
%      orig=zlibdecode(bytes,info);
%
% license:
%     BSD or GPL version 3, see LICENSE_{BSD,GPLv3}.txt files for details
%
% -- this function is part of JSONLab toolbox (http://neurojson.org/jsonlab)
%

if (nargin == 0)
    error('you must provide at least 1 input');
end

nozmat = getvarfrom({'caller', 'base'}, 'NO_ZMAT');

if ((exist('zmat', 'file') == 2 || exist('zmat', 'file') == 3) && (isempty(nozmat) || nozmat == 0))
    if (nargin > 1)
        [varargout{1:nargout}] = zmat(varargin{1}, varargin{2:end});
    else
        [varargout{1:nargout}] = zmat(varargin{1}, 0, 'zlib', varargin{2:end});
    end
    return
end

if (ischar(varargin{1}))
    varargin{1} = uint8(varargin{1});
end

input = typecast(varargin{1}(:)', 'uint8');

if (~usejava('jvm'))
    if (nargin > 1)
        [varargout{1:nargout}] = octavezmat(varargin{1}, varargin{2}, 'zlib');
    else
        [varargout{1:nargout}] = octavezmat(varargin{1}, 0, 'zlib');
    end
    return
end

if (isoctavemesh)
    % Octave with Java: write/read bytes one at a time
    n = numel(input);
    inputBaos = javaObject('java.io.ByteArrayOutputStream', n);
    for i = 1:n
        inputBaos.write(int32(input(i)));
    end
    bais = javaObject('java.io.ByteArrayInputStream', inputBaos.toByteArray());
    iis = javaObject('java.util.zip.InflaterInputStream', bais);
    outputBaos = javaObject('java.io.ByteArrayOutputStream');
    while true
        b = iis.read();
        if (b < 0)
            break
        end
        outputBaos.write(b);
    end
    iis.close();
    varargout{1} = typecast(outputBaos.toByteArray(), 'uint8')';
else
    % MATLAB with Java: direct array write
    buffer = java.io.ByteArrayOutputStream();
    zlib = java.util.zip.InflaterOutputStream(buffer);
    zlib.write(input, 0, numel(input));
    zlib.close();
    varargout{1} = typecast(buffer.toByteArray(), 'uint8')';
end

if (nargin > 1 && isstruct(varargin{2}) && isfield(varargin{2}, 'type'))
    inputinfo = varargin{2};
    varargout{1} = typecast(varargout{1}, inputinfo.type);
    varargout{1} = reshape(varargout{1}, inputinfo.size);
end
