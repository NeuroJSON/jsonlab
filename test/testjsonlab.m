function testjsonlab(tests)

if(nargin==0)
    tests={'js','jso','bj','bjo'};
end
%%
if(ismember('js',tests))
    fprintf(sprintf('%s\n',char(ones(1,79)*61)));
    fprintf('Test JSON functions\n');
    fprintf(sprintf('%s\n',char(ones(1,79)*61)));

    run_save_test('single integer',@savejson,5,'[5]');
    run_save_test('single float',@savejson,3.14,'[3.14]');
    run_save_test('nan',@savejson,nan,'["_NaN_"]');
    run_save_test('inf',@savejson,inf,'["_Inf_"]');
    run_save_test('-inf',@savejson,-inf,'["-_Inf_"]');
    run_save_test('large integer',@savejson,uint64(2^64),'[18446744073709551616]');
    run_save_test('large negative integer',@savejson,int64(-2^63),'[-9223372036854775808]');
    run_save_test('boolean as 01',@savejson,[true,false],'[1,0]','compact',1);
    run_save_test('empty array',@savejson,[],'[]');
    run_save_test('empty cell',@savejson,{},'[]');
    run_save_test('empty string',@savejson,'','""','compact',1);
    run_save_test('string escape',@savejson,sprintf('jdata\n\b\awill\tprevail\t"\"\\'),'"jdata\n\b\awill\tprevail\t\"\"\\"');
    if(exist('isstring'))
        run_save_test('string type',@savejson,string(sprintf('jdata\n\b\awill\tprevail')),'"jdata\n\b\awill\tprevail"','compact',1);
        run_save_test('string array',@savejson,[string('jdata');string('will');string('prevail')],'["jdata","will","prevail"]','compact',1);
    end
    run_save_test('row vector',@savejson,[1,2,3],'[1,2,3]');
    run_save_test('column vector',@savejson,[1;2;3],'[[1],[2],[3]]','compact',1);
    run_save_test('mixed array',@savejson,{'a',1,0.9},'["a",1,0.9]','compact',1);
    run_save_test('char array',@savejson,['AC';'EG'],'["AC","EG"]','compact',1);
    run_save_test('maps',@savejson,struct('a',1,'b','test'),'{"a":1,"b":"test"}','compact',1);
    run_save_test('2d array',@savejson,[1,2,3;4,5,6],'[[1,2,3],[4,5,6]]','compact',1);
    run_save_test('3d (row-major) nested array',@savejson,reshape(1:(2*3*2),2,3,2),...
         '[[[1,7],[3,9],[5,11]],[[2,8],[4,10],[6,12]]]','compact',1,'nestarray',1);
    run_save_test('3d (column-major) nested array',@savejson,reshape(1:(2*3*2),2,3,2),...
         '[[[1,2],[3,4],[5,6]],[[7,8],[9,10],[11,12]]]','compact',1,'nestarray',1,'formatversion',1.9);
    run_save_test('3d annotated array',@savejson,reshape(int8(1:(2*3*2)),2,3,2),...
         '{"_ArrayType_":"int8","_ArraySize_":[2,3,2],"_ArrayData_":[1,7,3,9,5,11,2,8,4,10,6,12]}','compact',1);
    run_save_test('complex number',@savejson,single(2+4i),...
         '{"_ArrayType_":"single","_ArraySize_":[1,1],"_ArrayIsComplex_":true,"_ArrayData_":[[2],[4]]}','compact',1);
    run_save_test('empty sparse matrix',@savejson,sparse(2,3),...
         '{"_ArrayType_":"double","_ArraySize_":[2,3],"_ArrayIsSparse_":true,"_ArrayData_":[]}','compact',1);
    run_save_test('real sparse matrix',@savejson,sparse([0,3,0,1,4]'),...
         '{"_ArrayType_":"double","_ArraySize_":[5,1],"_ArrayIsSparse_":true,"_ArrayData_":[[2,4,5],[3,1,4]]}','compact',1);
    run_save_test('complex sparse matrix',@savejson,sparse([0.0,3i,0.0,1,4i]'),...
         '{"_ArrayType_":"double","_ArraySize_":[5,1],"_ArrayIsComplex_":true,"_ArrayIsSparse_":true,"_ArrayData_":[[2,4,5],[0,1,0],[-3,0,-4]]}','compact',1);
    run_save_test('heterogeneous cell',@savejson,{{1,{2,3}},{4,5},{6};{7},{8,9},{10}},...
         '[[[1,[2,3]],[4,5],[6]],[[7],[8,9],[10]]]','compact',1);
    run_save_test('struct array',@savejson,repmat(struct('i',1.1,'d','str'),[1,2]),...
         '[{"i":1.1,"d":"str"},{"i":1.1,"d":"str"}]','compact',1);
    run_save_test('encoded fieldnames',@savejson,struct(encodevarname('_i'),1,encodevarname('i_'),'str'),...
         '{"_i":1,"i_":"str"}','compact',1);
    if(exist('OCTAVE_VERSION','builtin')~=0)
        run_save_test('encoded fieldnames without decoding',@savejson,struct(encodevarname('_i'),1,encodevarname('i_'),'str'),...
             '{"_i":1,"i_":"str"}','compact',1,'UnpackHex',0);
    else
        run_save_test('encoded fieldnames without decoding',@savejson,struct(encodevarname('_i'),1,encodevarname('i_'),'str'),...
             '{"x0x5F_i":1,"i_":"str"}','compact',1,'UnpackHex',0);
    end       
    if(exist('containers.Map'))
         run_save_test('containers.Map',@savejson,containers.Map({'Andy','^_^'},{true,'-_-'}),...
             '{"Andy":true,"^_^":"-_-"}','compact',1,'usemap',1);
    end
    if(exist('istable'))
         run_save_test('simple table',@savejson,table({'Andy','^_^'},{true,'-_-'}),...
             '{"_TableCols_":["Var1","Var2"],"_TableRows_":[],"_TableRecords_":[["Andy","^_^"],[true,"-_-"]]}','compact',1);
    end
    if(exist('bandwidth'))
         lband=2;
         uband=1;
         a=double(full(spdiags(true(4,lband+uband+1),-uband:lband,3,4)));
         a(a~=0)=find(a);

         run_save_test('lower band matrix',@savejson,tril(a),...
             '{"_ArrayType_":"double","_ArraySize_":[3,4],"_ArrayZipSize_":[2,3],"_ArrayShape_":["lowerband",1],"_ArrayData_":[1,5,9,0,2,6]}','compact',1,'usearrayshape',1);
         run_save_test('upper band matrix',@savejson,triu(a),...
             '{"_ArrayType_":"double","_ArraySize_":[3,4],"_ArrayZipSize_":[3,3],"_ArrayShape_":["upperband",2],"_ArrayData_":[7,11,0,4,8,12,1,5,9]}','compact',1,'usearrayshape',1);
         run_save_test('diag matrix',@savejson,tril(triu(a)),...
             '{"_ArrayType_":"double","_ArraySize_":[3,4],"_ArrayShape_":"diag","_ArrayData_":[1,5,9]}','compact',1,'usearrayshape',1);
         run_save_test('band matrix',@savejson,a,...
             '{"_ArrayType_":"double","_ArraySize_":[3,4],"_ArrayZipSize_":[4,3],"_ArrayShape_":["band",2,1],"_ArrayData_":[7,11,0,4,8,12,1,5,9,0,2,6]}','compact',1,'usearrayshape',1);
         a=a(:,1:3);
         a=uint8(tril(a)+tril(a)');
         run_save_test('symmetric band matrix',@savejson,a,...
             '{"_ArrayType_":"uint8","_ArraySize_":[3,3],"_ArrayZipSize_":[2,3],"_ArrayShape_":["lowersymmband",1],"_ArrayData_":[2,10,18,0,2,6]}','compact',1,'usearrayshape',1);
         a(a==0)=1;
         run_save_test('lower triangular matrix',@savejson,tril(a),...
             '{"_ArrayType_":"uint8","_ArraySize_":[3,3],"_ArrayShape_":"lower","_ArrayData_":[2,2,10,1,6,18]}','compact',1,'usearrayshape',1);
         run_save_test('upper triangular matrix',@savejson,triu(a),...
             '{"_ArrayType_":"uint8","_ArraySize_":[3,3],"_ArrayShape_":"upper","_ArrayData_":[2,2,1,10,6,18]}','compact',1,'usearrayshape',1);
    end
    try
        val=zlibencode('test');
        a=uint8(eye(5));
        a(20,1)=1;
        run_save_test('zlib/zip compression (level 6)',@savejson,a,...
            sprintf('{"_ArrayType_":"uint8","_ArraySize_":[20,5],"_ArrayZipSize_":[1,100],"_ArrayZipType_":"zlib","_ArrayZipData_":"eJxjZAABRhwkxQBsDAACIQAH\n"}'),...
            'compact',1, 'Compression','zlib','CompressArraySize',0)  % nestarray for 4-D or above is not working
        run_save_test('gzip compression (level 6)',@savejson,a,...
            sprintf('{"_ArrayType_":"uint8","_ArraySize_":[20,5],"_ArrayZipSize_":[1,100],"_ArrayZipType_":"gzip","_ArrayZipData_":"H4sIAAAAAAAAA2NkAAFGHCTFAGwMAF9Xq6VkAAAA\n"}'),...
            'compact',1, 'Compression','gzip','CompressArraySize',0)  % nestarray for 4-D or above is not working
        run_save_test('lzma compression (level 5)',@savejson,a,...
            sprintf('{"_ArrayType_":"uint8","_ArraySize_":[20,5],"_ArrayZipSize_":[1,100],"_ArrayZipType_":"lzma","_ArrayZipData_":"XQAAEABkAAAAAAAAAAAAgD1IirvlZSEY7DH///taoAA=\n"}'),...
            'compact',1, 'Compression','lzma','CompressArraySize',0)  % nestarray for 4-D or above is not working
    catch
    end
end
%%
if(ismember('jso',tests))
    fprintf(sprintf('%s\n',char(ones(1,79)*61)));
    fprintf('Test JSON function options\n');
    fprintf(sprintf('%s\n',char(ones(1,79)*61)));

    run_save_test('boolean',@savejson,[true,false],'[true,false]','compact',1,'ParseLogical',1);
    run_save_test('nan option',@savejson,nan,'["_nan_"]','NaN','"_nan_"');
    run_save_test('inf option',@savejson,-inf,'["-inf"]','Inf','"$1inf"');
end


%%
if(ismember('bj',tests))
    fprintf(sprintf('%s\n',char(ones(1,79)*61)));
    fprintf('Test Binary JSON functions\n');
    fprintf(sprintf('%s\n',char(ones(1,79)*61)));

    run_save_test('uint8 integer',@saveubjson,2^8-1,'U<255>','debug',1);
    run_save_test('uint16 integer',@saveubjson,2^8,'u<256>','debug',1);
    run_save_test('int8 integer',@saveubjson,-2^7,'i<-128>','debug',1);
    run_save_test('int16 integer',@saveubjson,-2^7-1,'I<-129>','debug',1);
    run_save_test('int32 integer',@saveubjson,-2^15-1,'l<-32769>','debug',1);
    run_save_test('uint16 integer',@saveubjson,2^16-1,'u<65535>','debug',1);
    run_save_test('uint32 integer',@saveubjson,2^16,'m<65536>','debug',1);
    run_save_test('uint32 integer',@saveubjson,2^32-1,'m<4294967295>','debug',1);
    run_save_test('int32 integer',@saveubjson,-2^31,'l<-2147483648>','debug',1);
    run_save_test('single float',@saveubjson,3.14,'[D<3.14>]','debug',1);
    run_save_test('nan',@saveubjson,nan,'[D<NaN>]','debug',1);
    run_save_test('inf',@saveubjson,inf,'[D<Inf>]','debug',1);
    run_save_test('-inf',@saveubjson,-inf,'[D<-Inf>]','debug',1);
    run_save_test('uint64 integer',@saveubjson,uint64(2^64),'M<18446744073709551616>','debug',1);
    run_save_test('int64 negative integer',@saveubjson,int64(-2^63),'L<-9223372036854775808>','debug',1);
    run_save_test('boolean as 01',@saveubjson,[true,false],'[U<1>U<0>]','debug',1,'nestarray',1);
    run_save_test('empty array',@saveubjson,[],'Z','debug',1);
    run_save_test('empty cell',@saveubjson,{},'Z','debug',1);
    run_save_test('empty string',@saveubjson,'','SU<0>','debug',1);
    run_save_test('string escape',@saveubjson,sprintf('jdata\n\b\awill\tprevail\t"\"\\'),sprintf('SU<24>jdata\n\b\awill\tprevail\t\"\"\\'),'debug',1);
    if(exist('isstring'))
        run_save_test('string type',@saveubjson,string(sprintf('jdata\n\b\awill\tprevail')),sprintf('[SU<20>jdata\n\b\awill\tprevail]'),'debug',1);
        run_save_test('string array',@saveubjson,[string('jdata');string('will');string('prevail')],'[[SU<5>jdataSU<4>willSU<7>prevail]]','debug',1);
    end
    run_save_test('row vector',@saveubjson,[1,2,3],'[$U#U<3><1><2><3>','debug',1);
    run_save_test('column vector',@saveubjson,[1;2;3],'[$U#[$U#U<2><3><1><1><2><3>','debug',1);
    run_save_test('mixed array',@saveubjson,{'a',1,0.9},'[CaU<1>[D<0.9>]]','debug',1);
    run_save_test('char array',@saveubjson,['AC';'EG'],'[SU<2>ACSU<2>EG]','debug',1);
    run_save_test('maps',@saveubjson,struct('a',1,'b','test'),'{U<1>aU<1>U<1>bSU<4>test}','debug',1);
    run_save_test('2d array',@saveubjson,[1,2,3;4,5,6],'[$U#[$U#U<2><2><3><1><4><2><5><3><6>','debug',1);
    run_save_test('3d (row-major) nested array',@saveubjson,reshape(1:(2*3*2),2,3,2),...
         '[[[U<1>U<7>][U<3>U<9>][U<5>U<11>]][[U<2>U<8>][U<4>U<10>][U<6>U<12>]]]','debug',1,'nestarray',1);
    run_save_test('3d (column-major) nested array',@saveubjson,reshape(1:(2*3*2),2,3,2),...
         '[[[U<1>U<2>][U<3>U<4>][U<5>U<6>]][[U<7>U<8>][U<9>U<10>][U<11>U<12>]]]','debug',1,'nestarray',1,'formatversion',1.9);
    run_save_test('3d annotated array',@saveubjson,reshape(int8(1:(2*3*2)),2,3,2),...
         '{U<11>_ArrayType_SU<4>int8U<11>_ArraySize_[$U#U<3><2><3><2>U<11>_ArrayData_[$U#U<12><1><7><3><9><5><11><2><8><4><10><6><12>}','debug',1);
    run_save_test('complex number',@saveubjson,single(2+4i),...
         '{U<11>_ArrayType_SU<6>singleU<11>_ArraySize_[$U#U<2><1><1>U<16>_ArrayIsComplex_TU<11>_ArrayData_[$U#[$U#U<2><2><1><2><4>}','debug',1);
    run_save_test('empty sparse matrix',@saveubjson,sparse(2,3),...
         '{U<11>_ArrayType_SU<6>doubleU<11>_ArraySize_[$U#U<2><2><3>U<15>_ArrayIsSparse_TU<11>_ArrayData_Z}','debug',1);
    run_save_test('real sparse matrix',@saveubjson,sparse([0,3,0,1,4]'),...
         '{U<11>_ArrayType_SU<6>doubleU<11>_ArraySize_[$U#U<2><5><1>U<15>_ArrayIsSparse_TU<11>_ArrayData_[$U#[$U#U<2><2><3><2><3><4><1><5><4>}','debug',1);
    run_save_test('complex sparse matrix',@saveubjson,sparse([0.0,3i,0.0,1,4i]'),...
         '{U<11>_ArrayType_SU<6>doubleU<11>_ArraySize_[$U#U<2><5><1>U<16>_ArrayIsComplex_TU<15>_ArrayIsSparse_TU<11>_ArrayData_[$i#[$U#U<2><3><3><2><0><-3><4><1><0><5><0><-4>}','debug',1);
    run_save_test('heterogeneous cell',@saveubjson,{{1,{2,3}},{4,5},{6};{7},{8,9},{10}},...
         '[[[U<1>[U<2>U<3>]][U<4>U<5>][U<6>]][[U<7>][U<8>U<9>][U<10>]]]','debug',1);
    run_save_test('struct array',@saveubjson,repmat(struct('i',1.1,'d','str'),[1,2]),...
         '[{U<1>i[D<1.1>]U<1>dSU<3>str}{U<1>i[D<1.1>]U<1>dSU<3>str}]','debug',1);
    run_save_test('encoded fieldnames',@saveubjson,struct(encodevarname('_i'),1,encodevarname('i_'),'str'),...
         '{U<2>_iU<1>U<2>i_SU<3>str}','debug',1);
    if(exist('OCTAVE_VERSION','builtin')~=0)
        run_save_test('encoded fieldnames without decoding',@saveubjson,struct(encodevarname('_i'),1,encodevarname('i_'),'str'),...
             '{U<2>_iU<1>U<2>i_SU<3>str}','debug',1,'UnpackHex',0);
    else
        run_save_test('encoded fieldnames without decoding',@saveubjson,struct(encodevarname('_i'),1,encodevarname('i_'),'str'),...
             '{U<7>x0x5F_iU<1>U<2>i_SU<3>str}','debug',1,'UnpackHex',0);
    end       
    if(exist('containers.Map'))
         run_save_test('containers.Map',@saveubjson,containers.Map({'Andy','^_^'},{true,'-_-'}),...
             '{U<4>AndyTU<3>^_^SU<3>-_-}','debug',1,'usemap',1);
    end
    if(exist('istable'))
         run_save_test('simple table',@saveubjson,table({'Andy','^_^'},{true,'-_-'}),...
             '{U<11>_TableCols_[SU<4>Var1SU<4>Var2]U<11>_TableRows_ZU<14>_TableRecords_[[SU<4>AndySU<3>^_^][TSU<3>-_-]]}','debug',1);
    end
    if(exist('bandwidth'))
         lband=2;
         uband=1;
         a=double(full(spdiags(true(4,lband+uband+1),-uband:lband,3,4)));
         a(a~=0)=find(a);

         run_save_test('lower band matrix',@saveubjson,tril(a),...
             '{U<11>_ArrayType_SU<6>doubleU<11>_ArraySize_[$U#U<2><3><4>U<14>_ArrayZipSize_[$U#U<2><2><3>U<12>_ArrayShape_[SU<9>lowerbandU<1>]U<11>_ArrayData_[$U#U<6><1><5><9><0><2><6>}','debug',1,'usearrayshape',1);
         run_save_test('upper band matrix',@saveubjson,triu(a),...
             '{U<11>_ArrayType_SU<6>doubleU<11>_ArraySize_[$U#U<2><3><4>U<14>_ArrayZipSize_[$U#U<2><3><3>U<12>_ArrayShape_[SU<9>upperbandU<2>]U<11>_ArrayData_[$U#U<9><7><11><0><4><8><12><1><5><9>}','debug',1,'usearrayshape',1);
         run_save_test('diag matrix',@saveubjson,tril(triu(a)),...
             '{U<11>_ArrayType_SU<6>doubleU<11>_ArraySize_[$U#U<2><3><4>U<12>_ArrayShape_SU<4>diagU<11>_ArrayData_[$U#U<3><1><5><9>}','debug',1,'usearrayshape',1);
         run_save_test('band matrix',@saveubjson,a,...
             '{U<11>_ArrayType_SU<6>doubleU<11>_ArraySize_[$U#U<2><3><4>U<14>_ArrayZipSize_[$U#U<2><4><3>U<12>_ArrayShape_[SU<4>bandU<2>U<1>]U<11>_ArrayData_[$U#U<12><7><11><0><4><8><12><1><5><9><0><2><6>}','debug',1,'usearrayshape',1);
         a=a(:,1:3);
         a=uint8(tril(a)+tril(a)');
         run_save_test('symmetric band matrix',@saveubjson,a,...
             '{U<11>_ArrayType_SU<5>uint8U<11>_ArraySize_[$U#U<2><3><3>U<14>_ArrayZipSize_[$U#U<2><2><3>U<12>_ArrayShape_[SU<13>lowersymmbandU<1>]U<11>_ArrayData_[$U#U<6><2><10><18><0><2><6>}','debug',1,'usearrayshape',1);
         a(a==0)=1;
         run_save_test('lower triangular matrix',@saveubjson,tril(a),...
             '{U<11>_ArrayType_SU<5>uint8U<11>_ArraySize_[$U#U<2><3><3>U<12>_ArrayShape_SU<5>lowerU<11>_ArrayData_[$U#U<6><2><2><10><1><6><18>}','debug',1,'usearrayshape',1);
         run_save_test('upper triangular matrix',@saveubjson,triu(a),...
             '{U<11>_ArrayType_SU<5>uint8U<11>_ArraySize_[$U#U<2><3><3>U<12>_ArrayShape_SU<5>upperU<11>_ArrayData_[$U#U<6><2><2><1><10><6><18>}','debug',1,'usearrayshape',1);
    end
    try
        val=zlibencode('test');
        a=uint8(eye(5));
        a(20,1)=1;
        run_save_test('zlib/zip compression (level 6)',@saveubjson,a,...
            '{U<11>_ArrayType_SU<5>uint8U<11>_ArraySize_[$U#U<2><20><5>U<14>_ArrayZipSize_[$U#U<2><1><100>U<14>_ArrayZipType_SU<4>zlibU<14>_ArrayZipData_[$U#U<18><120><156><99><100><0><1><70><28><36><197><0><108><12><0><2><33><0><7>}',...
            'debug',1, 'Compression','zlib','CompressArraySize',0)  % nestarray for 4-D or above is not working
        run_save_test('gzip compression (level 6)',@saveubjson,a,...
            '{U<11>_ArrayType_SU<5>uint8U<11>_ArraySize_[$U#U<2><20><5>U<14>_ArrayZipSize_[$U#U<2><1><100>U<14>_ArrayZipType_SU<4>gzipU<14>_ArrayZipData_[$U#U<30><31><139><8><0><0><0><0><0><0><3><99><100><0><1><70><28><36><197><0><108><12><0><95><87><171><165><100><0><0><0>}',...
            'debug',1, 'Compression','gzip','CompressArraySize',0)  % nestarray for 4-D or above is not working
        run_save_test('lzma compression (level 5)',@saveubjson,a,...
            '{U<11>_ArrayType_SU<5>uint8U<11>_ArraySize_[$U#U<2><20><5>U<14>_ArrayZipSize_[$U#U<2><1><100>U<14>_ArrayZipType_SU<4>lzmaU<14>_ArrayZipData_[$U#U<32><93><0><0><16><0><100><0><0><0><0><0><0><0><0><0><128><61><72><138><187><229><101><33><24><236><49><255><255><251><90><160><0>}',...
            'debug',1, 'Compression','lzma','CompressArraySize',0)  % nestarray for 4-D or above is not working
    catch
    end
end

%%
if(ismember('bjo',tests))
    fprintf(sprintf('%s\n',char(ones(1,79)*61)));
    fprintf('Test JSON function options\n');
    fprintf(sprintf('%s\n',char(ones(1,79)*61)));

    run_save_test('row vector',@saveubjson,[1,2,3],'[$U#U<3><1><2><3>','debug',1);
    run_save_test('single integer',@saveubjson,256,'I<256>','debug',1,'ubjson',1);
    run_save_test('single integer',@saveubjson,2^32-1,'L<4294967295>','debug',1,'ubjson',1);
    run_save_test('single integer',@saveubjson,2^64-1,'HU<20>18446744073709551616','debug',1,'ubjson',1);
    run_save_test('inf option',@savejson,-inf,'["-inf"]','Inf','"$1inf"');
end