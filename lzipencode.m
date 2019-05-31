function output = lzipencode(input)
%LZIPENCODE Compress input bytes with lzip.
%
%    output = lzipencode(input)
%
% The function takes a char, int8, or uint8 array INPUT and returns
% compressed bytes OUTPUT as a uint8 array. Note that the compression
% doesn't preserve input dimensions.
%
% See also lzipdecode
%
% License : BSD, see LICENSE_*.txt
%

if(nargin==0)
    error('you must provide at least 1 input');
end
if(exist('zmat')==3)
    output=zmat(uint8(input),1,'lzip');
    return;
else
    error('you must install ZMat toolbox to use this feature: http://github.com/fangq/zmat_mex')
end
