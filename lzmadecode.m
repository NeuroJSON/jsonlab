function output = lzmadecode(input)
%LZMADECODE Decompress input bytes using lzma.
%
%    output = lzmadecode(input)
%
% The function takes a compressed byte array INPUT and returns inflated
% bytes OUTPUT. The INPUT is a result of LZMADECODE function. The OUTPUT
% is always an 1-by-N uint8 array.
%
% See also lzmaencode typecast
%
% License : BSD, see LICENSE_*.txt
%

if(nargin==0)
    error('you must provide at least 1 input');
end
if(exist('zmat')==3)
    output=zmat(uint8(input),0,'lzma');
    return;
else
    error('you must install ZMat toolbox to use this feature: http://github.com/fangq/zmat_mex')
end
