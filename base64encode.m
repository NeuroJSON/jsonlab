function output = base64encode(input)
%BASE64ENCODE Encode a byte array using Base64 codec.
%
%    output = base64encode(input)
%
% The function takes a char, int8, or uint8 array INPUT and returns Base64
% encoded string OUTPUT. JAVA must be running to use this function. Note
% that encoding doesn't preserve input dimensions.
%
% See also base64decode
%
% Copyright (c) 2012, Kota Yamaguchi
% URL: https://www.mathworks.com/matlabcentral/fileexchange/39526-byte-encoding-utilities
% License : BSD, see LICENSE_*.txt
%

if(nargin==0)
    error('you must provide at least 1 input');
end
if(exist('zmat')==3)
    output=zmat(uint8(input),1,'base64');
    return;
end
if(exist('OCTAVE_VERSION','builtin'))
    output = base64_encode(uint8(input));
    return;
end
error(javachk('jvm'));
if ischar(input), input = uint8(input); end

output = char(org.apache.commons.codec.binary.Base64.encodeBase64Chunked(input))';
output = regexprep(output,'\r','');
end
