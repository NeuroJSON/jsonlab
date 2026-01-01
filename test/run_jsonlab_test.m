function run_jsonlab_test(tests)
%
% run_jsonlab_test
%   or
% run_jsonlab_test(tests)
% run_jsonlab_test({'js','jso','bj','bjo','jmap','bmap','jpath','jdict','bugs','yaml','yamlopt','xarray','schema','jdictadv','schemaadv'})
%
% Unit testing for JSONLab JSON, BJData/UBJSON encoders and decoders
%
% authors:Qianqian Fang (q.fang <at> neu.edu)
% date: 2020/06/08
%
% input:
%      tests: is a cell array of strings, possible elements include
%         'js':  test savejson/loadjson
%         'jso': test savejson/loadjson special options
%         'bj':  test savebj/loadbj
%         'bjo': test savebj/loadbj special options
%         'jmap': test jsonmmap features in loadjson
%         'bmap': test jsonmmap features in loadbj
%         'jpath': test jsonpath
%         'jdict': test jdict
%         'bugs': test specific bug fixes
%         'yaml': test yaml reader/writer
%         'yamlopt': test yaml handling options
%         'xarray': test jdict data attribute operations
%         'schema': schema-attribute and jsonschema tests
%         'jdictadv': jdict corner cases
%         'schemaadv': jdict schema-guarded assignment and validate
%
% license:
%     BSD or GPL version 3, see LICENSE_{BSD,GPLv3}.txt files for details
%
% -- this function is part of JSONLab toolbox (http://iso2mesh.sf.net/cgi-bin/index.cgi?jsonlab)
%

if (nargin == 0)
    tests = {'js', 'jso', 'bj', 'bjo', 'jmap', 'bmap', 'jpath', ...
             'jdict', 'bugs', 'yaml', 'yamlopt', 'xarray', 'schema', 'jdictadv', 'schemaadv'};
end

try
    testmap = containers.Map();
    hasContainersMap = true;
catch
    hasContainersMap = false;
end

%%
if (ismember('js', tests))
    fprintf(sprintf('%s\n', char(ones(1, 79) * 61)));
    fprintf('Test JSON functions\n');
    fprintf(sprintf('%s\n', char(ones(1, 79) * 61)));

    test_jsonlab('single integer', @savejson, 5, '[5]');
    test_jsonlab('single float', @savejson, 3.14, '[3.14]');
    test_jsonlab('nan', @savejson, nan, '["_NaN_"]');
    test_jsonlab('inf', @savejson, inf, '["_Inf_"]');
    test_jsonlab('-inf', @savejson, -inf, '["-_Inf_"]');
    test_jsonlab('large integer', @savejson, uint64(2^64), '[18446744073709551616]');
    test_jsonlab('large negative integer', @savejson, int64(-2^63), '[-9223372036854775808]');
    test_jsonlab('boolean as 01', @savejson, [true, false], '[1,0]', 'compact', 1);
    test_jsonlab('empty array', @savejson, [], '[]');
    test_jsonlab('empty cell', @savejson, {}, '[]');
    test_jsonlab('empty struct', @savejson, struct, '{}', 'compact', 1);
    test_jsonlab('empty struct with fields', @savejson, repmat(struct('a', 1), 0, 1), '[]');
    test_jsonlab('empty string', @savejson, '', '""', 'compact', 1);
    test_jsonlab('string escape', @savejson, sprintf('jdata\n\b\ashall\tprevail\t"\"\\'), '"jdata\n\b\ashall\tprevail\t\"\"\\"');
    if (exist('string'))
        test_jsonlab('string type', @savejson, string(sprintf('jdata\n\b\ashall\tprevail')), '"jdata\n\b\ashall\tprevail"', 'compact', 1);
        test_jsonlab('string array', @savejson, [string('jdata'), string('shall'), string('prevail')], '["jdata","shall","prevail"]', 'compact', 1);
    end
    test_jsonlab('empty name', @savejson, loadjson('{"":""}'), '{"":""}', 'compact', 1);
    if (hasContainersMap)
        if (~(exist('OCTAVE_VERSION', 'builtin') ~= 0 && ~isempty(regexp(OCTAVE_VERSION, '^[89]\.'))))
            test_jsonlab('empty name with map', @savejson, loadjson('{"":""}', 'usemap', 1), '{"":""}', 'compact', 1);
        end
        test_jsonlab('indentation', @savejson, savejson('s', containers.Map({'a', 'b'}, {[], struct('c', 1.1, 'd', struct('e', {1, 2}))})), ...
                     '"{\n\t\"s\":{\n\t\t\"a\":[],\n\t\t\"b\":{\n\t\t\t\"c\":1.1,\n\t\t\t\"d\":[\n\t\t\t\t{\n\t\t\t\t\t\"e\":1\n\t\t\t\t},\n\t\t\t\t{\n\t\t\t\t\t\"e\":2\n\t\t\t\t}\n\t\t\t]\n\t\t}\n\t}\n}\n"');
        test_jsonlab('key longer than 63', @savejson, loadjson('{"...........":""}', 'usemap', 0), '{"...........":""}', 'compact', 1);
    end
    test_jsonlab('row vector', @savejson, [1, 2, 3], '[1,2,3]');
    test_jsonlab('column vector', @savejson, [1; 2; 3], '[[1],[2],[3]]', 'compact', 1);
    test_jsonlab('mixed array', @savejson, {'a', 1, 0.9}, '["a",1,0.9]', 'compact', 1);
    test_jsonlab('mixed array from string', @savejson, loadjson('["a",{"c":1}, [2,3]]'), '["a",{"c":1},[2,3]]', 'compact', 1);
    test_jsonlab('char array', @savejson, ['AC'; 'EG'], '["AC","EG"]', 'compact', 1);
    test_jsonlab('maps', @savejson, struct('a', 1, 'b', 'test'), '{"a":1,"b":"test"}', 'compact', 1);
    test_jsonlab('2d array', @savejson, [1, 2, 3; 4, 5, 6], '[[1,2,3],[4,5,6]]', 'compact', 1);
    test_jsonlab('non-uniform 2d array', @savejson, {[1, 2], [3, 4, 5], [6, 7]}, '[[1,2],[3,4,5],[6,7]]', 'compact', 1);
    test_jsonlab('non-uniform array with length multiple of first element', @savejson, {[1, 2], [3, 4, 5, 6], [7, 8]}, '[[1,2],[3,4,5,6],[7,8]]', 'compact', 1);
    test_jsonlab('1d array with flexible white space', @savejson, loadjson(sprintf(' [ +1, \n -2e3 \n , 3.0E+00 ,\r+4e-0] ')), '[1,-2000,3,4]', 'compact', 1);
    test_jsonlab('2d array with flexible white space', @savejson, loadjson(sprintf(' [\r [\n 1 , \r\n  2\n, 3] ,\n[ 4, 5 , \t 6\t]\n] ')), '[[1,2,3],[4,5,6]]', 'compact', 1);
    test_jsonlab('3d (row-major) nested array', @savejson, reshape(1:(2 * 3 * 2), 2, 3, 2), ...
                 '[[[1,7],[3,9],[5,11]],[[2,8],[4,10],[6,12]]]', 'compact', 1, 'nestarray', 1);
    test_jsonlab('3d (column-major) nested array', @savejson, reshape(1:(2 * 3 * 2), 2, 3, 2), ...
                 '[[[1,2],[3,4],[5,6]],[[7,8],[9,10],[11,12]]]', 'compact', 1, 'nestarray', 1, 'formatversion', 1.9);
    test_jsonlab('3d annotated array', @savejson, reshape(int8(1:(2 * 3 * 2)), 2, 3, 2), ...
                 '{"_ArrayType_":"int8","_ArraySize_":[2,3,2],"_ArrayData_":[1,7,3,9,5,11,2,8,4,10,6,12]}', 'compact', 1);
    test_jsonlab('complex number', @savejson, single(2 + 4i), ...
                 '{"_ArrayType_":"single","_ArraySize_":[1,1],"_ArrayIsComplex_":true,"_ArrayData_":[[2],[4]]}', 'compact', 1);
    test_jsonlab('empty sparse matrix', @savejson, sparse(2, 3), ...
                 '{"_ArrayType_":"double","_ArraySize_":[2,3],"_ArrayIsSparse_":true,"_ArrayData_":[]}', 'compact', 1);
    test_jsonlab('real sparse matrix', @savejson, sparse([0, 3, 0, 1, 4]'), ...
                 '{"_ArrayType_":"double","_ArraySize_":[5,1],"_ArrayIsSparse_":true,"_ArrayData_":[[2,4,5],[3,1,4]]}', 'compact', 1);
    test_jsonlab('complex sparse matrix', @savejson, sparse([0, 3i, 0, 1, 4i].'), ...
                 '{"_ArrayType_":"double","_ArraySize_":[5,1],"_ArrayIsComplex_":true,"_ArrayIsSparse_":true,"_ArrayData_":[[2,4,5],[0,1,0],[3,0,4]]}', 'compact', 1);
    test_jsonlab('heterogeneous cell', @savejson, {{1, {2, 3}}, {4, 5}, {6}; {7}, {8, 9}, {10}}, ...
                 '[[[1,[2,3]],[4,5],[6]],[[7],[8,9],[10]]]', 'compact', 1);
    test_jsonlab('struct array', @savejson, repmat(struct('i', 1.1, 'd', 'str'), [1, 2]), ...
                 '[{"i":1.1,"d":"str"},{"i":1.1,"d":"str"}]', 'compact', 1);
    test_jsonlab('encoded fieldnames', @savejson, struct(encodevarname('_i'), 1, encodevarname('i_'), 'str'), ...
                 '{"_i":1,"i_":"str"}', 'compact', 1);
    if (exist('OCTAVE_VERSION', 'builtin') ~= 0)
        test_jsonlab('encoded fieldnames without decoding', @savejson, struct(encodevarname('_i'), 1, encodevarname('i_'), 'str'), ...
                     '{"_i":1,"i_":"str"}', 'compact', 1, 'UnpackHex', 0);
    else
        test_jsonlab('encoded fieldnames without decoding', @savejson, struct(encodevarname('_i'), 1, encodevarname('i_'), 'str'), ...
                     '{"x0x5F_i":1,"i_":"str"}', 'compact', 1, 'UnpackHex', 0);
    end
    if (hasContainersMap)
        if (exist('string'))
            test_jsonlab('containers.Map with string keys', @savejson, containers.Map([string('Andy'), string('^_^')], {true, '-_-'}), ...
                         '{"Andy":true,"^_^":"-_-"}', 'compact', 1, 'usemap', 1);
        end
        test_jsonlab('containers.Map with char keys', @savejson, containers.Map({'Andy', '^_^'}, {true, '-_-'}), ...
                     '{"Andy":true,"^_^":"-_-"}', 'compact', 1, 'usemap', 1);
        test_jsonlab('containers.Map with number keys', @savejson, containers.Map({1.1, 1.2}, {true, '-_-'}), ...
                     '{"_MapData_":[[1.1,true],[1.2,"-_-"]]}', 'compact', 1, 'usemap', 1);
    end
    if (exist('dictionary'))
        if (exist('string'))
            test_jsonlab('dictionary with string keys', @savejson, dictionary([string('Andy'), string('^_^')], {true, '-_-'}), ...
                         '{"Andy":true,"^_^":"-_-"}', 'compact', 1, 'usemap', 1);
        end
        test_jsonlab('dictionary with cell keys', @savejson, dictionary({'Andy', '^_^'}, {true, '-_-'}), ...
                     '{"_MapData_":[["Andy",true],["^_^","-_-"]]}', 'compact', 1, 'usemap', 1);
        test_jsonlab('dictionary with number keys', @savejson, dictionary({1.1, 1.2}, {true, '-_-'}), ...
                     '{"_MapData_":[[1.1,true],[1.2,"-_-"]]}', 'compact', 1, 'usemap', 1);
    end
    if (exist('istable'))
        test_jsonlab('simple table', @savejson, table({'Andy', '^_^'}, {true, '-_-'}), ...
                     '{"_TableCols_":["Var1","Var2"],"_TableRows_":[],"_TableRecords_":[["Andy","^_^"],[true,"-_-"]]}', 'compact', 1);
    end
    if (exist('bandwidth'))
        lband = 2;
        uband = 1;
        a = double(full(spdiags(true(4, lband + uband + 1), -uband:lband, 3, 4)));
        a(a ~= 0) = find(a);

        test_jsonlab('lower band matrix', @savejson, tril(a), ...
                     '{"_ArrayType_":"double","_ArraySize_":[3,4],"_ArrayZipSize_":[2,3],"_ArrayShape_":["lowerband",1],"_ArrayData_":[1,5,9,0,2,6]}', 'compact', 1, 'usearrayshape', 1);
        test_jsonlab('upper band matrix', @savejson, triu(a), ...
                     '{"_ArrayType_":"double","_ArraySize_":[3,4],"_ArrayZipSize_":[3,3],"_ArrayShape_":["upperband",2],"_ArrayData_":[7,11,0,4,8,12,1,5,9]}', 'compact', 1, 'usearrayshape', 1);
        test_jsonlab('diag matrix', @savejson, tril(triu(a)), ...
                     '{"_ArrayType_":"double","_ArraySize_":[3,4],"_ArrayShape_":"diag","_ArrayData_":[1,5,9]}', 'compact', 1, 'usearrayshape', 1);
        test_jsonlab('band matrix', @savejson, a, ...
                     '{"_ArrayType_":"double","_ArraySize_":[3,4],"_ArrayZipSize_":[4,3],"_ArrayShape_":["band",2,1],"_ArrayData_":[7,11,0,4,8,12,1,5,9,0,2,6]}', 'compact', 1, 'usearrayshape', 1);
        a = a(:, 1:3);
        a = uint8(tril(a) + tril(a)');
        test_jsonlab('symmetric band matrix', @savejson, a, ...
                     '{"_ArrayType_":"uint8","_ArraySize_":[3,3],"_ArrayZipSize_":[2,3],"_ArrayShape_":["lowersymmband",1],"_ArrayData_":[2,10,18,0,2,6]}', 'compact', 1, 'usearrayshape', 1);
        a(a == 0) = 1;
        test_jsonlab('lower triangular matrix', @savejson, tril(a), ...
                     '{"_ArrayType_":"uint8","_ArraySize_":[3,3],"_ArrayShape_":"lower","_ArrayData_":[2,2,10,1,6,18]}', 'compact', 1, 'usearrayshape', 1);
        test_jsonlab('upper triangular matrix', @savejson, triu(a), ...
                     '{"_ArrayType_":"uint8","_ArraySize_":[3,3],"_ArrayShape_":"upper","_ArrayData_":[2,2,1,10,6,18]}', 'compact', 1, 'usearrayshape', 1);
    end
    try
        val = zlibencode('test');
        a = uint8(eye(5));
        a(20, 1) = 1;
        test_jsonlab('zlib/zip compression (level 6)', @savejson, a, ...
                     sprintf('{"_ArrayType_":"uint8","_ArraySize_":[20,5],"_ArrayZipSize_":[1,100],"_ArrayZipType_":"zlib","_ArrayZipData_":"eJxjZAABRhwkxQBsDAACIQAH"}'), ...
                     'compact', 1, 'Compression', 'zlib', 'CompressArraySize', 0);  % nestarray for 4-D or above is not working
        test_jsonlab('gzip compression (level 6)', @savejson, a, ...
                     sprintf('{"_ArrayType_":"uint8","_ArraySize_":[20,5],"_ArrayZipSize_":[1,100],"_ArrayZipType_":"gzip","_ArrayZipData_":"H4sIAAAAAAAAA2NkAAFGHCTFAGwMAF9Xq6VkAAAA"}'), ...
                     'compact', 1, 'Compression', 'gzip', 'CompressArraySize', 0);  % nestarray for 4-D or above is not working
        test_jsonlab('lzma compression (level 5)', @savejson, a, ...
                     sprintf('{"_ArrayType_":"uint8","_ArraySize_":[20,5],"_ArrayZipSize_":[1,100],"_ArrayZipType_":"lzma","_ArrayZipData_":"XQAAEABkAAAAAAAAAAAAgD1IirvlZSEY7DH///taoAA="}'), ...
                     'compact', 1, 'Compression', 'lzma', 'CompressArraySize', 0);  % nestarray for 4-D or above is not working
    catch
    end
end
%%
if (ismember('jso', tests))
    fprintf(sprintf('%s\n', char(ones(1, 79) * 61)));
    fprintf('Test JSON function options\n');
    fprintf(sprintf('%s\n', char(ones(1, 79) * 61)));

    test_jsonlab('boolean', @savejson, [true, false], '[true,false]', 'compact', 1, 'ParseLogical', 1);
    test_jsonlab('nan option', @savejson, nan, '["_nan_"]', 'NaN', '"_nan_"');
    test_jsonlab('inf option', @savejson, -inf, '["-inf"]', 'Inf', '"$1inf"');
    test_jsonlab('output int format', @savejson, uint8(5), '[  5]', 'IntFormat', '%3d');
    test_jsonlab('output float format', @savejson, pi, '[3.142]', 'FloatFormat', '%5.3f');
    test_jsonlab('remove singlet array', @savejson, {struct('a', 1), 5}, '[{"a":1},5]', 'compact', 1, 'SingletArray', 0);
    test_jsonlab('keep singlet array', @savejson, {struct('a', 1), 5}, '[[{"a":[1]}],[5]]', 'compact', 1, 'SingletArray', 1);
    test_jsonlab('make null object roundtrip', @savejson, loadjson('{"a":null}'), '{"a":null}', 'EmptyArrayAsNull', 1, 'compact', 1);
    test_jsonlab('test no datalink', @savejson, loadjson(savejson('a', struct(encodevarname('_DataLink_'), ...
                                                                              '../examples/example2.json:$.glossary.title'))), '{"a":[{"_DataLink_":"../examples/example2.json:$.glossary.title"}]}', 'compact', 1, 'SingletArray', 1);
    test_jsonlab('test maxlinklevel', @savejson, loadjson(savejson('a', struct(encodevarname('_DataLink_'), ...
                                                                               '../examples/example2.json:$.glossary.title')), 'maxlinklevel', 1), '{"a":"example glossary"}', 'compact', 1, 'SingletArray', 1);
end

%%
if (ismember('bj', tests))
    fprintf(sprintf('%s\n', char(ones(1, 79) * 61)));
    fprintf('Test Binary JSON functions\n');
    fprintf(sprintf('%s\n', char(ones(1, 79) * 61)));

    test_jsonlab('uint8 integer', @savebj, 2^8 - 1, 'U<255>', 'debug', 1);
    test_jsonlab('uint16 integer', @savebj, 2^8, 'u<256>', 'debug', 1);
    test_jsonlab('int8 integer', @savebj, -2^7, 'i<-128>', 'debug', 1);
    test_jsonlab('int16 integer', @savebj, -2^7 - 1, 'I<-129>', 'debug', 1);
    test_jsonlab('int32 integer', @savebj, -2^15 - 1, 'l<-32769>', 'debug', 1);
    test_jsonlab('uint16 integer', @savebj, 2^16 - 1, 'u<65535>', 'debug', 1);
    test_jsonlab('uint32 integer', @savebj, 2^16, 'm<65536>', 'debug', 1);
    test_jsonlab('uint32 integer', @savebj, 2^32 - 1, 'm<4294967295>', 'debug', 1);
    test_jsonlab('int32 integer', @savebj, -2^31, 'l<-2147483648>', 'debug', 1);
    test_jsonlab('single float', @savebj, 3.14, 'D<3.14>', 'debug', 1);
    test_jsonlab('nan', @savebj, nan, 'D<NaN>', 'debug', 1);
    test_jsonlab('inf', @savebj, inf, 'D<Inf>', 'debug', 1);
    test_jsonlab('-inf', @savebj, -inf, 'D<-Inf>', 'debug', 1);
    test_jsonlab('uint64 integer', @savebj, uint64(2^64), 'M<18446744073709551616>', 'debug', 1);
    test_jsonlab('int64 negative integer', @savebj, int64(-2^63), 'L<-9223372036854775808>', 'debug', 1);
    test_jsonlab('boolean as 01', @savebj, [true, false], '[U<1>U<0>]', 'debug', 1, 'nestarray', 1);
    test_jsonlab('empty array', @savebj, [], 'Z', 'debug', 1);
    test_jsonlab('empty cell', @savebj, {}, 'Z', 'debug', 1);
    test_jsonlab('empty string', @savebj, '', 'SU<0>', 'debug', 1);
    test_jsonlab('skip no-op before marker and after value', @savebj, loadbj(char(['NN[NU' char(5) 'NNNU' char(1) ']'])), '[$U#U<2><5><1>', 'debug', 1);
    test_jsonlab('string escape', @savebj, sprintf('jdata\n\b\ashall\tprevail\t"\"\\'), sprintf('SU<25>jdata\n\b\ashall\tprevail\t\"\"\\'), 'debug', 1);
    if (exist('string') && isa(string('jdata'), 'string'))
        test_jsonlab('string type', @savebj, string(sprintf('jdata\n\b\ashall\tprevail')), sprintf('[SU<21>jdata\n\b\ashall\tprevail]'), 'debug', 1);
        test_jsonlab('string array', @savebj, [string('jdata'); string('shall'); string('prevail')], '[[SU<5>jdataSU<5>shallSU<7>prevail]]', 'debug', 1);
    end
    test_jsonlab('empty name', @savebj, loadbj(['{U' char(0) 'U' char(2) '}']), '{U<0>U<2>}', 'debug', 1);
    if (hasContainersMap)
        test_jsonlab('empty name with map', @savebj, loadbj(['{U' char(0) 'U' char(2) '}'], 'usemap', 1), '{U<0>U<2>}', 'debug', 1);
        test_jsonlab('key longer than 63', @savebj, loadbj(['{U' char(11) '...........U' char(2) '}'], 'usemap', 0), '{U<11>...........U<2>}', 'debug', 1);
    end
    test_jsonlab('row vector', @savebj, [1, 2, 3], '[$U#U<3><1><2><3>', 'debug', 1);
    test_jsonlab('column vector', @savebj, [1; 2; 3], '[$U#[$U#U<2><3><1><1><2><3>', 'debug', 1);
    test_jsonlab('mixed array', @savebj, {'a', 1, 0.9}, '[C<97>U<1>D<0.9>]', 'debug', 1);
    test_jsonlab('char array', @savebj, ['AC'; 'EG'], '[SU<2>ACSU<2>EG]', 'debug', 1);
    test_jsonlab('maps', @savebj, struct('a', 1, 'b', 'test'), '{U<1>aU<1>U<1>bSU<4>test}', 'debug', 1);
    test_jsonlab('2d array', @savebj, [1, 2, 3; 4, 5, 6], '[$U#[$U#U<2><2><3><1><2><3><4><5><6>', 'debug', 1);
    test_jsonlab('3d (row-major) nested array', @savebj, reshape(1:(2 * 3 * 2), 2, 3, 2), ...
                 '[[[U<1>U<7>][U<3>U<9>][U<5>U<11>]][[U<2>U<8>][U<4>U<10>][U<6>U<12>]]]', 'debug', 1, 'nestarray', 1);
    test_jsonlab('3d (column-major) nested array', @savebj, reshape(1:(2 * 3 * 2), 2, 3, 2), ...
                 '[[[U<1>U<2>][U<3>U<4>][U<5>U<6>]][[U<7>U<8>][U<9>U<10>][U<11>U<12>]]]', 'debug', 1, 'nestarray', 1, 'formatversion', 1.9);
    test_jsonlab('3d annotated array', @savebj, reshape(int8(1:(2 * 3 * 2)), 2, 3, 2), ...
                 '{U<11>_ArrayType_SU<4>int8U<11>_ArraySize_[$U#U<3><2><3><2>U<11>_ArrayData_[$U#U<12><1><7><3><9><5><11><2><8><4><10><6><12>}', 'debug', 1);
    test_jsonlab('complex number', @savebj, single(2 + 4i), ...
                 '{U<11>_ArrayType_SU<6>singleU<11>_ArraySize_[$U#U<2><1><1>U<16>_ArrayIsComplex_TU<11>_ArrayData_[$U#[$U#U<2><2><1><2><4>}', 'debug', 1);
    test_jsonlab('empty sparse matrix', @savebj, sparse(2, 3), ...
                 '{U<11>_ArrayType_SU<6>doubleU<11>_ArraySize_[$U#U<2><2><3>U<15>_ArrayIsSparse_TU<11>_ArrayData_Z}', 'debug', 1);
    test_jsonlab('real sparse matrix', @savebj, sparse([0, 3, 0, 1, 4]'), ...
                 '{U<11>_ArrayType_SU<6>doubleU<11>_ArraySize_[$U#U<2><5><1>U<15>_ArrayIsSparse_TU<11>_ArrayData_[$U#[$U#U<2><2><3><2><4><5><3><1><4>}', 'debug', 1);
    test_jsonlab('complex sparse matrix', @savebj, sparse([0, 3i, 0, 1, 4i].'), ...
                 '{U<11>_ArrayType_SU<6>doubleU<11>_ArraySize_[$U#U<2><5><1>U<16>_ArrayIsComplex_TU<15>_ArrayIsSparse_TU<11>_ArrayData_[$U#[$U#U<2><3><3><2><4><5><0><1><0><3><0><4>}', 'debug', 1);
    test_jsonlab('heterogeneous cell', @savebj, {{1, {2, 3}}, {4, 5}, {6}; {7}, {8, 9}, {10}}, ...
                 '[[[U<1>[U<2>U<3>]][U<4>U<5>][U<6>]][[U<7>][U<8>U<9>][U<10>]]]', 'debug', 1);
    test_jsonlab('struct array', @savebj, repmat(struct('i', 1.1, 'd', 'str'), [1, 2]), ...
                 '[{U<1>iD<1.1>U<1>dSU<3>str}{U<1>iD<1.1>U<1>dSU<3>str}]', 'debug', 1);
    test_jsonlab('encoded fieldnames', @savebj, struct(encodevarname('_i'), 1, encodevarname('i_'), 'str'), ...
                 '{U<2>_iU<1>U<2>i_SU<3>str}', 'debug', 1);
    test_jsonlab('optimized 2D row-major array', @savebj, loadbj(['[$i#[$U#U' char([2 2 3 61 62 65 66 67 68])]), '[$U#[$U#U<2><2><3><61><62><65><66><67><68>', 'debug', 1);
    test_jsonlab('optimized 2D column-major array', @savebj, loadbj(['[$U#[[$U#U' char([2 2 3]) ']' char([61 62 65 66 67 68])]), '[$U#[$U#U<2><2><3><61><65><67><62><66><68>', 'debug', 1);

    test_jsonlab('single byte', @savebj, loadbj(['B' char(65)]), 'C<65>', 'debug', 1);
    test_jsonlab('byte 1D vector', @savebj, loadbj(['[$B#U' char([3 61 62 65])]), 'SU<3>=>A', 'debug', 1);
    test_jsonlab('optimized byte 1D vector', @savebj, loadbj(['[$B#[$U#U' char([1 4 61 62 65 66])]), 'SU<4>=>AB', 'debug', 1);
    test_jsonlab('object with byte key', @savebj, loadbj(['{' 'i' char(3) 'lat' 'B' char(0) 'i' char(4) 'long' 'U' char(2) 'i' char(3) 'alt' 'B' char(210) '}']), '{U<3>latC<0>U<4>longU<2>U<3>altC<210>}', 'debug', 1);
    test_jsonlab('optimized object with byte key', @savebj, loadbj(['{$C#U' char(3) 'i' char(3) 'lat' char(10) 'i' char(4) 'long' char(9) 'i' char(3) 'alt' char(240)]), '{U<3>latC<10>U<4>longC<9>U<3>altC<240>}', 'debug', 1);

    if (exist('OCTAVE_VERSION', 'builtin') ~= 0)
        test_jsonlab('encoded fieldnames without decoding', @savebj, struct(encodevarname('_i'), 1, encodevarname('i_'), 'str'), ...
                     '{U<2>_iU<1>U<2>i_SU<3>str}', 'debug', 1, 'UnpackHex', 0);
    else
        test_jsonlab('encoded fieldnames without decoding', @savebj, struct(encodevarname('_i'), 1, encodevarname('i_'), 'str'), ...
                     '{U<7>x0x5F_iU<1>U<2>i_SU<3>str}', 'debug', 1, 'UnpackHex', 0);
    end
    if (hasContainersMap)
        test_jsonlab('containers.Map with char keys', @savebj, containers.Map({'Andy', '^_^'}, {true, '-_-'}), ...
                     '{U<4>AndyTU<3>^_^SU<3>-_-}', 'debug', 1, 'usemap', 1);
    end
    if (exist('dictionary'))
        test_jsonlab('dictionary with string keys', @savebj, dictionary([string('Andy'), string('^_^')], {true, '-_-'}), ...
                     '{U<4>AndyTU<3>^_^SU<3>-_-}', 'debug', 1, 'usemap', 1);
        test_jsonlab('dictionary with cell keys', @savebj, dictionary({'Andy', '^_^'}, {true, '-_-'}), ...
                     '{U<4>AndyTU<3>^_^SU<3>-_-}', 'debug', 1,  'usemap', 1);
    end
    if (exist('istable'))
        test_jsonlab('simple table', @savebj, table({'Andy', '^_^'}, {true, '-_-'}), ...
                     '{U<11>_TableCols_[SU<4>Var1SU<4>Var2]U<11>_TableRows_ZU<14>_TableRecords_[[SU<4>AndySU<3>^_^][TSU<3>-_-]]}', 'debug', 1);
    end
    if (exist('bandwidth'))
        lband = 2;
        uband = 1;
        a = double(full(spdiags(true(4, lband + uband + 1), -uband:lband, 3, 4)));
        a(a ~= 0) = find(a);

        test_jsonlab('lower band matrix', @savebj, tril(a), ...
                     '{U<11>_ArrayType_SU<6>doubleU<11>_ArraySize_[$U#U<2><3><4>U<14>_ArrayZipSize_[$U#U<2><2><3>U<12>_ArrayShape_[SU<9>lowerbandU<1>]U<11>_ArrayData_[$U#U<6><1><5><9><0><2><6>}', 'debug', 1, 'usearrayshape', 1);
        test_jsonlab('upper band matrix', @savebj, triu(a), ...
                     '{U<11>_ArrayType_SU<6>doubleU<11>_ArraySize_[$U#U<2><3><4>U<14>_ArrayZipSize_[$U#U<2><3><3>U<12>_ArrayShape_[SU<9>upperbandU<2>]U<11>_ArrayData_[$U#U<9><7><11><0><4><8><12><1><5><9>}', 'debug', 1, 'usearrayshape', 1);
        test_jsonlab('diag matrix', @savebj, tril(triu(a)), ...
                     '{U<11>_ArrayType_SU<6>doubleU<11>_ArraySize_[$U#U<2><3><4>U<12>_ArrayShape_SU<4>diagU<11>_ArrayData_[$U#U<3><1><5><9>}', 'debug', 1, 'usearrayshape', 1);
        test_jsonlab('band matrix', @savebj, a, ...
                     '{U<11>_ArrayType_SU<6>doubleU<11>_ArraySize_[$U#U<2><3><4>U<14>_ArrayZipSize_[$U#U<2><4><3>U<12>_ArrayShape_[SU<4>bandU<2>U<1>]U<11>_ArrayData_[$U#U<12><7><11><0><4><8><12><1><5><9><0><2><6>}', 'debug', 1, 'usearrayshape', 1);
        a = a(:, 1:3);
        a = uint8(tril(a) + tril(a)');
        test_jsonlab('symmetric band matrix', @savebj, a, ...
                     '{U<11>_ArrayType_SU<5>uint8U<11>_ArraySize_[$U#U<2><3><3>U<14>_ArrayZipSize_[$U#U<2><2><3>U<12>_ArrayShape_[SU<13>lowersymmbandU<1>]U<11>_ArrayData_[$U#U<6><2><10><18><0><2><6>}', 'debug', 1, 'usearrayshape', 1);
        a(a == 0) = 1;
        test_jsonlab('lower triangular matrix', @savebj, tril(a), ...
                     '{U<11>_ArrayType_SU<5>uint8U<11>_ArraySize_[$U#U<2><3><3>U<12>_ArrayShape_SU<5>lowerU<11>_ArrayData_[$U#U<6><2><2><10><1><6><18>}', 'debug', 1, 'usearrayshape', 1);
        test_jsonlab('upper triangular matrix', @savebj, triu(a), ...
                     '{U<11>_ArrayType_SU<5>uint8U<11>_ArraySize_[$U#U<2><3><3>U<12>_ArrayShape_SU<5>upperU<11>_ArrayData_[$U#U<6><2><2><1><10><6><18>}', 'debug', 1, 'usearrayshape', 1);
    end
    try
        val = zlibencode('test');
        a = uint8(eye(5));
        a(20, 1) = 1;
        test_jsonlab('zlib/zip compression (level 6)', @savebj, a, ...
                     '{U<11>_ArrayType_SU<5>uint8U<11>_ArraySize_[$U#U<2><20><5>U<14>_ArrayZipSize_[$U#U<2><1><100>U<14>_ArrayZipType_SU<4>zlibU<14>_ArrayZipData_[$U#U<18><120><156><99><100><0><1><70><28><36><197><0><108><12><0><2><33><0><7>}', ...
                     'debug', 1, 'Compression', 'zlib', 'CompressArraySize', 0);  % nestarray for 4-D or above is not working
        test_jsonlab('gzip compression (level 6)', @savebj, a, ...
                     '{U<11>_ArrayType_SU<5>uint8U<11>_ArraySize_[$U#U<2><20><5>U<14>_ArrayZipSize_[$U#U<2><1><100>U<14>_ArrayZipType_SU<4>gzipU<14>_ArrayZipData_[$U#U<30><31><139><8><0><0><0><0><0><0><3><99><100><0><1><70><28><36><197><0><108><12><0><95><87><171><165><100><0><0><0>}', ...
                     'debug', 1, 'Compression', 'gzip', 'CompressArraySize', 0);  % nestarray for 4-D or above is not working
        test_jsonlab('lzma compression (level 5)', @savebj, a, ...
                     '{U<11>_ArrayType_SU<5>uint8U<11>_ArraySize_[$U#U<2><20><5>U<14>_ArrayZipSize_[$U#U<2><1><100>U<14>_ArrayZipType_SU<4>lzmaU<14>_ArrayZipData_[$U#U<32><93><0><0><16><0><100><0><0><0><0><0><0><0><0><0><128><61><72><138><187><229><101><33><24><236><49><255><255><251><90><160><0>}', ...
                     'debug', 1, 'Compression', 'lzma', 'CompressArraySize', 0);  % nestarray for 4-D or above is not working
    catch
    end
end

%%
if (ismember('bjo', tests))
    fprintf(sprintf('%s\n', char(ones(1, 79) * 61)));
    fprintf('Test Binary JSON function options\n');
    fprintf(sprintf('%s\n', char(ones(1, 79) * 61)));

    test_jsonlab('remove ubjson optimized array header', @savebj, [1, 2, 3], '[U<1>U<2>U<3>]', 'debug', 1, 'nestarray', 1);
    test_jsonlab('limit to ubjson signed integer', @savebj, 256, 'I<256>', 'debug', 1, 'ubjson', 1);
    test_jsonlab('limit to ubjson integer markers', @savebj, 2^32 - 1, 'L<4294967295>', 'debug', 1, 'ubjson', 1);
    test_jsonlab('H marker for out of bound integer', @savebj, 2^64 - 1, 'HU<20>18446744073709551616', 'debug', 1, 'ubjson', 1);
    test_jsonlab('do not downcast integers to the shortest format', @savebj, int32(5), 'l<5>', 'debug', 1, 'keeptype', 1);
    test_jsonlab('do not downcast integer array to the shortest format', @savebj, int32([5, 6]), '[$l#U<2><5><6>', 'debug', 1, 'keeptype', 1);
    test_jsonlab('test little endian uint32', @savebj, typecast(uint8('abcd'), 'uint32'), 'mabcd', 'endian', 'L');
    test_jsonlab('test big endian uint32', @savebj, typecast(uint8('abcd'), 'uint32'), 'mdcba', 'endian', 'B');
    test_jsonlab('test little endian double', @savebj, typecast(uint8('01234567'), 'double'), 'D01234567', 'endian', 'L');
    test_jsonlab('test big endian double', @savebj, typecast(uint8('01234567'), 'double'), 'D76543210', 'endian', 'B');
    test_jsonlab('test default int endian for savebj', @savebj, typecast(uint8('jd'), 'uint16'), 'ujd');
    test_jsonlab('test default int endian for saveubjson', @saveubjson, typecast(uint8('jd'), 'uint16'), 'Idj');
    test_jsonlab('test default float endian for savebj', @savebj, typecast(uint8('1e05'), 'single'), 'd1e05');
    test_jsonlab('test default float endian for saveubjson', @saveubjson, typecast(uint8('12345678'), 'double'), 'D87654321');
end

%%
if (ismember('jmap', tests))
    fprintf(sprintf('%s\n', char(ones(1, 79) * 61)));
    fprintf('Test JSON mmap\n');
    fprintf(sprintf('%s\n', char(ones(1, 79) * 61)));

    test_jsonlab('mmap of a 1D numerical array', @savejson, loadjson('[1,2,3]', 'mmaponly', 1), '[["$",[1,7]]]', 'compact', 1);
    test_jsonlab('mmap of a 1D mixed array', @savejson, loadjson('[1,"2",3]', 'mmaponly', 1), '[["$",[1,9]]]', 'compact', 1);
    test_jsonlab('mmap of a 2D array', @savejson, loadjson('[[1,2,3],[4,5,6]]', 'mmaponly', 1), '[["$",[1,17]]]', 'compact', 1);
    test_jsonlab('mmap of concatenated json', @savejson, loadjson('[1,2,3][4,5,6]', 'mmaponly', 1), '[["$",[1,7]],["$1",[8,7]]]', 'compact', 1);
    test_jsonlab('mmap of concatenated json objects', @savejson, loadjson('[1,2,3]{"a":[4,5]}', 'mmaponly', 1), '[["$",[1,7]],["$1",[8,11]],["$1.a",[13,5]]]', 'compact', 1);
    test_jsonlab('mmap of an array with an object', @savejson, loadjson('[1,2,{"a":3}]', 'mmaponly', 1), ...
                 '[["$",[1,13]],["$[0]",[2,1]],["$[1]",[4,1]],["$[2]",[6,7]],["$[2].a",[11,1]]]', 'compact', 1);
    test_jsonlab('mmap of an object', @savejson, loadjson('{"a":1,"b":[2,3]}', 'mmaponly', 1), ...
                 '[["$",[1,17]],["$.a",[6,1]],["$.b",[12,5]]]', 'compact', 1);
    test_jsonlab('mmap of object with white-space', @savejson, loadjson('{"a":1 , "b"  :  [2,3]}', 'mmaponly', 1), ...
                 '[["$",[1,23]],["$.a",[6,1]],["$.b",[18,5,2]]]', 'compact', 1);
    test_jsonlab('mmapinclude option', @savejson, loadjson('[[1,2,3],{"a":[4,5]}]', 'mmaponly', 1, 'mmapinclude', '.a'), ...
                 '[["$[1].a",[15,5]]]', 'compact', 1);
    test_jsonlab('mmapexclude option', @savejson, loadjson('[[1,2,3],{"a":[4,5]}]', 'mmaponly', 1, 'mmapexclude', {'[0]', '[1]', '[2]'}), ...
                 '[["$",[1,21]]]', 'compact', 1);
    test_jsonlab('json with indentation', @savejson, loadjson(savejson({[1, 2, 3], struct('a', [4, 5])}), 'mmaponly', 1, 'mmapinclude', '.a'), ...
                 '[["$[1].a",[22,7]]]', 'compact', 1);
end

%%
if (ismember('bmap', tests))
    fprintf(sprintf('%s\n', char(ones(1, 79) * 61)));
    fprintf('Test Binary JSON mmap\n');
    fprintf(sprintf('%s\n', char(ones(1, 79) * 61)));

    test_jsonlab('mmap of a 1D numerical array', @savejson, loadbj(savebj([1, 2, 3]), 'mmaponly', 1), '[["$",[1,9]]]', 'compact', 1);
    test_jsonlab('mmap of a 1D mixed array', @savejson, loadbj(savebj({1, '2', 3}), 'mmaponly', 1), '[["$",[1,8]],["$[0]",[2,2]],["$[1]",[4,2]],["$[2]",[6,2]]]', 'compact', 1);
    test_jsonlab('mmap of a 2D array', @savejson, loadbj(savebj([[1, 2, 3], [4, 5, 6]]), 'mmaponly', 1), '[["$",[1,12]]]', 'compact', 1);
    test_jsonlab('mmap of an array with an object', @savejson, loadbj(savebj({1, 2, struct('a', 3)}), 'mmaponly', 1), ...
                 '[["$",[1,13]],["$[0]",[2,2]],["$[1]",[4,2]],["$[2]",[6,7]],["$[2].a",[10,2]]]', 'compact', 1);
    test_jsonlab('mmap of an object', @savejson, loadbj(savebj(struct('a', 1, 'b', [2, 3])), 'mmaponly', 1), ...
                 '[["$",[1,18]],["$.a",[5,2]],["$.b",[10,8]]]', 'compact', 1);
    test_jsonlab('mmapinclude option', @savejson, loadbj(savebj({[1, 2, 3], struct('a', [4, 5])}), 'mmaponly', 1, 'mmapinclude', '.a'), ...
                 '[["$[1].a",[15,8]]]', 'compact', 1);
    test_jsonlab('mmapexclude option', @savejson, loadbj(savebj({[1, 2, 3], struct('a', [4, 5])}), 'mmaponly', 1, 'mmapexclude', {'[0]', '[1]', '[2]'}), ...
                 '[["$",[1,24]]]', 'compact', 1);
    test_jsonlab('test multiple root objects with N padding', @savejson, loadbj([savebj({[1, 2, 3], struct('a', [4, 5])}) 'NNN' savebj(struct('b', [4, 5]))], 'mmaponly', 1, 'mmapinclude', '.b'), ...
                 '[["$1.b",[32,8]]]', 'compact', 1);
end

%%
if (ismember('jpath', tests))
    fprintf(sprintf('%s\n', char(ones(1, 79) * 61)));
    fprintf('Test JSONPath\n');
    fprintf(sprintf('%s\n', char(ones(1, 79) * 61)));

    testdata = struct('book', struct('title', {'Minch', 'Qui-Gon', 'Ben'}, 'author', {'Yoda', 'Jinn', 'Kenobi'}), 'game', struct('title', 'Mario', 'new', struct('title', 'Minecraft')));
    test_jsonlab('jsonpath of .key', @savejson, jsonpath(testdata, '$.game.title'), '"Mario"', 'compact', 1);
    test_jsonlab('jsonpath of ..key', @savejson, jsonpath(testdata, '$.book..title'), '["Minch","Qui-Gon","Ben"]', 'compact', 1);
    test_jsonlab('jsonpath of ..key cross objects', @savejson, jsonpath(testdata, '$..title'), '["Minch","Qui-Gon","Ben","Mario","Minecraft"]', 'compact', 1);
    test_jsonlab('jsonpath of [index]', @savejson, jsonpath(testdata, '$..title[1]'), '["Qui-Gon"]', 'compact', 1);
    test_jsonlab('jsonpath of [-index]', @savejson, jsonpath(testdata, '$..title[-1]'), '["Minecraft"]', 'compact', 1);
    test_jsonlab('jsonpath of [start:end]', @savejson, jsonpath(testdata, '$..title[0:2]'), '["Minch","Qui-Gon","Ben"]', 'compact', 1);
    test_jsonlab('jsonpath of [:end]', @savejson, jsonpath(testdata, '$..title[:2]'), '["Minch","Qui-Gon","Ben"]', 'compact', 1);
    test_jsonlab('jsonpath of [start:]', @savejson, jsonpath(testdata, '$..title[1:]'), '["Qui-Gon","Ben","Mario","Minecraft"]', 'compact', 1);
    test_jsonlab('jsonpath of [-start:-end]', @savejson, jsonpath(testdata, '$..title[-2:-1]'), '["Mario","Minecraft"]', 'compact', 1);
    test_jsonlab('jsonpath of [-start:]', @savejson, jsonpath(testdata, '$..title[:-3]'), '["Minch","Qui-Gon","Ben"]', 'compact', 1);
    test_jsonlab('jsonpath of [:-end]', @savejson, jsonpath(testdata, '$..title[-1:]'), '["Minecraft"]', 'compact', 1);
    test_jsonlab('jsonpath of object with [index]', @savejson, jsonpath(testdata, '$.book[1]'), '{"title":"Qui-Gon","author":"Jinn"}', 'compact', 1);
    test_jsonlab('jsonpath of element after [index]', @savejson, jsonpath(testdata, '$.book[1:2].author'), '["Jinn","Kenobi"]', 'compact', 1);
    test_jsonlab('jsonpath of [*] and deep scan', @savejson, jsonpath(testdata, '$.book[*]..author'), '["Yoda","Jinn","Kenobi"]', 'compact', 1);
    test_jsonlab('jsonpath of [*] after deep scan', @savejson, jsonpath(testdata, '$.book[*]..author[*]'), '["Yoda","Jinn","Kenobi"]', 'compact', 1);
    test_jsonlab('jsonpath use [] instead of .', @savejson, jsonpath(testdata, '$[book][2][author]'), '"Kenobi"', 'compact', 1);
    test_jsonlab('jsonpath use [] with [start:end]', @savejson, jsonpath(testdata, '$[book][1:2][author]'), '["Jinn","Kenobi"]', 'compact', 1);
    test_jsonlab('jsonpath use . after [start:end]', @savejson, jsonpath(testdata, '$[book][0:1].author'), '["Yoda","Jinn"]', 'compact', 1);
    test_jsonlab('jsonpath use [''*''] and ["*"]', @savejson, jsonpath(testdata, '$["book"][:-2][''author'']'), '["Yoda","Jinn"]', 'compact', 1);
    test_jsonlab('jsonpath use combinations', @savejson, jsonpath(testdata, '$..["book"][:-2].author[*][0]'), '["Yoda"]', 'compact', 1);

    if (hasContainersMap)
        testdata = loadjson(savejson('', testdata), 'usemap', 1);
        test_jsonlab('jsonpath use combinations', @savejson, jsonpath(testdata, '$..["book"].author[*][0]'), '["Yoda"]', 'compact', 1);
    end
    if (exist('istable'))
        testdata = struct('book', table({'Minch', 'Qui-Gon', 'Ben'}, {'Yoda', 'Jinn', 'Kenobi'}, 'variablenames', {'title', 'author'}), 'game', struct('title', 'Mario'));
        test_jsonlab('jsonpath use combinations', @savejson, jsonpath(testdata, '$..["book"].author[*][0]'), '["Yoda"]', 'compact', 1);
    end

    testdata = struct('book', struct(encodevarname('_title'), {'Minch', 'Qui-Gon', 'Ben'}, encodevarname(' author.last.name '), {'Yoda', 'Jinn', 'Kenobi'}), encodevarname('game.arcade'), struct('title', 'Mario'));
    test_jsonlab('jsonpath encoded field name in []', @savejson, jsonpath(testdata, '$..["book"][_title][*][0]'), '["Minch"]', 'compact', 1);
    test_jsonlab('jsonpath encoded field name after .', @savejson, jsonpath(testdata, '$..["book"]._title[*][0]'), '["Minch"]', 'compact', 1);
    test_jsonlab('jsonpath encoded field name after ..', @savejson, jsonpath(testdata, '$.._title'), '["Minch","Qui-Gon","Ben"]', 'compact', 1);
    test_jsonlab('jsonpath multiple encoded field name between quotes', @savejson, jsonpath(testdata, '$..["book"]['' author.last.name ''][*][1]'), '["Jinn"]', 'compact', 1);
    test_jsonlab('jsonpath multiple encoded field name between []', @savejson, jsonpath(testdata, '$..["book"][ author.last.name ][*][1]'), '["Jinn"]', 'compact', 1);
    test_jsonlab('jsonpath escape . using \.', @savejson, jsonpath(testdata, '$.game\.arcade'), '{"title":"Mario"}', 'compact', 1);
    test_jsonlab('jsonpath escape . using []', @savejson, jsonpath(testdata, '$.[game.arcade]'), '{"title":"Mario"}', 'compact', 1);
    test_jsonlab('jsonpath scan struct array', @savejson, jsonpath(testdata, '$.book[*]..author[*]'), '[]', 'compact', 1);

    clear testdata;
end

%%
if (ismember('jdict', tests) && hasContainersMap)
    fprintf(sprintf('%s\n', char(ones(1, 79) * 61)));
    fprintf('Test jdict\n');
    fprintf(sprintf('%s\n', char(ones(1, 79) * 61)));

    testdata = struct('key1', struct('subkey1', 1, 'subkey2', [1, 2, 3]), 'subkey2', 'str');
    testdata.key1.subkey3 = {8, 'test', struct('subsubkey1', 0)};
    jd = jdict(testdata);

    test_jsonlab('jd.(''key1'').(''subkey1'')', @savejson, jd.('key1').('subkey1'), '[1]', 'compact', 1);
    test_jsonlab('jd.(''key1'').(''subkey3'')', @savejson, jd.('key1').('subkey3'), '[8,"test",{"subsubkey1":0}]', 'compact', 1);
    test_jsonlab('jd.(''key1'').(''subkey3'')()', @savejson, jd.('key1').('subkey3')(), '[8,"test",{"subsubkey1":0}]', 'compact', 1);
    test_jsonlab('jd.(''key1'').(''subkey3'').v()', @savejson, class(jd.('key1').('subkey3').v()), '"cell"', 'compact', 1);
    test_jsonlab('jd.(''key1'').(''subkey3'').v(1)', @savejson, jd.('key1').('subkey3').v(1), '[8]', 'compact', 1);
    test_jsonlab('jd.(''key1'').(''subkey3'').v(3).(''subsubkey1'')', @savejson, jd.('key1').('subkey3').v(3).('subsubkey1'), '[0]', 'compact', 1);
    test_jsonlab('jd.(''key1'').(''subkey3'').v(2).v()', @savejson, jd.('key1').('subkey3').v(2).v(), '"test"', 'compact', 1);
    test_jsonlab('jd.(''$.key1.subkey1'')', @savejson, jd.('$.key1.subkey1'), '[1]', 'compact', 1);
    test_jsonlab('jd.(''$.key1.subkey2'')()', @savejson, jd.('$.key1.subkey2')(), '[1,2,3]', 'compact', 1);
    test_jsonlab('jd.(''$.key1.subkey2'').v()', @savejson, jd.('$.key1.subkey2').v(), '[1,2,3]', 'compact', 1);
    test_jsonlab('jd.(''$.key1.subkey2'')().v(1)', @savejson, jd.('$.key1.subkey2')().v(1), '[1]', 'compact', 1);
    test_jsonlab('jd.(''$.key1.subkey3[2].subsubkey1', @savejson, jd.('$.key1.subkey3[2].subsubkey1'), '[0]', 'compact', 1);
    test_jsonlab('jd.(''$..subkey2'')', @savejson, jd.('$..subkey2'), '["str",[1,2,3]]', 'compact', 1);
    test_jsonlab('jd.(''$..subkey2'').v(2)', @savejson, jd.('$..subkey2').v(2), '[1,2,3]', 'compact', 1);
    jd.('key1').('subkey2').v(1) = 2;
    jd.('key1').('subkey2').v([2, 3]) = [10, 11];
    jd.('key1').('subkey3').v(2) = 'mod';
    jd.('key1').('subkey3').v(3).('subsubkey1') = 1;
    jd.('key1').('subkey3').v(3).('subsubkey2') = 'new';
    test_jsonlab('jd.(''key1'').(''subkey3'')', @savejson, jd.('key1').('subkey3'), '[8,"mod",{"subsubkey1":1,"subsubkey2":"new"}]', 'compact', 1);
    test_jsonlab('jd.(''key1'').(''subkey2'')', @savejson, jd.('key1').('subkey2'), '[2,10,11]', 'compact', 1);
    test_jsonlab('jd.(''key1'').(''subkey2'').len()', @savejson, jd.('key1').('subkey2').len(), '[3]', 'compact', 1);
    test_jsonlab('jd.(''key1'').(''subkey2'').size()', @savejson, jd.('key1').('subkey2').size(), '[1,3]', 'compact', 1);
    test_jsonlab('jd.(''key1'').keys()', @savejson, jd.('key1').keys(), '[["subkey1"],["subkey2"],["subkey3"]]', 'compact', 1);
    test_jsonlab('jd.(''key1'').isKey(''subkey3'')', @savejson, jd.('key1').isKey('subkey3'), '[true]', 'compact', 1);
    test_jsonlab('jd.(''key1'').isKey(''subkey4'')', @savejson, jd.('key1').isKey('subkey4'), '[false]', 'compact', 1);

    jd.('$.key1.subkey1') = [1, 2, 3];
    test_jsonlab('jd.(''$.key1.subkey1'')', @savejson, jd.('key1').('subkey1'), '[1,2,3]', 'compact', 1);
    jd.key1.('$.subkey1') = 'newsubkey1';
    test_jsonlab('jd.key1.(''$.subkey1'')', @savejson, jd.('key1').('subkey1'), '"newsubkey1"', 'compact', 1);
    jd.('$.key1').subkey1 = struct('newkey', 1);
    test_jsonlab('jd.(''$.key1'').subkey1', @savejson, jd.('key1').('subkey1'), '{"newkey":1}', 'compact', 1);
    test_jsonlab('jd.(''$.key1.subkey1'').newkey', @savejson, jd.('key1').('subkey1').newkey, '[1]', 'compact', 1);

    % Test basic struct assignment to empty struct array
    person = jdict(struct('name', {}, 'age', {}, 'gender', {}));
    person.(1) = struct('name', 'Jar Jar', 'age', 100, 'gender', 'M');
    test_jsonlab('person.(1) = struct(...)', @savejson, person, '{"name":"Jar Jar","age":100,"gender":"M"}', 'compact', 1);

    % Test append second struct
    person.(2) = struct('name', 'Jane', 'age', 25, 'gender', 'F');
    test_jsonlab('person.(2) = struct(...)', @savejson, person, '[{"name":"Jar Jar","age":100,"gender":"M"},{"name":"Jane","age":25,"gender":"F"}]', 'compact', 1);

    % Test field-by-field assignment to new index
    person.(3).name = 'Bob';
    person.(3).age = 40;
    person.(3).gender = 'M';
    test_jsonlab('person.(3).name/age/gender', @savejson, person.v(3), '{"name":"Bob","age":40,"gender":"M"}', 'compact', 1);

    % Test modify existing element
    person.(1).name = 'Jar Jar Modified';
    person.(1).age = 101;
    test_jsonlab('person.(1).name = ...', @savejson, person.v(1), '{"name":"Jar Jar Modified","age":101,"gender":"M"}', 'compact', 1);

    clear testdata jd person;
end

%%
if (ismember('bugs', tests))
    fprintf(sprintf('%s\n', char(ones(1, 79) * 61)));
    fprintf('Test bug fixes\n');
    fprintf(sprintf('%s\n', char(ones(1, 79) * 61)));
    test_jsonlab('simplify cell arrays mixing numbers and chars', @savejson, loadjson('[1,0,"-","L",900]'), '[1,0,"-","L",900]', 'compact', 1);
    test_jsonlab('simplify cell arrays with string elements', @savejson, loadjson('["j","s","o","n"]'), '["j","s","o","n"]', 'compact', 1);
end

%%
if (ismember('yaml', tests))
    fprintf(sprintf('%s\n', char(ones(1, 79) * 61)));
    fprintf('Test YAML functions\n');
    fprintf(sprintf('%s\n', char(ones(1, 79) * 61)));

    %% Basic scalar types - saveyaml
    test_jsonlab('single integer', @saveyaml, 5, '5');
    test_jsonlab('negative integer', @saveyaml, -42, '-42');
    test_jsonlab('zero', @saveyaml, 0, '0');
    test_jsonlab('single float', @saveyaml, 3.14, '3.14');
    test_jsonlab('negative float', @saveyaml, -2.718, '-2.718');
    test_jsonlab('scientific notation', @saveyaml, 1.5e10, '1.5e+10');
    test_jsonlab('small scientific', @saveyaml, 1.5e-10, '1.5e-10');
    test_jsonlab('boolean true', @saveyaml, true, 'true', 'ParseLogical', 1);
    test_jsonlab('boolean false', @saveyaml, false, 'false', 'ParseLogical', 1);
    test_jsonlab('empty array', @saveyaml, [], '[]');
    test_jsonlab('empty cell', @saveyaml, {}, '[]');
    % Note: saveyaml returns 'e:' for empty nested struct (null value)
    test_jsonlab('empty struct nested', @saveyaml, struct('e', struct()), 'e:', 'EmptyArrayAsNull', 1);

    %% Special float values
    test_jsonlab('positive infinity', @saveyaml, Inf, '.inf');
    test_jsonlab('negative infinity', @saveyaml, -Inf, '-.inf');
    test_jsonlab('NaN', @saveyaml, NaN, '.nan');

    %% Strings - saveyaml
    test_jsonlab('simple string', @saveyaml, 'teststring', 'teststring');
    test_jsonlab('string with spaces', @saveyaml, 'hello world', '"hello world"');
    test_jsonlab('empty string', @saveyaml, '', '""');
    test_jsonlab('string with colon', @saveyaml, 'key: value', '"key: value"');
    test_jsonlab('string with hash', @saveyaml, 'test#comment', '"test#comment"');
    test_jsonlab('string looks like bool', @saveyaml, 'true', '"true"');
    test_jsonlab('string looks like null', @saveyaml, 'null', '"null"');
    test_jsonlab('string looks like number', @saveyaml, '123', '"123"');
    test_jsonlab('string with quotes', @saveyaml, 'say "hello"', '"say \"hello\""');
    test_jsonlab('string with newline', @saveyaml, sprintf('line1\nline2'), '"line1\nline2"');

    %% Vectors and arrays - saveyaml
    test_jsonlab('row vector', @saveyaml, [1, 2, 3], '[1, 2, 3]');
    test_jsonlab('column vector', @saveyaml, [1; 2; 3], sprintf('- [1]\n- [2]\n- [3]'));
    test_jsonlab('2d array', @saveyaml, [1, 2, 3; 4, 5, 6], sprintf('- [1, 2, 3]\n- [4, 5, 6]'));
    test_jsonlab('single element array', @saveyaml, [5], '5');
    test_jsonlab('logical array', @saveyaml, [true, false, true], '[1, 0, 1]');

    %% Cell arrays - saveyaml
    test_jsonlab('cell array', @saveyaml, {'a', 'b', 'c'}, sprintf('- a\n- b\n- c'));
    test_jsonlab('mixed cell array', @saveyaml, {'a', 1, 0.9}, sprintf('- a\n- 1\n- 0.9'));
    test_jsonlab('nested cell array', @saveyaml, {{'a', 'b'}, {'c', 'd'}}, sprintf('- - a\n  - b\n- - c\n  - d'));
    test_jsonlab('cell with empty', @saveyaml, {'a', [], 'b'}, sprintf('- a\n- null\n- b'), 'EmptyArrayAsNull', 1);
    test_jsonlab('char array', @saveyaml, ['AC'; 'EG'], sprintf('|\n  AC\n  EG'));

    %% Structs - saveyaml
    test_jsonlab('simple struct', @saveyaml, struct('name', 'test', 'value', 5), sprintf('name: test\nvalue: 5'));
    test_jsonlab('nested struct', @saveyaml, struct('person', struct('name', 'John', 'age', 30)), ...
                 sprintf('person:\n  name: John\n  age: 30'));
    test_jsonlab('struct array', @saveyaml, repmat(struct('i', 1.1, 'd', 'str'), [1, 2]), ...
                 sprintf('- i: 1.1\n  d: str\n- i: 1.1\n  d: str'));
    test_jsonlab('deeply nested struct', @saveyaml, struct('a', struct('b', struct('c', 1))), ...
                 sprintf('a:\n  b:\n    c: 1'));
    test_jsonlab('struct with array value', @saveyaml, struct('nums', [1, 2, 3]), 'nums: [1, 2, 3]');
    test_jsonlab('struct with cell value', @saveyaml, struct('items', {{'x', 'y'}}), sprintf('items:\n  - x\n  - y'));

    %% Special characters in struct keys/values
    test_jsonlab('string with colon', @saveyaml, struct('url', 'http://example.com'), 'url: "http://example.com"');
    test_jsonlab('string with dash', @saveyaml, struct('version', 'ubuntu-22.04'), 'version: ubuntu-22.04');
    test_jsonlab('string with at sign', @saveyaml, struct('action', 'actions/checkout@v3'), 'action: "actions/checkout@v3"');
    test_jsonlab('string with brackets', @saveyaml, struct('pattern', '[a-z]+'), 'pattern: "[a-z]+"');
    test_jsonlab('string with braces', @saveyaml, struct('template', '${var}'), 'template: "${var}"');

    %% Inline arrays in structs
    test_jsonlab('inline number array', @saveyaml, struct('values', [1, 2, 3]), 'values: [1, 2, 3]');
    test_jsonlab('inline 2d array', @saveyaml, struct('matrix', [1, 2; 3, 4]), sprintf('matrix:\n  - [1, 2]\n  - [3, 4]'));

    %% ========== LOADYAML TESTS ==========

    %% Basic types - loadyaml
    test_jsonlab('load simple key-value', @saveyaml, loadyaml('name: test'), 'name: test');
    test_jsonlab('load integer', @saveyaml, loadyaml('value: 5'), 'value: 5');
    test_jsonlab('load negative integer', @saveyaml, loadyaml('value: -42'), 'value: -42');
    test_jsonlab('load float', @saveyaml, loadyaml('value: 3.14'), 'value: 3.14');
    test_jsonlab('load scientific', @saveyaml, loadyaml('value: 1.5e10'), 'value: 1.5e+10');
    test_jsonlab('load hex number', @saveyaml, loadyaml('value: 0xFF'), 'value: 255');

    %% Booleans - loadyaml
    test_jsonlab('load boolean true', @saveyaml, loadyaml('flag: true'), 'flag: true');
    test_jsonlab('load boolean false', @saveyaml, loadyaml('flag: false'), 'flag: false');
    test_jsonlab('load boolean yes', @saveyaml, loadyaml('flag: yes'), 'flag: true');
    test_jsonlab('load boolean no', @saveyaml, loadyaml('flag: no'), 'flag: false');
    test_jsonlab('load boolean on', @saveyaml, loadyaml('flag: on'), 'flag: true');
    test_jsonlab('load boolean off', @saveyaml, loadyaml('flag: off'), 'flag: false');
    test_jsonlab('load boolean TRUE', @saveyaml, loadyaml('flag: TRUE'), 'flag: true');
    test_jsonlab('load boolean False', @saveyaml, loadyaml('flag: False'), 'flag: false');

    %% Null values - loadyaml
    test_jsonlab('load null', @saveyaml, loadyaml('value: null'), 'value: null', 'EmptyArrayAsNull', 1);
    test_jsonlab('load tilde null', @saveyaml, loadyaml('value: ~'), 'value: null', 'EmptyArrayAsNull', 1);
    test_jsonlab('load empty value', @saveyaml, loadyaml('value:'), 'value: null', 'EmptyArrayAsNull', 1);

    %% Special floats - loadyaml
    test_jsonlab('load positive inf', @saveyaml, loadyaml('value: .inf'), 'value: .inf');
    test_jsonlab('load negative inf', @saveyaml, loadyaml('value: -.inf'), 'value: -.inf');
    test_jsonlab('load nan', @saveyaml, loadyaml('value: .nan'), 'value: .nan');
    test_jsonlab('load +.inf', @saveyaml, loadyaml('value: +.inf'), 'value: .inf');

    %% Strings - loadyaml
    test_jsonlab('load unquoted string', @saveyaml, loadyaml('name: hello'), 'name: hello');
    test_jsonlab('load double quoted string', @saveyaml, loadyaml('name: "hello world"'), 'name: "hello world"');
    test_jsonlab('load single quoted string', @saveyaml, loadyaml('name: ''hello world'''), 'name: "hello world"');
    test_jsonlab('load empty double quoted', @saveyaml, loadyaml('name: ""'), 'name: ""');
    test_jsonlab('load empty single quoted', @saveyaml, loadyaml('name: '''''), 'name: ""');

    %% Escape sequences - loadyaml
    tmp = loadyaml('s: "hello\tworld"');
    test_jsonlab('escape tab', @savejson, tmp.s, sprintf('"hello\\tworld"'));
    tmp = loadyaml('s: "line1\nline2"');
    test_jsonlab('escape newline', @savejson, tmp.s, sprintf('"line1\\nline2"'));
    tmp = loadyaml('s: "col1\rcol2"');
    test_jsonlab('escape carriage return', @savejson, tmp.s, sprintf('"col1\\rcol2"'));
    tmp = loadyaml('s: "say \"hi\""');
    test_jsonlab('escape quote', @savejson, tmp.s, '"say \"hi\""');
    tmp = loadyaml('s: "back\\slash"');
    test_jsonlab('escape backslash', @savejson, tmp.s, '"back\\slash"');
    tmp = loadyaml('s: "\a"');
    test_jsonlab('escape bell code', @saveyaml, double(tmp.s), '7');
    tmp = loadyaml('s: "\v"');
    test_jsonlab('escape vtab code', @saveyaml, double(tmp.s), '11');
    tmp = loadyaml('s: "\0"');
    test_jsonlab('escape null code', @saveyaml, double(tmp.s), '0');
    tmp = loadyaml('s: "\x41\x42\x43"');
    test_jsonlab('escape hex', @savejson, tmp.s, '"ABC"');
    tmp = loadyaml('s: "\u0048\u0069"');
    test_jsonlab('escape unicode', @savejson, tmp.s, '"Hi"');

    %% Block sequences - loadyaml
    test_jsonlab('load simple list', @saveyaml, loadyaml(sprintf('- a\n- b\n- c')), sprintf('- a\n- b\n- c'));
    test_jsonlab('load numeric list', @saveyaml, loadyaml(sprintf('- 1\n- 2\n- 3')), '[1, 2, 3]');
    test_jsonlab('load mixed list', @saveyaml, loadyaml(sprintf('- hello\n- 42\n- true')), sprintf('- hello\n- 42\n- true'));

    %% Inline arrays - loadyaml
    test_jsonlab('load inline array', @saveyaml, loadyaml('values: [1, 2, 3]'), 'values: [1, 2, 3]');
    test_jsonlab('load inline string array', @saveyaml, loadyaml('items: [a, b, c]'), sprintf('items:\n  - a\n  - b\n  - c'));
    test_jsonlab('load inline mixed array', @saveyaml, loadyaml('data: [1, "two", true]'), sprintf('data:\n  - 1\n  - two\n  - true'));
    test_jsonlab('load empty inline array', @saveyaml, loadyaml('items: []'), 'items: []');
    test_jsonlab('load nested inline array', @saveyaml, loadyaml('coords: [[1, 2], [3, 4]]'), sprintf('coords:\n  - [1, 2]\n  - [3, 4]'));

    %% Inline objects - loadyaml
    result_inline_obj = loadyaml('person: {name: John, age: 30}');
    test_jsonlab('load inline object name', @saveyaml, result_inline_obj.person.name, 'John');
    test_jsonlab('load inline object age', @saveyaml, result_inline_obj.person.age, '30');
    test_jsonlab('load empty inline object', @saveyaml, loadyaml('empty: {}'), 'empty:', 'EmptyArrayAsNull', 1);

    %% Nested structures - loadyaml
    test_jsonlab('load nested object', @saveyaml, loadyaml(sprintf('person:\n  name: John\n  age: 30')), ...
                 sprintf('person:\n  name: John\n  age: 30'));
    test_jsonlab('load deeply nested', @saveyaml, loadyaml(sprintf('a:\n  b:\n    c: 1')), sprintf('a:\n  b:\n    c: 1'));
    test_jsonlab('load array of objects', @saveyaml, loadyaml(sprintf('- name: Alice\n  age: 25\n- name: Bob\n  age: 30')), ...
                 sprintf('- name: Alice\n  age: 25\n- name: Bob\n  age: 30'));

    %% Double-nested block sequences (- - pattern) - loadyaml
    yaml_nested = sprintf('coords:\n  - - [1, 2]\n    - [3, 4]\n  - - [5, 6]\n    - [7, 8]');
    result = loadyaml(yaml_nested);
    test_jsonlab('nested seq is cell', @saveyaml, iscell(result.coords), 'true');
    test_jsonlab('nested seq length', @saveyaml, length(result.coords), '2');
    test_jsonlab('nested seq polygon 1', @saveyaml, result.coords{1}, sprintf('- [1, 2]\n- [3, 4]'));
    test_jsonlab('nested seq polygon 2', @saveyaml, result.coords{2}, sprintf('- [5, 6]\n- [7, 8]'));

    %% Comments - loadyaml
    test_jsonlab('load with comment', @saveyaml, loadyaml(sprintf('name: test # this is a comment')), 'name: test');
    test_jsonlab('load with full line comment', @saveyaml, loadyaml(sprintf('# comment\nname: test')), 'name: test');
    test_jsonlab('load hash in quoted string', @saveyaml, loadyaml('tag: "#hashtag"'), 'tag: "#hashtag"');

    %% Multi-document - loadyaml
    test_jsonlab('load multi-document', @saveyaml, loadyaml(sprintf('---\nname: doc1\n---\nname: doc2')), ...
                 sprintf('- name: doc1\n- name: doc2'));

    %% Complex structures - loadyaml
    geojson_yaml = sprintf(['type: Feature\n' ...
                            'geometry:\n' ...
                            '  type: Polygon\n' ...
                            '  coordinates:\n' ...
                            '    - - [0, 0]\n' ...
                            '      - [1, 0]\n' ...
                            '      - [1, 1]\n' ...
                            '      - [0, 0]']);
    result = loadyaml(geojson_yaml);
    test_jsonlab('geojson type', @saveyaml, result.type, 'Feature');
    test_jsonlab('geojson geom type', @saveyaml, result.geometry.type, 'Polygon');
    test_jsonlab('geojson coords is cell', @saveyaml, iscell(result.geometry.coordinates), 'true');
    test_jsonlab('geojson coords size', @saveyaml, size(result.geometry.coordinates{1}), '[4, 2]');

    %% Round-trip tests (use empty rootname to avoid variable name wrapping)
    rt_int = struct('v', 42);
    test_jsonlab('roundtrip integer', @saveyaml, loadyaml(saveyaml('', rt_int)), 'v: 42');
    rt_float = struct('v', 3.14);
    test_jsonlab('roundtrip float', @saveyaml, loadyaml(saveyaml('', rt_float)), 'v: 3.14');
    rt_bool = struct('v', true);
    test_jsonlab('roundtrip boolean', @saveyaml, loadyaml(saveyaml('', rt_bool)), 'v: true');
    rt_vec = struct('v', [1, 2, 3]);
    test_jsonlab('roundtrip row vector', @saveyaml, loadyaml(saveyaml('', rt_vec)), 'v: [1, 2, 3]');
    rt_mat = struct('v', [1, 2; 3, 4]);
    test_jsonlab('roundtrip matrix', @saveyaml, loadyaml(saveyaml('', rt_mat)), sprintf('v:\n  - [1, 2]\n  - [3, 4]'));

    rt_struct = struct('name', 'test', 'value', 123);
    test_jsonlab('roundtrip struct', @saveyaml, loadyaml(saveyaml('', rt_struct)), sprintf('name: test\nvalue: 123'));

    rt_nested = struct('outer', struct('inner', struct('value', 42)));
    test_jsonlab('roundtrip nested struct', @saveyaml, loadyaml(saveyaml('', rt_nested)), sprintf('outer:\n  inner:\n    value: 42'));

    rt_arr = struct('data', [1, 2, 3], 'name', 'test');
    test_jsonlab('roundtrip struct with array', @saveyaml, loadyaml(saveyaml('', rt_arr)), sprintf('data: [1, 2, 3]\nname: test'));
end

%%
if (ismember('yamlopt', tests))
    fprintf(sprintf('%s\n', char(ones(1, 79) * 61)));
    fprintf('Test YAML function options\n');
    fprintf(sprintf('%s\n', char(ones(1, 79) * 61)));

    %% saveyaml options
    test_jsonlab('indent option', @saveyaml, struct('a', struct('b', 1)), ...
                 sprintf('a:\n    b: 1'), 'Indent', 4);
    test_jsonlab('float format option', @saveyaml, pi, '3.142', 'FloatFormat', '%.3f');
    test_jsonlab('int format option', @saveyaml, uint8(5), '5', 'IntFormat', '%d');

    %% Multi-document saveyaml
    test_jsonlab('save multi-document', @saveyaml, {struct('a', 1), struct('b', 2)}, ...
                 sprintf('---\na: 1\n---\nb: 2'), 'MultiDocument', 1);

    %% loadyaml options
    test_jsonlab('simplify cell option', @saveyaml, loadyaml(sprintf('- 1\n- 2\n- 3'), 'SimplifyCell', 1), '[1, 2, 3]');
    tmp = loadyaml(sprintf('- 1\n- 2\n- 3'), 'SimplifyCell', 0);
    test_jsonlab('simplify cell off', @savejson, iscell(tmp), '[true]');

    %% FastArrayParser option
    yaml_arr = 'coords: [[1, 2], [3, 4], [5, 6]]';
    result_fast = loadyaml(yaml_arr, 'FastArrayParser', 1);
    result_slow = loadyaml(yaml_arr, 'FastArrayParser', 0);
    test_jsonlab('fast array parser match', @savejson, isequal(result_fast.coords, result_slow.coords), '[true]');
end

%%
if (ismember('yamledge', tests))
    fprintf(sprintf('%s\n', char(ones(1, 79) * 61)));
    fprintf('Test YAML edge cases\n');
    fprintf(sprintf('%s\n', char(ones(1, 79) * 61)));

    %% Edge cases - whitespace handling
    tmp = loadyaml('value:   5');
    test_jsonlab('extra spaces after colon', @saveyaml, tmp.value, '5');
    tmp = loadyaml('value: 5  ');
    test_jsonlab('trailing spaces', @saveyaml, tmp.value, '5');
    tmp = loadyaml(sprintf('  value: 5'));
    test_jsonlab('leading spaces', @saveyaml, tmp.value, '5');

    %% Edge cases - special key names
    result = loadyaml('"quoted key": value');
    fnames = fieldnames(result);
    test_jsonlab('quoted key has field', @saveyaml, ~isempty(fnames), 'true');
    test_jsonlab('quoted key value', @saveyaml, result.(fnames{1}), 'value');

    %% Edge cases - deeply nested arrays (parsed as cell of matrices)
    yaml_deep = 'arr: [[[1, 2], [3, 4]], [[5, 6], [7, 8]]]';
    result = loadyaml(yaml_deep);
    test_jsonlab('deep array is cell', @saveyaml, iscell(result.arr), 'true');
    test_jsonlab('deep array length', @saveyaml, length(result.arr), '2');
    test_jsonlab('deep array elem size', @saveyaml, size(result.arr{1}), '[2, 2]');

    %% Edge cases - empty structures
    tmp = loadyaml('arr: []');
    test_jsonlab('empty array field', @saveyaml, isempty(tmp.arr), 'true');
    result_empty_obj = loadyaml('obj: {}');
    test_jsonlab('empty object is struct', @saveyaml, isstruct(result_empty_obj.obj), 'true');
    test_jsonlab('empty object no fields', @saveyaml, isempty(fieldnames(result_empty_obj.obj)), 'true');

    %% Edge cases - unicode in strings
    result = loadyaml('emoji: "\u263A"');
    test_jsonlab('unicode char code', @saveyaml, double(result.emoji), '9786');

    %% Edge cases - colons in values
    tmp = loadyaml('time: "12:30:00"');
    test_jsonlab('time string', @saveyaml, tmp.time, '"12:30:00"');
    tmp = loadyaml('url: "http://example.com"');
    test_jsonlab('url string', @saveyaml, tmp.url, '"http://example.com"');

    %% Edge cases - array with single element
    tmp = loadyaml('arr: [42]');
    test_jsonlab('single element array', @saveyaml, tmp.arr, '42');

    %% Edge cases - tabs as indentation
    yaml_tabs = sprintf('parent:\n\tchild: value');
    tmp = loadyaml(yaml_tabs);
    test_jsonlab('tab indentation', @saveyaml, tmp.parent.child, 'value');

    %% Edge cases - numbers in various formats
    tmp = loadyaml('val: 0777');
    test_jsonlab('plain number', @saveyaml, tmp.val, '777');
    tmp = loadyaml('val: 0x1F');
    test_jsonlab('hex number', @saveyaml, tmp.val, '31');
end

%%
if (ismember('xarray', tests) && hasContainersMap)
    fprintf(sprintf('%s\n', char(ones(1, 79) * 61)));
    fprintf('Test jdict xarray-like attributes\n');
    fprintf(sprintf('%s\n', char(ones(1, 79) * 61)));

    % Test 1: Root level dims attribute
    jd1 = jdict(rand(10, 20, 30));
    if (exist('OCTAVE_VERSION', 'builtin') ~= 0)
        jd1.setattr('dims', {'time', 'channels', 'trials'});
    else
        jd1{'dims'} = {'time', 'channels', 'trials'};
    end
    test_jsonlab('test root level dims', @savejson, jd1{'dims'}, '["time","channels","trials"]', 'compact', 1);

    % Test 2: Root level units attribute
    if (exist('OCTAVE_VERSION', 'builtin') ~= 0)
        jd1.setattr('units', 'uV');
    else
        jd1{'units'} = 'uV';
    end
    test_jsonlab('test root level attributes', @savejson, jd1{'units'}, '"uV"', 'compact', 1);

    % Test 3: Multiple attributes on same object
    if (exist('OCTAVE_VERSION', 'builtin') ~= 0)
        jd1.setattr('description', 'test data');
    else
        jd1{'description'} = 'test data';
    end
    test_jsonlab('test multiple attrs on same object', @savejson, jd1{'description'}, '"test data"', 'compact', 1);

    % Test 4: Second level on key a
    jd2 = jdict(struct('a', rand(5, 10), 'b', rand(8, 12)));
    if (exist('OCTAVE_VERSION', 'builtin') ~= 0)
        jd2.('a').setattr('dims', {'x', 'y'});
    else
        jd2.('a'){'dims'} = {'x', 'y'};
    end
    test_jsonlab('test attribute for second level on key a', @savejson, jd2.('a'){'dims'}, '["x","y"]', 'compact', 1);

    % Test 5: Second level on key b
    if (exist('OCTAVE_VERSION', 'builtin') ~= 0)
        jd2.('b').setattr('dims', {'rows', 'cols'});
    else
        jd2.('b'){'dims'} = {'rows', 'cols'};
    end
    test_jsonlab('test attribute for second level on key b', @savejson, jd2.('b'){'dims'}, '["rows","cols"]', 'compact', 1);

    % Test 6: Verify independence of attributes
    test_jsonlab('test attribute independence', @savejson, {jd2.('a'){'dims'}, jd2.('b'){'dims'}}, '[["x","y"],["rows","cols"]]', 'compact', 1);

    % Test 7: Third level nested
    jd3 = jdict(struct('level1', struct('level2', struct('data', rand(4, 5, 6)))));
    if (exist('OCTAVE_VERSION', 'builtin') ~= 0)
        jd3.('level1').('level2').('data').setattr('dims', {'i', 'j', 'k'});
    else
        jd3.('level1').('level2').('data'){'dims'} = {'i', 'j', 'k'};
    end
    test_jsonlab('test third level nested attribute', @savejson, jd3.('level1').('level2').('data'){'dims'}, '["i","j","k"]', 'compact', 1);

    % Test 8: Attribute overwrite
    jd4 = jdict(rand(5, 5));
    if (exist('OCTAVE_VERSION', 'builtin') ~= 0)
        jd4.setattr('dims', {'old1', 'old2'});
        jd4.setattr('dims', {'new1', 'new2'});
    else
        jd4{'dims'} = {'old1', 'old2'};
        jd4{'dims'} = {'new1', 'new2'};
    end
    test_jsonlab('test attribute overwrite', @savejson, jd4{'dims'}, '["new1","new2"]', 'compact', 1);

    % Test 9: Non-existent attribute returns empty
    jd5 = jdict(rand(3, 3));
    test_jsonlab('test non-existent attribute returns empty', @savejson, jd5{'nonexistent'}, '[]', 'compact', 1);

    % Test 10: Nested struct with sibling attributes
    jd6 = jdict(struct('exp1', struct('trial1', rand(10, 5), 'trial2', rand(10, 5))));
    if (exist('OCTAVE_VERSION', 'builtin') ~= 0)
        jd6.('exp1').('trial1').setattr('dims', {'time', 'channels'});
        jd6.('exp1').('trial2').setattr('dims', {'samples', 'sensors'});
    else
        jd6.('exp1').('trial1'){'dims'} = {'time', 'channels'};
        jd6.('exp1').('trial2'){'dims'} = {'samples', 'sensors'};
    end
    test_jsonlab('test nested struct with sibling attributes', @savejson, {jd6.('exp1').('trial1'){'dims'}, jd6.('exp1').('trial2'){'dims'}}, '[["time","channels"],["samples","sensors"]]', 'compact', 1);

    % Test 11: Attribute persistence across navigation
    jd7 = jdict(struct('data', ones(3, 4)));
    if (exist('OCTAVE_VERSION', 'builtin') ~= 0)
        jd7.('data').setattr('dims', {'x', 'y'});
        jd7.('data').setattr('sampling_rate', 1000);
    else
        jd7.('data'){'dims'} = {'x', 'y'};
        jd7.('data'){'sampling_rate'} = 1000;
    end
    test_jsonlab('dims attribute in level 1', @savejson, jd7.('data'){'dims'}, '["x","y"]', 'compact', 1);
    test_jsonlab('other attribute in level 1', @savejson, jd7.('data'){'sampling_rate'}, '[1000]', 'compact', 1);
    test_jsonlab('getattr list top attr key', @savejson, jd7.getattr(), '["$.data"]', 'compact', 1);
    test_jsonlab('getattr return all attributes', @savejson, jd7.getattr('$.data'), '{"dims":["x","y"],"sampling_rate":1000}', 'compact', 1);
    test_jsonlab('getattr get one attr', @savejson, jd7.getattr('$.data', 'dims'), '["x","y"]', 'compact', 1);
    test_jsonlab('savejson with _ArrayLabel_', @savejson, jd7, '{"data":{"_ArrayType_":"double","_ArraySize_":[3,4],"_ArrayData_":[1,1,1,1,1,1,1,1,1,1,1,1],"_ArrayLabel_":["x","y"],"sampling_rate":1000}}', 'compact', 1);
    temp = loadjson(jd7.tojson());
    test_jsonlab('loadjson with _ArrayLabel_', @savejson, temp.data.getattr('$', 'dims'), '["x","y"]', 'compact', 1);

    % Test 12: Multiple attributes different types
    jd8 = jdict(rand(10, 20));
    if (exist('OCTAVE_VERSION', 'builtin') ~= 0)
        jd8.setattr('dims', {'time', 'space'});
        jd8.setattr('units', 'meters');
        jd8.setattr('count', 42);
        jd8.setattr('flag', true);
    else
        jd8{'dims'} = {'time', 'space'};
        jd8{'units'} = 'meters';
        jd8{'count'} = 42;
        jd8{'flag'} = true;
    end
    test_jsonlab('test multiple attributes different types', @savejson, {jd8{'dims'}, jd8{'units'}, jd8{'count'}, jd8{'flag'}}, '[["time","space"],"meters",42,true]', 'compact', 1);
end

%%
if (ismember('schema', tests) && hasContainersMap)
    fprintf(sprintf('%s\n', char(ones(1, 79) * 61)));
    fprintf('Test jdict JSON Schema validation\n');
    fprintf(sprintf('%s\n', char(ones(1, 79) * 61)));

    % =======================================================================
    % setschema/getschema tests
    % =======================================================================
    jd = jdict(struct('name', 'John', 'age', 30));
    jd.setschema(struct('type', 'object'));
    test_jsonlab('setschema from struct', @savejson, ~isempty(jd.getschema()), '[true]', 'compact', 1);
    test_jsonlab('getschema as json', @savejson, ~isempty(strfind(jd.getschema('json'), 'object')), '[true]', 'compact', 1);

    jd.setschema('{"type":"object","properties":{"x":{"type":"integer"}}}');
    test_jsonlab('setschema from json string', @savejson, ~isempty(jd.getschema()), '[true]', 'compact', 1);

    jd.setschema([]);
    test_jsonlab('clear schema / getschema empty', @savejson, isempty(jd.getschema()), '[true]', 'compact', 1);

    % =======================================================================
    % Type validation tests
    % =======================================================================
    types = {'string', 'hello', 123; 'integer', 42, 3.14; 'number', 3.14, 'x'; ...
             'boolean', true, 1; 'null', [], 0; 'array', {{1, 2}}, 'x'; 'object', struct('a', 1), 5};
    for i = 1:size(types, 1)
        jd = jdict(types{i, 2});
        jd.setschema(struct('type', types{i, 1}));
        test_jsonlab(['validate ' types{i, 1} ' pass'], @savejson, isempty(jd.validate()), '[true]', 'compact', 1);
        jd = jdict(types{i, 3});
        jd.setschema(struct('type', types{i, 1}));
        test_jsonlab(['validate ' types{i, 1} ' fail'], @savejson, ~isempty(jd.validate()), '[true]', 'compact', 1);
    end

    % =======================================================================
    % Numeric constraints
    % =======================================================================
    jd = jdict(10);
    jd.setschema(struct('type', 'integer', 'minimum', 5));
    test_jsonlab('validate minimum pass', @savejson, isempty(jd.validate()), '[true]', 'compact', 1);
    jd = jdict(3);
    jd.setschema(struct('type', 'integer', 'minimum', 5));
    test_jsonlab('validate minimum fail', @savejson, ~isempty(jd.validate()), '[true]', 'compact', 1);

    jd = jdict(5);
    jd.setschema(struct('type', 'integer', 'maximum', 10));
    test_jsonlab('validate maximum pass', @savejson, isempty(jd.validate()), '[true]', 'compact', 1);
    jd = jdict(15);
    jd.setschema(struct('type', 'integer', 'maximum', 10));
    test_jsonlab('validate maximum fail', @savejson, ~isempty(jd.validate()), '[true]', 'compact', 1);

    jd = jdict(6);
    jd.setschema(struct('type', 'integer', 'exclusiveMinimum', 5));
    test_jsonlab('validate exclusiveMinimum pass', @savejson, isempty(jd.validate()), '[true]', 'compact', 1);
    jd = jdict(5);
    jd.setschema(struct('type', 'integer', 'exclusiveMinimum', 5));
    test_jsonlab('validate exclusiveMinimum fail', @savejson, ~isempty(jd.validate()), '[true]', 'compact', 1);

    jd = jdict(4);
    jd.setschema(struct('type', 'integer', 'exclusiveMaximum', 5));
    test_jsonlab('validate exclusiveMaximum pass', @savejson, isempty(jd.validate()), '[true]', 'compact', 1);
    jd = jdict(5);
    jd.setschema(struct('type', 'integer', 'exclusiveMaximum', 5));
    test_jsonlab('validate exclusiveMaximum fail', @savejson, ~isempty(jd.validate()), '[true]', 'compact', 1);

    jd = jdict(15);
    jd.setschema(struct('type', 'integer', 'multipleOf', 5));
    test_jsonlab('validate multipleOf pass', @savejson, isempty(jd.validate()), '[true]', 'compact', 1);
    jd = jdict(17);
    jd.setschema(struct('type', 'integer', 'multipleOf', 5));
    test_jsonlab('validate multipleOf fail', @savejson, ~isempty(jd.validate()), '[true]', 'compact', 1);

    % =======================================================================
    % String constraints
    % =======================================================================
    strtests = {'minLength', 'hello', 'hi', 3; 'maxLength', 'hi', 'hello world', 5; ...
                'pattern', 'abc123', '123abc', '^[a-z]+[0-9]+$'; ...
                'format', 'user@example.com', 'notanemail', 'email'};
    for i = 1:size(strtests, 1)
        s = struct('type', 'string', strtests{i, 1}, strtests{i, 4});
        jd = jdict(strtests{i, 2});
        jd.setschema(s);
        test_jsonlab(['validate ' strtests{i, 1} ' pass'], @savejson, isempty(jd.validate()), '[true]', 'compact', 1);
        jd = jdict(strtests{i, 3});
        jd.setschema(s);
        test_jsonlab(['validate ' strtests{i, 1} ' fail'], @savejson, ~isempty(jd.validate()), '[true]', 'compact', 1);
    end

    % =======================================================================
    % Enum and const
    % =======================================================================
    jd = jdict('red');
    jd.setschema(struct('enum', {{'red', 'green', 'blue'}}));
    test_jsonlab('validate enum pass', @savejson, isempty(jd.validate()), '[true]', 'compact', 1);
    jd = jdict('yellow');
    jd.setschema(struct('enum', {{'red', 'green', 'blue'}}));
    test_jsonlab('validate enum fail', @savejson, ~isempty(jd.validate()), '[true]', 'compact', 1);

    jd = jdict('fixed');
    jd.setschema(struct('const', 'fixed'));
    test_jsonlab('validate const pass', @savejson, isempty(jd.validate()), '[true]', 'compact', 1);
    jd = jdict('other');
    jd.setschema(struct('const', 'fixed'));
    test_jsonlab('validate const fail', @savejson, ~isempty(jd.validate()), '[true]', 'compact', 1);

    % =======================================================================
    % Array constraints
    % =======================================================================
    jd = jdict({1, 2, 3});
    jd.setschema(struct('type', 'array', 'minItems', 2));
    test_jsonlab('validate minItems pass', @savejson, isempty(jd.validate()), '[true]', 'compact', 1);
    jd = jdict({1});
    jd.setschema(struct('type', 'array', 'minItems', 2));
    test_jsonlab('validate minItems fail', @savejson, ~isempty(jd.validate()), '[true]', 'compact', 1);

    jd = jdict({1, 2});
    jd.setschema(struct('type', 'array', 'maxItems', 3));
    test_jsonlab('validate maxItems pass', @savejson, isempty(jd.validate()), '[true]', 'compact', 1);
    jd = jdict({1, 2, 3, 4});
    jd.setschema(struct('type', 'array', 'maxItems', 3));
    test_jsonlab('validate maxItems fail', @savejson, ~isempty(jd.validate()), '[true]', 'compact', 1);

    jd = jdict({1, 2, 3});
    jd.setschema(struct('type', 'array', 'uniqueItems', true));
    test_jsonlab('validate uniqueItems pass', @savejson, isempty(jd.validate()), '[true]', 'compact', 1);
    jd = jdict({1, 2, 2});
    jd.setschema(struct('type', 'array', 'uniqueItems', true));
    test_jsonlab('validate uniqueItems fail', @savejson, ~isempty(jd.validate()), '[true]', 'compact', 1);

    jd = jdict({1, 2, 3});
    jd.setschema(struct('type', 'array', 'items', struct('type', 'integer')));
    test_jsonlab('validate items pass', @savejson, isempty(jd.validate()), '[true]', 'compact', 1);
    jd = jdict({1, 'two', 3});
    jd.setschema(struct('type', 'array', 'items', struct('type', 'integer')));
    test_jsonlab('validate items fail', @savejson, ~isempty(jd.validate()), '[true]', 'compact', 1);

    jd = jdict({1, 'hello', 3});
    jd.setschema(struct('type', 'array', 'contains', struct('type', 'string')));
    test_jsonlab('validate contains pass', @savejson, isempty(jd.validate()), '[true]', 'compact', 1);
    jd = jdict({1, 2, 3});
    jd.setschema(struct('type', 'array', 'contains', struct('type', 'string')));
    test_jsonlab('validate contains fail', @savejson, ~isempty(jd.validate()), '[true]', 'compact', 1);

    % =======================================================================
    % Object constraints
    % =======================================================================
    s = struct('type', 'object', 'required', {{'name', 'age'}});
    jd = jdict(struct('name', 'John', 'age', 30));
    jd.setschema(s);
    test_jsonlab('validate required pass', @savejson, isempty(jd.validate()), '[true]', 'compact', 1);
    jd = jdict(struct('name', 'John'));
    jd.setschema(s);
    test_jsonlab('validate required fail', @savejson, ~isempty(jd.validate()), '[true]', 'compact', 1);

    s = struct('type', 'object', 'properties', struct('name', struct('type', 'string'), 'age', struct('type', 'integer')));
    jd = jdict(struct('name', 'John', 'age', 30));
    jd.setschema(s);
    test_jsonlab('validate properties pass', @savejson, isempty(jd.validate()), '[true]', 'compact', 1);
    jd = jdict(struct('name', 123, 'age', 30));
    jd.setschema(s);
    test_jsonlab('validate properties fail', @savejson, ~isempty(jd.validate()), '[true]', 'compact', 1);

    objtests = {'minProperties', struct('a', 1, 'b', 2), struct('a', 1), 2; ...
                'maxProperties', struct('a', 1, 'b', 2), struct('a', 1, 'b', 2, 'c', 3, 'd', 4), 3};
    for i = 1:size(objtests, 1)
        s = struct('type', 'object', objtests{i, 1}, objtests{i, 4});
        jd = jdict(objtests{i, 2});
        jd.setschema(s);
        test_jsonlab(['validate ' objtests{i, 1} ' pass'], @savejson, isempty(jd.validate()), '[true]', 'compact', 1);
        jd = jdict(objtests{i, 3});
        jd.setschema(s);
        test_jsonlab(['validate ' objtests{i, 1} ' fail'], @savejson, ~isempty(jd.validate()), '[true]', 'compact', 1);
    end

    s = struct('type', 'object', 'properties', struct('name', struct('type', 'string')), 'additionalProperties', false);
    jd = jdict(struct('name', 'John'));
    jd.setschema(s);
    test_jsonlab('validate additionalProperties pass', @savejson, isempty(jd.validate()), '[true]', 'compact', 1);
    jd = jdict(struct('name', 'John', 'extra', 'field'));
    jd.setschema(s);
    test_jsonlab('validate additionalProperties fail', @savejson, ~isempty(jd.validate()), '[true]', 'compact', 1);

    % =======================================================================
    % Composition (allOf, anyOf, oneOf, not)
    % =======================================================================
    jd = jdict(10);
    jd.setschema(struct('allOf', {{struct('type', 'integer'), struct('minimum', 5)}}));
    test_jsonlab('validate allOf pass', @savejson, isempty(jd.validate()), '[true]', 'compact', 1);
    jd = jdict(3);
    jd.setschema(struct('allOf', {{struct('type', 'integer'), struct('minimum', 5)}}));
    test_jsonlab('validate allOf fail', @savejson, ~isempty(jd.validate()), '[true]', 'compact', 1);

    jd = jdict('hello');
    jd.setschema(struct('anyOf', {{struct('type', 'integer'), struct('type', 'string')}}));
    test_jsonlab('validate anyOf pass', @savejson, isempty(jd.validate()), '[true]', 'compact', 1);
    jd = jdict(true);
    jd.setschema(struct('anyOf', {{struct('type', 'integer'), struct('type', 'string')}}));
    test_jsonlab('validate anyOf fail', @savejson, ~isempty(jd.validate()), '[true]', 'compact', 1);

    jd = jdict(5);
    jd.setschema(struct('oneOf', {{struct('type', 'integer'), struct('type', 'string')}}));
    test_jsonlab('validate oneOf pass', @savejson, isempty(jd.validate()), '[true]', 'compact', 1);
    jd = jdict(true);
    jd.setschema(struct('oneOf', {{struct('type', 'integer'), struct('type', 'string')}}));
    test_jsonlab('validate oneOf fail', @savejson, ~isempty(jd.validate()), '[true]', 'compact', 1);

    jd = jdict('hello');
    jd.setschema(struct('not', struct('type', 'integer')));
    test_jsonlab('validate not pass', @savejson, isempty(jd.validate()), '[true]', 'compact', 1);
    jd = jdict(42);
    jd.setschema(struct('not', struct('type', 'integer')));
    test_jsonlab('validate not fail', @savejson, ~isempty(jd.validate()), '[true]', 'compact', 1);

    % =======================================================================
    % Nested objects and schema argument
    % =======================================================================
    s = struct('type', 'object', 'properties', struct('person', ...
                                                      struct('type', 'object', 'properties', struct('name', struct('type', 'string'), 'age', struct('type', 'integer')))));
    jd = jdict(struct('person', struct('name', 'John', 'age', 30)));
    jd.setschema(s);
    test_jsonlab('validate nested object pass', @savejson, isempty(jd.validate()), '[true]', 'compact', 1);
    jd = jdict(struct('person', struct('name', 'John', 'age', 'thirty')));
    jd.setschema(s);
    test_jsonlab('validate nested object fail', @savejson, ~isempty(jd.validate()), '[true]', 'compact', 1);

    jd = jdict(struct('x', 10));
    s = struct('type', 'object', 'properties', struct('x', struct('type', 'integer')));
    test_jsonlab('validate with schema arg', @savejson, isempty(jd.validate(s)), '[true]', 'compact', 1);

    % =======================================================================
    % attr2schema tests
    % =======================================================================
    jd = jdict(struct('age', 25));
    jd.('age').setattr(':type', 'integer');
    jd.('age').setattr(':minimum', 0);
    jd.('age').setattr(':maximum', 150);
    schema = jd.attr2schema('title', 'Test Schema');
    test_jsonlab('attr2schema with constraints', @savejson, ...
                 isfield(schema, 'properties') && isfield(schema.properties.age, 'minimum'), '[true]', 'compact', 1);
    test_jsonlab('attr2schema with title', @savejson, strcmp(schema.title, 'Test Schema'), '[true]', 'compact', 1);

    jd.setschema(schema);
    test_jsonlab('attr2schema roundtrip validate', @savejson, isempty(jd.validate()), '[true]', 'compact', 1);

    % =======================================================================
    % Edge cases
    % =======================================================================
    jd = jdict(struct());
    jd.setschema(struct('type', 'object'));
    test_jsonlab('empty object validates', @savejson, isempty(jd.validate()), '[true]', 'compact', 1);

    jd = jdict({});
    jd.setschema(struct('type', 'array'));
    test_jsonlab('empty array validates', @savejson, isempty(jd.validate()), '[true]', 'compact', 1);

    jd = jdict('test');
    jd.setschema(loadjson('{"type":["string","integer"]}', 'usemap', 1));
    test_jsonlab('multiple type validation', @savejson, isempty(jd.validate()), '[true]', 'compact', 1);

    jd = jdict([1, 2, 3, 4, 5]);
    jd.setschema(struct('type', 'array', 'minItems', 3));
    test_jsonlab('numeric array validation', @savejson, isempty(jd.validate()), '[true]', 'compact', 1);

    jd = jdict(struct('count', 5));
    s = '{"$defs":{"posInt":{"type":"integer","minimum":1}},"properties":{"count":{"$ref":"#/$defs/posInt"}}}';
    jd.setschema(loadjson(s, 'usemap', 1));
    test_jsonlab('$ref validation', @savejson, isempty(jd.validate()), '[true]', 'compact', 1);

    jd = jdict(struct('type', 'premium', 'discount', 20));
    s = '{"if":{"properties":{"type":{"const":"premium"}}},"then":{"properties":{"discount":{"minimum":10}}}}';
    jd.setschema(loadjson(s, 'usemap', 1));
    test_jsonlab('if/then validation', @savejson, isempty(jd.validate()), '[true]', 'compact', 1);

    % =======================================================================
    % attr2schema advanced tests
    % =======================================================================
    jd = jdict(struct('name', 'test', 'count', 5));
    jd.('name').setattr(':type', 'string');
    jd.('name').setattr(':minLength', 1);
    jd.('count').setattr(':type', 'integer');
    jd.('count').setattr(':minimum', 0);
    jd.('count').setattr(':maximum', 100);
    schema = jd.attr2schema();
    test_jsonlab('attr2schema multi-field', @savejson, ...
                 isfield(schema.properties, 'name') && isfield(schema.properties, 'count'), '[true]', 'compact', 1);
    test_jsonlab('attr2schema string constraint', @savejson, schema.properties.name.minLength, '[1]', 'compact', 1);
    test_jsonlab('attr2schema integer constraints', @savejson, ...
                 [schema.properties.count.minimum, schema.properties.count.maximum], '[0,100]', 'compact', 1);

    jd = jdict(struct('status', 'active'));
    jd.('status').setattr(':type', 'string');
    jd.('status').setattr(':enum', {'active', 'inactive', 'pending'});
    schema = jd.attr2schema();
    test_jsonlab('attr2schema with enum', @savejson, length(schema.properties.status.enum), '[3]', 'compact', 1);

    % =======================================================================
    % jsonschema() generation tests
    % =======================================================================
    test_jsonlab('generate null', @savejson, jsonschema(struct('type', 'null')), '[]', 'compact', 1);
    test_jsonlab('generate boolean', @savejson, jsonschema(struct('type', 'boolean')), '[false]', 'compact', 1);
    test_jsonlab('generate integer', @savejson, jsonschema(struct('type', 'integer')), '[0]', 'compact', 1);
    test_jsonlab('generate number', @savejson, jsonschema(struct('type', 'number')), '[0]', 'compact', 1);
    test_jsonlab('generate string', @savejson, jsonschema(struct('type', 'string')), '""', 'compact', 1);

    test_jsonlab('generate with default', @savejson, ...
                 jsonschema(struct('type', 'string', 'default', 'hello')), '"hello"', 'compact', 1);
    test_jsonlab('generate with const', @savejson, jsonschema(struct('const', 'fixed')), '"fixed"', 'compact', 1);
    test_jsonlab('generate with enum', @savejson, ...
                 jsonschema(struct('enum', {{'red', 'green', 'blue'}})), '"red"', 'compact', 1);

    test_jsonlab('generate int with minimum', @savejson, ...
                 jsonschema(struct('type', 'integer', 'minimum', 10)), '[10]', 'compact', 1);
    test_jsonlab('generate int with exclusiveMin', @savejson, ...
                 jsonschema(struct('type', 'integer', 'exclusiveMinimum', 10)), '[11]', 'compact', 1);

    s = struct('type', 'integer', 'minimum', 7, 'multipleOf', 5);
    test_jsonlab('generate int with multipleOf', @savejson, jsonschema(s), '[10]', 'compact', 1);

    test_jsonlab('generate string minLength', @savejson, ...
                 length(jsonschema(struct('type', 'string', 'minLength', 5))), '[5]', 'compact', 1);

    test_jsonlab('generate email format', @savejson, ...
                 ~isempty(strfind(jsonschema(struct('type', 'string', 'format', 'email')), '@')), '[true]', 'compact', 1);
    test_jsonlab('generate uri format', @savejson, ...
                 strncmp(jsonschema(struct('type', 'string', 'format', 'uri')), 'http', 4), '[true]', 'compact', 1);
    test_jsonlab('generate date format', @savejson, ...
                 jsonschema(struct('type', 'string', 'format', 'date')), '"2000-01-01"', 'compact', 1);

    test_jsonlab('generate empty array', @savejson, jsonschema(struct('type', 'array')), '[]', 'compact', 1);

    s = struct('type', 'array', 'minItems', 3, 'items', struct('type', 'integer'));
    result = jsonschema(s);
    test_jsonlab('generate array minItems', @savejson, length(result), '[3]', 'compact', 1);

    test_jsonlab('generate empty object', @savejson, jsonschema(struct('type', 'object')), '{}', 'compact', 1);

    s = struct('type', 'object', 'required', {{'name', 'age'}}, ...
               'properties', struct('name', struct('type', 'string', 'default', 'John'), ...
                                    'age', struct('type', 'integer'), ...
                                    'optional', struct('type', 'string')));
    result = jsonschema(s);
    test_jsonlab('generate obj required fields', @savejson, ...
                 isfield(result, 'name') && isfield(result, 'age'), '[true]', 'compact', 1);
    test_jsonlab('generate obj uses default', @savejson, strcmp(result.name, 'John'), '[true]', 'compact', 1);
    test_jsonlab('generate obj skips optional', @savejson, ~isfield(result, 'optional'), '[true]', 'compact', 1);

    result = jsonschema(s, [], 'generate', 'all');
    test_jsonlab('generate all fields', @savejson, isfield(result, 'optional'), '[true]', 'compact', 1);

    s2 = struct('type', 'object', 'required', {{'id'}}, ...
                'properties', struct('id', struct('type', 'integer'), ...
                                     'extra', struct('type', 'string', 'default', 'test')));
    result = jsonschema(s2, [], 'generate', 'required');
    test_jsonlab('generate required only', @savejson, ...
                 isfield(result, 'id') && ~isfield(result, 'extra'), '[true]', 'compact', 1);

    s = struct('type', 'object', 'required', {{'person'}}, ...
               'properties', struct('person', struct('type', 'object', 'required', {{'name'}}, ...
                                                     'properties', struct('name', struct('type', 'string', 'default', 'Anonymous')))));
    result = jsonschema(s);
    test_jsonlab('generate nested object', @savejson, ...
                 isfield(result, 'person') && isfield(result.person, 'name'), '[true]', 'compact', 1);
    test_jsonlab('generate nested default', @savejson, strcmp(result.person.name, 'Anonymous'), '[true]', 'compact', 1);

    s = loadjson('{"$defs":{"name":{"type":"string","default":"RefName"}},"type":"object","required":["title"],"properties":{"title":{"$ref":"#/$defs/name"}}}', 'usemap', 1);
    result = jsonschema(s);
    test_jsonlab('generate with $ref', @savejson, strcmp(result.title, 'RefName'), '[true]', 'compact', 1);

    s = struct('type', 'object', 'allOf', {{struct('properties', struct('a', struct('type', 'integer', 'default', 1))), ...
                                            struct('properties', struct('b', struct('type', 'string', 'default', 'x')))}});
    result = jsonschema(s);
    test_jsonlab('generate with allOf', @savejson, ...
                 isstruct(result) && isfield(result, 'a') && isfield(result, 'b'), '[true]', 'compact', 1);

    s = struct('type', 'object', 'required', {{'id', 'name'}}, ...
               'properties', struct('id', struct('type', 'integer', 'minimum', 1, 'default', 1), ...
                                    'name', struct('type', 'string', 'minLength', 1, 'default', 'test')));
    result = jsonschema(s);
    [valid, ~] = jsonschema(result, s);
    test_jsonlab('generated data validates', @savejson, valid, '[true]', 'compact', 1);

    clear jd s s2 schema result valid types strtests objtests;
end

%%
if (ismember('jdictadv', tests) && hasContainersMap)
    fprintf(sprintf('%s\n', char(ones(1, 79) * 61)));
    fprintf('Test jdict advanced member functions\n');
    fprintf(sprintf('%s\n', char(ones(1, 79) * 61)));

    % =======================================================================
    % numel tests
    % =======================================================================
    jd = jdict(struct('a', 1, 'b', 2));
    test_jsonlab('numel without indexing', @savejson, numel(jd), '[1]', 'compact', 1);
    test_jsonlab('numel with indexing', @savejson, numel(jd, 'a'), '[1]', 'compact', 1);

    jd = jdict([1, 2, 3, 4, 5]);
    if (exist('OCTAVE_VERSION', 'builtin') == 0)
        test_jsonlab('numel array data', @savejson, numel(jd), '[5]', 'compact', 1);
    else
        test_jsonlab('numel array data', @savejson, numel(jd), '[1]', 'compact', 1);
    end

    % =======================================================================
    % tojson with options
    % =======================================================================
    jd = jdict(struct('name', 'test', 'value', 123));
    test_jsonlab('tojson compact', @savejson, ~isempty(strfind(jd.tojson(), '"name"')), '[true]', 'compact', 1);
    test_jsonlab('tojson no space', @savejson, isempty(strfind(jd.tojson(), ': ')), '[true]', 'compact', 1);

    jd = jdict(struct('arr', [1, 2, 3]));
    json = jd.tojson('nestarray', 1);
    test_jsonlab('tojson with nestarray', @savejson, ~isempty(strfind(json, '[1,2,3]')), '[true]', 'compact', 1);

    % =======================================================================
    % keys, len, size, isKey tests
    % =======================================================================
    jd = jdict(struct('a', 1, 'b', 2, 'c', 3));
    test_jsonlab('keys on struct', @savejson, length(jd.keys()), '[3]', 'compact', 1);
    test_jsonlab('len on struct', @savejson, jd.len(), '[3]', 'compact', 1);
    test_jsonlab('isKey exists', @savejson, jd.isKey('a'), '[true]', 'compact', 1);
    test_jsonlab('isKey not exists', @savejson, jd.isKey('x'), '[false]', 'compact', 1);

    jd = jdict([1, 2, 3, 4, 5]);
    test_jsonlab('keys on array', @savejson, jd.keys(), '[1,2,3,4,5]', 'compact', 1);
    test_jsonlab('len on array', @savejson, jd.len(), '[5]', 'compact', 1);
    test_jsonlab('size on row vector', @savejson, jd.size(), '[1,5]', 'compact', 1);
    test_jsonlab('isKey in range', @savejson, jd.isKey(3), '[true]', 'compact', 1);
    test_jsonlab('isKey out of range', @savejson, jd.isKey(10), '[false]', 'compact', 1);

    jd = jdict(reshape(1:12, 3, 4));
    test_jsonlab('size on 2D array', @savejson, jd.size(), '[3,4]', 'compact', 1);
    test_jsonlab('len on 2D array', @savejson, jd.len(), '[4]', 'compact', 1);

    jd = jdict({'a', 'b', 'c'});
    test_jsonlab('keys on cell', @savejson, jd.keys(), '[1,2,3]', 'compact', 1);
    test_jsonlab('len on cell', @savejson, jd.len(), '[3]', 'compact', 1);

    if hasContainersMap
        jd = jdict(containers.Map({'x', 'y', 'z'}, {1, 2, 3}));
        k = jd.keys();
        test_jsonlab('keys on Map', @savejson, length(k), '[3]', 'compact', 1);
        test_jsonlab('len on Map', @savejson, jd.len(), '[3]', 'compact', 1);
        test_jsonlab('isKey on Map exists', @savejson, jd.isKey('x'), '[true]', 'compact', 1);
        test_jsonlab('isKey on Map not exists', @savejson, jd.isKey('w'), '[false]', 'compact', 1);
    end

    % =======================================================================
    % v() method tests
    % =======================================================================
    jd = jdict([10, 20, 30, 40]);
    test_jsonlab('v() returns data', @savejson, jd.v(), '[10,20,30,40]', 'compact', 1);
    test_jsonlab('v(idx) single', @savejson, jd.v(2), '[20]', 'compact', 1);
    test_jsonlab('v(range)', @savejson, jd.v(2:3), '[20,30]', 'compact', 1);

    jd = jdict({'a', 'b', 'c'});
    test_jsonlab('v() on cell', @savejson, jd.v(), '["a","b","c"]', 'compact', 1);
    test_jsonlab('v(idx) on cell', @savejson, jd.v(2), '"b"', 'compact', 1);

    jd = jdict(struct('arr', {{1, 2, 3}}));
    test_jsonlab('nested v() access', @savejson, jd.('arr').v(2).v(), '[2]', 'compact', 1);

    % =======================================================================
    % Dimension-based indexing
    % =======================================================================
    jd = jdict(struct('data', zeros(4, 5, 6)));
    jd.('data').setattr('dims', {'x', 'y', 'z'});
    test_jsonlab('dims attribute set', @savejson, jd.('data').getattr('dims'), '["x","y","z"]', 'compact', 1);

    result = jd.('data').x(2);
    test_jsonlab('dim slice x size', @savejson, size(result.v()), '[1,5,6]', 'compact', 1);

    result = jd.('data').y(3);
    test_jsonlab('dim slice y size', @savejson, size(result.v()), '[4,1,6]', 'compact', 1);

    result = jd.('data').z(4);
    test_jsonlab('dim slice z size', @savejson, size(result.v()), '[4,5]', 'compact', 1);

    result = jd.('data').x(1:2);
    test_jsonlab('dim range slice size', @savejson, size(result.v()), '[2,5,6]', 'compact', 1);

    % =======================================================================
    % containers.Map as underlying data
    % =======================================================================
    if hasContainersMap
        m = containers.Map();
        m('key1') = struct('nested', 'value1');
        m('key2') = [1, 2, 3];
        jd = jdict(m);

        test_jsonlab('Map access key1', @savejson, jd.('key1').('nested'), '"value1"', 'compact', 1);
        test_jsonlab('Map access key2', @savejson, jd.('key2'), '[1,2,3]', 'compact', 1);

        jd.('key3') = 'newvalue';
        test_jsonlab('Map add new key', @savejson, jd.('key3'), '"newvalue"', 'compact', 1);

        jd.('key1').('nested') = 'modified';
        test_jsonlab('Map modify nested', @savejson, jd.('key1').('nested'), '"modified"', 'compact', 1);
    end

    % =======================================================================
    % JSONPath tests
    % =======================================================================
    jd = jdict(struct('level1', struct('level2', struct('level3', struct('value', 42)))));
    test_jsonlab('jsonpath deep access', @savejson, jd.('$.level1.level2.level3.value'), '[42]', 'compact', 1);
    test_jsonlab('jsonpath deep scan', @savejson, jd.('$..value'), '[42]', 'compact', 1);

    jd.('$.level1.level2.level3.value') = 100;
    test_jsonlab('jsonpath assignment', @savejson, jd.('$.level1.level2.level3.value'), '[100]', 'compact', 1);

    jd = jdict(struct('items', {{struct('id', 1), struct('id', 2), struct('id', 3)}}));
    test_jsonlab('jsonpath array index', @savejson, jd.('$.items[1].id'), '[2]', 'compact', 1);

    % =======================================================================
    % Struct array field access
    % =======================================================================
    sa = struct('name', {'Alice', 'Bob', 'Charlie'}, 'age', {25, 30, 35});
    jd = jdict(sa);
    result = jd.('name');
    test_jsonlab('struct array field names', @savejson, result(), '["Alice","Bob","Charlie"]', 'compact', 1);
    result = jd.('age');
    ages = result();
    test_jsonlab('struct array field ages', @savejson, ages(:)', '[25,30,35]', 'compact', 1);
    names = jd.('name')();
    test_jsonlab('struct array field indexed', @savejson, names{2}, '"Bob"', 'compact', 1);

    % =======================================================================
    % Constructor tests
    % =======================================================================
    jd = jdict();
    test_jsonlab('empty constructor', @savejson, isempty(jd.v()), '[true]', 'compact', 1);
    jd.('newkey') = 'newvalue';
    test_jsonlab('add to empty jdict', @savejson, jd.('newkey'), '"newvalue"', 'compact', 1);

    jd1 = jdict(struct('a', 1, 'b', 2));
    jd1.setattr('$.a', 'myattr', 'attrvalue');
    jd2 = jdict(jd1);
    test_jsonlab('jdict copy data', @savejson, jd2.('a')(), '[1]', 'compact', 1);
    test_jsonlab('jdict copy attr', @savejson, jd2.getattr('$.a', 'myattr'), '"attrvalue"', 'compact', 1);

    % =======================================================================
    % Attribute operations
    % =======================================================================
    jd = jdict(struct('x', 1, 'y', 2));
    jd.setattr('$.x', 'attr1', 'val1');
    jd.setattr('$.x', 'attr2', 100);
    jd.setattr('$.y', 'attr1', 'val2');

    test_jsonlab('getattr single', @savejson, jd.getattr('$.x', 'attr1'), '"val1"', 'compact', 1);
    test_jsonlab('getattr numeric', @savejson, jd.getattr('$.x', 'attr2'), '[100]', 'compact', 1);

    xattrs = jd.getattr('$.x');
    test_jsonlab('getattr all for path', @savejson, ...
                 isa(xattrs, 'containers.Map') && length(keys(xattrs)) == 2, '[true]', 'compact', 1);

    allpaths = jd.getattr();
    test_jsonlab('getattr list paths', @savejson, length(allpaths), '[2]', 'compact', 1);

    if (exist('OCTAVE_VERSION', 'builtin') == 0)
        jd.('x'){'newattr'} = 'curlyval';
        test_jsonlab('curly bracket setattr', @savejson, jd.('x'){'newattr'}, '"curlyval"', 'compact', 1);
    end

    % =======================================================================
    % Special key names
    % =======================================================================
    jd = jdict();
    jd.('_DataInfo_') = struct('version', '1.0');
    test_jsonlab('special key _DataInfo_', @savejson, jd.('_DataInfo_').('version'), '"1.0"', 'compact', 1);

    if hasContainersMap
        jd = jdict(struct());
        jd.data = containers.Map();
        jd.('data').('key.with" dots') = 'dotvalue';
        test_jsonlab('key with dots', @savejson, jd.('data').('key.with" dots'), '"dotvalue"', 'compact', 1);
    end

    % =======================================================================
    % Built-in key names
    % =======================================================================
    jd = jdict();
    jd.v = struct('k', 1);
    jd.attr = [1, 2, 3];
    jd.flags__ = 'flags__value';
    jd.tojson = 'tojson_value';
    test_jsonlab('key with dots', @savejson, {jd.v, jd.v.v(), jd.v.k, jd.attr.v(2), jd.flags__, jd.tojson.tojson()}, '[{"k":1},{"k":1},1,2,"flags__value","\"tojson_value\""]', 'compact', 1);
    jd.v.k = 10;
    jd.v.k{'dims'} = {'count'};
    test_jsonlab('key with dots', @savejson, jd.v.k{'dims'}, '["count"]', 'compact', 1);

    % =======================================================================
    % Mixed nested structures
    % =======================================================================
    if hasContainersMap
        jd = jdict();
        m = containers.Map('KeyType', 'char', 'ValueType', 'any');
        m('opt1') = 'val1';
        m('opt2') = 'val2';
        jd.('config') = struct('settings', m);
        jd.('config').('settings').('opt3') = 'new';
        test_jsonlab('mixed struct/map nested', @savejson, jd.('config').('settings').('opt3')(), '"new"', 'compact', 1);

        jd.('config').('list') = {1, 'two', struct('three', 3)};
        test_jsonlab('mixed with cell', @savejson, jd.('config').('list').v(3).('three')(), '[3]', 'compact', 1);
    end

    % =======================================================================
    % Error handling
    % =======================================================================
    jd = jdict(struct('a', 1));
    test_jsonlab('nonexistent attr empty', @savejson, isempty(jd.getattr('$', 'nonexistent')), '[true]', 'compact', 1);
    test_jsonlab('nested nonexistent attr', @savejson, isempty(jd.('a').getattr('noattr')), '[true]', 'compact', 1);

    clear jd jd1 jd2 m k sa result json xattrs allpaths;
end

if (ismember('schemaadv', tests) && hasContainersMap)
    fprintf(sprintf('%s\n', char(ones(1, 79) * 61)));
    fprintf('Test jdict schema-validated assignment and subkey validation\n');
    fprintf(sprintf('%s\n', char(ones(1, 79) * 61)));

    % =======================================================================
    % Schema-validated assignment (<=) tests - root level
    % =======================================================================
    jd = jdict('hello');
    jd.setschema(struct('type', 'string'));
    jd <= 'world';
    test_jsonlab('<= root string pass', @savejson, jd(), '"world"', 'compact', 1);

    jd = jdict(10);
    jd.setschema(struct('type', 'integer', 'minimum', 0, 'maximum', 100));
    jd <= 50;
    test_jsonlab('<= root integer pass', @savejson, jd(), '[50]', 'compact', 1);

    jd = jdict(10);
    jd.setschema(struct('type', 'integer', 'minimum', 0));
    try
        jd <= -5;
        test_jsonlab('<= root integer fail', @savejson, false, '[true]', 'compact', 1);
    catch
        test_jsonlab('<= root integer fail', @savejson, true, '[true]', 'compact', 1);
    end

    jd = jdict('test');
    jd.setschema(struct('type', 'string', 'minLength', 3));
    try
        jd <= 'ab';
        test_jsonlab('<= root string minLength fail', @savejson, false, '[true]', 'compact', 1);
    catch
        test_jsonlab('<= root string minLength fail', @savejson, true, '[true]', 'compact', 1);
    end

    % =======================================================================
    % Schema-validated assignment (<=) tests - subkey level
    % =======================================================================
    jd = jdict(struct('name', 'John', 'age', 30));
    jd.setschema(struct('type', 'object', 'properties', ...
                        struct('name', struct('type', 'string'), ...
                               'age', struct('type', 'integer', 'minimum', 0, 'maximum', 150))));
    jd.name <= 'Jane';
    test_jsonlab('<= subkey string pass', @savejson, jd().name, '"Jane"', 'compact', 1);

    jd.age <= 25;
    test_jsonlab('<= subkey integer pass', @savejson, jd().age, '[25]', 'compact', 1);

    try
        jd.age <= -10;
        test_jsonlab('<= subkey integer minimum fail', @savejson, false, '[true]', 'compact', 1);
    catch
        test_jsonlab('<= subkey integer minimum fail', @savejson, true, '[true]', 'compact', 1);
    end

    try
        jd.age <= 200;
        test_jsonlab('<= subkey integer maximum fail', @savejson, false, '[true]', 'compact', 1);
    catch
        test_jsonlab('<= subkey integer maximum fail', @savejson, true, '[true]', 'compact', 1);
    end

    try
        jd.name <= 123;
        test_jsonlab('<= subkey type mismatch fail', @savejson, false, '[true]', 'compact', 1);
    catch
        test_jsonlab('<= subkey type mismatch fail', @savejson, true, '[true]', 'compact', 1);
    end

    % =======================================================================
    % Schema-validated assignment (<=) tests - nested subkey
    % =======================================================================
    jd = jdict(struct('person', struct('name', 'John', 'age', 30)));
    s = struct('type', 'object', 'properties', struct('person', ...
                                                      struct('type', 'object', 'properties', ...
                                                             struct('name', struct('type', 'string', 'minLength', 1), ...
                                                                    'age', struct('type', 'integer', 'minimum', 0)))));
    jd.setschema(s);

    jd.person.name <= 'Alice';
    test_jsonlab('<= nested subkey pass', @savejson, jd().person.name, '"Alice"', 'compact', 1);

    jd.person.age <= 40;
    test_jsonlab('<= nested subkey integer pass', @savejson, jd().person.age, '[40]', 'compact', 1);

    try
        jd.person.name <= '';
        test_jsonlab('<= nested subkey minLength fail', @savejson, false, '[true]', 'compact', 1);
    catch
        test_jsonlab('<= nested subkey minLength fail', @savejson, true, '[true]', 'compact', 1);
    end

    try
        jd.person.age <= -5;
        test_jsonlab('<= nested subkey minimum fail', @savejson, false, '[true]', 'compact', 1);
    catch
        test_jsonlab('<= nested subkey minimum fail', @savejson, true, '[true]', 'compact', 1);
    end

    % =======================================================================
    % Schema-validated assignment (<=) tests - no schema
    % =======================================================================
    jd = jdict(struct('x', 1));
    jd.x <= 999;
    test_jsonlab('<= no schema allows assignment', @savejson, jd().x, '[999]', 'compact', 1);

    % =======================================================================
    % Schema-validated assignment (<=) tests - no subschema for path
    % =======================================================================
    jd = jdict(struct('a', 1, 'b', 2));
    jd.setschema(struct('type', 'object', 'properties', ...
                        struct('a', struct('type', 'integer'))));
    jd.b <= 'anything';
    test_jsonlab('<= no subschema allows assignment', @savejson, jd().b, '"anything"', 'compact', 1);

    % =======================================================================
    % Schema-validated assignment (<=) tests - with $ref
    % =======================================================================
    jd = jdict(struct('count', 5, 'total', 10));
    s = ['{"$defs":{"posInt":{"type":"integer","minimum":0}},' ...
         '"type":"object","properties":{' ...
         '"count":{"$ref":"#/$defs/posInt"},' ...
         '"total":{"$ref":"#/$defs/posInt"}}}'];
    jd.setschema(loadjson(s, 'usemap', 1));

    jd.count <= 100;
    test_jsonlab('<= $ref pass', @savejson, jd().count, '[100]', 'compact', 1);

    try
        jd.total <= -1;
        test_jsonlab('<= $ref minimum fail', @savejson, false, '[true]', 'compact', 1);
    catch
        test_jsonlab('<= $ref minimum fail', @savejson, true, '[true]', 'compact', 1);
    end

    % =======================================================================
    % Schema-validated assignment (<=) tests - array items
    % =======================================================================
    jd = jdict(struct('scores', {{1, 2, 3}}));
    jd.setschema(struct('type', 'object', 'properties', ...
                        struct('scores', struct('type', 'array', ...
                                                'items', struct('type', 'integer', 'minimum', 0)))));

    jd.scores <= {10, 20, 30};
    test_jsonlab('<= array pass', @savejson, jd().scores, '[10,20,30]', 'compact', 1);

    try
        jd.scores <= {1, -2, 3};
        test_jsonlab('<= array items fail', @savejson, false, '[true]', 'compact', 1);
    catch
        test_jsonlab('<= array items fail', @savejson, true, '[true]', 'compact', 1);
    end

    % =======================================================================
    % Schema-validated assignment (<=) tests - enum
    % =======================================================================
    jd = jdict(struct('status', 'active'));
    jd.setschema(struct('type', 'object', 'properties', ...
                        struct('status', struct('type', 'string', ...
                                                'enum', {{'active', 'inactive', 'pending'}}))));

    jd.status <= 'inactive';
    test_jsonlab('<= enum pass', @savejson, jd().status, '"inactive"', 'compact', 1);

    try
        jd.status <= 'unknown';
        test_jsonlab('<= enum fail', @savejson, false, '[true]', 'compact', 1);
    catch
        test_jsonlab('<= enum fail', @savejson, true, '[true]', 'compact', 1);
    end

    % =======================================================================
    % Schema-validated assignment (<=) tests - const
    % =======================================================================
    jd = jdict(struct('version', '1.0'));
    jd.setschema(struct('type', 'object', 'properties', ...
                        struct('version', struct('const', '1.0'))));

    jd.version <= '1.0';
    test_jsonlab('<= const pass', @savejson, jd().version, '"1.0"', 'compact', 1);

    try
        jd.version <= '2.0';
        test_jsonlab('<= const fail', @savejson, false, '[true]', 'compact', 1);
    catch
        test_jsonlab('<= const fail', @savejson, true, '[true]', 'compact', 1);
    end

    % =======================================================================
    % Schema-validated assignment (<=) tests - pattern
    % =======================================================================
    jd = jdict(struct('email', 'test@example.com'));
    pat = '^[^@]+@[^@]+\.[^@]+$';
    jd.setschema(struct('type', 'object', 'properties', ...
                        struct('email', struct('type', 'string', 'pattern', pat))));

    jd.email <= 'user@domain.org';
    test_jsonlab('<= pattern pass', @savejson, jd().email, '"user@domain.org"', 'compact', 1);

    try
        jd.email <= 'invalid-email';
        test_jsonlab('<= pattern fail', @savejson, false, '[true]', 'compact', 1);
    catch
        test_jsonlab('<= pattern fail', @savejson, true, '[true]', 'compact', 1);
    end

    % =======================================================================
    % Schema-validated assignment (<=) tests - format
    % =======================================================================
    jd = jdict(struct('website', 'http://example.com'));
    jd.setschema(struct('type', 'object', 'properties', ...
                        struct('website', struct('type', 'string', 'format', 'uri'))));

    jd.website <= 'https://newsite.org';
    test_jsonlab('<= format uri pass', @savejson, jd().website, '"https://newsite.org"', 'compact', 1);

    try
        jd.website <= 'not-a-url';
        test_jsonlab('<= format uri fail', @savejson, false, '[true]', 'compact', 1);
    catch
        test_jsonlab('<= format uri fail', @savejson, true, '[true]', 'compact', 1);
    end

    % =======================================================================
    % Schema-validated assignment (<=) tests - multipleOf
    % =======================================================================
    jd = jdict(struct('quantity', 10));
    jd.setschema(struct('type', 'object', 'properties', ...
                        struct('quantity', struct('type', 'integer', 'multipleOf', 5))));

    jd.quantity <= 25;
    test_jsonlab('<= multipleOf pass', @savejson, jd().quantity, '[25]', 'compact', 1);

    try
        jd.quantity <= 17;
        test_jsonlab('<= multipleOf fail', @savejson, false, '[true]', 'compact', 1);
    catch
        test_jsonlab('<= multipleOf fail', @savejson, true, '[true]', 'compact', 1);
    end

    % =======================================================================
    % Schema-validated assignment (<=) tests - exclusiveMinimum/Maximum
    % =======================================================================
    jd = jdict(struct('score', 50));
    jd.setschema(struct('type', 'object', 'properties', ...
                        struct('score', struct('type', 'integer', ...
                                               'exclusiveMinimum', 0, 'exclusiveMaximum', 100))));

    jd.score <= 50;
    test_jsonlab('<= exclusive range pass', @savejson, jd().score, '[50]', 'compact', 1);

    try
        jd.score <= 0;
        test_jsonlab('<= exclusiveMinimum fail', @savejson, false, '[true]', 'compact', 1);
    catch
        test_jsonlab('<= exclusiveMinimum fail', @savejson, true, '[true]', 'compact', 1);
    end

    try
        jd.score <= 100;
        test_jsonlab('<= exclusiveMaximum fail', @savejson, false, '[true]', 'compact', 1);
    catch
        test_jsonlab('<= exclusiveMaximum fail', @savejson, true, '[true]', 'compact', 1);
    end

    % =======================================================================
    % Schema-validated assignment (<=) tests - maxLength
    % =======================================================================
    jd = jdict(struct('code', 'ABC'));
    jd.setschema(struct('type', 'object', 'properties', ...
                        struct('code', struct('type', 'string', 'minLength', 2, 'maxLength', 5))));

    jd.code <= 'XYZ';
    test_jsonlab('<= string length pass', @savejson, jd().code, '"XYZ"', 'compact', 1);

    try
        jd.code <= 'A';
        test_jsonlab('<= minLength fail', @savejson, false, '[true]', 'compact', 1);
    catch
        test_jsonlab('<= minLength fail', @savejson, true, '[true]', 'compact', 1);
    end

    try
        jd.code <= 'TOOLONGCODE';
        test_jsonlab('<= maxLength fail', @savejson, false, '[true]', 'compact', 1);
    catch
        test_jsonlab('<= maxLength fail', @savejson, true, '[true]', 'compact', 1);
    end

    % =======================================================================
    % Schema-validated assignment (<=) tests - allOf
    % =======================================================================
    jd = jdict(struct('value', 10));
    jd.setschema(struct('type', 'object', 'properties', ...
                        struct('value', struct('allOf', {{struct('type', 'integer'), ...
                                                          struct('minimum', 5), struct('maximum', 20)}}))));

    jd.value <= 15;
    test_jsonlab('<= allOf pass', @savejson, jd().value, '[15]', 'compact', 1);

    try
        jd.value <= 3;
        test_jsonlab('<= allOf fail', @savejson, false, '[true]', 'compact', 1);
    catch
        test_jsonlab('<= allOf fail', @savejson, true, '[true]', 'compact', 1);
    end

    % =======================================================================
    % Schema-validated assignment (<=) tests - anyOf
    % =======================================================================
    jd = jdict(struct('id', 'abc'));
    jd.setschema(struct('type', 'object', 'properties', ...
                        struct('id', struct('anyOf', {{struct('type', 'string'), ...
                                                       struct('type', 'integer')}}))));

    jd.id <= 'xyz';
    test_jsonlab('<= anyOf string pass', @savejson, jd().id, '"xyz"', 'compact', 1);

    jd.id <= 123;
    test_jsonlab('<= anyOf integer pass', @savejson, jd().id, '[123]', 'compact', 1);

    try
        jd.id <= true;
        test_jsonlab('<= anyOf fail', @savejson, false, '[true]', 'compact', 1);
    catch
        test_jsonlab('<= anyOf fail', @savejson, true, '[true]', 'compact', 1);
    end

    % =======================================================================
    % Schema-validated assignment (<=) tests - oneOf
    % =======================================================================
    jd = jdict(struct('dat', 5));
    jd.setschema(struct('type', 'object', 'properties', ...
                        struct('dat', struct('oneOf', {{struct('type', 'integer', 'minimum', 10), ...
                                                        struct('type', 'integer', 'maximum', 5)}}))));

    jd.dat <= 3;
    test_jsonlab('<= oneOf pass (second)', @savejson, jd().dat, '[3]', 'compact', 1);

    jd.dat <= 15;
    test_jsonlab('<= oneOf pass (first)', @savejson, jd().dat, '[15]', 'compact', 1);

    try
        jd.dat <= 7;
        test_jsonlab('<= oneOf fail (matches none)', @savejson, false, '[true]', 'compact', 1);
    catch
        test_jsonlab('<= oneOf fail (matches none)', @savejson, true, '[true]', 'compact', 1);
    end

    % =======================================================================
    % Schema-validated assignment (<=) tests - not
    % =======================================================================
    jd = jdict(struct('tag', 'hello'));
    jd.setschema(struct('type', 'object', 'properties', ...
                        struct('tag', struct('not', struct('type', 'integer')))));

    jd.tag <= 'world';
    test_jsonlab('<= not pass', @savejson, jd().tag, '"world"', 'compact', 1);

    try
        jd.tag <= 42;
        test_jsonlab('<= not fail', @savejson, false, '[true]', 'compact', 1);
    catch
        test_jsonlab('<= not fail', @savejson, true, '[true]', 'compact', 1);
    end

    % =======================================================================
    % Schema-validated assignment (<=) tests - minItems/maxItems
    % =======================================================================
    jd = jdict(struct('nums', {{1, 2, 3}}));
    jd.setschema(struct('type', 'object', 'properties', ...
                        struct('nums', struct('type', 'array', 'minItems', 2, 'maxItems', 5))));

    jd.nums <= {1, 2, 3, 4};
    test_jsonlab('<= array length pass', @savejson, jd().nums, '[1,2,3,4]', 'compact', 1);

    try
        jd.nums <= {1};
        test_jsonlab('<= minItems fail', @savejson, false, '[true]', 'compact', 1);
    catch
        test_jsonlab('<= minItems fail', @savejson, true, '[true]', 'compact', 1);
    end

    try
        jd.nums <= {1, 2, 3, 4, 5, 6};
        test_jsonlab('<= maxItems fail', @savejson, false, '[true]', 'compact', 1);
    catch
        test_jsonlab('<= maxItems fail', @savejson, true, '[true]', 'compact', 1);
    end

    % =======================================================================
    % Schema-validated assignment (<=) tests - uniqueItems
    % =======================================================================
    jd = jdict(struct('tags', {{'a', 'b', 'c'}}));
    jd.setschema(struct('type', 'object', 'properties', ...
                        struct('tags', struct('type', 'array', 'uniqueItems', true))));

    jd.tags <= {'x', 'y', 'z'};
    test_jsonlab('<= uniqueItems pass', @savejson, jd().tags, '["x","y","z"]', 'compact', 1);

    try
        jd.tags <= {'a', 'b', 'a'};
        test_jsonlab('<= uniqueItems fail', @savejson, false, '[true]', 'compact', 1);
    catch
        test_jsonlab('<= uniqueItems fail', @savejson, true, '[true]', 'compact', 1);
    end

    % =======================================================================
    % Schema-validated assignment (<=) tests - contains
    % =======================================================================
    jd = jdict(struct('mixed', {{1, 'hello', 3}}));
    jd.setschema(struct('type', 'object', 'properties', ...
                        struct('mixed', struct('type', 'array', ...
                                               'contains', struct('type', 'string')))));

    jd.mixed <= {1, 2, 'world'};
    test_jsonlab('<= contains pass', @savejson, jd.mixed.v(3), '"world"', 'compact', 1);

    try
        jd.mixed <= {1, 2, 3};
        test_jsonlab('<= contains fail', @savejson, false, '[true]', 'compact', 1);
    catch
        test_jsonlab('<= contains fail', @savejson, true, '[true]', 'compact', 1);
    end

    % =======================================================================
    % Schema-validated assignment (<=) tests - required
    % =======================================================================
    jd = jdict(struct('obj', struct('a', 1, 'b', 2)));
    jd.setschema(struct('type', 'object', 'properties', ...
                        struct('obj', struct('type', 'object', 'required', {{'a', 'b'}}))));

    jd.obj <= struct('a', 10, 'b', 20);
    test_jsonlab('<= required pass', @savejson, jd().obj, '{"a":10,"b":20}', 'compact', 1);

    try
        jd.obj <= struct('a', 10);
        test_jsonlab('<= required fail', @savejson, false, '[true]', 'compact', 1);
    catch
        test_jsonlab('<= required fail', @savejson, true, '[true]', 'compact', 1);
    end

    % =======================================================================
    % Schema-validated assignment (<=) tests - additionalProperties
    % =======================================================================
    jd = jdict(struct('config', struct('name', 'test')));
    jd.setschema(struct('type', 'object', 'properties', ...
                        struct('config', struct('type', 'object', ...
                                                'properties', struct('name', struct('type', 'string')), ...
                                                'additionalProperties', false))));

    jd.config <= struct('name', 'valid');
    test_jsonlab('<= additionalProperties pass', @savejson, jd().config, '{"name":"valid"}', 'compact', 1);

    try
        jd.config <= struct('name', 'test', 'extra', 'field');
        test_jsonlab('<= additionalProperties fail', @savejson, false, '[true]', 'compact', 1);
    catch
        test_jsonlab('<= additionalProperties fail', @savejson, true, '[true]', 'compact', 1);
    end

    % =======================================================================
    % Schema-validated assignment (<=) tests - minProperties/maxProperties
    % =======================================================================
    jd = jdict(struct('meta', struct('a', 1, 'b', 2)));
    jd.setschema(struct('type', 'object', 'properties', ...
                        struct('meta', struct('type', 'object', ...
                                              'minProperties', 2, 'maxProperties', 4))));

    jd.meta <= struct('x', 1, 'y', 2, 'z', 3);
    test_jsonlab('<= properties count pass', @savejson, jd().meta, '{"x":1,"y":2,"z":3}', 'compact', 1);

    try
        jd.meta <= struct('a', 1);
        test_jsonlab('<= minProperties fail', @savejson, false, '[true]', 'compact', 1);
    catch
        test_jsonlab('<= minProperties fail', @savejson, true, '[true]', 'compact', 1);
    end

    try
        jd.meta <= struct('a', 1, 'b', 2, 'c', 3, 'd', 4, 'e', 5);
        test_jsonlab('<= maxProperties fail', @savejson, false, '[true]', 'compact', 1);
    catch
        test_jsonlab('<= maxProperties fail', @savejson, true, '[true]', 'compact', 1);
    end

    % =======================================================================
    % validate() at subkey level
    % =======================================================================
    jd = jdict(struct('name', 'John', 'age', 30));
    jd.setschema(struct('type', 'object', 'properties', ...
                        struct('name', struct('type', 'string'), ...
                               'age', struct('type', 'integer', 'minimum', 0))));
    test_jsonlab('validate root pass', @savejson, jd.validate(), '[]', 'compact', 1);
    test_jsonlab('validate subkey name pass', @savejson, jd.name.validate(), '[]', 'compact', 1);
    test_jsonlab('validate subkey age pass', @savejson, jd.age.validate(), '[]', 'compact', 1);

    jd.age = -10;
    test_jsonlab('validate root fail', @savejson, length(jd.validate()) > 0, '[true]', 'compact', 1);
    test_jsonlab('validate subkey age fail', @savejson, length(jd.age.validate()) > 0, '[true]', 'compact', 1);
    test_jsonlab('validate subkey name still pass', @savejson, jd.name.validate(), '[]', 'compact', 1);

    % =======================================================================
    % validate() nested subkey
    % =======================================================================
    jd = jdict(struct('person', struct('name', 'Alice', 'age', 25)));
    s = struct('type', 'object', 'properties', struct('person', ...
                                                      struct('type', 'object', 'properties', ...
                                                             struct('name', struct('type', 'string'), ...
                                                                    'age', struct('type', 'integer', 'minimum', 0)))));
    jd.setschema(s);

    test_jsonlab('validate nested root pass', @savejson, jd.validate(), '[]', 'compact', 1);
    test_jsonlab('validate nested person pass', @savejson, jd.person.validate(), '[]', 'compact', 1);
    test_jsonlab('validate nested person.name pass', @savejson, ...
                 jd.person.name.validate(), '[]', 'compact', 1);

    jd.person.age = -5;
    test_jsonlab('validate nested root fail', @savejson, ...
                 length(jd.validate()) > 0, '[true]', 'compact', 1);
    test_jsonlab('validate nested person fail', @savejson, ...
                 length(jd.person.validate()) > 0, '[true]', 'compact', 1);
    test_jsonlab('validate nested person.age fail', @savejson, ...
                 length(jd.person.age.validate()) > 0, '[true]', 'compact', 1);
    test_jsonlab('validate nested person.name still pass', @savejson, ...
                 jd.person.name.validate(), '[]', 'compact', 1);

    % =======================================================================
    % validate() with various schema criteria
    % =======================================================================
    jd = jdict(struct('code', 'ABC123'));
    pat = '^[A-Z]+[0-9]+$';
    jd.setschema(struct('type', 'object', 'properties', ...
                        struct('code', struct('type', 'string', 'pattern', pat))));
    test_jsonlab('validate pattern pass', @savejson, jd.code.validate(), '[]', 'compact', 1);
    jd.code = '123ABC';
    test_jsonlab('validate pattern fail', @savejson, ...
                 length(jd.code.validate()) > 0, '[true]', 'compact', 1);

    jd = jdict(struct('color', 'red'));
    jd.setschema(struct('type', 'object', 'properties', ...
                        struct('color', struct('enum', {{'red', 'green', 'blue'}}))));
    test_jsonlab('validate enum pass', @savejson, jd.color.validate(), '[]', 'compact', 1);
    jd.color = 'yellow';
    test_jsonlab('validate enum fail', @savejson, ...
                 length(jd.color.validate()) > 0, '[true]', 'compact', 1);

    jd = jdict(struct('val', 10));
    jd.setschema(struct('type', 'object', 'properties', ...
                        struct('val', struct('oneOf', {{struct('type', 'integer', 'minimum', 20), ...
                                                        struct('type', 'integer', 'maximum', 5)}}))));
    jd.val <= 3;
    test_jsonlab('validate oneOf pass', @savejson, jd.val.validate(), '[]', 'compact', 1);
    jd.val = 10;
    test_jsonlab('validate oneOf fail', @savejson, ...
                 length(jd.val.validate()) > 0, '[true]', 'compact', 1);

    jd = jdict(struct('num', 15));
    jd.setschema(struct('type', 'object', 'properties', ...
                        struct('num', struct('allOf', {{struct('type', 'integer'), ...
                                                        struct('minimum', 10), struct('maximum', 20)}}))));
    test_jsonlab('validate allOf pass', @savejson, jd.num.validate(), '[]', 'compact', 1);
    jd.num = 5;
    test_jsonlab('validate allOf fail', @savejson, ...
                 length(jd.num.validate()) > 0, '[true]', 'compact', 1);

    jd = jdict(struct('x', 'hello'));
    jd.setschema(struct('type', 'object', 'properties', ...
                        struct('x', struct('anyOf', {{struct('type', 'string'), ...
                                                      struct('type', 'integer')}}))));
    test_jsonlab('validate anyOf string pass', @savejson, jd.x.validate(), '[]', 'compact', 1);
    jd.x <= 42;
    test_jsonlab('validate anyOf integer pass', @savejson, jd.x.validate(), '[]', 'compact', 1);
    jd.x = true;
    test_jsonlab('validate anyOf fail', @savejson, ...
                 length(jd.x.validate()) > 0, '[true]', 'compact', 1);

    jd = jdict(struct('y', 'test'));
    jd.setschema(struct('type', 'object', 'properties', ...
                        struct('y', struct('not', struct('type', 'integer')))));
    test_jsonlab('validate not pass', @savejson, jd.y.validate(), '[]', 'compact', 1);
    jd.y = 123;
    test_jsonlab('validate not fail', @savejson, ...
                 length(jd.y.validate()) > 0, '[true]', 'compact', 1);

    % =======================================================================
    % validate() with no schema at subpath
    % =======================================================================
    jd = jdict(struct('a', 1, 'b', 'test'));
    jd.setschema(struct('type', 'object', 'properties', ...
                        struct('a', struct('type', 'integer'))));
    test_jsonlab('validate subkey no schema pass', @savejson, ...
                 jd.b.validate(), '[]', 'compact', 1);

    clear jd s pat;
end
