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

% Try built-in JVM-based zlib first when Java is available
if (jdhasjava)
    try
        rawinput = varargin{1};
        if (ischar(rawinput))
            rawinput = uint8(rawinput);
        end
        input = typecast(rawinput(:)', 'uint8');

        % InflaterOutputStream lets the compressed bytes be pushed in rather
        % than pulled out, so a single bulk write replaces what used to be two
        % byte-at-a-time loops on Octave
        buffer = javaObject('java.io.ByteArrayOutputStream');
        zlib = javaObject('java.util.zip.InflaterOutputStream', buffer);
        jdjavawrite(zlib, input);
        zlib.close();
        varargout{1} = typecast(buffer.toByteArray(), 'uint8')';

        if (nargin > 1 && isstruct(varargin{2}) && isfield(varargin{2}, 'type'))
            inputinfo = varargin{2};
            varargout{1} = typecast(varargout{1}, inputinfo.type);
            varargout{1} = reshape(varargout{1}, inputinfo.size);
        end
        return
    catch
        % JVM-based zlib failed; fall through to zmat/octavezmat
    end
end

% Fall back to ZMat toolbox when available
nozmat = getvarfrom({'caller', 'base'}, 'NO_ZMAT');

if ((exist('zmat', 'file') == 2 || exist('zmat', 'file') == 3) && (isempty(nozmat) || nozmat == 0))
    try
        if (nargin > 1)
            [varargout{1:nargout}] = zmat(varargin{1}, varargin{2:end});
        else
            [varargout{1:nargout}] = zmat(varargin{1}, 0, 'zlib', varargin{2:end});
        end
        return
    catch
        % zmat is on path but its zipmat MEX is missing or failed;
        % fall through to the pure-MATLAB/Octave fallback
    end
end

% Final fallback: pure-MATLAB/Octave implementation
if (nargin > 1)
    [varargout{1:nargout}] = octavezmat(varargin{1}, varargin{2}, 'zlib');
else
    [varargout{1:nargout}] = octavezmat(varargin{1}, 0, 'zlib');
end
