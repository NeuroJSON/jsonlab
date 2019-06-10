%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%         Demonstration of Basic Utilities of JSONlab
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

rngstate = rand ('state');
randseed=hex2dec('623F9A9E');
clear data2json json2data

fprintf(1,'\n%%=================================================\n')
fprintf(1,'%%  a simple scalar value \n')
fprintf(1,'%%=================================================\n\n')

data2json=pi
saveubjson('',data2json)
json2data=loadubjson(ans)

fprintf(1,'\n%%=================================================\n')
fprintf(1,'%%  an empty array \n')
fprintf(1,'%%=================================================\n\n')

data2json=[]
saveubjson('empty',data2json)
json2data=loadubjson(ans)

fprintf(1,'\n%%=================================================\n')
fprintf(1,'%%  an ampty string \n')
fprintf(1,'%%=================================================\n\n')

data2json=''
saveubjson('emptystr',data2json)
json2data=loadubjson(ans)

fprintf(1,'\n%%=================================================\n')
fprintf(1,'%%  a simple row vector \n')
fprintf(1,'%%=================================================\n\n')

data2json=1:3
saveubjson('',data2json)
json2data=loadubjson(ans)

fprintf(1,'\n%%=================================================\n')
fprintf(1,'%%  a simple column vector \n')
fprintf(1,'%%=================================================\n\n')

data2json=(1:3)'
saveubjson('',data2json)
json2data=loadubjson(ans)

fprintf(1,'\n%%=================================================\n')
fprintf(1,'%%  a string array \n')
fprintf(1,'%%=================================================\n\n')

data2json=['AC';'EG']
saveubjson('',data2json)
json2data=loadubjson(ans)

fprintf(1,'\n%%=================================================\n')
fprintf(1,'%%  a string with escape symbols \n')
fprintf(1,'%%=================================================\n\n')

data2json=sprintf('AB\tCD\none"two')
saveubjson('str',data2json)
json2data=loadubjson(ans)

fprintf(1,'\n%%=================================================\n')
fprintf(1,'%%  a mix-typed cell \n')
fprintf(1,'%%=================================================\n\n')

data2json={'a',true,[2;3]}
saveubjson('',data2json)
json2data=loadubjson(ans)

fprintf(1,'\n%%=================================================\n')
fprintf(1,'%%  a 3-D array in nested array form\n')
fprintf(1,'%%=================================================\n\n')

data2json=reshape(1:(2*4*6),[2,4,6]);
saveubjson('',data2json,'NestArray',1)
json2data=loadubjson(ans)
% if(any(json2data(:)~=data2json(:)) || any(size(json2data)~=size(data2json)))
%     warning('conversion does not preserve original data');
% end

fprintf(1,'\n%%=================================================\n')
fprintf(1,'%%  a 3-D array in annotated array form\n')
fprintf(1,'%%=================================================\n\n')

data2json=reshape(1:(2*4*6),[2,4,6]);
saveubjson('',data2json,'NestArray',0)
json2data=loadubjson(ans)
if(any(json2data(:)~=data2json(:)) || any(size(json2data)~=size(data2json)))
    warning('conversion does not preserve original data');
end

fprintf(1,'\n%%=================================================\n')
fprintf(1,'%%  a 4-D array in annotated array form\n')
fprintf(1,'%%=================================================\n\n')

data2json=reshape(1:(2*4*3*2),[2,4,3,2]);
saveubjson('',data2json,'NestArray',0)  % nestarray for 4-D or above is not working
json2data=loadubjson(ans)
if(any(json2data(:)~=data2json(:)) || any(size(json2data)~=size(data2json)))
    warning('conversion does not preserve original data');
end

fprintf(1,'\n%%=================================================\n')
fprintf(1,'%%  a 3-D array in nested array form (JSONLab 1.9)\n')
fprintf(1,'%%=================================================\n\n')

data2json=reshape(1:(2*4*6),[2,4,6]);
saveubjson('',data2json,'NestArray',1,'FormatVersion',1.8)

fprintf(1,'\n%%=================================================\n')
fprintf(1,'%%  a 3-D array in annotated array form (JSONLab 1.9 or earlier)\n')
fprintf(1,'%%=================================================\n\n')

data2json=reshape(1:(2*4*6),[2,4,6]);
saveubjson('',data2json,'NestArray',0,'FormatVersion',1.8)

fprintf(1,'\n%%=================================================\n')
fprintf(1,'%%  a complex number\n')
fprintf(1,'%%=================================================\n\n')

data2json=1+2i
saveubjson('',data2json)
json2data=loadubjson(ans) 

fprintf(1,'\n%%=================================================\n')
fprintf(1,'%%  a complex matrix\n')
fprintf(1,'%%=================================================\n\n')

data2json=magic(6);
data2json=data2json(:,1:3)+data2json(:,4:6)*1i
saveubjson('',data2json)
json2data=loadubjson(ans)

fprintf(1,'\n%%=================================================\n')
fprintf(1,'%%  MATLAB special constants\n')
fprintf(1,'%%=================================================\n\n')

data2json=[NaN Inf -Inf]
saveubjson('specials',data2json)
json2data=loadubjson(ans)

fprintf(1,'\n%%=================================================\n')
fprintf(1,'%%  a real sparse matrix\n')
fprintf(1,'%%=================================================\n\n')

data2json=sprand(10,10,0.1)
saveubjson('sparse',data2json)
json2data=loadubjson(ans)

fprintf(1,'\n%%=================================================\n')
fprintf(1,'%%  a complex sparse matrix\n')
fprintf(1,'%%=================================================\n\n')

data2json=data2json-data2json*1i
saveubjson('complex_sparse',data2json)
json2data=loadubjson(ans)

fprintf(1,'\n%%=================================================\n')
fprintf(1,'%%  an all-zero sparse matrix\n')
fprintf(1,'%%=================================================\n\n')

data2json=sparse(2,3);
saveubjson('all_zero_sparse',data2json)
json2data=loadubjson(ans)

fprintf(1,'\n%%=================================================\n')
fprintf(1,'%%  an empty sparse matrix\n')
fprintf(1,'%%=================================================\n\n')

data2json=sparse([]);
saveubjson('empty_sparse',data2json)
json2data=loadubjson(ans)

fprintf(1,'\n%%=================================================\n')
fprintf(1,'%%  an empty 0-by-0 real matrix\n')
fprintf(1,'%%=================================================\n\n')

data2json=[];
saveubjson('empty_0by0_real',data2json)
json2data=loadubjson(ans)

fprintf(1,'\n%%=================================================\n')
fprintf(1,'%%  an empty 0-by-3 real matrix\n')
fprintf(1,'%%=================================================\n\n')

data2json=zeros(0,3);
saveubjson('empty_0by3_real',data2json)
json2data=loadubjson(ans)

fprintf(1,'\n%%=================================================\n')
fprintf(1,'%%  a sparse real column vector\n')
fprintf(1,'%%=================================================\n\n')

data2json=sparse([0,3,0,1,4]');
saveubjson('sparse_column_vector',data2json)
json2data=loadubjson(ans)

fprintf(1,'\n%%=================================================\n')
fprintf(1,'%%  a sparse complex column vector\n')
fprintf(1,'%%=================================================\n\n')

data2json=data2json-1i*data2json;
saveubjson('complex_sparse_column_vector',data2json)
json2data=loadubjson(ans)

fprintf(1,'\n%%=================================================\n')
fprintf(1,'%%  a sparse real row vector\n')
fprintf(1,'%%=================================================\n\n')

data2json=sparse([0,3,0,1,4]);
saveubjson('sparse_row_vector',data2json)
json2data=loadubjson(ans)

fprintf(1,'\n%%=================================================\n')
fprintf(1,'%%  a sparse complex row vector\n')
fprintf(1,'%%=================================================\n\n')

data2json=data2json-1i*data2json;
saveubjson('complex_sparse_row_vector',data2json)
json2data=loadubjson(ans)

fprintf(1,'\n%%=================================================\n')
fprintf(1,'%%  a structure\n')
fprintf(1,'%%=================================================\n\n')

data2json=struct('name','Think Different','year',1997,'magic',magic(3),...
                 'misfits',[Inf,NaN],'embedded',struct('left',true,'right',false))
saveubjson('astruct',data2json,struct('ParseLogical',1))
json2data=loadubjson(ans)
class(json2data.astruct.embedded.left)

fprintf(1,'\n%%=================================================\n')
fprintf(1,'%%  a structure array\n')
fprintf(1,'%%=================================================\n\n')

data2json=struct('name','Nexus Prime','rank',9);
data2json(2)=struct('name','Sentinel Prime','rank',9);
data2json(3)=struct('name','Optimus Prime','rank',9);
saveubjson('Supreme Commander',data2json)
json2data=loadubjson(ans)

fprintf(1,'\n%%=================================================\n')
fprintf(1,'%%  a cell array\n')
fprintf(1,'%%=================================================\n\n')

data2json=cell(3,1);
data2json{1}=struct('buzz',1.1,'rex',1.2,'bo',1.3,'hamm',2.0,'slink',2.1,'potato',2.2,...
              'woody',3.0,'sarge',3.1,'etch',4.0,'lenny',5.0,'squeeze',6.0,'wheezy',7.0);
data2json{2}=struct('Ubuntu',['Kubuntu';'Xubuntu';'Lubuntu']);
data2json{3}=[10.04,10.10,11.04,11.10]
saveubjson('debian',data2json,struct('FloatFormat','%.2f'))
json2data=loadubjson(ans)

fprintf(1,'\n%%=================================================\n')
fprintf(1,'%%  invalid field-name handling\n')
fprintf(1,'%%=================================================\n\n')

json2data=loadubjson(saveubjson('',loadjson('{"ValidName":1, "_InvalidName":2, ":Field:":3, "项目":"绝密"}')))

fprintf(1,'\n%%=================================================\n')
fprintf(1,'%%  a function handle\n')
fprintf(1,'%%=================================================\n\n')

data2json=@(x) x+1
saveubjson('handle',data2json)
json2data=loadubjson(ans)

fprintf(1,'\n%%=================================================\n')
fprintf(1,'%%  a 2D cell array\n')
fprintf(1,'%%=================================================\n\n')

data2json={{1,{2,3}},{4,5},{6};{7},{8,9},{10}};
saveubjson('data2json',data2json)
json2data=loadubjson(ans)  % only saveubjson works for cell arrays, loadubjson has issues

fprintf(1,'\n%%=================================================\n')
fprintf(1,'%%  a 2D struct array\n')
fprintf(1,'%%=================================================\n\n')

data2json=repmat(struct('idx',0,'data','structs'),[2,3])
for i=1:6
    data2json(i).idx=i;
end
saveubjson('data2json',data2json)
json2data=loadubjson(ans)


if(exist('datetime'))
    fprintf(1,'\n%%=================================================\n')
    fprintf(1,'%%  datetime object \n')
    fprintf(1,'%%=================================================\n\n')

    data2json=datetime({'8 April 2015','9 May 2015'}, 'InputFormat','d MMMM yyyy')
    saveubjson('',data2json)
    json2data=loadubjson(ans)
end

if(exist('containers.Map'))
    fprintf(1,'\n%%=================================================\n')
    fprintf(1,'%%  a container.Maps object \n')
    fprintf(1,'%%=================================================\n\n')

    data2json=containers.Map({'Andy','William','Om'},[21,21,22])
    saveubjson('',data2json)
    json2data=loadubjson(ans)
end

if(exist('istable'))
    fprintf(1,'\n%%=================================================\n')
    fprintf(1,'%%  a table object \n')
    fprintf(1,'%%=================================================\n\n')

    Names={'Andy','William','Om'}';
    Age=[21,21,22]';
    data2json=table(Names,Age)
    saveubjson('table',table(Names,Age))
    json2data=loadubjson(ans)
end

rand ('state',rngstate);

