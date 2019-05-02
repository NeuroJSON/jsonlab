function output = base64decode(input)
%BASE64DECODE Decode Base64 string to a byte array.
%
%    output = base64decode(input)
%
% The function takes a Base64 string INPUT and returns a uint8 array
% OUTPUT. JAVA must be running to use this function. The result is always
% given as a 1-by-N array, and doesn't retrieve the original dimensions.
%
% See also base64encode
%
% Copyright (c) 2012, Kota Yamaguchi
% URL: https://www.mathworks.com/matlabcentral/fileexchange/39526-byte-encoding-utilities
% License : BSD, see LICENSE_*.txt
%

if(nargin==0)
    error('you must provide at least 1 input');
end
if(exist('zmat')==3)
    output=zmat(uint8(input),0,'base64');
    return;
end
if(exist('OCTAVE_VERSION','builtin'))
    len=rem(numel(input),8)
    if(len)
       input=[input(:)', repmat(sprintf('\0'),1,(8-len))];
    end
    output = base64_decode(input);
    return;
end
error(javachk('jvm'));
if ischar(input), input = uint8(input); end

output = typecast(org.apache.commons.codec.binary.Base64.decodeBase64(input), 'uint8')';

end

