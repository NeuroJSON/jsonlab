function key = jdatahash(data, algorithm, varargin)
%
%    key = jdatahash(data)
%        or
%    key = jdatahash(data, algorithm)
%
%    computing the hash key for a string or a numeric array (data elements
%    are serialized in the row-major order first)
%
%    author: Qianqian Fang (q.fang <at> neu.edu)
%
%    input:
%        data: a string or a numeric array
%        algorithm: a string denoting the data hashing algorithm (case
%              insensitive); default is 'sha256'; supported options include
%
%        for both MATLAB/Octave: 'sha256' (default), 'sha1', 'md5'
%        Octave-only: 'md2', 'md4', 'sha224', 'sha384', 'sha512'
%
%    examples:
%        jdatahash('neurojson')
%        key = jdatahash('reusable data', 'md5')
%
%    license:
%        BSD or GPL version 3, see LICENSE_{BSD,GPLv3}.txt files for details
%
% -- this function is part of JSONLab toolbox (http://iso2mesh.sf.net/cgi-bin/index.cgi?jsonlab)
%

if(nargin < 2)
    algorithm = 'sha-256';
end

if (ischar(data))
    data = uint8(data);
end

opt=varargin2struct(varargin{:});

if(jsonopt(opt))
data = permute(data, ndims(data):-1:1);

if(isoctavemesh && exist('hash'))
    algorithm(algorithm=='-')=[];
    key = hash(algorithm, char(typecast(data(:).', 'uint8')));
else
    md = java.security.MessageDigest.getInstance(algorithm);
    key = sprintf('%2.2x', typecast(md.digest(typecast(data(:), 'uint8')), 'uint8')');
end