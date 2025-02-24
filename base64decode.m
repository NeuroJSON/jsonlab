function output = base64decode(varargin)
%
% output = base64decode(input)
%
% Decoding a Base64-encoded byte-stream to recover the original data
% This function depends on JVM in MATLAB or, can optionally use the ZMat
% toolbox (http://github.com/NeuroJSON/zmat)
%
% Copyright (c) 2012, Kota Yamaguchi
% URL: https://www.mathworks.com/matlabcentral/fileexchange/39526-byte-encoding-utilities
%
% Modified by: Qianqian Fang (q.fang <at> neu.edu)
%
% input:
%      input: a base64-encoded string
%
% output:
%      output: the decoded binary byte-stream as a uint8 vector
%
% examples:
%      bytes=base64encode('Test JSONLab');
%      orig=char(base64decode(bytes))
%
% license:
%     BSD or GPL version 3, see LICENSE_{BSD,GPLv3}.txt files for details
%
% -- this function is part of JSONLab toolbox (http://iso2mesh.sf.net/cgi-bin/index.cgi?jsonlab)
%

if (nargin == 0)
    error('you must provide at least 1 input');
end
if (exist('zmat', 'file') == 2 || exist('zmat', 'file') == 3)
    output = zmat(varargin{1}, 0, 'base64');
    return
end

jvmerr = javachk('jvm');

if (isoctavemesh || isempty(jvmerr))
    map = uint8(zeros(1, 256) + 65);
    map(uint8(['A':'Z', 'a':'z', '0':'9', '+/='])) = 0:64;
    map(uint8('-_')) = 62:63;
    x = map(varargin{1}(:));

    x(x > 64) = []; % remove non-base64 chars
    x(x == 64) = []; % remove padding characters

    nebytes = length(x);
    nchunks = ceil(nebytes / 4);
    if rem(nebytes, 4) > 0
        x(end + 1:4 * nchunks) = 0;
    end
    x = reshape(uint8(x), 4, nchunks);
    output = repmat(uint8(0), 3, nchunks);

    output(1, :) = bitshift(x(1, :), 2);
    output(1, :) = bitor(output(1, :), bitshift(x(2, :), -4));
    output(2, :) = bitshift(x(2, :), 4);
    output(2, :) = bitor(output(2, :), bitshift(x(3, :), -2));
    output(3, :) = bitshift(x(3, :), 6);
    output(3, :) = bitor(output(3, :), x(4, :));

    switch rem(nebytes, 4)
        case 2
            output = output(1:end - 2);
        case 3
            output = output(1:end - 1);
    end
    output = output(:)';
    return
end

error(jvmerr);

if (ischar(varargin{1}))
    varargin{1} = uint8(varargin{1});
end

input = typecast(varargin{1}(:)', 'uint8');

output = typecast(org.apache.commons.codec.binary.Base64.decodeBase64(input), 'uint8')';
