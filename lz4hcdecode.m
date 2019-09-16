function output = lz4hcdecode(input)
%LZ4HCDECODE Decompress input bytes using lz4hc.
%
%    output = lz4hcdecode(input)
%
% The function takes a compressed byte array INPUT and returns inflated
% bytes OUTPUT. The INPUT is a result of LZ4HCDECODE function. The OUTPUT
% is always an 1-by-N uint8 array.
%
% See also lz4hcencode typecast
%
% License : BSD, see LICENSE_*.txt
%

if(nargin==0)
    error('you must provide at least 1 input');
end
if(exist('zmat','file')==2 || exist('zmat','file')==3)
    output=zmat(uint8(input),0,'lz4hc');
    return;
else
    error('you must install ZMat toolbox to use this feature: http://github.com/fangq/zmat')
end
