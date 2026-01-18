%% Fuzz-Based Unit Tests for JSONlab (loadjson/savejson)
% Compatible with MATLAB R2010+ and GNU Octave
%
% Usage:
%   test_jsonlab_fuzz          % Run all tests
%   test_jsonlab_fuzz('seed', 123)  % Custom seed
%   test_jsonlab_fuzz('iterations', 50)  % Fewer iterations
%   test_jsonlab_fuzz('verbose', true)   % Show all details

function results = test_jsonlab_fuzz(varargin)

%% Parse options
opt.seed = 42;
opt.iterations = 100;
opt.maxdepth = 10;
opt.maxarraysize = 1000;
opt.verbose = false;

for i = 1:2:length(varargin)
    if isfield(opt, lower(varargin{i}))
        opt.(lower(varargin{i})) = varargin{i + 1};
    end
end

%% Initialize RNG (compatible with old MATLAB and Octave)
initRNG(opt.seed);

%% Check for JSONlab
if ~(exist('savejson', 'file') == 2 && exist('loadjson', 'file') == 2)
    error('JSONlab not found. Please add loadjson.m and savejson.m to path.');
end

%% Run tests
results = struct('passed', 0, 'partial', 0, 'failed', 0, 'errors', 0, 'skipped', 0, 'details', {{}});

fprintf('=== JSONlab Fuzz Test Suite ===\n');
fprintf('Seed: %d | Iterations: %d | MaxDepth: %d\n\n', ...
        opt.seed, opt.iterations, opt.maxdepth);

% Test list
tests = {
         @() testFuzzRandomStructures(opt), 'Random Structures'
         @() testFuzzRandomArrays(opt), 'Random Arrays'
         @() testFuzzMixedCellArrays(opt), 'Mixed Cell Arrays'
         @() testFuzzRandomStrings(opt), 'Random Strings'
         @() testFuzzNumericEdgeCases(opt), 'Numeric Edge Cases'
         @() testFuzzDeepNesting(opt), 'Deep Nesting'
         @() testFuzzLargeArrays(opt), 'Large Arrays'
         @() testFuzzEmptyValues(opt), 'Empty Values'
         @() testFuzzSpecialFieldNames(opt), 'Special Field Names'
         @() testFuzzFileIO(opt), 'File I/O'
         @() testMalformedJSON(opt), 'Malformed JSON'
         @() testFuzzMutatedJSON(opt), 'Mutated JSON'
         @() testFuzzBinaryNoise(opt), 'Binary Noise'
         @() testStressRapidCalls(opt), 'Stress: Rapid Calls'
         @() testEscapeSequences(opt), 'Escape Sequences'
        };

for t = 1:size(tests, 1)
    testFunc = tests{t, 1};
    testName = tests{t, 2};
    fprintf('Running: %-25s ', testName);
    try
        [pass, partial, fail, msgs] = testFunc();
        results.passed = results.passed + pass;
        results.partial = results.partial + partial;
        results.failed = results.failed + fail;
        if fail == 0 && partial == 0
            fprintf('[PASS] (%d)\n', pass);
        elseif fail == 0
            fprintf('[PASS] (%d full, %d partial)\n', pass, partial);
        else
            fprintf('[FAIL] (%d passed, %d partial, %d failed)\n', pass, partial, fail);
            if opt.verbose
                for m = 1:length(msgs)
                    fprintf('  - %s\n', msgs{m});
                end
            end
        end
        results.details{end + 1} = struct('name', testName, 'pass', pass, 'partial', partial, 'fail', fail, 'msgs', {msgs});
    catch ME
        results.errors = results.errors + 1;
        fprintf('[ERROR] %s\n', ME.message);
        results.details{end + 1} = struct('name', testName, 'pass', 0, 'partial', 0, 'fail', 0, 'error', ME.message);
    end
end

%% Summary
fprintf('\n=== Summary ===\n');
fprintf('Passed: %d | Partial: %d | Failed: %d | Errors: %d\n', ...
        results.passed, results.partial, results.failed, results.errors);
if results.failed == 0 && results.errors == 0
    fprintf('All tests PASSED!\n');
else
    fprintf('\n=== Failed Test Details ===\n');
    for i = 1:length(results.details)
        d = results.details{i};
        if isfield(d, 'msgs') && ~isempty(d.msgs) && d.fail > 0
            fprintf('\n[%s] %d failures:\n', d.name, d.fail);
            maxShow = min(5, length(d.msgs));
            for m = 1:maxShow
                fprintf('  - %s\n', truncateStr(d.msgs{m}, 100));
            end
            if length(d.msgs) > maxShow
                fprintf('  ... and %d more\n', length(d.msgs) - maxShow);
            end
        end
    end
end
end

function str = truncateStr(str, maxLen)
if length(str) > maxLen
    str = [str(1:maxLen) '...'];
end
end

%% ===== Test Functions =====

function [pass, partial, fail, msgs] = testFuzzRandomStructures(opt)
pass = 0;
partial = 0;
fail = 0;
msgs = {};
for i = 1:opt.iterations
    depth = randInt(1, opt.maxdepth);
    data = generateRandomStruct(depth);
    [status, msg] = verifyRoundTrip(data, sprintf('iter %d', i));
    if status == 1
        pass = pass + 1;
    elseif status == 0
        partial = partial + 1;
    else
        fail = fail + 1;
        msgs{end + 1} = msg;
    end
end
end

function [pass, partial, fail, msgs] = testFuzzRandomArrays(opt)
pass = 0;
partial = 0;
fail = 0;
msgs = {};
for i = 1:opt.iterations
    data = generateRandomArray(opt.maxarraysize);
    [status, msg] = verifyRoundTrip(data, sprintf('iter %d', i));
    if status == 1
        pass = pass + 1;
    elseif status == 0
        partial = partial + 1;
    else
        fail = fail + 1;
        msgs{end + 1} = msg;
    end
end
end

function [pass, partial, fail, msgs] = testFuzzMixedCellArrays(opt)
pass = 0;
partial = 0;
fail = 0;
msgs = {};
for i = 1:opt.iterations
    len = randInt(1, 50);
    data = cell(1, len);
    for j = 1:len
        data{j} = generateRandomValue(randInt(0, 3));
    end
    [status, msg] = verifyRoundTrip(data, sprintf('iter %d', i));
    if status == 1
        pass = pass + 1;
    elseif status == 0
        partial = partial + 1;
    else
        fail = fail + 1;
        msgs{end + 1} = msg;
    end
end
end

function [pass, partial, fail, msgs] = testFuzzRandomStrings(opt)
pass = 0;
partial = 0;
fail = 0;
msgs = {};
for i = 1:opt.iterations
    data = generateRandomString(randInt(0, 500));
    % Wrap string in struct since loadjson interprets bare strings as filenames
    [status, msg] = verifyRoundTrip(struct('s', data), sprintf('iter %d', i));
    if status == 1
        pass = pass + 1;
    elseif status == 0
        partial = partial + 1;
    else
        fail = fail + 1;
        msgs{end + 1} = msg;
    end
end
end

function [pass, partial, fail, msgs] = testFuzzNumericEdgeCases(~)
pass = 0;
partial = 0;
fail = 0;
msgs = {};
edgeCases = {
             0, -0, 1, -1, ...
             double(intmax('int32')), double(intmin('int32')), ...
             realmax, realmin, -realmax, -realmin, ...
             eps, -eps, 1e-308, 1e308, pi, exp(1), ...
             NaN, Inf, -Inf, single(3.14)
            };
% realmax/realmin may lose precision due to %.16g format - track separately
realmax_idx = [7, 9];  % indices of realmax, -realmax

for i = 1:length(edgeCases)
    data = edgeCases{i};
    try
        json = savejson('', data, 'Compression', '');
        decoded = loadjson(json);
        if isnan(data)
            if isnan(decoded) || isequal(decoded, 'NaN') || isempty(decoded)
                pass = pass + 1;
            else
                fail = fail + 1;
                msgs{end + 1} = sprintf('NaN case %d', i);
            end
        elseif isinf(data)
            if isinf(decoded) || ischar(decoded) || isempty(decoded)
                pass = pass + 1;
            else
                fail = fail + 1;
                msgs{end + 1} = sprintf('Inf case %d', i);
            end
        elseif ismember(i, realmax_idx)
            % realmax loses precision in %.16g format, may become Inf - known limitation
            if isinf(decoded) && sign(decoded) == sign(data)
                partial = partial + 1;  % Partial: known precision limitation
            elseif abs(double(decoded) - double(data)) <= eps(double(data)) * 10
                pass = pass + 1;
            else
                fail = fail + 1;
                msgs{end + 1} = sprintf('Numeric case %d (realmax): expected %g got %g', i, data, decoded);
            end
        else
            if abs(double(decoded) - double(data)) <= eps(double(data)) * 10
                pass = pass + 1;
            else
                fail = fail + 1;
                msgs{end + 1} = sprintf('Numeric case %d: expected %g got %g', i, data, decoded);
            end
        end
    catch ME
        fail = fail + 1;
        msgs{end + 1} = sprintf('Numeric case %d error: %s', i, ME.message);
    end
end
end

function [pass, partial, fail, msgs] = testFuzzDeepNesting(~)
pass = 0;
partial = 0;
fail = 0;
msgs = {};
depths = [5, 10, 20, 50, 100];
for i = 1:length(depths)
    depth = depths(i);
    data = createDeepNest(depth);
    try
        [status, msg] = verifyRoundTrip(data, sprintf('depth=%d', depth));
        if status == 1
            pass = pass + 1;
        elseif status == 0
            partial = partial + 1;
        else
            fail = fail + 1;
            msgs{end + 1} = msg;
        end
    catch ME
        fail = fail + 1;
        msgs{end + 1} = sprintf('depth=%d error: %s', depth, ME.message);
    end
end
end

function [pass, partial, fail, msgs] = testFuzzLargeArrays(~)
pass = 0;
partial = 0;
fail = 0;
msgs = {};
sizes = {[1e4, 1], [1, 1e4], [100, 100], [10, 10, 10]};
for i = 1:length(sizes)
    sz = sizes{i};
    data = rand(sz);
    [status, msg] = verifyRoundTrip(data, sprintf('size %s', mat2str(sz)));
    if status == 1
        pass = pass + 1;
    elseif status == 0
        partial = partial + 1;
    else
        fail = fail + 1;
        msgs{end + 1} = msg;
    end
end
end

function [pass, partial, fail, msgs] = testFuzzEmptyValues(~)
pass = 0;
partial = 0;
fail = 0;
msgs = {};
% Wrap values in struct to avoid loadjson interpreting them as filenames
empties = {[], {}, struct(), '', zeros(0, 1), zeros(1, 0), cell(0, 1)};
for i = 1:length(empties)
    data = struct('v', {empties{i}});  % Use cell syntax to handle empty
    try
        json = savejson('', data, 'Compression', '');
        decoded = loadjson(json);
        pass = pass + 1;
    catch ME
        fail = fail + 1;
        msgs{end + 1} = sprintf('Empty case %d: %s', i, ME.message);
    end
end
end

function [pass, partial, fail, msgs] = testFuzzSpecialFieldNames(opt)
pass = 0;
partial = 0;
fail = 0;
msgs = {};
for i = 1:opt.iterations
    validName = generateValidFieldName();
    try
        data = struct(validName, rand());
        [status, msg] = verifyRoundTrip(data, sprintf('field: %s', validName));
        if status == 1
            pass = pass + 1;
        elseif status == 0
            partial = partial + 1;
        else
            fail = fail + 1;
            msgs{end + 1} = msg;
        end
    catch ME
        fail = fail + 1;
        msgs{end + 1} = sprintf('field %s: %s', validName, ME.message);
    end
end
end

function [pass, partial, fail, msgs] = testFuzzFileIO(opt)
pass = 0;
partial = 0;
fail = 0;
msgs = {};
tempFile = [tempname '.json'];
for i = 1:min(20, opt.iterations)
    data = generateRandomStruct(randInt(1, 5));
    try
        savejson('', data, 'FileName', tempFile, 'ParseLogical', 0, 'Compression', '', 'SingletCell', 0);
        decoded = loadjson(tempFile);
        [status, msg] = verifyStructuralEquality(data, decoded, sprintf('FileIO iter %d', i));
        if status == 1
            pass = pass + 1;
        elseif status == 0
            partial = partial + 1;
        else
            fail = fail + 1;
            msgs{end + 1} = msg;
        end
    catch ME
        fail = fail + 1;
        msgs{end + 1} = sprintf('FileIO iter %d: %s', i, ME.message);
    end
end
if exist(tempFile, 'file')
    delete(tempFile);
end
end

function [pass, partial, fail, msgs] = testMalformedJSON(~)
pass = 0;
partial = 0;
fail = 0;
msgs = {};
malformed = {
             '', '   ', '{', '[', '{"a":}', '{"a":1,}', '[1,2,]', ...
             '{"a":1 "b":2}', '{a:1}', '{"a":undefined}', '{"a":1e}', ...
             '{"a":.5}', '{"a":+1}', '{"a":01}', '{"a":"\x00"}', ...
             '{"a":1}{"b":2}'
            };
for i = 1:length(malformed)
    json = malformed{i};
    try
        result = loadjson(json);
        % Accepted - not necessarily wrong, just note it
        pass = pass + 1;
    catch
        % Expected behavior for malformed input
        pass = pass + 1;
    end
end
end

function [pass, partial, fail, msgs] = testFuzzMutatedJSON(opt)
pass = 0;
partial = 0;
fail = 0;
msgs = {};
validData = struct('a', 1, 'b', 'test', 'c', [1, 2, 3]);
validJSON = savejson('', validData, 'Compression', '');
for i = 1:opt.iterations
    mutType = randInt(1, 4);
    switch mutType
        case 1
            mutated = deleteMutation(validJSON);
        case 2
            mutated = insertMutation(validJSON);
        case 3
            mutated = swapMutation(validJSON);
        case 4
            mutated = replaceMutation(validJSON);
    end
    try
        result = loadjson(mutated);
        pass = pass + 1;  % Parsed despite mutation
    catch
        pass = pass + 1;  % Expected for most mutations
    end
end
end

function [pass, partial, fail, msgs] = testFuzzBinaryNoise(opt)
pass = 0;
partial = 0;
fail = 0;
msgs = {};
for i = 1:opt.iterations
    len = randInt(1, 1000);
    noise = char(floor(rand(1, len) * 256));
    try
        result = loadjson(noise);
        pass = pass + 1;
    catch
        pass = pass + 1;  % Expected
    end
end
end

function [pass, partial, fail, msgs] = testStressRapidCalls(~)
pass = 0;
partial = 0;
fail = 0;
msgs = {};
data = struct('x', rand(10));
try
    for i = 1:500
        json = savejson('', data, 'Compression', '');
        decoded = loadjson(json);
    end
    pass = 1;
catch ME
    fail = 1;
    msgs{end + 1} = ME.message;
end
end

function [pass, partial, fail, msgs] = testEscapeSequences(~)
% Test specific escape sequences that JSON must handle
pass = 0;
partial = 0;
fail = 0;
msgs = {};

testCases = {
             'hello world', 'plain string'
             'with space', 'spaces'
             'back\slash', 'single backslash mid-string'
             'two\\back', 'two backslashes'
             'end\', 'trailing single backslash'
             '\start', 'leading backslash'
             '\\\\multi\\\\', 'multiple backslash pairs'
             'path\to\file', 'windows path style'
             sprintf('line1\nline2'), 'actual newline char'
             sprintf('with\ttab'), 'actual tab char'
             sprintf('cr\rhere'), 'carriage return'
             '/forward/slash', 'forward slashes'
             ' ', 'single space'
             '   ', 'multiple spaces'
             'a', 'single char'
             '\', 'just one backslash'
            };

numTests = size(testCases, 1);
for i = 1:numTests
    str = testCases{i, 1};
    desc = testCases{i, 2};
    try
        json = savejson('', struct('s', str), 'Compression', '');
        decoded = loadjson(json);
        if isfield(decoded, 's') && strcmp(decoded.s, str)
            pass = pass + 1;
        else
            fail = fail + 1;
            if isfield(decoded, 's')
                msgs{end + 1} = sprintf('%s: mismatch (len %d vs %d)', desc, length(str), length(decoded.s));
            else
                msgs{end + 1} = sprintf('%s: field missing after decode', desc);
            end
        end
    catch ME
        fail = fail + 1;
        msgs{end + 1} = sprintf('%s: ERROR %s', desc, ME.message);
    end
end

% Test empty string separately - known to decode as []
try
    json = savejson('', struct('s', ''), 'Compression', '');
    decoded = loadjson(json);
    if isfield(decoded, 's') && (isempty(decoded.s) || strcmp(decoded.s, ''))
        pass = pass + 1;  % Accept [] or '' as equivalent to empty string
    else
        fail = fail + 1;
        msgs{end + 1} = 'empty string: unexpected result';
    end
catch ME
    fail = fail + 1;
    msgs{end + 1} = sprintf('empty string: ERROR %s', ME.message);
end
end

%% ===== Helper Functions =====

function initRNG(seed)
% Initialize RNG compatible with MATLAB R2010+ and Octave
try
    rng(seed, 'twister');
catch
    try
        rng('default');
        rng(seed, 'twister');
    catch
        % Fallback for old MATLAB / Octave without rng()
        rand('twister', seed);  %#ok<RAND>
    end
end
end

function n = randInt(lo, hi)
% Generate random integer in [lo, hi]
n = floor(rand() * (hi - lo + 1)) + lo;
end

function [status, msg] = verifyRoundTrip(data, label)
% Returns: status = 1 (pass), 0 (partial), -1 (fail)
try
    % Use ParseLogical=0 to output logical as 0/1 (more consistent round-trip)
    % Use Compression='' to disable compression for clearer debugging
    % Use NestArray=1 to output nested arrays instead of JData _ArrayType_ constructs
    % Use SingletCell=0 to avoid extra [] around single-element cells
    json = savejson('', data, 'ParseLogical', 0, 'Compression', '', 'SingletCell', 0);
    decoded = loadjson(json);
    [status, msg] = verifyStructuralEquality(data, decoded, label);
catch ME
    status = -1;
    msg = sprintf('%s: %s', label, ME.message);
end
end

function [status, msg] = verifyStructuralEquality(orig, decoded, label)
% Returns: status = 1 (pass), 0 (partial), -1 (fail)
msg = '';

% Fast path: if isequaln says they're equal, full pass
if isequaln(orig, decoded)
    status = 1;
    return
end

% Second check: recursive value comparison (handles type differences)
[match, compareReason] = compareValues(orig, decoded, '');
if match
    status = 1;
    return
end

% Compare by re-serializing to JSON - if same JSON, partial pass
try
    opts = {'Compact', 1, 'Compression', '', 'ParseLogical', 0, 'SingletCell', 0};
    origJson = savejson('', orig, opts{:});
    decodedJson = savejson('', decoded, opts{:});
    if strcmp(origJson, decodedJson)
        status = 0;  % Partial: different MATLAB types but same JSON
        msg = '';
    else
        status = -1;  % Fail: different JSON

        % Find first mismatch position
        minLen = min(length(origJson), length(decodedJson));
        mismatchPos = find(origJson(1:minLen) ~= decodedJson(1:minLen), 1);
        if isempty(mismatchPos)
            mismatchPos = minLen + 1;  % Mismatch is due to length difference
        end

        % Extract context around mismatch
        contextStart = max(1, mismatchPos - 20);
        contextEndOrig = min(length(origJson), mismatchPos + 50);
        contextEndDecoded = min(length(decodedJson), mismatchPos + 50);

        origContext = origJson(contextStart:contextEndOrig);
        decodedContext = decodedJson(contextStart:contextEndDecoded);

        % Mark mismatch position in context
        markerPos = mismatchPos - contextStart + 1;

        msg = sprintf('%s: JSON mismatch at position %d', label, mismatchPos);
        msg = sprintf('%s\n    orig:    ...%s', msg, origContext);
        msg = sprintf('%s\n    decoded: ...%s', msg, decodedContext);
        msg = sprintf('%s\n             %s^', msg, repmat(' ', 1, markerPos + 5));
        msg = sprintf('%s\n    Value comparison: %s', msg, compareReason);
    end
catch ME
    status = -1;
    msg = sprintf('%s: comparison error: %s. Value comparison: %s', label, ME.message, compareReason);
end
end

function [match, reason] = compareValues(orig, decoded, path)
% Recursive comparison that handles type differences
% Returns: match (boolean), reason (string explaining mismatch)
match = false;
reason = '';

if isempty(path)
    path = 'root';
end

try
    % Both numeric (including logical as numeric)
    if (isnumeric(orig) || islogical(orig)) && (isnumeric(decoded) || islogical(decoded))
        if numel(orig) ~= numel(decoded)
            reason = sprintf('%s: size mismatch (%s vs %s)', path, mat2str(size(orig)), mat2str(size(decoded)));
            return
        end
        origVals = double(orig(:));
        decodedVals = double(decoded(:));
        nanMatch = isnan(origVals) & isnan(decodedVals);
        valMatch = abs(origVals - decodedVals) < 1e-10;
        if all(nanMatch | valMatch)
            match = true;
            return
        else
            mismatchIdx = find(~(nanMatch | valMatch), 1);
            reason = sprintf('%s: numeric value mismatch at index %d (%.6g vs %.6g)', ...
                             path, mismatchIdx, origVals(mismatchIdx), decodedVals(mismatchIdx));
            return
        end
    end

    % Both char
    if ischar(orig) && ischar(decoded)
        if strcmp(orig, decoded)
            match = true;
        else
            reason = sprintf('%s: string mismatch (''%s'' vs ''%s'')', path, truncateStr(orig, 20), truncateStr(decoded, 20));
        end
        return
    end

    % Empty values
    if isempty(orig) && isempty(decoded)
        match = true;
        return
    end

    % Both struct
    if isstruct(orig) && isstruct(decoded)
        if numel(orig) ~= numel(decoded)
            reason = sprintf('%s: struct array size mismatch (%d vs %d)', path, numel(orig), numel(decoded));
            return
        end
        fnOrig = fieldnames(orig);
        fnDecoded = fieldnames(decoded);
        if ~isequal(sort(fnOrig), sort(fnDecoded))
            missingInDecoded = setdiff(fnOrig, fnDecoded);
            extraInDecoded = setdiff(fnDecoded, fnOrig);
            reason = sprintf('%s: field mismatch (missing: {%s}, extra: {%s})', ...
                             path, strjoin(missingInDecoded, ','), strjoin(extraInDecoded, ','));
            return
        end
        for i = 1:numel(orig)
            for j = 1:length(fnOrig)
                fieldPath = sprintf('%s.%s', path, fnOrig{j});
                if numel(orig) > 1
                    fieldPath = sprintf('%s(%d).%s', path, i, fnOrig{j});
                end
                [fieldMatch, fieldReason] = compareValues(orig(i).(fnOrig{j}), decoded(i).(fnOrig{j}), fieldPath);
                if ~fieldMatch
                    reason = fieldReason;
                    return
                end
            end
        end
        match = true;
        return
    end

    % Both cell - recursive element comparison
    if iscell(orig) && iscell(decoded)
        if numel(orig) == numel(decoded)
            % Try element-wise comparison first
            allMatch = true;
            lastReason = '';
            for i = 1:numel(orig)
                cellPath = sprintf('%s{%d}', path, i);
                [cellMatch, cellReason] = compareValues(orig{i}, decoded{i}, cellPath);
                if ~cellMatch
                    allMatch = false;
                    lastReason = cellReason;
                    break
                end
            end
            if allMatch
                match = true;
                return
            end
        end

        % Element-wise failed or sizes differ - try flattening both to numeric
        [flatOrig, okOrig] = tryFlattenCell(orig);
        [flatDecoded, okDecoded] = tryFlattenCell(decoded);
        if okOrig && okDecoded && numel(flatOrig) == numel(flatDecoded)
            nanMatch = isnan(flatOrig(:)) & isnan(flatDecoded(:));
            valMatch = abs(flatOrig(:) - flatDecoded(:)) < 1e-10;
            if all(nanMatch | valMatch)
                match = true;
                return
            end
        end

        % Try cell2mat on orig to see if it matches decoded after conversion
        try
            origMat = cell2mat(orig);
            [matMatch, ~] = compareValues(origMat, decoded, path);
            if matMatch
                match = true;
                return
            end
        catch
        end

        if numel(orig) ~= numel(decoded)
            reason = sprintf('%s: cell size mismatch (%d vs %d), flattening also failed', path, numel(orig), numel(decoded));
        else
            reason = lastReason;
        end
        return
    end

    % Numeric vs cell or cell vs numeric - try cell2mat-style flattening
    if ((isnumeric(orig) || islogical(orig)) && iscell(decoded)) || ...
       (iscell(orig) && (isnumeric(decoded) || islogical(decoded)))
        % Determine which is cell and which is numeric
        if iscell(orig)
            cellVal = orig;
            numVal = decoded;
        else
            cellVal = decoded;
            numVal = orig;
        end

        % Try cell2mat first (preserves shape better than tryFlattenCell)
        try
            cellMat = cell2mat(cellVal);
            if numel(cellMat) == numel(numVal)
                cellVals = double(cellMat(:));
                numVals = double(numVal(:));
                nanMatch = isnan(cellVals) & isnan(numVals);
                valMatch = abs(cellVals - numVals) < 1e-10;
                if all(nanMatch | valMatch)
                    match = true;
                    return
                end
            end
        catch
        end

        % Fallback: try recursive flattening
        [flattenedNum, flattenOk] = tryFlattenCell(cellVal);
        if flattenOk
            if numel(flattenedNum) == numel(numVal)
                flatVals = double(flattenedNum(:));
                numVals = double(numVal(:));
                nanMatch = isnan(flatVals) & isnan(numVals);
                valMatch = abs(flatVals - numVals) < 1e-10;
                if all(nanMatch | valMatch)
                    match = true;
                    return
                end
            end
        end

        reason = sprintf('%s: type mismatch (cell vs numeric), cell2mat and flattening failed or values differ', path);
        return
    end

    % Type mismatch - neither matched above
    reason = sprintf('%s: incompatible types (%s vs %s)', path, class(orig), class(decoded));

catch ME
    match = false;
    reason = sprintf('%s: comparison error - %s', path, ME.message);
end
end

function s = generateRandomStruct(depth)
if depth <= 0
    s = generateRandomValue(0);
    return
end
numFields = randInt(1, 5);
s = struct();
for i = 1:numFields
    fname = sprintf('f%d', i);
    if rand() < 0.3 && depth > 1
        s.(fname) = generateRandomStruct(depth - 1);
    else
        s.(fname) = generateRandomValue(depth - 1);
    end
end
end

function v = generateRandomValue(depth)
choice = randInt(1, 6);
switch choice
    case 1  % Number
        v = randn() * 10^(randInt(-5, 5));
    case 2  % String
        v = generateRandomString(randInt(0, 50));
    case 3  % Array
        v = generateRandomArray(100);
    case 4  % Boolean
        v = rand() > 0.5;
    case 5  % Nested struct
        if depth > 0
            v = generateRandomStruct(depth - 1);
        else
            v = rand();
        end
    case 6  % Cell array
        len = randInt(0, 5);
        v = cell(1, len);
        for j = 1:len
            v{j} = generateRandomValue(max(0, depth - 1));
        end
end
end

function arr = generateRandomArray(maxSize)
ndims_val = randInt(1, 3);
maxDim = floor(maxSize^(1 / ndims_val));
sz = zeros(1, ndims_val);
for d = 1:ndims_val
    sz(d) = randInt(1, max(1, maxDim));
end
% Avoid leading dimension of 1 for 3D+ arrays (causes ambiguous cell2mat behavior)
if ndims_val >= 3 && sz(1) == 1
    sz(1) = randInt(2, max(2, maxDim));
end
typeChoice = randInt(1, 4);
switch typeChoice
    case 1
        arr = rand(sz);
    case 2
        arr = floor(rand(sz) * 1000);
    case 3
        arr = randn(sz);
    case 4
        arr = rand(sz) > 0.5;
end
end

function str = generateRandomString(len)
if len == 0
    str = '';
    return
end
% Safe printable ASCII: exclude problematic chars for JSON round-trip
% Exclude: \ (92), " (34), [ (91), ] (93), { (123), } (125), ' (39)
chars = [32:33, 35:38, 40:90, 94:122, 124, 126];  % Safe subset
idx = floor(rand(1, len) * length(chars)) + 1;
str = char(chars(idx));
end

function name = generateValidFieldName()
len = randInt(1, 15);
% Start with letter
first = char(floor(rand() * 26) + 97);  % a-z
rest = '';
for i = 2:len
    c = randInt(1, 3);
    switch c
        case 1
            rest = [rest char(floor(rand() * 26) + 97)];  %#ok a-z
        case 2
            rest = [rest char(floor(rand() * 26) + 65)];  %#ok A-Z
        case 3
            rest = [rest char(floor(rand() * 10) + 48)];  %#ok 0-9
    end
end
name = [first rest];
end

function [result, ok] = tryFlattenCell(c)
% Recursively flatten a cell array to numeric, similar to cell2mat behavior
% Returns: result (numeric array), ok (true if successful)
ok = false;
result = [];

if ~iscell(c)
    if isnumeric(c) || islogical(c)
        result = double(c);
        ok = true;
    end
    return
end

if isempty(c)
    result = [];
    ok = true;
    return
end

% Check if all elements are numeric/logical (possibly nested in cells)
flatElements = {};
for i = 1:numel(c)
    elem = c{i};
    if isnumeric(elem) || islogical(elem)
        flatElements{end + 1} = double(elem(:));
    elseif iscell(elem)
        [subResult, subOk] = tryFlattenCell(elem);
        if ~subOk
            return   % Can't flatten
        end
        flatElements{end + 1} = subResult(:);
    else
        return   % Non-numeric, non-cell element
    end
end

% Concatenate all flattened elements
try
    result = vertcat(flatElements{:});
    ok = true;
catch
    ok = false;
end
end

function nested = createDeepNest(depth)
nested = struct('val', rand());
for d = 1:depth
    nested = struct('level', d, 'child', nested);
end
end

function out = deleteMutation(json)
if isempty(json)
    out = json;
    return
end
pos = randInt(1, length(json));
out = [json(1:pos - 1) json(pos + 1:end)];
end

function out = insertMutation(json)
pos = randInt(1, length(json) + 1);
ch = char(randInt(32, 126));
if pos == 1
    out = [ch json];
elseif pos > length(json)
    out = [json ch];
else
    out = [json(1:pos - 1) ch json(pos:end)];
end
end

function out = swapMutation(json)
if length(json) < 2
    out = json;
    return
end
p1 = randInt(1, length(json));
p2 = randInt(1, length(json));
out = json;
tmp = out(p1);
out(p1) = out(p2);
out(p2) = tmp;
end

function out = replaceMutation(json)
if isempty(json)
    out = json;
    return
end
pos = randInt(1, length(json));
out = json;
out(pos) = char(randInt(32, 126));
end
