function results = benchmark_json(varargin)
%
% results = benchmark_json('param1', value1, 'param2', value2, ...)
%
% Benchmark JSON encoding/decoding performance comparing:
%   - Native MATLAB/Octave (jsonencode/jsondecode)
%   - JSONlab text JSON (savejson/loadjson)
%   - JSONlab binary JSON (savebj/loadbj)
%
% Parameters:
%   'numTrials'    - Number of trials per test (default: 5)
%   'arraySize'    - Size of flat array test (default: 100000)
%   'structCount'  - Number of struct array elements (default: 1000)
%   'nestDepth'    - Depth of nested structure (default: 8)
%   'stringCount'  - Number of strings in mixed test (default: 500)
%   'intCount'     - Number of integers in mixed test (default: 1000)
%   'floatSize'    - Size of float matrix [m,n] (default: [100,100])
%   'cellCount'    - Number of cell array elements (default: 200)
%   'verbose'      - Display progress (default: true)
%
% Output:
%   results - Structure containing benchmark results for all operations
%
% Example:
%   results = benchmark_json('numTrials', 10, 'nestDepth', 5);
%   results = benchmark_json('arraySize', 50000, 'verbose', false);
%
% Author: Qianqian Fang (q.fang at neu.edu)
%
% License: BSD or GPL version 3, see LICENSE_{BSD,GPLv3}.txt
%
% -- this function is part of JSONLab toolbox (http://neurojson.org/jsonlab)
%

% Parse input parameters
opt = varargin2struct(varargin{:});

% Set defaults
numTrials = jsonopt('numTrials', 5, opt);
arraySize = jsonopt('arraySize', 100000, opt);
structCount = jsonopt('structCount', 1000, opt);
nestDepth = jsonopt('nestDepth', 8, opt);
stringCount = jsonopt('stringCount', 500, opt);
intCount = jsonopt('intCount', 1000, opt);
floatSize = jsonopt('floatSize', [100, 100], opt);
cellCount = jsonopt('cellCount', 200, opt);
verbose = jsonopt('verbose', true, opt);

tempFile = tempname;    % Temporary file for disk I/O tests

%% Generate test data structures
if verbose
    fprintf('=== JSON Benchmark: JSONlab vs Native MATLAB/Octave ===\n\n');
    fprintf('Generating test data structures...\n');
    fprintf('  Array size: %d\n', arraySize);
    fprintf('  Struct array: %d elements\n', structCount);
    fprintf('  Nest depth: %d levels\n', nestDepth);
    fprintf('  Trials per test: %d\n', numTrials);
end

% 1. Large flat array
data.flatArray = rand(1, arraySize);

% 2. Large struct array
for i = 1:structCount
    data.structArray(i).id = i;
    data.structArray(i).value = rand();
    data.structArray(i).name = sprintf('item_%d', i);
    data.structArray(i).flags = rand(1, 10);
end

% 3. Deeply nested structure
data.deep = createDeepStruct_(nestDepth);

% 4. Mixed types structure
data.mixed.strings = arrayfun(@(x) sprintf('str_%d', x), 1:stringCount, 'UniformOutput', false);
data.mixed.integers = randi(1000, 1, intCount);
data.mixed.floats = rand(floatSize(1), floatSize(2));
data.mixed.booleans = rand(1, intCount) > 0.5;
data.mixed.nested.level1.level2.values = rand(1, 100);

% 5. Cell array with heterogeneous data
data.cells = cell(1, cellCount);
for i = 1:cellCount
    switch mod(i, 4)
        case 0
            data.cells{i} = rand(5, 5);
        case 1
            data.cells{i} = sprintf('string_%d', i);
        case 2
            data.cells{i} = randi(100, 1, 10);
        case 3
            data.cells{i} = struct('a', i, 'b', rand());
    end
end

if verbose
    fprintf('Test data generated.\n\n');
end

%% Check for JSONlab and Binary JSON
hasJSONlab = exist('savejson', 'file') == 2 && exist('loadjson', 'file') == 2;
hasBinaryJSON = exist('savebj', 'file') == 2 && exist('loadbj', 'file') == 2;

if ~hasJSONlab && verbose
    warning('JSONlab not found in path. Only native functions will be tested.');
end
if ~hasBinaryJSON && verbose
    warning('Binary JSON functions (savebj/loadbj) not found.');
end

%% Initialize results
results = struct();
results.config = struct('numTrials', numTrials, 'arraySize', arraySize, ...
                        'structCount', structCount, 'nestDepth', nestDepth);

%% Benchmark: Encoding/Saving to string
if verbose
    fprintf('--- Encoding to JSON String ---\n');
end

% Native jsonencode
times = zeros(1, numTrials);
for t = 1:numTrials
    tic;
    jsonStr_native = jsonencode(data);
    times(t) = toc;
end
results.encode.native.mean = mean(times);
results.encode.native.std = std(times);
results.encode.native.size = length(jsonStr_native);
if verbose
    fprintf('jsonencode:  %.4f ± %.4f sec (output: %.2f KB)\n', ...
            results.encode.native.mean, results.encode.native.std, results.encode.native.size / 1024);
end

% JSONlab savejson (to string)
if hasJSONlab
    times = zeros(1, numTrials);
    for t = 1:numTrials
        tic;
        jsonStr_jlab = savejson('', data, 'compression', '');
        times(t) = toc;
    end
    results.encode.jsonlab.mean = mean(times);
    results.encode.jsonlab.std = std(times);
    results.encode.jsonlab.size = length(jsonStr_jlab);
    if verbose
        fprintf('savejson:    %.4f ± %.4f sec (output: %.2f KB)\n', ...
                results.encode.jsonlab.mean, results.encode.jsonlab.std, results.encode.jsonlab.size / 1024);
        fprintf('Speedup (native/jsonlab): %.2fx\n', results.encode.jsonlab.mean / results.encode.native.mean);
    end
end

%% Benchmark: Decoding/Loading from string
if verbose
    fprintf('\n--- Decoding from JSON String ---\n');
end

% Native jsondecode
times = zeros(1, numTrials);
for t = 1:numTrials
    tic;
    decoded_native = jsondecode(jsonStr_native);
    times(t) = toc;
end
results.decode.native.mean = mean(times);
results.decode.native.std = std(times);
if verbose
    fprintf('jsondecode:  %.4f ± %.4f sec\n', results.decode.native.mean, results.decode.native.std);
end

% JSONlab loadjson (from string)
if hasJSONlab
    times = zeros(1, numTrials);
    for t = 1:numTrials
        tic;
        decoded_jlab = loadjson(jsonStr_jlab);
        times(t) = toc;
    end
    results.decode.jsonlab.mean = mean(times);
    results.decode.jsonlab.std = std(times);
    if verbose
        fprintf('loadjson:    %.4f ± %.4f sec\n', results.decode.jsonlab.mean, results.decode.jsonlab.std);
        fprintf('Speedup (native/jsonlab): %.2fx\n', results.decode.jsonlab.mean / results.decode.native.mean);
    end
end

%% Benchmark: File I/O (Write)
if verbose
    fprintf('\n--- Writing to File ---\n');
end

% Native: jsonencode + fwrite
times = zeros(1, numTrials);
nativeFile = [tempFile '_native.json'];
for t = 1:numTrials
    tic;
    fid = fopen(nativeFile, 'w');
    fwrite(fid, jsonencode(data), 'char');
    fclose(fid);
    times(t) = toc;
end
results.fileWrite.native.mean = mean(times);
results.fileWrite.native.std = std(times);
if verbose
    fprintf('jsonencode+fwrite: %.4f ± %.4f sec\n', results.fileWrite.native.mean, results.fileWrite.native.std);
end

% JSONlab savejson to file
if hasJSONlab
    times = zeros(1, numTrials);
    jlabFile = [tempFile '_jsonlab.json'];
    for t = 1:numTrials
        tic;
        savejson('', data, 'FileName', jlabFile);
        times(t) = toc;
    end
    results.fileWrite.jsonlab.mean = mean(times);
    results.fileWrite.jsonlab.std = std(times);
    if verbose
        fprintf('savejson (file):   %.4f ± %.4f sec\n', results.fileWrite.jsonlab.mean, results.fileWrite.jsonlab.std);
        fprintf('Speedup (native/jsonlab): %.2fx\n', results.fileWrite.jsonlab.mean / results.fileWrite.native.mean);
    end
end

%% Benchmark: File I/O (Read)
if verbose
    fprintf('\n--- Reading from File ---\n');
end

% Native: fread + jsondecode
times = zeros(1, numTrials);
for t = 1:numTrials
    tic;
    fid = fopen(nativeFile, 'r');
    raw = fread(fid, '*char')';
    fclose(fid);
    decoded = jsondecode(raw);
    times(t) = toc;
end
results.fileRead.native.mean = mean(times);
results.fileRead.native.std = std(times);
if verbose
    fprintf('fread+jsondecode:  %.4f ± %.4f sec\n', results.fileRead.native.mean, results.fileRead.native.std);
end

% JSONlab loadjson from file
if hasJSONlab
    times = zeros(1, numTrials);
    for t = 1:numTrials
        tic;
        decoded = loadjson(jlabFile);
        times(t) = toc;
    end
    results.fileRead.jsonlab.mean = mean(times);
    results.fileRead.jsonlab.std = std(times);
    if verbose
        fprintf('loadjson (file):   %.4f ± %.4f sec\n', results.fileRead.jsonlab.mean, results.fileRead.jsonlab.std);
        fprintf('Speedup (native/jsonlab): %.2fx\n', results.fileRead.jsonlab.mean / results.fileRead.native.mean);
    end
end

%% Benchmark: Binary JSON Encoding (to buffer)
if hasBinaryJSON
    if verbose
        fprintf('\n--- Binary JSON Encoding (to buffer) ---\n');
    end

    times = zeros(1, numTrials);
    bjFile_mem = [tempFile '_binary_mem.bjd'];
    for t = 1:numTrials
        tic;
        savebj('', data, 'FileName', bjFile_mem);
        times(t) = toc;
    end
    results.encodeBinary.mean = mean(times);
    results.encodeBinary.std = std(times);

    % Get buffer size
    fileInfo = dir(bjFile_mem);
    results.encodeBinary.size = fileInfo.bytes;

    if verbose
        fprintf('savebj (buffer):   %.4f ± %.4f sec (output: %.2f KB)\n', ...
                results.encodeBinary.mean, results.encodeBinary.std, results.encodeBinary.size / 1024);

        fprintf('Speedup vs native:   %.2fx\n', results.encode.native.mean / results.encodeBinary.mean);
        if hasJSONlab
            fprintf('Speedup vs savejson: %.2fx\n', results.encode.jsonlab.mean / results.encodeBinary.mean);
            fprintf('Size ratio (binary/text): %.1f%% (saved %.2f KB, %.1f%% smaller)\n', ...
                    100 * results.encodeBinary.size / results.encode.jsonlab.size, ...
                    (results.encode.jsonlab.size - results.encodeBinary.size) / 1024, ...
                    100 * (1 - results.encodeBinary.size / results.encode.jsonlab.size));
        end
    end
end

%% Benchmark: Binary JSON Decoding (from buffer)
if hasBinaryJSON
    if verbose
        fprintf('\n--- Binary JSON Decoding (from buffer) ---\n');
    end

    times = zeros(1, numTrials);
    for t = 1:numTrials
        tic;
        decoded_bj = loadbj(bjFile_mem);
        times(t) = toc;
    end
    results.decodeBinary.mean = mean(times);
    results.decodeBinary.std = std(times);
    if verbose
        fprintf('loadbj (buffer):   %.4f ± %.4f sec\n', results.decodeBinary.mean, results.decodeBinary.std);

        fprintf('Speedup vs native:   %.2fx\n', results.decode.native.mean / results.decodeBinary.mean);
        if hasJSONlab
            fprintf('Speedup vs loadjson: %.2fx\n', results.decode.jsonlab.mean / results.decodeBinary.mean);
        end
    end
end

%% Benchmark: Binary JSON File I/O (Write)
if hasBinaryJSON
    if verbose
        fprintf('\n--- Binary JSON Writing to File ---\n');
    end

    times = zeros(1, numTrials);
    bjFile = [tempFile '_binary.bjd'];
    for t = 1:numTrials
        tic;
        savebj('', data, 'FileName', bjFile);
        times(t) = toc;
    end
    results.fileWriteBinary.mean = mean(times);
    results.fileWriteBinary.std = std(times);

    % Get file size
    fileInfo = dir(bjFile);
    results.fileWriteBinary.size = fileInfo.bytes;

    if verbose
        fprintf('savebj (file):     %.4f ± %.4f sec (file: %.2f KB)\n', ...
                results.fileWriteBinary.mean, results.fileWriteBinary.std, ...
                results.fileWriteBinary.size / 1024);

        fprintf('Speedup vs native:   %.2fx\n', results.fileWrite.native.mean / results.fileWriteBinary.mean);
        if hasJSONlab
            fprintf('Speedup vs savejson: %.2fx\n', results.fileWrite.jsonlab.mean / results.fileWriteBinary.mean);

            % Compare file sizes
            jlabFileInfo = dir(jlabFile);
            fprintf('File size ratio (binary/text): %.1f%% (saved %.2f KB, %.1f%% smaller)\n', ...
                    100 * results.fileWriteBinary.size / jlabFileInfo.bytes, ...
                    (jlabFileInfo.bytes - results.fileWriteBinary.size) / 1024, ...
                    100 * (1 - results.fileWriteBinary.size / jlabFileInfo.bytes));
        end
    end
end

%% Benchmark: Binary JSON File I/O (Read)
if hasBinaryJSON
    if verbose
        fprintf('\n--- Binary JSON Reading from File ---\n');
    end

    times = zeros(1, numTrials);
    for t = 1:numTrials
        tic;
        decoded_bj = loadbj(bjFile);
        times(t) = toc;
    end
    results.fileReadBinary.mean = mean(times);
    results.fileReadBinary.std = std(times);
    if verbose
        fprintf('loadbj (file):     %.4f ± %.4f sec\n', results.fileReadBinary.mean, results.fileReadBinary.std);

        fprintf('Speedup vs native:   %.2fx\n', results.fileRead.native.mean / results.fileReadBinary.mean);
        if hasJSONlab
            fprintf('Speedup vs loadjson: %.2fx\n', results.fileRead.jsonlab.mean / results.fileReadBinary.mean);
        end
    end
end

%% Cleanup temp files
delete([tempFile '*']);

%% Summary
if verbose
    fprintf('\n=== Summary ===\n');
    if hasBinaryJSON
        fprintf('%-25s %12s %12s %12s %12s\n', 'Operation', 'Native (s)', 'JSONlab (s)', 'Binary (s)', 'Winner');
        fprintf('%s\n', repmat('-', 1, 77));
    else
        fprintf('%-20s %12s %12s %12s\n', 'Operation', 'Native (s)', 'JSONlab (s)', 'Ratio');
        fprintf('%s\n', repmat('-', 1, 60));
    end

    ops = {'encode', 'decode', 'fileWrite', 'fileRead'};
    opsBinary = {'encodeBinary', 'decodeBinary', 'fileWriteBinary', 'fileReadBinary'};
    opNames = {'Encode (string)', 'Decode (string)', 'Write (file)', 'Read (file)'};

    for i = 1:length(ops)
        nativeTime = results.(ops{i}).native.mean;

        if hasBinaryJSON
            if hasJSONlab
                jlabTime = results.(ops{i}).jsonlab.mean;
            else
                jlabTime = inf;
            end
            binaryTime = results.(opsBinary{i}).mean;

            % Find winner
            [minTime, minIdx] = min([nativeTime, jlabTime, binaryTime]);
            winners = {'Native', 'JSONlab', 'Binary'};
            winner = winners{minIdx};

            if hasJSONlab
                fprintf('%-25s %12.4f %12.4f %12.4f %12s\n', opNames{i}, ...
                        nativeTime, jlabTime, binaryTime, winner);
            else
                fprintf('%-25s %12.4f %12s %12.4f %12s\n', opNames{i}, ...
                        nativeTime, 'N/A', binaryTime, winner);
            end
        else
            if hasJSONlab
                ratio = results.(ops{i}).jsonlab.mean / nativeTime;
                fprintf('%-20s %12.4f %12.4f %12.2fx\n', opNames{i}, ...
                        nativeTime, results.(ops{i}).jsonlab.mean, ratio);
            else
                fprintf('%-20s %12.4f %12s %12s\n', opNames{i}, ...
                        nativeTime, 'N/A', 'N/A');
            end
        end
    end

    %% Size Comparison
    if hasBinaryJSON && hasJSONlab
        fprintf('\n=== Size Comparison ===\n');
        fprintf('%-25s %15s %15s %15s\n', 'Format', 'Memory (KB)', 'File (KB)', 'vs Text');
        fprintf('%s\n', repmat('-', 1, 72));

        textMemSize = results.encode.jsonlab.size / 1024;
        binaryMemSize = results.encodeBinary.size / 1024;

        if exist(jlabFile, 'file')
            jlabFileInfo = dir(jlabFile);
            textFileSize = jlabFileInfo.bytes / 1024;
        else
            textFileSize = textMemSize;
        end

        if exist(bjFile, 'file')
            binaryFileSize = results.fileWriteBinary.size / 1024;
        else
            binaryFileSize = binaryMemSize;
        end

        fprintf('%-25s %15.2f %15.2f %15s\n', 'Text JSON', textMemSize, textFileSize, 'baseline');
        fprintf('%-25s %15.2f %15.2f %15.1f%%\n', 'Binary JSON', ...
                binaryMemSize, binaryFileSize, 100 * binaryFileSize / textFileSize);
        fprintf('\nBinary JSON is %.1f%% smaller (saved %.2f KB in memory, %.2f KB on disk)\n', ...
                100 * (1 - binaryMemSize / textMemSize), textMemSize - binaryMemSize, textFileSize - binaryFileSize);
    end

    %% Performance Ratios
    fprintf('\n=== Performance Ratios (relative to native) ===\n');
    if hasBinaryJSON
        fprintf('%-25s %15s %15s\n', 'Operation', 'JSONlab/Native', 'Binary/Native');
        fprintf('%s\n', repmat('-', 1, 60));
    else
        fprintf('%-20s %15s\n', 'Operation', 'JSONlab/Native');
        fprintf('%s\n', repmat('-', 1, 40));
    end

    for i = 1:length(ops)
        nativeTime = results.(ops{i}).native.mean;

        if hasBinaryJSON
            if hasJSONlab
                jlabRatio = results.(ops{i}).jsonlab.mean / nativeTime;
            else
                jlabRatio = inf;
            end
            binaryRatio = results.(opsBinary{i}).mean / nativeTime;

            if hasJSONlab
                fprintf('%-25s %15.2fx %15.2fx\n', opNames{i}, jlabRatio, binaryRatio);
            else
                fprintf('%-25s %15s %15.2fx\n', opNames{i}, 'N/A', binaryRatio);
            end
        else
            if hasJSONlab
                ratio = results.(ops{i}).jsonlab.mean / nativeTime;
                fprintf('%-20s %15.2fx\n', opNames{i}, ratio);
            else
                fprintf('%-20s %15s\n', opNames{i}, 'N/A');
            end
        end
    end

    fprintf('\nNote: Ratio < 1 means faster than native; > 1 means slower than native.\n');
end

%% -------------------------------------------------------------------------
function s = createDeepStruct_(depth)
if depth <= 0
    s.value = rand(1, 50);
    s.label = 'leaf_node';
else
    s.level = depth;
    s.data = rand(1, 20);
    s.metadata = struct('created', datestr(now), 'id', randi(10000));
    s.child = createDeepStruct_(depth - 1);
    % Add sibling branches for complexity
    if depth > 2
        s.sibling = createDeepStruct_(depth - 2);
    end
end
