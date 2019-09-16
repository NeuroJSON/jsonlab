function output = lz4hcencode(input)
%LZ4HCENCODE Compress input bytes with lz4hc.
%
%    output = lz4hcencode(input)
%
% The function takes a char, int8, or uint8 array INPUT and returns
% compressed bytes OUTPUT as a uint8 array. Note that the compression
% doesn't preserve input dimensions.
%
% See also lz4hcdecode
%
% License : BSD, see LICENSE_*.txt
%

if(nargin==0)
    error('you must provide at least 1 input');
end
if(exist('zmat','file')==2 || exist('zmat','file')==3)
    output=zmat(uint8(input),1,'lz4hc');
    return;
else
    error('you must install ZMat toolbox to use this feature: http://github.com/fangq/zmat')
end
