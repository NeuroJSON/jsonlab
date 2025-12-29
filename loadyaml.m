function [data, mmap] = loadyaml(fname, varargin)
%
% data=loadyaml(fname,opt)
%    or
% [data, mmap]=loadyaml(fname,'param1',value1,'param2',value2,...)
%
% parse a YAML (YAML Ain't Markup Language) file or string and return a
% matlab data structure with optional memory-map (mmap) table
%
% authors:Qianqian Fang (q.fang <at> neu.edu)
% created on 2025/01/01
%
% input:
%      fname: input file name; if fname contains valid YAML syntax,
%             fname will be interpreted as a YAML string
%      opt: same options as loadjson (see loadjson help for details)
%           All loadjson options are supported through yaml2json conversion
%
% output:
%      dat: a cell array or struct converted from YAML
%      mmap: (optional) memory-mapping table (see loadjson documentation)
%
% examples:
%      dat=loadyaml('name: value')
%      dat=loadyaml(['examples' filesep 'example.yaml'])
%      [dat, mmap]=loadyaml('config.yaml','SimplifyCell',0)
%
% license:
%     BSD or GPL version 3, see LICENSE_{BSD,GPLv3}.txt files for details
%
% -- this function is part of JSONLab toolbox (http://neurojson.org/jsonlab)
%

opt = varargin2struct(varargin{:});
webopt = jsonopt('WebOptions', {}, opt);

% Read YAML input (file, URL, or string)
if (regexpi(fname, '^\s*(http|https|ftp|file)://'))
    yamlstring = urlread(fname, webopt{:});
elseif (exist(fname, 'file'))
    try
        encoding = jsonopt('Encoding', '', opt);
        if (isempty(encoding))
            yamlstring = fileread(fname);
        else
            fid = fopen(fname, 'r', 'n', encoding);
            yamlstring = fread(fid, '*char')';
            fclose(fid);
        end
    catch
        try
            yamlstring = urlread(fname, webopt{:});
        catch
            yamlstring = urlread(['file://', fullfile(pwd, fname)]);
        end
    end
else
    % Assume it's a YAML string
    yamlstring = fname;
end

if (jsonopt('Raw', 0, opt))
    data = yamlstring;
    if (nargout > 1)
        mmap = {};
    end
    return
end

% Convert YAML to JSON
jsonstring = yaml2json(yamlstring);

% Use loadjson to parse the converted JSON
if (nargout > 1)
    [data, mmap] = loadjson(jsonstring, varargin{:});
else
    data = loadjson(jsonstring, varargin{:});
end
