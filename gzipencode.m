function varargout = gzipencode(varargin)
%
% output = gzipencode(input)
%    or
% [output, info] = gzipencode(input)
%
% Compress a string or numerical array using the GZIP-compression
%
% This function depends on JVM in MATLAB or, can optionally use the ZMat
% toolbox (https://github.com/NeuroJSON/zmat)
%
% Copyright (c) 2012, Kota Yamaguchi
% URL: https://www.mathworks.com/matlabcentral/fileexchange/39526-byte-encoding-utilities
%
% Modified by: Qianqian Fang (q.fang <at> neu.edu)
%
% input:
%      input: the original data, can be a string, a numerical vector or array
%
% output:
%      output: the decompressed byte stream stored in a uint8 vector; if info is
%            given, output will restore the original data's type and dimensions
%
% examples:
%      [bytes, info]=gzipencode(eye(10));
%      orig=gzipdecode(bytes,info);
%
% license:
%     BSD or GPL version 3, see LICENSE_{BSD,GPLv3}.txt files for details
%
% -- this function is part of JSONLab toolbox (http://neurojson.org/jsonlab)
%

if (nargin == 0)
    error('you must provide at least 1 input');
end

inputinfo = struct('type', class(varargin{1}), 'size', size(varargin{1}), 'method', 'gzip', 'status', 0);

% Try built-in JVM-based gzip first when Java is available
if (usejava('jvm'))
    try
        input = varargin{1}(:)';
        if (ischar(input))
            input = uint8(input);
        elseif (isa(input, 'string'))
            input = uint8(char(input));
        else
            input = typecast(input, 'uint8');
        end

        if (isoctavemesh)
            % Octave with Java: write bytes one at a time
            baos = javaObject('java.io.ByteArrayOutputStream');
            gzos = javaObject('java.util.zip.GZIPOutputStream', baos);
            for i = 1:numel(input)
                gzos.write(int32(input(i)));
            end
            gzos.finish();
            gzos.close();
            varargout{1} = typecast(baos.toByteArray(), 'uint8')';
        else
            % MATLAB with Java: direct array write
            buffer = java.io.ByteArrayOutputStream();
            gzip = java.util.zip.GZIPOutputStream(buffer);
            gzip.write(input, 0, numel(input));
            gzip.close();
            varargout{1} = typecast(buffer.toByteArray(), 'uint8')';
        end
        varargout{1} = normalize_gzip_os(varargout{1});
        if (nargout > 1)
            varargout{2} = inputinfo;
        end
        return
    catch
        % JVM-based gzip failed; fall through to zmat/octavezmat
    end
end

% Fall back to ZMat toolbox when available
nozmat = getvarfrom({'caller', 'base'}, 'NO_ZMAT');

if ((exist('zmat', 'file') == 2 || exist('zmat', 'file') == 3) && (isempty(nozmat) || nozmat == 0))
    try
        [varargout{1:nargout}] = zmat(varargin{1}, 1, 'gzip');
        varargout{1} = normalize_gzip_os(varargout{1});
        return
    catch
        % zmat is on path but its zipmat MEX is missing or failed;
        % fall through to the pure-MATLAB/Octave fallback
    end
end

% Final fallback: pure-MATLAB/Octave implementation
[varargout{1:nargout}] = octavezmat(varargin{1}, 1, 'gzip');
varargout{1} = normalize_gzip_os(varargout{1});

% --------------------------------------------------------------------------
function out = normalize_gzip_os(out)
% Force the gzip header OS byte (offset 9) to 0x03 (Unix) so the output is
% byte-identical across backends (Java=0x00, zmat=platform-dependent) and
% platforms (Windows/Mac/Linux).
if (numel(out) >= 10)
    out(10) = uint8(3);
end
