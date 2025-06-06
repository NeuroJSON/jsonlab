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
% -- this function is part of JSONLab toolbox (http://iso2mesh.sf.net/cgi-bin/index.cgi?jsonlab)
%

if (nargin == 0)
    error('you must provide at least 1 input');
end

nozmat = getvarfrom({'caller', 'base'}, 'NO_ZMAT');

if ((exist('zmat', 'file') == 2 || exist('zmat', 'file') == 3) && (isempty(nozmat) || nozmat == 0))
    [varargout{1:nargout}] = zmat(varargin{1}, 1, 'gzip');
    return
elseif (isoctavemesh)
    [varargout{1:nargout}] = octavezmat(varargin{1}, 1, 'gzip');
    return
end

error(javachk('jvm'));

input = varargin{1}(:)';
if (ischar(input))
    input = uint8(input);
elseif (isa(input, 'string'))
    input = uint8(char(input));
else
    input = typecast(input, 'uint8');
end

input = typecast(input, 'uint8');

buffer = java.io.ByteArrayOutputStream();
gzip = java.util.zip.GZIPOutputStream(buffer);
gzip.write(input, 0, numel(input));
gzip.close();

varargout{1} = typecast(buffer.toByteArray(), 'uint8')';

if (nargout > 1)
    varargout{2} = struct('type', class(varargin{1}), 'size', size(varargin{1}), 'method', 'gzip', 'status', 0);
end
