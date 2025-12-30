function str = encodevarname(str, varargin)
%
%    newname = encodevarname(name)
%
%    Encode an invalid variable name using a hex-format for bi-directional
%    conversions.
%
%    This function is sensitive to the default charset
%    settings in MATLAB, please call feature('DefaultCharacterSet','utf8')
%    to set the encoding to UTF-8 before calling this function.
%
%    author: Qianqian Fang (q.fang <at> neu.edu)
%
%    input:
%        name: a string, can be either a valid or invalid variable name
%
%    output:
%        newname: a valid variable name by converting the leading non-ascii
%              letter into "x0xHH_" and non-ascii letters into "_0xHH_"
%              format, where HH is the ascii (or Unicode) value of the
%              character.
%
%              if the encoded variable name CAN NOT be longer than 63, i.e.
%              the maximum variable name specified by namelengthmax, and
%              one uses the output of this function as a struct or variable
%              name, the name will be truncated at 63. Please consider using
%              the name as a containers.Map key, which does not have such
%              limit.
%
%    example:
%        encodevarname('_a')   % returns x0x5F_a
%        encodevarname('a_')   % returns a_ as it is a valid variable name
%        encodevarname('变量')  % returns 'x0xE58F98__0xE9878F_'
%
%    this file is part of EasyH5 Toolbox: https://github.com/NeuroJSON/easyh5
%
%    License: GPLv3 or 3-clause BSD license, see https://github.com/NeuroJSON/easyh5 for details
%

% Fast path: check first character directly instead of calling isvarname
c1 = str(1);
if ~((c1 >= 'a' && c1 <= 'z') || (c1 >= 'A' && c1 <= 'Z'))
    % First char is not a letter - need to encode it
    if (exist('unicode2native', 'builtin'))
        str = sprintf('x0x%s_%s', sprintf('%X', unicode2native(c1)), str(2:end));
    else
        str = sprintf('x0x%X_%s', c1 + 0, str(2:end));
    end
end

% Fast validation: check if all remaining chars are valid (alphanumeric or underscore)
% This is faster than calling isvarname for simple cases
len = length(str);
if len <= 63
    isvalid = true;
    for i = 1:len
        c = str(i);
        if ~((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '_')
            isvalid = false;
            break
        end
    end
    if isvalid
        return
    end
end

% Slow path: has invalid characters, need full encoding
if (exist('unicode2native', 'builtin'))
    str = regexprep(str, '([^0-9A-Za-z_])', '_0x${sprintf(''%X'',unicode2native($1))}_');
else
    cpos = find(~ismember(str, ['0':'9', 'A':'Z', 'a':'z', '_']));
    if (isempty(cpos))
        return
    end
    str0 = str;
    pos0 = [0 cpos(:)' length(str)];
    str = '';
    for i = 1:length(cpos)
        str = [str str0(pos0(i) + 1:cpos(i) - 1) sprintf('_0x%X_', str0(cpos(i)) + 0)];
    end
    if (cpos(end) ~= length(str))
        str = [str str0(pos0(end - 1) + 1:pos0(end))];
    end
end
