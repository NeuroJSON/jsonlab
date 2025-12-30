function [data, mmap] = loadjson(fname, varargin)
%
% data=loadjson(fname,opt)
%    or
% [data, mmap]=loadjson(fname,'param1',value1,'param2',value2,...)
%
% parse a JSON (JavaScript Object Notation) file or string and return a
% matlab data structure with optional memory-map (mmap) table
%
% authors:Qianqian Fang (q.fang <at> neu.edu)
% created on 2011/09/09, including previous works from
%
%         Nedialko Krouchev: http://www.mathworks.com/matlabcentral/fileexchange/25713
%            created on 2009/11/02
%         François Glineur: http://www.mathworks.com/matlabcentral/fileexchange/23393
%            created on  2009/03/22
%         Joel Feenstra:
%         http://www.mathworks.com/matlabcentral/fileexchange/20565
%            created on 2008/07/03
%
% input:
%      fname: input file name; if fname contains "{}" or "[]", fname
%             will be interpreted as a JSON string
%      opt: (optional) a struct to store parsing options, opt can be replaced by
%           a list of ('param',value) pairs - the param string is equivalent
%           to a field in opt. opt can have the following
%           fields (first in [.|.] is the default)
%
%           Raw [0|1]: if set to 1, loadjson returns the raw JSON string
%           SimplifyCell [1|0]: if set to 1, loadjson will call cell2mat
%                         for each element of the JSON data, and group
%                         arrays based on the cell2mat rules.
%           FastArrayParser [1|0 or integer]: if set to 1, use a
%                         speed-optimized array parser when loading an
%                         array object. The fast array parser may
%                         collapse block arrays into a single large
%                         array similar to rules defined in cell2mat; 0 to
%                         use a legacy parser; if set to a larger-than-1
%                         value, this option will specify the minimum
%                         dimension to enable the fast array parser. For
%                         example, if the input is a 3D array, setting
%                         FastArrayParser to 1 will return a 3D array;
%                         setting to 2 will return a cell array of 2D
%                         arrays; setting to 3 will return to a 2D cell
%                         array of 1D vectors; setting to 4 will return a
%                         3D cell array.
%           UseMap [0|1]: if set to 1, loadjson uses a containers.Map to
%                         store map objects; otherwise use a struct object
%           ShowProgress [0|1]: if set to 1, loadjson displays a progress bar.
%           ParseStringArray [0|1]: if set to 0, loadjson converts "string arrays"
%                         (introduced in MATLAB R2016b) to char arrays; if set to 1,
%                         loadjson skips this conversion.
%           FormatVersion [3|float]: set the JSONLab format version; since
%                         v2.0, JSONLab uses JData specification Draft 1
%                         for output format, it is incompatible with all
%                         previous releases; if old output is desired,
%                         please set FormatVersion to 1.9 or earlier.
%           Encoding ['']: json file encoding. Support all encodings of
%                         fopen() function
%           ObjectID [0|integer or list]: if set to a positive number,
%                         it returns the specified JSON object by index
%                         in a multi-JSON document; if set to a vector,
%                         it returns a list of specified objects.
%           JDataDecode [1|0]: if set to 1, call jdatadecode to decode
%                         JData structures defined in the JData
%                         Specification.
%           BuiltinJSON [0|1]: if set to 1, this function attempts to call
%                         jsondecode, if presents (MATLAB R2016b or Octave
%                         6) first. If jsondecode does not exist or failed,
%                         this function falls back to the jsonlab parser
%           MmapOnly [0|1]: if set to 1, this function only returns mmap
%           MMapInclude 'str1' or  {'str1','str2',..}: if provided, the
%                         returned mmap will be filtered by only keeping
%                         entries containing any one of the string patterns
%                         provided in a cell
%           MMapExclude 'str1' or  {'str1','str2',..}: if provided, the
%                         returned mmap will be filtered by removing
%                         entries containing any one of the string patterns
%                         provided in a cell
%           WebOptions {'Username', ..}: additional parameters for urlread
%
% output:
%      dat: a cell array, where {...} blocks are converted into cell arrays,
%           and [...] are converted to arrays
%      mmap: (optional) a cell array as memory-mapping table in the form of
%             {{jsonpath1,[start,length,<whitespace_pre>]},
%              {jsonpath2,[start,length,<whitespace_pre>]}, ...}
%           where jsonpath_i is a string in the JSONPath [1,2] format, and
%           "start" is an integer referring to the offset from the beginning
%           of the stream, and "length" is the JSON object string length.
%           An optional 3rd integer "whitespace_pre" may appear to record
%           the preceding whitespace length in case expansion of the data
%           record is needed when using the mmap.
%
%           The format of the mmap table returned from this function
%           follows the JSON-Mmap Specification Draft 1 [3] defined by the
%           NeuroJSON project, see https://neurojson.org/jsonmmap/draft1/
%
%           Memory-mapping table (mmap) is useful when fast reading/writing
%           specific data records inside a large JSON file without needing
%           to load/parse/overwrite the entire file.
%
%           The JSONPath keys used in mmap is largely compatible to the
%           upstream specification defined in [1], with a slight extension
%           to handle concatenated JSON files.
%
%           In the mmap jsonpath key, a '$' denotes the root object, a '.'
%           denotes a child of the preceding element; '.key' points to the
%           value segment of the child named "key" of the preceding
%           object; '[i]' denotes the (i+1)th member of the preceding
%           element, which must be an array. For example, a key
%
%           $.obj1.obj2[0].obj3
%
%           defines the memory-map of the "value" section in the below
%           hierarchy:
%             {
%                "obj1":{
%                    "obj2":[
%                       {"obj3":value},
%                       ...
%                    ],
%                    ...
%                 }
%             }
%           Please note that "value" can be any valid JSON value, including
%           an array, an object, a string or numerical value.
%
%           To handle concatenated JSON objects (including ndjson,
%           http://ndjson.org/), such as
%
%             {"root1": {"obj1": ...}}
%             ["root2", value1, value2, {"obj2": ...}]
%             {"root3": ...}
%
%           we use '$' or '$0' for the first root-object, and '$1' refers
%           to the 2nd root object (["root2",...]) and '$2' refers to the
%           3rd root object, and so on. Please note that this syntax is an
%           extension from the JSONPath documentation [1,2]
%
%           [1] https://goessner.net/articles/JsonPath/
%           [2] http://jsonpath.herokuapp.com/
%           [3] https://neurojson.org/jsonmmap/draft1/
%
% examples:
%      dat=loadjson('{"obj":{"string":"value","array":[1,2,3]}}')
%      dat=loadjson(['examples' filesep 'example1.json'])
%      [dat, mmap]=loadjson(['examples' filesep 'example1.json'],'SimplifyCell',0)
%
% license:
%     BSD or GPL version 3, see LICENSE_{BSD,GPLv3}.txt files for details
%
% -- this function is part of JSONLab toolbox (http://neurojson.org/jsonlab)
%

opt = varargin2struct(varargin{:});
webopt = jsonopt('WebOptions', {}, opt);

if (regexp(fname, '^\s*(?:\[.*\])|(?:\{.*\})\s*$', 'once'))
    jsonstring = fname;
elseif (regexpi(fname, '^\s*(http|https|ftp|file)://'))
    if (jsonopt('Header', 0, opt))
        [status, jsonstring] = system(['curl --head "' fname '"']);
        jsonstring = regexp(jsonstring, '\[\d+[a-z]*([^\n]+)\[\d+[a-z]*:\s*([^\r\n]*)', 'tokens');
    else
        jsonstring = urlread(fname, webopt{:});
    end
elseif (exist(fname, 'file'))
    try
        encoding = jsonopt('Encoding', '', opt);
        if (isempty(encoding))
            jsonstring = fileread(fname);
        else
            fid = fopen(fname, 'r', 'n', encoding);
            jsonstring = fread(fid, '*char')';
            fclose(fid);
        end
    catch
        try
            jsonstring = urlread(fname, webopt{:});
        catch
            jsonstring = urlread(['file://', fullfile(pwd, fname)]);
        end
    end
else
    error('input file does not exist');
end

if (jsonopt('Raw', 0, opt) || jsonopt('Header', 0, opt))
    data = jsonstring;
    if (nargout > 1)
        mmap = {};
    end
    return
end

if (jsonopt('BuiltinJSON', 0, opt) && exist('jsondecode', 'builtin'))
    try
        newstring = regexprep(jsonstring, '[\r\n]', '');
        newdata = jsondecode(newstring);
        newdata = jdatadecode(newdata, 'Base64', 1, 'Recursive', 1, varargin{:});
        data = newdata;
        return
    catch
        warning('built-in jsondecode function failed to parse the file, fallback to loadjson');
    end
end

inputlen = length(jsonstring);
inputstr = jsonstring;

% OPTIMIZATION: Precompute next non-whitespace position lookup table
ws = (inputstr == ' ' | inputstr == char(9) | inputstr == char(10) | inputstr == char(13));
nonws_idx = find(~ws);
if ~isempty(nonws_idx)
    marker = repmat(inputlen + 1, 1, inputlen);
    marker(nonws_idx) = nonws_idx;
    opt.next_nonws_ = fliplr(cummin(fliplr(marker)));
else
    opt.next_nonws_ = repmat(inputlen + 1, 1, inputlen);
end
opt.inputlen_ = inputlen;

% Precompute array tokens for fast array parsing
arraytokenidx = find(inputstr == '[' | inputstr == ']');
arraytoken = inputstr(arraytokenidx);

% String delimiters and escape chars identified to improve speed:
esc = find(inputstr == '"' | inputstr == '\');

opt.arraytoken_ = arraytoken;
opt.arraytokenidx_ = arraytokenidx;
opt.simplifycell = jsonopt('SimplifyCell', 1, opt);
opt.simplifycellarray = jsonopt('SimplifyCellArray', opt.simplifycell, opt);
opt.formatversion = jsonopt('FormatVersion', 3, opt);
opt.fastarrayparser = jsonopt('FastArrayParser', 1, opt);
opt.parsestringarray = jsonopt('ParseStringArray', 0, opt);
opt.usemap = jsonopt('UseMap', 0, opt);
opt.arraydepth_ = 1;
opt.mmaponly = jsonopt('MmapOnly', 0, opt);

if (jsonopt('ShowProgress', 0, opt) == 1)
    opt.progressbar_ = waitbar(0, 'loading ...');
end

objid = jsonopt('ObjectID', 0, opt);
maxobjid = max(objid);
if (maxobjid == 0)
    maxobjid = inf;
end
opt.jsonpath_ = '$';
needmmap = (nargout > 1 || opt.mmaponly);
if needmmap
    mmap = {};
end
if isempty(nonws_idx)
    data = [];
    inputlen = 0;
end

jsoncount = 1;
pos = 1;
index_esc = 1;
next_nonws = opt.next_nonws_;

while pos <= inputlen
    % Inline next_char
    w1 = pos;
    pos = next_nonws(pos);
    w1 = pos - w1;
    cc = inputstr(pos);

    switch cc
        case '{'
            if needmmap
                mmap{end + 1} = {opt.jsonpath_, [pos, 0, w1]};
                [data{jsoncount}, pos, index_esc, newmmap] = parse_object(inputstr, pos, esc, index_esc, opt);
                if (pos < 0)
                    opt.usemap = 1;
                    [data{jsoncount}, pos, index_esc, newmmap] = parse_object(inputstr, -pos, esc, index_esc, opt);
                end
                mmap{end}{2}(2) = pos - mmap{end}{2}(1);
                mmap = [mmap(:); newmmap(:)];
            else
                [data{jsoncount}, pos, index_esc] = parse_object(inputstr, pos, esc, index_esc, opt);
                if (pos < 0)
                    opt.usemap = 1;
                    [data{jsoncount}, pos, index_esc] = parse_object(inputstr, -pos, esc, index_esc, opt);
                end
            end
        case '['
            if needmmap
                mmap{end + 1} = {opt.jsonpath_, [pos, 0, w1]};
                [data{jsoncount}, pos, index_esc, newmmap] = parse_array(inputstr, pos, esc, index_esc, opt);
                mmap{end}{2}(2) = pos - mmap{end}{2}(1);
                mmap = [mmap(:); newmmap(:)];
            else
                [data{jsoncount}, pos, index_esc] = parse_array(inputstr, pos, esc, index_esc, opt);
            end
        otherwise
            error_pos('Outer level structure must be an object or an array', inputstr, pos);
    end
    if jsoncount >= maxobjid
        break
    end
    opt.jsonpath_ = sprintf('$%d', jsoncount);
    jsoncount = jsoncount + 1;
end

if (length(objid) > 1 || min(objid) > 1)
    data = data(objid(objid <= length(data)));
end

jsoncount = length(data);
if (jsoncount == 1 && iscell(data))
    data = data{1};
end
if needmmap
    mmap = mmap';
    mmap = filterjsonmmap(mmap, jsonopt('MMapExclude', {}, opt), 0);
    mmap = filterjsonmmap(mmap, jsonopt('MMapInclude', {}, opt), 1);
    mmap = cellfun(@(x) {x{1}, x{2}(1:(2 + int8(length(x{2}) >= 3 && (x{2}(3) > 0))))}, mmap, 'UniformOutput', false);
end
if (jsonopt('JDataDecode', 1, opt) == 1)
    try
        data = jdatadecode(data, 'Base64', 1, 'Recursive', 1, opt);
    catch ME
        warning(['Failed to decode embedded JData annotations, '...
                 'return raw JSON data\n\njdatadecode error: %s\n%s\nCall stack:\n%s\n'], ...
                ME.identifier, ME.message, char(savejson('', ME.stack)));
    end
end
if opt.mmaponly
    data = mmap;
end
if isfield(opt, 'progressbar_')
    close(opt.progressbar_);
end

%% -------------------------------------------------------------------------
%% helper functions
%% -------------------------------------------------------------------------

function [object, pos, index_esc, mmap] = parse_array(inputstr, pos, esc, index_esc, opt)
% JSON array is written in row-major order
needmmap = (nargout > 3);
if needmmap
    mmap = {};
    origpath = opt.jsonpath_;
end

next_nonws = opt.next_nonws_;
inputlen = opt.inputlen_;

% Inline parse_char for '['
pos = next_nonws(pos);
pos = pos + 1;  % skip '['
if pos <= inputlen
    pos = next_nonws(pos);
end

object = cell(0, 1);
arraydepth = opt.arraydepth_;
pbar = -1;
if isfield(opt, 'progressbar_')
    pbar = opt.progressbar_;
end
format = opt.formatversion;

if pos > inputlen
    return
end

cc = inputstr(pos);
endpos = [];

if cc ~= ']'
    try
        if opt.fastarrayparser >= 1 && arraydepth >= opt.fastarrayparser
            [endpos, maxlevel] = fast_match_bracket(opt.arraytoken_, opt.arraytokenidx_, pos);
            if ~isempty(endpos)
                arraystr = ['[' inputstr(pos:endpos)];
                arraystr = sscanf_prep(arraystr);
                if isempty(find(arraystr == '"', 1))
                    % handle 1D array first
                    if maxlevel == 1
                        astr = arraystr(2:end - 1);
                        astr(astr == ' ') = '';
                        [obj, count, errmsg, nextidx] = sscanf(astr, '%f,', [1, inf]);
                        if nextidx >= length(astr) - 1
                            object = obj;
                            pos = endpos;
                            % Inline parse_char for ']'
                            pos = next_nonws(pos);
                            pos = pos + 1;
                            if pos <= inputlen
                                pos = next_nonws(pos);
                            end
                            return
                        end
                    end

                    % for N-D packed array in a nested array construct
                    if maxlevel >= 2 && ~isempty(regexp(arraystr(2:end), '^\s*\[', 'once'))
                        [dims, isndarray] = nestbracket2dim(arraystr);
                        rowstart = find(arraystr(2:end) == '[', 1) + 1;
                        if rowstart && isndarray
                            [obj, nextidx] = parsendarray(arraystr, dims);
                            if nextidx >= length(arraystr) - 1
                                object = obj;
                                if format > 1.9
                                    object = permute(object, ndims(object):-1:1);
                                end
                                pos = endpos;
                                pos = next_nonws(pos);
                                pos = pos + 1;
                                if pos <= inputlen
                                    pos = next_nonws(pos);
                                end
                                if pbar > 0
                                    waitbar(pos / inputlen, pbar, 'loading ...');
                                end
                                return
                            end
                        end
                    end
                end
            end
        end
        if ~isempty(endpos) && isempty(regexp(arraystr, '[:\(]', 'once'))
            arraystr = strrep(strrep(arraystr, '[', '{'), ']', '}');
            if opt.parsestringarray == 0
                arraystr = strrep(arraystr, '"', '''');
            end
            object = eval(arraystr);
            if iscell(object)
                object = cellfun(@unescapejsonstring, object, 'UniformOutput', false);
            end
            pos = endpos;
        end
    catch
    end
    if isempty(endpos) || pos ~= endpos
        w2 = 0;
        while 1
            opt.arraydepth_ = arraydepth + 1;
            if needmmap
                opt.jsonpath_ = [origpath sprintf('[%d]', length(object))];
                mmap{end + 1} = {opt.jsonpath_, [pos, 0, w2]};
                [val, pos, index_esc, newmmap] = parse_value(inputstr, pos, esc, index_esc, opt);
                mmap{end}{2}(2) = pos - mmap{end}{2}(1);
                mmap = [mmap(:); newmmap(:)];
            else
                [val, pos, index_esc] = parse_value(inputstr, pos, esc, index_esc, opt);
            end
            % Skip whitespace after value
            if pos <= inputlen
                pos = next_nonws(pos);
            end
            object{end + 1} = val;
            if pos > inputlen
                break
            end
            cc = inputstr(pos);
            if cc == ']'
                break
            end
            % Inline parse_char for ','
            pos = pos + 1;
            w2 = pos;
            if pos <= inputlen
                pos = next_nonws(pos);
            end
            w2 = pos - w2;
        end
    end
end

if opt.simplifycell && iscell(object) && ~isempty(object)
    if all(cellfun('isclass', object, 'double')) || all(cellfun('isclass', object, 'struct'))
        if all(cellfun(@(e) isequal(size(object{1}), size(e)), object(2:end)))
            try
                oldobj = object;
                if iscell(object) && length(object) > 1 && ndims(object{1}) >= 2
                    catdim = size(object{1});
                    catdim = ndims(object{1}) - (catdim(end) == 1) + 1;
                    object = cat(catdim, object{:});
                    object = permute(object, ndims(object):-1:1);
                else
                    object = cell2mat(object.')';
                end
                if iscell(oldobj) && isstruct(object) && numel(object) > 1 && opt.simplifycellarray == 0
                    object = oldobj;
                end
            catch
            end
        end
    end
end

% Inline parse_char for ']'
pos = next_nonws(pos);
pos = pos + 1;
if pos <= inputlen
    pos = next_nonws(pos);
end

if pbar > 0
    waitbar(pos / inputlen, pbar, 'loading ...');
end

%% -------------------------------------------------------------------------

function [str, pos, index_esc] = parseStr(inputstr, pos, esc, index_esc, opt)
inputlen = opt.inputlen_;
pos = pos + 1;  % skip opening "

% Fast path: find closing quote
while index_esc <= length(esc) && esc(index_esc) < pos
    index_esc = index_esc + 1;
end

% Check if simple string (next special char is a quote, not backslash)
if index_esc <= length(esc) && inputstr(esc(index_esc)) == '"'
    endpos = esc(index_esc);
    str = inputstr(pos:endpos - 1);
    pos = endpos + 1;
    index_esc = index_esc + 1;
    % Handle special values
    if length(str) == 5
        if strcmp(str, '_Inf_')
            str = Inf;
        elseif strcmp(str, '_NaN_')
            str = NaN;
        end
    elseif length(str) == 6 && strcmp(str, '-_Inf_')
        str = -Inf;
    end
    return
end

% Slow path: string with escapes
str = '';
while pos <= inputlen
    while index_esc <= length(esc) && esc(index_esc) < pos
        index_esc = index_esc + 1;
    end
    if index_esc > length(esc)
        str = [str inputstr(pos:inputlen)];
        pos = inputlen + 1;
        break
    else
        str = [str inputstr(pos:esc(index_esc) - 1)];
        pos = esc(index_esc);
    end
    nstr = length(str);
    switch inputstr(pos)
        case '"'
            pos = pos + 1;
            if (~isempty(str))
                if (strcmp(str, '_Inf_'))
                    str = Inf;
                elseif (strcmp(str, '-_Inf_'))
                    str = -Inf;
                elseif (strcmp(str, '_NaN_'))
                    str = NaN;
                end
            end
            return
        case '\'
            if pos + 1 > inputlen
                pos = error_pos('End of file reached right after escape character', inputstr, pos);
            end
            pos = pos + 1;
            switch inputstr(pos)
                case {'"' '\' '/'}
                    str(nstr + 1) = inputstr(pos);
                    pos = pos + 1;
                case {'b' 'f' 'n' 'r' 't'}
                    str(nstr + 1) = sprintf(['\' inputstr(pos)]);
                    pos = pos + 1;
                case 'u'
                    if pos + 4 > inputlen
                        pos = error_pos('End of file reached in escaped unicode character', inputstr, pos);
                    end
                    str(nstr + (1:6)) = inputstr(pos - 1:pos + 4);
                    pos = pos + 5;
            end
        otherwise % should never happen
            str(nstr + 1) = inputstr(pos);
            pos = pos + 1;
    end
end
str = unescapejsonstring(str);
pos = error_pos('End of file while expecting end of inputstr', inputstr, pos);

%% -------------------------------------------------------------------------

function [num, pos] = parse_number(inputstr, pos, inputlen)
startpos = pos;
if inputstr(pos) == '-'
    pos = pos + 1;
end
while pos <= inputlen
    c = inputstr(pos);
    if c >= '0' && c <= '9'
        pos = pos + 1;
    else
        break
    end
end
if pos <= inputlen && inputstr(pos) == '.'
    pos = pos + 1;
    while pos <= inputlen
        c = inputstr(pos);
        if c >= '0' && c <= '9'
            pos = pos + 1;
        else
            break
        end
    end
end
if pos <= inputlen && (inputstr(pos) == 'e' || inputstr(pos) == 'E')
    pos = pos + 1;
    if pos <= inputlen && (inputstr(pos) == '+' || inputstr(pos) == '-')
        pos = pos + 1;
    end
    while pos <= inputlen
        c = inputstr(pos);
        if c >= '0' && c <= '9'
            pos = pos + 1;
        else
            break
        end
    end
end
num = sscanf(inputstr(startpos:pos - 1), '%f', 1);

%% -------------------------------------------------------------------------

function [val, pos, index_esc, mmap] = parse_value(inputstr, pos, esc, index_esc, opt)
needmmap = (nargout > 3);
if needmmap
    mmap = {};
end

inputlen = opt.inputlen_;

if isfield(opt, 'progressbar_')
    waitbar(pos / inputlen, opt.progressbar_, 'loading ...');
end

ch = inputstr(pos);
if ch == '"'
    [val, pos, index_esc] = parseStr(inputstr, pos, esc, index_esc, opt);
elseif ch == '['
    if needmmap
        [val, pos, index_esc, mmap] = parse_array(inputstr, pos, esc, index_esc, opt);
    else
        [val, pos, index_esc] = parse_array(inputstr, pos, esc, index_esc, opt);
    end
elseif ch == '{'
    if needmmap
        [val, pos, index_esc, mmap] = parse_object(inputstr, pos, esc, index_esc, opt);
    else
        [val, pos, index_esc] = parse_object(inputstr, pos, esc, index_esc, opt);
    end
    if pos < 0
        opt.usemap = 1;
        if needmmap
            [val, pos, index_esc, mmap] = parse_object(inputstr, -pos, esc, index_esc, opt);
        else
            [val, pos, index_esc] = parse_object(inputstr, -pos, esc, index_esc, opt);
        end
    end
elseif ch == '-' || (ch >= '0' && ch <= '9')
    [val, pos] = parse_number(inputstr, pos, inputlen);
elseif ch == 't' && pos + 3 <= inputlen && inputstr(pos + 1) == 'r' && inputstr(pos + 2) == 'u' && inputstr(pos + 3) == 'e'
    val = true;
    pos = pos + 4;
elseif ch == 'f' && pos + 4 <= inputlen && inputstr(pos + 1) == 'a' && inputstr(pos + 2) == 'l' && inputstr(pos + 3) == 's' && inputstr(pos + 4) == 'e'
    val = false;
    pos = pos + 5;
elseif ch == 'n' && pos + 3 <= inputlen && inputstr(pos + 1) == 'u' && inputstr(pos + 2) == 'l' && inputstr(pos + 3) == 'l'
    val = [];
    pos = pos + 4;
else
    error_pos('Value expected at position %d', inputstr, pos);
end

%% -------------------------------------------------------------------------

function [object, pos, index_esc, mmap] = parse_object(inputstr, pos, esc, index_esc, opt)
oldpos = pos;
oldindex_esc = index_esc;
needmmap = (nargout > 3);
if needmmap
    mmap = {};
    origpath = opt.jsonpath_;
end

next_nonws = opt.next_nonws_;
inputlen = opt.inputlen_;

% Inline parse_char for '{'
pos = next_nonws(pos);
pos = pos + 1;
if pos <= inputlen
    pos = next_nonws(pos);
end

usemap = opt.usemap;
if usemap
    object = containers.Map();
else
    object = [];
end

if pos > inputlen
    return
end

cc = inputstr(pos);
if cc ~= '}'
    while 1
        [str, pos, index_esc] = parseStr(inputstr, pos, esc, index_esc, opt);
        if ischar(str) && length(str) > 63
            pos = -oldpos;
            index_esc = oldindex_esc;
            object = [];
            return
        end
        if isempty(str) && ~usemap
            str = 'x0x0_';  % empty name is valid in JSON, decodevarname('x0x0_') restores '\0'
        end

        % Inline parse_char for ':'
        if pos <= inputlen
            pos = next_nonws(pos);
        end
        pos = pos + 1;  % skip ':'
        w2 = 0;
        if pos <= inputlen
            oldpos2 = pos;
            pos = next_nonws(pos);
            w2 = pos - oldpos2;
        end

        if needmmap
            opt.jsonpath_ = [origpath, '.', str];
            mmap{end + 1} = {opt.jsonpath_, [pos, 0, w2]};
            [val, pos, index_esc, newmmap] = parse_value(inputstr, pos, esc, index_esc, opt);
            mmap{end}{2}(2) = pos - mmap{end}{2}(1);
            mmap = [mmap(:); newmmap(:)];
        else
            [val, pos, index_esc] = parse_value(inputstr, pos, esc, index_esc, opt);
        end
        % Skip whitespace after value
        if pos <= inputlen
            pos = next_nonws(pos);
        end

        if usemap
            object(str) = val;
        else
            str = encodevarname(str, opt);
            if length(str) > 63
                pos = -oldpos;
                index_esc = oldindex_esc;
                object = [];
                return
            end
            object.(str) = val;
        end

        if pos > inputlen
            break
        end
        cc = inputstr(pos);
        if cc == '}'
            break
        end
        % Inline parse_char for ','
        pos = pos + 1;
        if pos <= inputlen
            pos = next_nonws(pos);
        end
    end
end

% Inline parse_char for '}'
pos = next_nonws(pos);
pos = pos + 1;
if pos <= inputlen
    pos = next_nonws(pos);
end

%% -------------------------------------------------------------------------

function pos = error_pos(msg, inputstr, pos)
poShow = max(min([pos - 15 pos - 1 pos pos + 20], length(inputstr)), 1);
if poShow(3) == poShow(2)
    poShow(3:4) = poShow(2) + [0 -1];  % display nothing after
end
msg = [sprintf(msg, pos) ': ' inputstr(poShow(1):poShow(2)) '<e>' inputstr(poShow(3):poShow(4))];
error('JSONLAB:JSON:InvalidFormat', msg);

%% -------------------------------------------------------------------------

function newstr = unescapejsonstring(str)
newstr = str;
if iscell(str)
    try
        newstr = cell2mat(cellfun(@(x) cell2mat(x), str(:), 'un', 0));
    catch
    end
end
if ~ischar(str) || isempty(find(str == '\', 1))
    return
end
newstr = sprintf(str);
newstr = regexprep(newstr, '\\u([0-9A-Fa-f]{4})', '${char(base2dec($1,16))}');

%% -------------------------------------------------------------------------

function arraystr = sscanf_prep(str)
arraystr = str;
if any(str == '"')
    arraystr = regexprep(arraystr, '"_NaN_"', 'NaN');
    arraystr = regexprep(arraystr, '"([-+]*)_Inf_"', '$1Inf');
end
arraystr(arraystr == char(10) | arraystr == char(13)) = ' ';

%% -------------------------------------------------------------------------

function [obj, nextidx] = parsendarray(arraystr, dims)
astr = arraystr;
astr(astr == '[' | astr == ']' | astr == ',') = ' ';
[obj, count, errmsg, nextidx] = sscanf(astr, '%f', inf);
if nextidx >= length(astr) - 1
    obj = reshape(obj, dims);
    nextidx = length(arraystr) + 1;
end
