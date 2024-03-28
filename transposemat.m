function data = transposemat(input)
%
%    data=transposemat(input)
%
%    Iterate over struct/cell and transpose 2D or higher-dimensional numerical
%    array to match Octave loaded HDF5 array elements with loadh5 default setting
%
%    author: Qianqian Fang (q.fang <at> neu.edu)
%
%    input:
%        name: a matlab variable, can be a cell, struct, containers.Map, numeric array or strings
%
%    output:
%        newname: the restored original string
%
%    example:
%        a=struct('a', ones(2,3), 'b', 'a string', 'c', uint8(zeros(2,3,4)));
%        b=transposemat(a)
%
%    this file is part of EasyH5 Toolbox: https://github.com/NeuroJSON/easyh5
%
%    License: GPLv3 or 3-clause BSD license, see https://github.com/NeuroJSON/easyh5 for details
%

if (isstruct(input))
    data = structfun(@transposemat, input, 'UniformOutput', false);
elseif (iscell(input))
    data = cellfun(@transposemat, input, 'UniformOutput', 'false');
elseif (isa(input, 'containers.Map'))
    allkeys = keys(input);
    for i = 1:length(allkeys)
        input(allkeys(i)) = transposemat(allkeys(i));
    end
elseif (isnumeric(input) && (ndims(input) > 2 || all(size(input) > 1)))
    data = permute(input, ndims(input):-1:1);
elseif (ischar(input) && ndims(input) == 2 && size(input, 1) == 1 && size(input, 2) > 1 && input(end) == ' ')
    data = input(1:end - 1);
else
    data = input;
end
