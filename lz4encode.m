function output = lz4encode(input)
%LZ4ENCODE Compress input bytes with lz4.
%
%    output = lz4encode(input)
%
% The function takes a char, int8, or uint8 array INPUT and returns
% compressed bytes OUTPUT as a uint8 array. Note that the compression
% doesn't preserve input dimensions.
%
% See also lz4decode
%
% License : BSD, see LICENSE_*.txt
%

if(nargin==0)
    error('you must provide at least 1 input');
end
if(exist('zmat','file')==2 || exist('zmat','file')==3)
    output=zmat(uint8(input),1,'lz4');
    return;
else
    error('you must install ZMat toolbox to use this feature: http://github.com/fangq/zmat')
end
