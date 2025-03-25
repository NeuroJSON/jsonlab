function [res, restapi, jsonstring] = neuroj(cmd, varargin)
%
%    [data, url, rawoutput] = neuroj(command, database, dataset, attachment, ...)
%
%    NeuroJSON.io client - browsing/listing/downloading/uploading data
%    provided at https://neurojson.io
%
%    author: Qianqian Fang (q.fang <at> neu.edu)
%
%    input:
%        command: a string, must be one of
%               'gui':
%                  - start a GUI and interactively browse datasets
%               'list':
%                  - if followed by nothing, list all databases
%                  - if database is given, list its all datasets
%                  - if dataset is given, list all its revisions
%               'info': return metadata associated with the specified
%                     database, dataset or attachment of a dataset
%               'get': must provide database and dataset name, download and
%                     parse the specified dataset or its attachment
%               'find':
%                  - if database is a string '/.../', find database by a
%                    regular expression pattern
%                  - if database is a struct, find database using
%                    NeuroJSON's search API
%                  - if dataset is a string '/.../', find datasets by a
%                    regular expression pattern
%                  - if dataset is a struct, find database using
%                    the _find API
%
%            admin commands (require database admin credentials):
%               'put': create database, create dataset under a dataset, or
%                     upload an attachment under a dataset
%               'delete': delete the specified attachment, dataset or
%                     database
%        jpath: a string in the format of JSONPath, see loadjson help
%
%    output:
%        data: parsed response data
%        url: the URL or REST-API of the desired resource
%        jsonstring: the JSON raw data from the URL
%
%    example:
%        neuroj('gui') % start neuroj client in the GUI mode
%
%        res = neuroj('list') % list all databases under res.database
%        res = neuroj('list', 'cotilab') % list all dataset under res.dataset
%        res = neuroj('list', 'cotilab', 'CSF_Neurophotonics_2025') % list all versions
%        res = neuroj('info') % list metadata of all datasets
%        res = neuroj('info', 'cotilab') % list metadata of a given database
%        res = neuroj('info', 'cotilab', 'CSF_Neurophotonics_2025') % list dataset header
%        res = neuroj('info', 'cotilab', 'CSF_Neurophotonics_2025') % list dataset header
%        [res, url, rawstr] = neuroj('get', 'cotilab', 'CSF_Neurophotonics_2025')
%        res = neuroj('get', 'cotilab', 'CSF_Neurophotonics_2025')
%        userinfo = inputdlg({'Username:', 'Password:'});
%        options = {'UserName', userinfo{1}, 'Password', userinfo{2});
%        res = neuroj('put', 'sandbox1d', 'newdoc', struct('Author', 'QF') 'weboptions', options);

%
% license:
%     BSD or GPL version 3, see LICENSE_{BSD,GPLv3}.txt files for details
%
% -- this function is part of JSONLab toolbox (http://iso2mesh.sf.net/cgi-bin/index.cgi?jsonlab)
%

if (nargin == 0)
    disp('NeuroJSON.io Client (https://neurojson.io)');
    fprintf('Format:\n\t[data, restapi] = neuroj(command, database, dataset, attachment, ...)\n\n');
    return
end

global fmMain lsDb lsDs lsJSON txValue

if (nargin == 1 && strcmp(cmd, 'gui'))
    fmMain = figure('numbertitle', 'off', 'name', 'NeuroJSON.io Dataset Browser');
    tbTool = uitoolbar(fmMain);
    btLoadDb = uipushtool(tbTool, 'tooltipstring', 'List databases', 'ClickedCallback', @loaddb);
    if (~isoctavemesh)
        btLoadDb.CData = zeros(40, 40, 3);
    end
    lsDb = uicontrol(fmMain, 'tooltipstring', 'Database', 'style', 'listbox', 'units', 'normalized', 'position', [0 0 1 / 5 1], 'Callback', @loadds, 'KeyPressFcn', @loadds);
    lsDs = uicontrol(fmMain, 'tooltipstring', 'Dataset', 'style', 'listbox', 'units', 'normalized', 'position', [1 / 5 0 1 / 4 1], 'Callback', @loaddsdata, 'KeyPressFcn', @loaddsdata);
    lsJSON = uicontrol(fmMain, 'tooltipstring', 'Data', 'style', 'listbox', 'units', 'normalized', 'position', [9 / 20 1 / 4 1 - 9 / 20 3 / 4], 'Callback', @expandjsontree, 'KeyPressFcn', @expandjsontree);
    txValue = uicontrol(fmMain, 'tooltipstring', 'Value', 'style', 'edit', 'max', 50, 'HorizontalAlignment', 'left', 'units', 'normalized', 'position', [9 / 20 0 1 - 9 / 20 1 / 4]);
    return
end

dbname = '';
if (~isempty(varargin))
    dbname = varargin{1};
end

dsname = '';
if (length(varargin) > 1)
    dsname = varargin{2};
end

attachment = '';
if (length(varargin) > 2)
    attachment = varargin{3};
end

opt = struct;
if (length(varargin) > 3)
    opt = varargin2struct(varargin{4:end});
end

serverurl = getenv('NEUROJSON_IO');

if (isempty(serverurl))
    serverurl = 'https://neurojson.io:7777/';
end

serverurl = jsonopt('server', serverurl, opt);
options = jsonopt('weboptions', {}, opt);
opt.weboptions = options;
rev = jsonopt('rev', '', opt);

cmd = lower(cmd);

restapi = serverurl;

if (strcmp(cmd, 'list'))
    restapi = [serverurl, 'sys/registry'];
    if (~isempty(dbname))
        restapi = [serverurl, dbname, '/', '_all_docs'];
        if (~isempty(dsname))
            restapi = [serverurl, dbname, '/', dsname, '?revs_info=true'];
        end
    end
    jsonstring = loadjson(restapi, opt, 'raw', 1);
    res = loadjson(jsonstring, opt);
    if (~isempty(dsname))
        res = res.(encodevarname('_revs_info'));
    elseif (~isempty(dbname))
        res.dataset = res.rows;
        res = rmfield(res, 'rows');
    end
elseif (strcmp(cmd, 'info'))
    restapi = [serverurl, '_dbs_info'];
    if (~isempty(dbname))
        restapi = [serverurl, dbname, '/'];
        if (~isempty(dsname))
            restapi = [serverurl, dbname, '/', dsname];
            if (~isempty(attachment))
                restapi = [serverurl, dbname, '/', dsname, '/', attachment];
            end
        end
    end
    if (~isempty(dsname) || ~isempty(attachment))
        res = loadjson(restapi, opt, 'header', 1);
        jsonstring = savejson('', res);
    else
        jsonstring = loadjson(restapi, opt, 'raw', 1);
        res = loadjson(jsonstring);
    end
elseif (strcmp(cmd, 'get'))
    if (isempty(dsname))
        error('get requires a dataset, i.e. document, name');
    end
    if (isempty(attachment))
        restapi = [serverurl, dbname, '/', dsname];
        if (~isempty(rev))
            restapi = [serverurl, dbname, '/', dsname, '?rev=' rev];
        end
        jsonstring = loadjson(restapi, opt, 'raw', 1);
        res = loadjson(jsonstring, opt);
    else
        restapi = [serverurl, dbname, '/', dsname, '/', attachment];
        [res, jsonstring] = jdlink(restapi);
    end
elseif (strcmp(cmd, 'put'))
    if (isempty(dbname))
        error('put requires at least a database name');
    end
    restapi = [serverurl, dbname];
    putoption = weboptions(opt.weboptions{:});
    putoption.RequestMethod = 'post';
    putoption.MediaType = 'application/json';
    if (~isempty(dsname))
        if (isempty(attachment))
            error('must provide JSON input to upload');
        end
        if (ischar(attachment) && exist(attachment, 'file'))
            [afpath, afname, afext] = fileparts(attachment);
            attname = jsonopt('filename', [afname, afext], opt);
            restapi = [serverurl, dbname, '/' dsname '/' attname];
            res = websave(attname, restapi, weboptions('RequestMethod', 'put'));
        else
            restapi = [serverurl, dbname, '/_design/qq/_update/timestamp/' dsname];
            jsonstring = savejson('', attachment, 'compact', 1);
            res = webwrite(restapi, jsonstring, putoption);
        end
    else
        putoption.RequestMethod = 'put';
        res = webwrite(restapi, [], putoption);
    end
elseif (strcmp(cmd, 'delete'))
    if (isempty(dbname))
        error('put requires at least a database name');
    end
    deloption = weboptions(opt.weboptions{:});
    deloption.RequestMethod = 'delete';
    restapi = [serverurl, dbname];
    if (~isempty(dsname))
        restapi = [serverurl, dbname, '/', dsname];
        if (~isempty(attachment))
            restapi = [serverurl, dbname, '/', dsname, '/', attachment];
        end
    end
    res = webwrite(restapi, [], deloption);
elseif (strcmp(cmd, 'find'))
    if (isempty(dbname))
        error('find requires at least a search regular expression pattern');
    end
    if (~isempty(dbname))
        if (ischar(dsname) && dbname(1) == '/' && dbname(end) == '/')
            [dblist, restapi, jsonstring] = neuroj('list');
            res = {};
            for i = 1:length(dblist.database)
                if (~isempty(regexpi(savejson('', dblist.database{i}, 'compact', 1), dbname(2:end - 1), 'once')))
                    res{end + 1} = dblist.database{i};
                end
            end
        elseif (isstruct(dbname))
            param = join(cellfun(@(x) [x '=' dbname.(x)], fieldnames(dbname), 'UniformOutput', false));
            restapi = ['https://neurojson.org/io/search.cgi?' param{:}];
            jsonstring = loadjson(restapi, opt, 'raw', 1);
            res = loadjson(jsonstrong, opt);
        elseif (~isempty(dsname) && ischar(dsname) && dsname(1) == '/' && dsname(end) == '/')
            [dslist, restapi, jsonstring] = neuroj('list', dbname);
            res = {};
            for i = 1:length(dslist.dataset)
                if (~isempty(regexpi(dslist.dataset(i).id, dsname(2:end - 1), 'once')))
                    res{end + 1} = dslist.dataset(i).id;
                end
            end
        elseif (~isempty(dsname) && (isstruct(dsname) || (ischar(dsname) && dsname(1) == '{' && dsname(end) == '}')))
            findoption = weboptions(opt.weboptions{:});
            findoption.RequestMethod = 'post';
            findoption.MediaType = 'application/json';
            restapi = [serverurl, dbname, '/_find'];
            if (isstruct(dsname))
                if (~isfield(dsname, 'selector'))
                    dsname.selector = {};
                end
                res = webwrite(restapi, savejson('', dsname, 'compact', 1), findoption);
            else
                res = webwrite(restapi, dsname, findoption);
            end
        end
    end
end

function loaddb(src, event)
global lsDb
dbs = neuroj('list');
set(lsDb, 'String', (cellfun(@(x) x.id, dbs.database, 'UniformOutput', false)));

function loadds(src, event)
global fmMain lsDb lsDs
get(fmMain, 'SelectionType');
if isfield(event, 'Key') && strcmp(event.Key, 'enter') || strcmp(get(fmMain, 'SelectionType'), 'open')
    idx = get(src, 'value');
    dbs = get(src, 'string');
    dslist = neuroj('list', dbs{idx});
    dslist.dataset = dslist.dataset(arrayfun(@(x) x.id(1) ~= '_', dslist.dataset));
    set(lsDs, 'string', {dslist.dataset.id}, 'value', 1);
    set(lsDb, 'tag', dbs{idx});
end

function loaddsdata(src, event)
global fmMain lsDb lsJSON
get(fmMain, 'SelectionType');
if isfield(event, 'Key') && strcmp(event.Key, 'enter') || strcmp(get(fmMain, 'SelectionType'), 'open')
    idx = get(src, 'value');
    dbs = get(src, 'string');
    dbid = get(lsDb, 'tag');
    datasets = jdict(neuroj('get', dbid, dbs{idx}));
    set(lsJSON, 'string', cellfun(@(x) decodevarname(x), datasets.keys(), 'UniformOutput', false), 'value', 1);
    set(lsJSON, 'userdata', datasets);
    set(lsJSON, 'tag', '');
end

function expandjsontree(src, event)
global fmMain lsJSON txValue
if (~isa(get(lsJSON, 'userdata'), 'jdict'))
    return
end
get(fmMain, 'SelectionType');
if isfield(event, 'Key') && strcmp(event.Key, 'enter') || strcmp(get(fmMain, 'SelectionType'), 'open')
    idx = get(src, 'value');
    dbs = get(src, 'string');
    rootpath = get(lsJSON, 'tag');
    datasets = get(lsJSON, 'userdata');
    if (isempty(rootpath))
        rootpath = '$';
    end
    if (strcmp(dbs{idx}, '..'))
        rootpath = regexprep(rootpath, '\[[^\]]+\]$', '');
    else
        rootpath = [rootpath '["' dbs{idx} '"]'];
    end

    datasets = datasets.(rootpath);
    try
        if (iscell(datasets.keys()))
            subitem = cellfun(@(x) decodevarname(x), datasets.keys(), 'UniformOutput', false);
            if (~strcmp(rootpath, '$'))
                subitem = {'..', subitem{:}};
            end
            set(lsJSON, 'string', subitem, 'value', 1);
            set(lsJSON, 'tag', rootpath);
        else
            set(txValue, 'string', datasets.v());
        end
    catch
    end
end
