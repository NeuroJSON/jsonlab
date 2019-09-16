function output = lz4decode(input)
%LZ4DECODE Decompress input bytes using lz4.
%
%    output = lz4decode(input)
%
% The function takes a compressed byte array INPUT and returns inflated
% bytes OUTPUT. The INPUT is a result of LZ4DECODE function. The OUTPUT
% is always an 1-by-N uint8 array.
%
% See also lz4encode typecast
%
% License : BSD, see LICENSE_*.txt
%

if(nargin==0)
    error('you must provide at least 1 input');
end
if(exist('zmat','file')==2 || exist('zmat','file')==3)
    output=zmat(uint8(input),0,'lz4');
    return;
else
    error('you must install ZMat toolbox to use this feature: http://github.com/fangq/zmat')
end
