function varargout = zstdencode(varargin)
%
% output = zstdencode(input)
%    or
% [output, info] = zstdencode(input)
%
% Compress a string or a numerical array using Zstd-compression
%
% This function depends on the ZMat toolbox (http://github.com/NeuroJSON/zmat)
%
% authors:Qianqian Fang (q.fang <at> neu.edu)
%
% input:
%      input: the original data, can be a string, a numerical vector or array
%
% output:
%      output: the compressed byte stream stored in a uint8 vector
%      info: (optional) a struct storing the metadata of the input, see "help zmat" for details
%
% examples:
%      [bytes, info]=zstdencode(eye(10));
%      orig=zstddecode(bytes,info);
%
% license:
%     BSD or GPL version 3, see LICENSE_{BSD,GPLv3}.txt files for details
%
% -- this function is part of JSONLab toolbox (http://neurojson.org/jsonlab)
%

if (nargin == 0)
    error('you must provide at least 1 input');
end

if (exist('zmat', 'file') == 2 || exist('zmat', 'file') == 3)
    [varargout{1:nargout}] = zmat(varargin{1}, 1, 'zstd', varargin{2:end});
    return
else
    error('you must install ZMat toolbox to use this feature: http://github.com/NeuroJSON/zmat');
end
