function output = lzipdecode(input)
%LZIPDECODE Decompress input bytes using lzip.
%
%    output = lzipdecode(input)
%
% The function takes a compressed byte array INPUT and returns inflated
% bytes OUTPUT. The INPUT is a result of LZIPDECODE function. The OUTPUT
% is always an 1-by-N uint8 array.
%
% See also lzipencode typecast
%
% License : BSD, see LICENSE_*.txt
%

if(nargin==0)
    error('you must provide at least 1 input');
end
if(exist('zmat','file')==2 || exist('zmat','file')==3)
    output=zmat(uint8(input),0,'lzip');
    return;
else
    error('you must install ZMat toolbox to use this feature: http://github.com/fangq/zmat')
end
