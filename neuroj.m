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
%               'export': export a dataset to a local folder structure
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
%        [res, url, rawstr] = neuroj('get', 'cotilab', 'CSF_Neurophotonics_2025')
%        res = neuroj('export', 'cotilab', 'CSF_Neurophotonics_2025')
%        userinfo = inputdlg({'Username:', 'Password:'});
%        options = {'UserName', userinfo{1}, 'Password', userinfo{2});
%        res = neuroj('put', 'sandbox1d', 'newdoc', struct('Author', 'QF') 'weboptions', options);
%
% license:
%     BSD or GPL version 3, see LICENSE_{BSD,GPLv3}.txt files for details
%
% -- this function is part of JSONLab toolbox (http://neurojson.org/jsonlab)
%

if (nargin == 0)
    disp('NeuroJSON.io Client (https://neurojson.io)');
    fprintf('Format:\n\t[data, restapi] = neuroj(command, database, dataset, attachment, ...)\n\n');
    return
end

if (nargin == 1 && strcmp(cmd, 'gui'))
    handles.fmMain = figure('numbertitle', 'off', 'name', 'NeuroJSON.io Dataset Browser');
    tbTool = uitoolbar(handles.fmMain);

    % Create search panel (initially hidden) - takes top 50% when visible
    handles.pnSearch = uipanel(handles.fmMain, 'units', 'normalized', 'position', [0 0.5 1 0.5], 'visible', 'off', 'title', 'Dataset Search');

    % Column 1: Basic search
    col1 = 0.01;
    col1w = 0.08;
    col1e = 0.10;
    col1ew = 0.14;
    uicontrol(handles.pnSearch, 'style', 'text', 'string', 'Keyword:', 'units', 'normalized', 'position', [col1 0.88 col1w 0.08], 'HorizontalAlignment', 'right');
    handles.hKeyword = uicontrol(handles.pnSearch, 'style', 'edit', 'units', 'normalized', 'position', [col1e 0.88 col1ew 0.08]);
    uicontrol(handles.pnSearch, 'style', 'text', 'string', 'Database:', 'units', 'normalized', 'position', [col1 0.78 col1w 0.08], 'HorizontalAlignment', 'right');
    handles.hDatabase = uicontrol(handles.pnSearch, 'style', 'popupmenu', 'string', {'any', 'openneuro', 'abide', 'abide2', 'datalad-registry', 'adhd200'}, 'units', 'normalized', 'position', [col1e 0.78 col1ew 0.08]);
    uicontrol(handles.pnSearch, 'style', 'text', 'string', 'Dataset:', 'units', 'normalized', 'position', [col1 0.68 col1w 0.08], 'HorizontalAlignment', 'right');
    handles.hDataset = uicontrol(handles.pnSearch, 'style', 'edit', 'units', 'normalized', 'position', [col1e 0.68 col1ew 0.08]);
    uicontrol(handles.pnSearch, 'style', 'text', 'string', 'Subject:', 'units', 'normalized', 'position', [col1 0.58 col1w 0.08], 'HorizontalAlignment', 'right');
    handles.hSubject = uicontrol(handles.pnSearch, 'style', 'edit', 'units', 'normalized', 'position', [col1e 0.58 col1ew 0.08]);
    uicontrol(handles.pnSearch, 'style', 'text', 'string', 'Gender:', 'units', 'normalized', 'position', [col1 0.48 col1w 0.08], 'HorizontalAlignment', 'right');
    handles.hGender = uicontrol(handles.pnSearch, 'style', 'popupmenu', 'string', {'any', 'male', 'female', 'unknown'}, 'units', 'normalized', 'position', [col1e 0.48 col1ew 0.08]);
    uicontrol(handles.pnSearch, 'style', 'text', 'string', 'Modality:', 'units', 'normalized', 'position', [col1 0.38 col1w 0.08], 'HorizontalAlignment', 'right');
    handles.hModality = uicontrol(handles.pnSearch, 'style', 'popupmenu', 'string', {'any', 'anat', 'func', 'dwi', 'fmap', 'perf', 'meg', 'eeg', 'ieeg', 'beh', 'pet', 'micr', 'nirs', 'motion'}, 'units', 'normalized', 'position', [col1e 0.38 col1ew 0.08]);
    uicontrol(handles.pnSearch, 'style', 'text', 'string', 'Data type:', 'units', 'normalized', 'position', [col1 0.28 col1w 0.08], 'HorizontalAlignment', 'right');
    handles.hTypeName = uicontrol(handles.pnSearch, 'style', 'edit', 'units', 'normalized', 'position', [col1e 0.28 col1ew 0.08]);

    % Column 2: Age and counts
    col2 = 0.26;
    col2w = 0.08;
    col2e = 0.35;
    col2ew = 0.06;
    uicontrol(handles.pnSearch, 'style', 'text', 'string', 'Age min:', 'units', 'normalized', 'position', [col2 0.88 col2w 0.08], 'HorizontalAlignment', 'right');
    handles.hAgeMin = uicontrol(handles.pnSearch, 'style', 'edit', 'units', 'normalized', 'position', [col2e 0.88 col2ew 0.08]);
    uicontrol(handles.pnSearch, 'style', 'text', 'string', 'Age max:', 'units', 'normalized', 'position', [col2 0.78 col2w 0.08], 'HorizontalAlignment', 'right');
    handles.hAgeMax = uicontrol(handles.pnSearch, 'style', 'edit', 'units', 'normalized', 'position', [col2e 0.78 col2ew 0.08]);
    uicontrol(handles.pnSearch, 'style', 'text', 'string', 'Sess min:', 'units', 'normalized', 'position', [col2 0.68 col2w 0.08], 'HorizontalAlignment', 'right');
    handles.hSessMin = uicontrol(handles.pnSearch, 'style', 'edit', 'units', 'normalized', 'position', [col2e 0.68 col2ew 0.08]);
    uicontrol(handles.pnSearch, 'style', 'text', 'string', 'Sess max:', 'units', 'normalized', 'position', [col2 0.58 col2w 0.08], 'HorizontalAlignment', 'right');
    handles.hSessMax = uicontrol(handles.pnSearch, 'style', 'edit', 'units', 'normalized', 'position', [col2e 0.58 col2ew 0.08]);
    uicontrol(handles.pnSearch, 'style', 'text', 'string', 'Task min:', 'units', 'normalized', 'position', [col2 0.48 col2w 0.08], 'HorizontalAlignment', 'right');
    handles.hTaskMin = uicontrol(handles.pnSearch, 'style', 'edit', 'units', 'normalized', 'position', [col2e 0.48 col2ew 0.08]);
    uicontrol(handles.pnSearch, 'style', 'text', 'string', 'Task max:', 'units', 'normalized', 'position', [col2 0.38 col2w 0.08], 'HorizontalAlignment', 'right');
    handles.hTaskMax = uicontrol(handles.pnSearch, 'style', 'edit', 'units', 'normalized', 'position', [col2e 0.38 col2ew 0.08]);
    uicontrol(handles.pnSearch, 'style', 'text', 'string', 'Run min:', 'units', 'normalized', 'position', [col2 0.28 col2w 0.08], 'HorizontalAlignment', 'right');
    handles.hRunMin = uicontrol(handles.pnSearch, 'style', 'edit', 'units', 'normalized', 'position', [col2e 0.28 col2ew 0.08]);
    uicontrol(handles.pnSearch, 'style', 'text', 'string', 'Run max:', 'units', 'normalized', 'position', [col2 0.18 col2w 0.08], 'HorizontalAlignment', 'right');
    handles.hRunMax = uicontrol(handles.pnSearch, 'style', 'edit', 'units', 'normalized', 'position', [col2e 0.18 col2ew 0.08]);

    % Column 3: Name filters
    col3 = 0.43;
    col3w = 0.10;
    col3e = 0.54;
    col3ew = 0.12;
    uicontrol(handles.pnSearch, 'style', 'text', 'string', 'Task name:', 'units', 'normalized', 'position', [col3 0.88 col3w 0.08], 'HorizontalAlignment', 'right');
    handles.hTaskName = uicontrol(handles.pnSearch, 'style', 'edit', 'units', 'normalized', 'position', [col3e 0.88 col3ew 0.08]);
    uicontrol(handles.pnSearch, 'style', 'text', 'string', 'Session:', 'units', 'normalized', 'position', [col3 0.78 col3w 0.08], 'HorizontalAlignment', 'right');
    handles.hSessionName = uicontrol(handles.pnSearch, 'style', 'edit', 'units', 'normalized', 'position', [col3e 0.78 col3ew 0.08]);
    uicontrol(handles.pnSearch, 'style', 'text', 'string', 'Run name:', 'units', 'normalized', 'position', [col3 0.68 col3w 0.08], 'HorizontalAlignment', 'right');
    handles.hRunName = uicontrol(handles.pnSearch, 'style', 'edit', 'units', 'normalized', 'position', [col3e 0.68 col3ew 0.08]);

    % Column 4: Options
    col4 = 0.68;
    col4w = 0.08;
    col4e = 0.77;
    col4ew = 0.08;
    uicontrol(handles.pnSearch, 'style', 'text', 'string', 'Limit:', 'units', 'normalized', 'position', [col4 0.88 col4w 0.08], 'HorizontalAlignment', 'right');
    handles.hLimit = uicontrol(handles.pnSearch, 'style', 'edit', 'string', '25', 'units', 'normalized', 'position', [col4e 0.88 col4ew 0.08]);
    uicontrol(handles.pnSearch, 'style', 'text', 'string', 'Skip:', 'units', 'normalized', 'position', [col4 0.78 col4w 0.08], 'HorizontalAlignment', 'right');
    handles.hSkip = uicontrol(handles.pnSearch, 'style', 'edit', 'string', '0', 'units', 'normalized', 'position', [col4e 0.78 col4ew 0.08]);
    handles.hCount = uicontrol(handles.pnSearch, 'style', 'checkbox', 'string', 'Count only', 'units', 'normalized', 'position', [col4 0.68 0.12 0.08]);
    handles.hUnique = uicontrol(handles.pnSearch, 'style', 'checkbox', 'string', 'Unique only', 'units', 'normalized', 'position', [col4 0.58 0.12 0.08]);

    % Buttons
    uicontrol(handles.pnSearch, 'style', 'pushbutton', 'string', 'Search', 'units', 'normalized', 'position', [0.88 0.78 0.10 0.12], 'Callback', @(s, e) dosearch(handles.fmMain));
    uicontrol(handles.pnSearch, 'style', 'pushbutton', 'string', 'Clear', 'units', 'normalized', 'position', [0.88 0.63 0.10 0.12], 'Callback', @(s, e) clearsearch(handles.fmMain));
    uicontrol(handles.pnSearch, 'style', 'pushbutton', 'string', 'Close', 'units', 'normalized', 'position', [0.88 0.48 0.10 0.12], 'Callback', @(s, e) togglesearch(handles.fmMain));

    % Main panels - start with full window (search panel hidden)
    handles.lsDb = uicontrol(handles.fmMain, 'tooltipstring', 'Database', 'style', 'listbox', 'units', 'normalized', 'position', [0 0 1 / 5 1]);
    handles.lsDs = uicontrol(handles.fmMain, 'tooltipstring', 'Dataset', 'style', 'listbox', 'units', 'normalized', 'position', [1 / 5 0 1 / 4 1]);
    handles.lsJSON = uicontrol(handles.fmMain, 'tooltipstring', 'Data', 'style', 'listbox', 'units', 'normalized', 'position', [9 / 20 0.25 1 - 9 / 20 0.75]);
    handles.txValue = uicontrol(handles.fmMain, 'tooltipstring', 'Value', 'style', 'edit', 'max', 50, 'HorizontalAlignment', 'left', 'units', 'normalized', 'position', [9 / 20 0 1 - 9 / 20 0.25]);
    handles.t0 = cputime;
    handles.hbox = msgbox('Loading data', 'modal');
    set(handles.hbox, 'visible', 'off');
    set(handles.fmMain, 'userdata', handles);
    set(handles.lsDb, 'Callback', @(src, events) loadds(src, events, handles.fmMain));
    set(handles.lsDs, 'Callback', @(src, events) loaddsdata(src, events, handles.fmMain));
    set(handles.lsJSON, 'Callback', @(src, events) expandjsontree(src, events, handles.fmMain));

    btLoadDb = uipushtool(tbTool, 'tooltipstring', 'List databases', 'ClickedCallback', @(src, events) loaddb(src, events, handles.fmMain));
    if (~isoctavemesh)
        btLoadDb.CData = create_refresh_icon();
    else
        set(btLoadDb, 'CData', create_refresh_icon());
    end

    btSearch = uipushtool(tbTool, 'tooltipstring', 'Search datasets', 'ClickedCallback', @(src, events) togglesearch(handles.fmMain));
    if (~isoctavemesh)
        btSearch.CData = create_search_icon();
    else
        set(btSearch, 'CData', create_search_icon());
    end

    btExport = uipushtool(tbTool, 'tooltipstring', 'Export dataset', 'ClickedCallback', @(src, events) exportdataset(handles.fmMain));
    if (~isoctavemesh)
        btExport.CData = create_export_icon();
    else
        set(btExport, 'CData', create_export_icon());
    end
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
    else
        restapi = [serverurl, dbname, '/', dsname, '/', attachment];
    end
    [res, jsonstring] = jdlink(restapi);
elseif (strcmp(cmd, 'export'))
    if (isempty(dsname))
        error('export requires a dataset name');
    end

    % Ask user to choose export folder
    exportroot = uigetdir(pwd, 'Select folder to export dataset');
    if (exportroot == 0)
        res = [];
        restapi = '';
        jsonstring = '';
        return
    end

    % Load the dataset
    restapi = [serverurl, dbname, '/', dsname];
    if (~isempty(rev))
        restapi = [serverurl, dbname, '/', dsname, '?rev=' rev];
    end
    [data, jsonfile] = jdlink(restapi);
    if (iscell(jsonfile))
        jsonfile = jsonfile{1};
    end

    % Check if BIDS dataset by looking for BIDSVersion in dataset_description.json
    isBIDS = false;
    if (isstruct(data))
        % Try different possible key formats
        ddkeys = {'dataset_description.json', 'dataset_description_x2E_json', ...
                  encodevarname('dataset_description.json')};
        for i = 1:length(ddkeys)
            if (isfield(data, ddkeys{i}))
                ddcontent = data.(ddkeys{i});
                if (isstruct(ddcontent) && isfield(ddcontent, 'BIDSVersion'))
                    isBIDS = true;
                    break
                end
            end
        end
    end

    if (isBIDS)
        % Create dataset subfolder and perform folder reconstruction
        datasetfolder = fullfile(exportroot, dsname);
        if (~exist(datasetfolder, 'dir'))
            mkdir(datasetfolder);
        end
        exportdata(data, datasetfolder, dsname, data, jsonfile, datasetfolder);
        res = struct('exportpath', datasetfolder, 'status', 'success', 'type', 'BIDS');
    else
        % Not a BIDS dataset - just copy the cached JSON file
        [~, ~, fext] = fileparts(jsonfile);
        if (isempty(fext))
            fext = '.json';
        end
        destfile = fullfile(exportroot, [dsname, fext]);
        copyfile(jsonfile, destfile);
        res = struct('exportpath', destfile, 'status', 'success', 'type', 'JSON');
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
            res = loadjson(jsonstring, opt);
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

% --------------------------------------------------------------------------
function exportdata(data, currentfolder, parentkey, rootdata, cachefile, exportroot)
% Export data structure to folder hierarchy

if (nargin < 6)
    exportroot = currentfolder;
end
if (~isstruct(data))
    return
end

keys = fieldnames(data);
datainfo = struct();

for i = 1:length(keys)
    key = keys{i};
    val = data.(key);
    decodedkey = decodevarname(key);

    % First check if value is a _DataLink_ struct (regardless of key name)
    isDataLink = isstruct(val) && ...
        (isfield(val, '_DataLink_') || isfield(val, encodevarname('_DataLink_')));

    if (isDataLink)
        % Get the link URL
        if isfield(val, '_DataLink_')
            linkurl = val.('_DataLink_');
        else
            linkurl = val.(encodevarname('_DataLink_'));
        end

        % Determine destination path
        if (~isempty(regexp(decodedkey, '\.[^\.\/\\]+$', 'once')) && ~strcmp(decodedkey(1), '.'))
            % Key looks like a filename
            linkpath = fullfile(currentfolder, decodedkey);
        else
            % Key doesn't have extension
            linkpath = fullfile(currentfolder, decodedkey);
        end

        if (~isempty(linkurl))
            if (linkurl(1) == '$')
                resolveinternal(rootdata, linkurl, linkpath, exportroot);
            else
                [~, cachedfile] = jdlink(linkurl);
                if (iscell(cachedfile))
                    cachedfile = cachedfile{1};
                end
                if (~isempty(cachedfile))
                    createlink(cachedfile, linkpath);
                end
            end
        end

        % Check if it's a file (contains . with suffix, not starting with .)
    elseif (~isempty(regexp(decodedkey, '\.[^\.\/\\]+$', 'once')) && ~strcmp(decodedkey(1), '.'))
        filepath = fullfile(currentfolder, decodedkey);

        % .snirf file with SNIRFData
        if (myendswith(lower(decodedkey), '.snirf') && isstruct(val) && ...
            (isfield(val, 'SNIRFData') || isfield(val, encodevarname('SNIRFData'))))
            try
                if isfield(val, 'SNIRFData')
                    snirfdata = val.SNIRFData;
                else
                    snirfdata = val.(encodevarname('SNIRFData'));
                end
                savesnirf(snirfdata, filepath);
            catch
                savejson('', val, 'filename', filepath);
            end
            % .tsv file - convert JSON to TSV
        elseif (myendswith(lower(decodedkey), '.tsv') && isstruct(val))
            savestruct2tsv(val, filepath);
        elseif (ischar(val) || isstring(val))
            fid = fopen(filepath, 'w');
            if (fid > 0)
                fwrite(fid, val);
                fclose(fid);
            end
        elseif (isnumeric(val) || islogical(val))
            fid = fopen(filepath, 'wb');
            if (fid > 0)
                fwrite(fid, val);
                fclose(fid);
            end
        elseif (isstruct(val))
            % Struct without _DataLink_ - save as JSON
            savejson('', val, 'filename', filepath);
        else
            savejson('', val, 'filename', filepath);
        end

        % Metadata fields for .datainfo.json
    elseif (strcmp(decodedkey, '_id') || strcmp(decodedkey, '_rev') || ...
            ~isempty(regexp(decodedkey, '^Mesh', 'once')) || ...
            ~isempty(regexp(decodedkey, '^_Array.*_$', 'once')))
        datainfo.(key) = val;

        % Subfolder (struct without file extension in key name)
    elseif (isstruct(val))
        subfolder = fullfile(currentfolder, decodedkey);
        if (~exist(subfolder, 'dir'))
            mkdir(subfolder);
        end
        exportdata(val, subfolder, decodedkey, rootdata, cachefile, exportroot);
    end
end

if (~isempty(fieldnames(datainfo)))
    savejson('', datainfo, 'filename', fullfile(currentfolder, '.datainfo.json'));
end

% --------------------------------------------------------------------------
function resolveinternal(rootdata, jpathstr, destpath, exportroot)
% Resolve internal JSONPath reference - create relative symlink

try
    % Convert JSONPath to relative file path for symlink
    % Example: $.sub-6022.ses-1.nirs.sub-6022_ses-1_task-MA_run-01_channels\.tsv
    % becomes: sub-6022/ses-1/nirs/sub-6022_ses-1_task-MA_run-01_channels.tsv

    if (length(jpathstr) > 2 && strcmp(jpathstr(1:2), '$.') && ~isempty(exportroot))
        % Remove $. prefix
        pathpart = jpathstr(3:end);

        % Use same placeholder as jsonpath.m: replace \. with _0x2E_
        pathpart = strrep(pathpart, '\.', '_0x2E_');

        % Split by dots (path separators)
        parts = strsplit(pathpart, '.');

        % Restore dots in each part
        parts = cellfun(@(x) strrep(x, '_0x2E_', '.'), parts, 'UniformOutput', false);

        % Build relative path
        if (~isempty(parts))
            relpath = fullfile(parts{:});
            targetpath = fullfile(exportroot, relpath);

            % Calculate relative path from destpath's directory to target
            destdir = fileparts(destpath);

            % Ensure parent directory exists
            if (~isempty(destdir) && ~exist(destdir, 'dir'))
                mkdir(destdir);
            end

            % Calculate relative symlink target
            reltarget = relativepath(targetpath, destdir);

            % Create symlink
            createlink(reltarget, destpath);
            return
        end
    end

    % Fallback: resolve and save actual data using jdict/jsonpath
    jd = jdict(rootdata);
    resolved = jd.(jpathstr);
    if (isa(resolved, 'jdict'))
        resolved = resolved.v();
    end

    if (isempty(resolved))
        warning('Could not resolve jsonpath: %s', jpathstr);
        return
    end

    [~, ~, ext] = fileparts(destpath);

    % Ensure parent directory exists
    destdir = fileparts(destpath);
    if (~isempty(destdir) && ~exist(destdir, 'dir'))
        mkdir(destdir);
    end

    if (strcmpi(ext, '.tsv') && isstruct(resolved))
        savestruct2tsv(resolved, destpath);
    elseif (ischar(resolved) || isstring(resolved))
        fid = fopen(destpath, 'w');
        if (fid > 0)
            fwrite(fid, resolved);
            fclose(fid);
        end
    elseif (isstruct(resolved))
        savejson('', resolved, 'filename', destpath);
    else
        fid = fopen(destpath, 'wb');
        if (fid > 0)
            fwrite(fid, resolved);
            fclose(fid);
        end
    end
catch ME
    warning('Could not resolve internal link: %s - %s', jpathstr, ME.message);
end

% --------------------------------------------------------------------------
function relpath = relativepath(targetpath, basepath)
% Calculate relative path from basepath to targetpath

if (isempty(basepath))
    relpath = targetpath;
    return
end

% Normalize paths - get absolute paths
targetpath = getfullpath(targetpath);
basepath = getfullpath(basepath);

% Split into parts
if (ispc)
    sep = '\';
    targparts = strsplit(targetpath, {'\', '/'});
    baseparts = strsplit(basepath, {'\', '/'});
else
    sep = '/';
    targparts = strsplit(targetpath, '/');
    baseparts = strsplit(basepath, '/');
end

% Remove empty parts
targparts = targparts(~cellfun('isempty', targparts));
baseparts = baseparts(~cellfun('isempty', baseparts));

% Find common prefix length
commonlen = 0;
minlen = min(length(targparts), length(baseparts));
for j = 1:minlen
    if (strcmpi(targparts{j}, baseparts{j}))
        commonlen = j;
    else
        break
    end
end

% Build relative path
numdirs = length(baseparts) - commonlen;
numtargparts = length(targparts) - commonlen;
relparts = cell(1, numdirs + numtargparts);

for j = 1:numdirs
    relparts{j} = '..';
end

for j = 1:numtargparts
    relparts{numdirs + j} = targparts{commonlen + j};
end

if (isempty(relparts))
    relpath = '.';
else
    relpath = strjoin(relparts, sep);
end

% --------------------------------------------------------------------------
function fullpath = getfullpath(filepath)
% Get full absolute path

if (isempty(filepath))
    fullpath = pwd;
    return
end

% Check if already absolute
if (ispc)
    isabs = (length(filepath) >= 2 && filepath(2) == ':') || ...
            (length(filepath) >= 1 && (filepath(1) == '\' || filepath(1) == '/'));
else
    isabs = (length(filepath) >= 1 && filepath(1) == '/');
end

if (isabs)
    fullpath = filepath;
else
    fullpath = fullfile(pwd, filepath);
end

% --------------------------------------------------------------------------
function savestruct2tsv(data, filepath)
% Convert a struct with column arrays to TSV format

if (~isstruct(data))
    return
end
keys = fieldnames(data);
if (isempty(keys))
    return
end

% Get the length of the first column to determine number of rows
firstcol = data.(keys{1});
if (iscell(firstcol))
    nrows = length(firstcol);
elseif (isnumeric(firstcol) || islogical(firstcol))
    nrows = length(firstcol);
else
    nrows = 1;
end

fid = fopen(filepath, 'w');
if (fid < 0)
    return
end

% Write header
header = cellfun(@decodevarname, keys, 'UniformOutput', false);
fprintf(fid, '%s\n', strjoin(header, char(9)));

% Write data rows
for r = 1:nrows
    row = cell(1, length(keys));
    for c = 1:length(keys)
        coldata = data.(keys{c});
        if (iscell(coldata) && r <= length(coldata))
            val = coldata{r};
        elseif ((isnumeric(coldata) || islogical(coldata)) && r <= length(coldata))
            val = coldata(r);
        else
            val = coldata;
        end
        if (isnumeric(val))
            row{c} = num2str(val);
        elseif (islogical(val))
            row{c} = num2str(double(val));
        else
            row{c} = char(val);
        end
    end
    fprintf(fid, '%s\n', strjoin(row, char(9)));
end
fclose(fid);

% --------------------------------------------------------------------------
function createlink(target, linkname)
% Create a symbolic link (platform-dependent)

if (ispc)
    [status, ~] = system(['mklink "' linkname '" "' target '"']);
    if (status ~= 0)
        [status, ~] = system(['mklink /D "' linkname '" "' target '"']);
        %         if (status ~= 0)
        %             copyfile(target, linkname);
        %         end
    end
else
    [status, ~] = system(['ln -s "' target '" "' linkname '"']);
    %     if (status ~= 0)
    %         copyfile(target, linkname);
    %     end
end

% --------------------------------------------------------------------------
function tf = myendswith(str, suffix)
% Check if string ends with suffix (for older MATLAB compatibility)

if (length(str) >= length(suffix))
    tf = strcmp(str(end - length(suffix) + 1:end), suffix);
else
    tf = false;
end

% --------------------------------------------------------------------------
function icon_cdata = create_refresh_icon()

icon_cdata = ones(16, 16, 3) * 0.94;
blue = reshape([0.2 0.5 0.9], 1, 1, 3);
icon_cdata(4:5, 8:13, :) = repmat(blue, 2, 6, 1);
icon_cdata(6:7, 12:13, :) = repmat(blue, 2, 2, 1);
icon_cdata(8:9, 12:13, :) = repmat(blue, 2, 2, 1);
icon_cdata(10:11, 11:12, :) = repmat(blue, 2, 2, 1);
icon_cdata(12:13, 8:10, :) = repmat(blue, 2, 3, 1);
icon_cdata(12:13, 6:7, :) = repmat(blue, 2, 2, 1);
icon_cdata(10:11, 4:5, :) = repmat(blue, 2, 2, 1);
icon_cdata(8:9, 3:4, :) = repmat(blue, 2, 2, 1);
icon_cdata(3:4, 13:14, :) = repmat(blue, 2, 2, 1);
icon_cdata(5:6, 12:13, :) = repmat(blue, 2, 2, 1);
icon_cdata(5:6, 14:15, :) = repmat(blue, 2, 2, 1);

% --------------------------------------------------------------------------
function icon_cdata = create_search_icon()

icon_cdata = ones(16, 16, 3) * 0.94;
green = reshape([0.1 0.7 0.2], 1, 1, 3);
icon_cdata(4:5, 5:10, :) = repmat(green, 2, 6, 1);
icon_cdata(6:7, 4:5, :) = repmat(green, 2, 2, 1);
icon_cdata(6:7, 10:11, :) = repmat(green, 2, 2, 1);
icon_cdata(8:9, 4:5, :) = repmat(green, 2, 2, 1);
icon_cdata(8:9, 10:11, :) = repmat(green, 2, 2, 1);
icon_cdata(10:11, 5:10, :) = repmat(green, 2, 6, 1);
icon_cdata(11:13, 11:12, :) = repmat(green, 3, 2, 1);
icon_cdata(12:14, 12:13, :) = repmat(green, 3, 2, 1);

% --------------------------------------------------------------------------
function icon_cdata = create_export_icon()

icon_cdata = ones(16, 16, 3) * 0.94;
orange = reshape([0.9 0.5 0.1], 1, 1, 3);
icon_cdata(3:9, 7:9, :) = repmat(orange, 7, 3, 1);
icon_cdata(10:11, 5:11, :) = repmat(orange, 2, 7, 1);
icon_cdata(12:13, 6:10, :) = repmat(orange, 2, 5, 1);
icon_cdata(14, 7:9, :) = repmat(orange, 1, 3, 1);
icon_cdata(13:14, 3:13, :) = repmat(orange, 2, 11, 1);

% --------------------------------------------------------------------------
function icontype = detect_data_type(dataobj, key)

icontype = 'data';
if strcmp(key, '..')
    icontype = 'parent';
    return
end
if ~isstruct(dataobj) && ~isa(dataobj, 'containers.Map') && ~isa(dataobj, 'jdict')
    return
end
try
    if isstruct(dataobj) || isa(dataobj, 'jdict')
        fields = fieldnames(dataobj);
        if length(fields) == 1
            if strcmp(fields{1}, '_DataLink_') || strcmp(fields{1}, encodevarname('_DataLink_'))
                icontype = 'link';
                return
            end
        end
        if any(strcmp(fields, '_ArrayType_')) || any(strcmp(fields, '_ArraySize_'))
            icontype = 'jdata';
            return
        end
        if any(strcmp(fields, '_MeshNode_')) || any(strcmp(fields, 'MeshNode3D'))
            icontype = 'mesh';
            return
        end
        if any(strcmp(fields, 'NIFTIData')) || any(strcmp(fields, 'NIFTIHeader'))
            icontype = 'nifti';
            return
        end
        if any(strcmp(fields, 'SNIRFData')) || any(strcmp(fields, 'nirs'))
            icontype = 'snirf';
            return
        end
        icontype = 'folder';
    end
catch
    icontype = 'data';
end

% --------------------------------------------------------------------------
function display_string = create_icon_string(icontype, text)

ascii_icons = struct();
ascii_icons.database = '[DB]';
ascii_icons.folder = '[+]';
ascii_icons.jdata = '[J]';
ascii_icons.mesh = '[M]';
ascii_icons.nifti = '[N]';
ascii_icons.snirf = '[S]';
ascii_icons.data = '[-]';
ascii_icons.parent = '[..]';
ascii_icons.link = '[->]';
if isfield(ascii_icons, icontype)
    display_string = [ascii_icons.(icontype) ' ' text];
else
    display_string = [ascii_icons.data ' ' text];
end

% --------------------------------------------------------------------------
function exportdataset(hwin)

handles = get(hwin, 'userdata');
dbidx = get(handles.lsDb, 'value');
dbs = get(handles.lsDb, 'string');
if isempty(dbs)
    msgbox('Please select a database first', 'Export', 'warn');
    return
end
dbname = regexprep(dbs{dbidx}, '^\[[^\]]*\]\s+', '');

dsidx = get(handles.lsDs, 'value');
datasets = get(handles.lsDs, 'string');
if isempty(datasets)
    msgbox('Please select a dataset first', 'Export', 'warn');
    return
end
dsname = regexprep(datasets{dsidx}, '^\[[^\]]*\]\s+', '');

try
    if ishandle(handles.hbox)
        set(handles.hbox, 'visible', 'on');
    end
    res = neuroj('export', dbname, dsname);
    if ishandle(handles.hbox)
        set(handles.hbox, 'visible', 'off');
    end
    if ~isempty(res) && isfield(res, 'exportpath')
        set(handles.txValue, 'string', ['Dataset exported to: ' res.exportpath]);
        msgbox(['Dataset exported successfully to:' char(10) res.exportpath], 'Export Complete');
    end
catch err
    if ishandle(handles.hbox)
        set(handles.hbox, 'visible', 'off');
    end
    msgbox(['Export failed: ' err.message], 'Export Error', 'error');
end

% --------------------------------------------------------------------------
function loaddb(src, event, hwin)

handles = get(hwin, 'userdata');
if ishandle(handles.hbox)
    set(handles.hbox, 'visible', 'on');
end
dbs = neuroj('list');
dblist = cellfun(@(x) create_icon_string('database', x.id), dbs.database, 'UniformOutput', false);
set(handles.lsDb, 'String', dblist);
if ishandle(handles.hbox)
    set(handles.hbox, 'visible', 'off');
end

% --------------------------------------------------------------------------
function togglesearch(hwin)

handles = get(hwin, 'userdata');
searchVisible = get(handles.pnSearch, 'visible');
if strcmp(searchVisible, 'off')
    set(handles.pnSearch, 'visible', 'on');
    set(handles.lsDb, 'position', [0 0 1 / 5 0.5]);
    set(handles.lsDs, 'position', [1 / 5 0 1 / 4 0.5]);
    set(handles.lsJSON, 'position', [9 / 20 0.125 1 - 9 / 20 0.375]);
    set(handles.txValue, 'position', [9 / 20 0 1 - 9 / 20 0.125]);
else
    set(handles.pnSearch, 'visible', 'off');
    set(handles.lsDb, 'position', [0 0 1 / 5 1]);
    set(handles.lsDs, 'position', [1 / 5 0 1 / 4 1]);
    set(handles.lsJSON, 'position', [9 / 20 0.25 1 - 9 / 20 0.75]);
    set(handles.txValue, 'position', [9 / 20 0 1 - 9 / 20 0.25]);
end

% --------------------------------------------------------------------------
function clearsearch(hwin)

handles = get(hwin, 'userdata');
set(handles.hKeyword, 'string', '');
set(handles.hDatabase, 'value', 1);
set(handles.hDataset, 'string', '');
set(handles.hSubject, 'string', '');
set(handles.hGender, 'value', 1);
set(handles.hModality, 'value', 1);
set(handles.hTypeName, 'string', '');
set(handles.hAgeMin, 'string', '');
set(handles.hAgeMax, 'string', '');
set(handles.hSessMin, 'string', '');
set(handles.hSessMax, 'string', '');
set(handles.hTaskMin, 'string', '');
set(handles.hTaskMax, 'string', '');
set(handles.hRunMin, 'string', '');
set(handles.hRunMax, 'string', '');
set(handles.hTaskName, 'string', '');
set(handles.hSessionName, 'string', '');
set(handles.hRunName, 'string', '');
set(handles.hLimit, 'string', '25');
set(handles.hSkip, 'string', '0');
set(handles.hCount, 'value', 0);
set(handles.hUnique, 'value', 0);

% --------------------------------------------------------------------------
function dosearch(hwin)

handles = get(hwin, 'userdata');
baseurl = 'https://neurojson.org/io/search.cgi';
param = {};

keyword = strtrim(get(handles.hKeyword, 'string'));
if ~isempty(keyword)
    param = [param, 'keyword', keyword];
end

dbnames = get(handles.hDatabase, 'string');
database = dbnames{get(handles.hDatabase, 'value')};
if ~strcmp(database, 'any')
    param = [param, 'dbname', database];
end

dataset = strtrim(get(handles.hDataset, 'string'));
if ~isempty(dataset)
    param = [param, 'dsname', dataset];
end

subject = strtrim(get(handles.hSubject, 'string'));
if ~isempty(subject)
    param = [param, 'subname', subject];
end

genders = get(handles.hGender, 'string');
gender = genders{get(handles.hGender, 'value')};
if ~strcmp(gender, 'any')
    param = [param, 'gender', gender(1)];
end

modalities = get(handles.hModality, 'string');
modality = modalities{get(handles.hModality, 'value')};
if ~strcmp(modality, 'any')
    param = [param, 'modality', modality];
end

typename = strtrim(get(handles.hTypeName, 'string'));
if ~isempty(typename)
    param = [param, 'type', typename];
end

agemin = strtrim(get(handles.hAgeMin, 'string'));
if ~isempty(agemin) && ~isnan(str2double(agemin))
    param = [param, 'agemin', sprintf('%05d', floor(str2double(agemin) * 100))];
end

agemax = strtrim(get(handles.hAgeMax, 'string'));
if ~isempty(agemax) && ~isnan(str2double(agemax))
    param = [param, 'agemax', sprintf('%05d', floor(str2double(agemax) * 100))];
end

sessmin = strtrim(get(handles.hSessMin, 'string'));
if ~isempty(sessmin)
    param = [param, 'sessmin', sessmin];
end

sessmax = strtrim(get(handles.hSessMax, 'string'));
if ~isempty(sessmax)
    param = [param, 'sessmax', sessmax];
end

taskmin = strtrim(get(handles.hTaskMin, 'string'));
if ~isempty(taskmin)
    param = [param, 'taskmin', taskmin];
end

taskmax = strtrim(get(handles.hTaskMax, 'string'));
if ~isempty(taskmax)
    param = [param, 'taskmax', taskmax];
end

runmin = strtrim(get(handles.hRunMin, 'string'));
if ~isempty(runmin)
    param = [param, 'runmin', runmin];
end

runmax = strtrim(get(handles.hRunMax, 'string'));
if ~isempty(runmax)
    param = [param, 'runmax', runmax];
end

taskname = strtrim(get(handles.hTaskName, 'string'));
if ~isempty(taskname)
    param = [param, 'task', taskname];
end

sessionname = strtrim(get(handles.hSessionName, 'string'));
if ~isempty(sessionname)
    param = [param, 'session', sessionname];
end

runname = strtrim(get(handles.hRunName, 'string'));
if ~isempty(runname)
    param = [param, 'run', runname];
end

limit = strtrim(get(handles.hLimit, 'string'));
skip = strtrim(get(handles.hSkip, 'string'));
param = [param, 'limit', limit, 'skip', skip];

if get(handles.hCount, 'value')
    param = [param, 'count', 'true'];
end

if get(handles.hUnique, 'value')
    param = [param, 'unique', 'true'];
end

if ishandle(handles.hbox)
    set(handles.hbox, 'visible', 'on');
end

try
    result = webread(baseurl, param{:});
    if isempty(result)
        set(handles.txValue, 'string', 'No results found');
        if ishandle(handles.hbox)
            set(handles.hbox, 'visible', 'off');
        end
        return
    end

    uniquedb = {};
    datasetsByDb = containers.Map();
    subjectmap = containers.Map();

    if isstruct(result)
        for i = 1:length(result)
            if isfield(result(i), 'dbname') && isfield(result(i), 'dsname')
                dbname = result(i).dbname;
                dsname = result(i).dsname;
                key = [dbname '/' dsname];
                if isempty(uniquedb) || ~any(strcmp(uniquedb, dbname))
                    uniquedb{end + 1} = dbname;
                    datasetsByDb(dbname) = {};
                end
                dslist = datasetsByDb(dbname);
                if isempty(dslist) || ~any(strcmp(dslist, dsname))
                    dslist{end + 1} = dsname;
                    datasetsByDb(dbname) = dslist;
                end
                if ~isKey(subjectmap, key)
                    subjectmap(key) = {};
                end
                if isfield(result(i), 'subj')
                    subjects = subjectmap(key);
                    subjname = result(i).subj;
                    if isempty(subjects) || ~any(strcmp(subjects, subjname))
                        subjects{end + 1} = subjname;
                        subjectmap(key) = subjects;
                    end
                end
            end
        end
    end

    if ~isempty(uniquedb)
        dblist = cellfun(@(x) create_icon_string('database', x), uniquedb, 'UniformOutput', false);
        set(handles.lsDb, 'String', dblist);
        set(handles.lsDb, 'Value', 1);
        set(handles.lsDb, 'tag', uniquedb{1});
        firstdb = uniquedb{1};
        if isKey(datasetsByDb, firstdb)
            dslist = datasetsByDb(firstdb);
            dsdisplay = cellfun(@(x) create_icon_string('data', x), dslist, 'UniformOutput', false);
            set(handles.lsDs, 'String', dsdisplay);
            set(handles.lsDs, 'Value', 1);
        end
    end

    set(handles.lsJSON, 'String', {});
    totaldatasets = 0;
    dbkeys = keys(datasetsByDb);
    for i = 1:length(dbkeys)
        totaldatasets = totaldatasets + length(datasetsByDb(dbkeys{i}));
    end
    set(handles.txValue, 'String', sprintf('Found %d results from %d databases, %d datasets', length(result), length(uniquedb), totaldatasets));
    setappdata(hwin, 'searchSubjects', subjectmap);
    setappdata(hwin, 'searchDatasets', datasetsByDb);
    set(hwin, 'userdata', handles);
    togglesearch(hwin);
catch err
    set(handles.txValue, 'string', ['Search error: ' err.message]);
end

if ishandle(handles.hbox)
    set(handles.hbox, 'visible', 'off');
end

% --------------------------------------------------------------------------
function loadds(src, event, hwin)

handles = get(hwin, 'userdata');
if ishandle(handles.hbox)
    set(handles.hbox, 'visible', 'on');
end

if (isfield(event, 'Key') && strcmp(event.Key, 'enter')) || strcmp(get(handles.fmMain, 'SelectionType'), 'open') || (cputime - handles.t0) < 0.01
    idx = get(src, 'value');
    dbs = get(src, 'string');
    dbname = regexprep(dbs{idx}, '^\[[^\]]*\]\s+', '');
    searchDatasets = getappdata(hwin, 'searchDatasets');
    if ~isempty(searchDatasets) && isa(searchDatasets, 'containers.Map') && isKey(searchDatasets, dbname)
        dslist = searchDatasets(dbname);
        dsdisplay = cellfun(@(x) create_icon_string('data', x), dslist, 'UniformOutput', false);
        set(handles.lsDs, 'string', dsdisplay, 'value', 1);
        set(handles.lsDb, 'tag', dbname);
        set(handles.lsJSON, 'string', {});
    else
        dslist = neuroj('list', dbname);
        dslist.dataset = dslist.dataset(arrayfun(@(x) x.id(1) ~= '_', dslist.dataset));
        dsnames = cellfun(@(x) create_icon_string('data', x), {dslist.dataset.id}, 'UniformOutput', false);
        set(handles.lsDs, 'string', dsnames, 'value', 1);
        set(handles.lsDb, 'tag', dbname);
    end
end

handles.t0 = cputime;
set(hwin, 'userdata', handles);

if ishandle(handles.hbox)
    set(handles.hbox, 'visible', 'off');
end

% --------------------------------------------------------------------------
function loaddsdata(src, event, hwin)

handles = get(hwin, 'userdata');
if ishandle(handles.hbox)
    set(handles.hbox, 'visible', 'on');
end

if isfield(event, 'Key') && strcmp(event.Key, 'enter') || strcmp(get(handles.fmMain, 'SelectionType'), 'open') || (cputime - handles.t0) < 0.01
    idx = get(src, 'value');
    dbs = get(src, 'string');
    dsname = regexprep(dbs{idx}, '^\[[^\]]*\]\s+', '');
    dbid = get(handles.lsDb, 'tag');
    searchSubjects = getappdata(hwin, 'searchSubjects');
    key = [dbid '/' dsname];
    if ~isempty(searchSubjects) && isa(searchSubjects, 'containers.Map') && isKey(searchSubjects, key)
        subjects = searchSubjects(key);
        if ~isempty(subjects)
            subjectlist = cellfun(@(x) create_icon_string('data', ['sub-' x]), subjects, 'UniformOutput', false);
            set(handles.lsJSON, 'string', subjectlist, 'value', 1);
            set(handles.lsJSON, 'userdata', []);
            set(handles.lsJSON, 'tag', '');
            set(handles.txValue, 'string', sprintf('Showing %d subjects from search results for %s', length(subjects), key));
        else
            loaddataset(handles, dbid, dsname);
        end
    else
        loaddataset(handles, dbid, dsname);
    end
end

handles.t0 = cputime;
set(hwin, 'userdata', handles);

if ishandle(handles.hbox)
    set(handles.hbox, 'visible', 'off');
end

% --------------------------------------------------------------------------
function loaddataset(handles, dbid, dsname)

datasets = jdict(neuroj('get', dbid, dsname));
keys = datasets.keys();
display_strs = cell(size(keys));
for i = 1:length(keys)
    key = decodevarname(keys{i});
    try
        dataobj = datasets.(keys{i});
        icontype = detect_data_type(dataobj, key);
        display_strs{i} = create_icon_string(icontype, key);
    catch
        display_strs{i} = create_icon_string('data', key);
    end
end
set(handles.lsJSON, 'string', display_strs, 'value', 1);
set(handles.lsJSON, 'userdata', datasets);
set(handles.lsJSON, 'tag', '');

% --------------------------------------------------------------------------
function expandjsontree(src, event, hwin)

handles = get(hwin, 'userdata');
if (~isa(get(handles.lsJSON, 'userdata'), 'jdict'))
    return
end

if ishandle(handles.hbox)
    set(handles.hbox, 'visible', 'on');
end

if isfield(event, 'Key') && strcmp(event.Key, 'enter') || strcmp(get(handles.fmMain, 'SelectionType'), 'open') || (cputime - handles.t0) < 0.01
    idx = get(src, 'value');
    dbs = get(src, 'string');

    if isempty(dbs) || idx < 1 || idx > length(dbs)
        if ishandle(handles.hbox)
            set(handles.hbox, 'visible', 'off');
        end
        return
    end

    keyname = regexprep(dbs{idx}, '^\[[^\]]*\]\s+', '');
    rootpath = get(handles.lsJSON, 'tag');
    datasets = get(handles.lsJSON, 'userdata');
    dollarchar = char(36);

    if (isempty(rootpath))
        rootpath = dollarchar;
    end

    if (strcmp(keyname, '..'))
        rootpath = regexprep(rootpath, ['\[[^\]]+\]', char(36)], '');
    else
        rootpath = [rootpath, '["', keyname, '"]'];
    end

    datasets = datasets.(rootpath);

    try
        if (iscell(datasets.keys()))
            keys = datasets.keys();
            subitem = cell(size(keys));
            for i = 1:length(keys)
                key = decodevarname(keys{i});
                try
                    dataobj = datasets.(keys{i});
                    icontype = detect_data_type(dataobj, key);
                catch
                    icontype = 'data';
                end
                subitem{i} = create_icon_string(icontype, key);
            end
            if (~strcmp(rootpath, dollarchar))
                subitem = {create_icon_string('parent', '..'), subitem{:}};
            end
            set(handles.lsJSON, 'string', subitem, 'value', 1);
            set(handles.lsJSON, 'tag', rootpath);
        else
            try
                parentpath = regexprep(rootpath, ['\"', keyname, '"\]', char(36)], '');
                parentpath = regexprep(parentpath, ['\[\"', char(36)], '');
                alldatasets = get(handles.lsJSON, 'userdata');
                if ~strcmp(parentpath, dollarchar)
                    parentobj = alldatasets.(parentpath).(keyname);
                else
                    parentobj = alldatasets.(keyname);
                end
                if isstruct(parentobj) || isa(parentobj, 'jdict') || isa(parentobj, 'containers.Map')
                    fields = fieldnames(parentobj);
                    if length(fields) == 1
                        encodedlink = encodevarname('_DataLink_');
                        if strcmp(fields{1}, '_DataLink_') || strcmp(fields{1}, encodedlink)
                            if isa(parentobj, 'jdict') || isa(parentobj, 'containers.Map')
                                linkurl = parentobj.('_DataLink_');
                            else
                                linkurl = parentobj.(encodedlink);
                            end
                            if ~isempty(linkurl)
                                web(linkurl, '-browser');
                                set(handles.txValue, 'string', ['Opening link: ' linkurl]);
                            else
                                set(handles.txValue, 'string', datasets.v());
                            end
                        else
                            set(handles.txValue, 'string', datasets.v());
                        end
                    else
                        set(handles.txValue, 'string', datasets.v());
                    end
                else
                    set(handles.txValue, 'string', datasets.v());
                end
            catch
                set(handles.txValue, 'string', datasets.v());
            end
        end
    catch
    end
end

handles.t0 = cputime;
set(hwin, 'userdata', handles);

if ishandle(handles.hbox)
    set(handles.hbox, 'visible', 'off');
end
