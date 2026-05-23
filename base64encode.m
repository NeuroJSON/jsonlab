function varargout = base64encode(varargin)
%
% output = base64encode(input)
%
% Encoding a binary vector or array using Base64
%
% This function depends on JVM in MATLAB or, can optionally use the ZMat
% toolbox (http://github.com/NeuroJSON/zmat)
%
% Copyright (c) 2012, Kota Yamaguchi
% URL: https://www.mathworks.com/matlabcentral/fileexchange/39526-byte-encoding-utilities
%
% Modified by: Qianqian Fang (q.fang <at> neu.edu)
%
% input:
%      input: a base64-encoded string
%
% output:
%      output: the decoded binary byte-stream as a uint8 vector
%
% examples:
%      bytes=base64encode('Test JSONLab');
%      orig=char(base64decode(bytes))
%
% license:
%     BSD or GPL version 3, see LICENSE_{BSD,GPLv3}.txt files for details
%
% -- this function is part of JSONLab toolbox (http://neurojson.org/jsonlab)
%

if (nargin == 0)
    error('you must provide at least 1 input');
end

% Try built-in base64 encoder first
if (isoctavemesh)
    try
        rawinput = varargin{1};
        if (ischar(rawinput))
            rawinput = uint8(rawinput);
        end
        input = typecast(rawinput(:)', 'uint8');
        varargout{1} = base64_encode(uint8(input));
        return
    catch
        % fall through to zmat/JVM
    end
elseif (usejava('jvm'))
    try
        rawinput = varargin{1};
        if (ischar(rawinput))
            rawinput = uint8(rawinput);
        end
        input = typecast(rawinput(:)', 'uint8');
        varargout{1} = char(org.apache.commons.codec.binary.Base64.encodeBase64Chunked(input))';
        varargout{1} = regexprep(varargout{1}, '[\r\n]', '');
        return
    catch
        % fall through to zmat
    end
end

% Fall back to ZMat toolbox when available
nozmat = getvarfrom({'caller', 'base'}, 'NO_ZMAT');

if ((exist('zmat', 'file') == 2 || exist('zmat', 'file') == 3) && (isempty(nozmat) || nozmat == 0))
    try
        [varargout{1:nargout}] = zmat(varargin{1}, 1, 'base64', varargin{2:end});
        return
    catch
        % zmat is on path but its zipmat MEX is missing or failed
    end
end

error('no available base64 encoder: requires Octave, JVM, or the ZMat toolbox');
