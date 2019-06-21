function json=saveubjson(rootname,obj,varargin)
%
% json=saveubjson(rootname,obj,filename)
%    or
% json=saveubjson(rootname,obj,opt)
% json=saveubjson(rootname,obj,'param1',value1,'param2',value2,...)
%
% convert a MATLAB object  (cell, struct, array, table, map, handles ...) 
% into a Universal Binary JSON (UBJSON) or a MessagePack binary stream
%
% author: Qianqian Fang (q.fang <at> neu.edu)
% created on 2013/08/17
%
% $Id$
%
% input:
%      rootname: the name of the root-object, when set to '', the root name
%        is ignored, however, when opt.ForceRootName is set to 1 (see below),
%        the MATLAB variable name will be used as the root name.
%      obj: a MATLAB object (array, cell, cell array, struct, struct array,
%        class instance)
%      filename: a string for the file name to save the output UBJSON data
%      opt: a struct for additional options, ignore to use default values.
%        opt can have the following fields (first in [.|.] is the default)
%
%        opt.FileName [''|string]: a file name to save the output JSON data
%        opt.ArrayToStruct[0|1]: when set to 0, saveubjson outputs 1D/2D
%                         array in JSON array format; if sets to 1, an
%                         array will be shown as a struct with fields
%                         "_ArrayType_", "_ArraySize_" and "_ArrayData_"; for
%                         sparse arrays, the non-zero elements will be
%                         saved to _ArrayData_ field in triplet-format i.e.
%                         (ix,iy,val) and "_ArrayIsSparse_" will be added
%                         with a value of 1; for a complex array, the 
%                         _ArrayData_ array will include two columns 
%                         (4 for sparse) to record the real and imaginary 
%                         parts, and also "_ArrayIsComplex_":1 is added. 
%        opt.NestArray    [0|1]: If set to 1, use nested array constructs
%                         to store N-dimensional arrays (compatible with 
%                         UBJSON specification Draft 12); if set to 0,
%                         use the JData (v0.5) optimized N-D array header;
%                         NestArray is automatically set to 1 when
%                         MessagePack is set to 1
%        opt.ParseLogical [1|0]: if this is set to 1, logical array elem
%                         will use true/false rather than 1/0.
%        opt.SingletArray [0|1]: if this is set to 1, arrays with a single
%                         numerical element will be shown without a square
%                         bracket, unless it is the root object; if 0, square
%                         brackets are forced for any numerical arrays.
%        opt.SingletCell  [1|0]: if 1, always enclose a cell with "[]" 
%                         even it has only one element; if 0, brackets
%                         are ignored when a cell has only 1 element.
%        opt.ForceRootName [0|1]: when set to 1 and rootname is empty, saveubjson
%                         will use the name of the passed obj variable as the 
%                         root object name; if obj is an expression and 
%                         does not have a name, 'root' will be used; if this 
%                         is set to 0 and rootname is empty, the root level 
%                         will be merged down to the lower level.
%        opt.JSONP [''|string]: to generate a JSONP output (JSON with padding),
%                         for example, if opt.JSON='foo', the JSON data is
%                         wrapped inside a function call as 'foo(...);'
%        opt.UnpackHex [1|0]: conver the 0x[hex code] output by loadjson 
%                         back to the string form
%        opt.Compression  'zlib', 'gzip', 'lzma' or 'lzip': specify array compression
%                         method; currently only supports 4 methods. The
%                         data compression only applicable to numerical arrays 
%                         in 3D or higher dimensions, or when ArrayToStruct
%                         is 1 for 1D or 2D arrays. If one wants to
%                         compress a long string, one must convert
%                         it to uint8 or int8 array first. The compressed
%                         array uses three extra fields
%                         "_ArrayZipType_": the opt.Compression value. 
%                         "_ArrayZipSize_": a 1D interger array to
%                            store the pre-compressed (but post-processed)
%                            array dimensions, and 
%                         "_ArrayZipData_": the binary stream of
%                            the compressed binary array data WITHOUT
%                            'base64' encoding
%        opt.CompressArraySize [100|int]: only to compress an array if the total 
%                         element count is larger than this number.
%        opt.MessagePack [0|1]: output MessagePack (https://msgpack.org/)
%                         binary stream instead of UBJSON
%        opt.FormatVersion [2|float]: set the JSONLab output version; since
%                         v2.0, JSONLab uses JData specification Draft 1
%                         for output format, it is incompatible with all
%                         previous releases; if old output is desired,
%                         please set FormatVersion to 1.9 or earlier.
%        opt.Debug [0|1]: output binary numbers in <%g> format for debugging
%
%        opt can be replaced by a list of ('param',value) pairs. The param 
%        string is equivallent to a field in opt and is case sensitive.
% output:
%      json: a binary string in the UBJSON format (see http://ubjson.org)
%
% examples:
%      jsonmesh=struct('MeshNode',[0 0 0;1 0 0;0 1 0;1 1 0;0 0 1;1 0 1;0 1 1;1 1 1],... 
%               'MeshTetra',[1 2 4 8;1 3 4 8;1 2 6 8;1 5 6 8;1 5 7 8;1 3 7 8],...
%               'MeshTri',[1 2 4;1 2 6;1 3 4;1 3 7;1 5 6;1 5 7;...
%                          2 8 4;2 8 6;3 8 4;3 8 7;5 8 6;5 8 7],...
%               'MeshCreator','FangQ','MeshTitle','T6 Cube',...
%               'SpecialData',[nan, inf, -inf]);
%      saveubjson('jsonmesh',jsonmesh)
%      saveubjson('jsonmesh',jsonmesh,'meshdata.ubj')
%      saveubjson('jsonmesh',jsonmesh,'FileName','meshdata.msgpk','MessagePack',1)
%
% license:
%     BSD or GPL version 3, see LICENSE_{BSD,GPLv3}.txt files for details
%
% -- this function is part of JSONLab toolbox (http://iso2mesh.sf.net/cgi-bin/index.cgi?jsonlab)
%
global ismsgpack

if(nargin==1)
   varname=inputname(1);
   obj=rootname;
   if(isempty(varname)) 
      varname='root';
   end
   rootname=varname;
else
   varname=inputname(2);
end
if(length(varargin)==1 && ischar(varargin{1}))
   opt=struct('filename',varargin{1});
else
   opt=varargin2struct(varargin{:});
end
opt.IsOctave=isoctave;

dozip=jsonopt('Compression','',opt);
if(~isempty(dozip))
    if(isempty(strmatch(dozip,{'zlib','gzip','lzma','lzip'})))
        error('compression method "%s" is not supported',dozip);
    end
    if(exist('zmat')~=3)
        try
            error(javachk('jvm'));
            try
               base64decode('test');
            catch
               matlab.net.base64decode('test');
            end
        catch
            error('java-based compression is not supported');
        end
    end    
    opt.Compression=dozip;
end
ismsgpack=jsonopt('MessagePack',0,opt) + bitshift(jsonopt('Debug',0,opt),1);
if(~bitget(ismsgpack, 1))
    opt.IM_='UiIlL';
    opt.FM_='dD';
    opt.FTM_='FT';
    opt.SM_='CS';
    opt.ZM_='Z';
    opt.OM_={'{','}'};
    opt.AM_={'[',']'};
else
    opt.IM_=char([hex2dec('cc') hex2dec('d0') hex2dec('d1') hex2dec('d2') hex2dec('d3')]);
    opt.FM_=char([hex2dec('ca') hex2dec('cb')]);
    opt.FTM_=char([hex2dec('c2') hex2dec('c3')]);
    opt.SM_=char([hex2dec('a1') hex2dec('db')]);
    opt.ZM_=char(hex2dec('c0'));
    opt.OM_={char(hex2dec('df')),''};
    opt.AM_={char(hex2dec('dd')),''};
end
if(isfield(opt,'norowbracket'))
    warning('Option ''NoRowBracket'' is depreciated, please use ''SingletArray'' and set its value to not(NoRowBracket)');
    if(~isfield(opt,'singletarray'))
        opt.singletarray=not(opt.norowbracket);
    end
end
rootisarray=0;
rootlevel=1;
forceroot=jsonopt('ForceRootName',0,opt);
if((isnumeric(obj) || islogical(obj) || ischar(obj) || isstruct(obj) || ...
        iscell(obj) || isobject(obj)) && isempty(rootname) && forceroot==0)
    rootisarray=1;
    rootlevel=0;
else
    if(isempty(rootname))
        rootname=varname;
    end
end
if((isstruct(obj) || iscell(obj))&& isempty(rootname) && forceroot)
    rootname='root';
end
json=obj2ubjson(rootname,obj,rootlevel,opt);
if(~rootisarray)
    if(bitget(ismsgpack, 1))
        json=[char(129) json opt.OM_{2}];
    else
        json=[opt.OM_{1} json opt.OM_{2}];
    end
end

jsonp=jsonopt('JSONP','',opt);
if(~isempty(jsonp))
    json=[jsonp '(' json ')'];
end

% save to a file if FileName is set, suggested by Patrick Rapin
filename=jsonopt('FileName','',opt);
if(~isempty(filename))
    fid = fopen(filename, 'wb');
    fwrite(fid,json);
    fclose(fid);
end

%%-------------------------------------------------------------------------
function txt=obj2ubjson(name,item,level,varargin)

if(iscell(item))
    txt=cell2ubjson(name,item,level,varargin{:});
elseif(isstruct(item))
    txt=struct2ubjson(name,item,level,varargin{:});
elseif(ischar(item))
    txt=str2ubjson(name,item,level,varargin{:});
elseif(isa(item,'function_handle'))
    txt=struct2ubjson(name,functions(item),level,varargin{:});
elseif(isa(item,'containers.Map'))
    txt=map2ubjson(name,item,level,varargin{:});
elseif(isa(item,'categorical'))
    txt=cell2ubjson(name,cellstr(item),level,varargin{:});
elseif(isobject(item)) 
    if(~exist('OCTAVE_VERSION','builtin') && exist('istable') && istable(item))
        txt=matlabtable2ubjson(name,item,level,varargin{:});
    else
        txt=matlabobject2ubjson(name,item,level,varargin{:});
    end
else
    txt=mat2ubjson(name,item,level,varargin{:});
end

%%-------------------------------------------------------------------------
function txt=cell2ubjson(name,item,level,varargin)
txt='';
if(~iscell(item))
        error('input is not a cell');
end
isnum2cell=jsonopt('num2cell_',0,varargin{:});
if(isnum2cell)
    item=squeeze(item);
else
    format=jsonopt('FormatVersion',2,varargin{:});
    if(format>1.9 && ~isvector(item))
        item=permute(item,ndims(item):-1:1);
    end
end

dim=size(item);
if(ndims(squeeze(item))>2) % for 3D or higher dimensions, flatten to 2D for now
    item=reshape(item,dim(1),numel(item)/dim(1));
    dim=size(item);
end
bracketlevel=~jsonopt('singletcell',1,varargin{:});
Zmarker=jsonopt('ZM_','Z',varargin{:});
Imarker=jsonopt('IM_','UiIlL',varargin{:});
Amarker=jsonopt('AM_',{'[',']'},varargin{:});
if(~strcmp(Amarker{1},'['))
    am0=Imsgpk_(dim(2),Imarker,220,144);
else
    am0=Amarker{1};
end
len=numel(item); % let's handle 1D cell first
if(len>bracketlevel) 
    if(~isempty(name))
        txt=[N_(checkname(name,varargin{:})) am0]; name=''; 
    else
        txt=am0; 
    end
elseif(len==0)
    if(~isempty(name))
        txt=[N_(checkname(name,varargin{:})) Zmarker]; name=''; 
    else
        txt=Zmarker; 
    end
end
if(~strcmp(Amarker{1},'['))
    am0=Imsgpk_(dim(1),Imarker,220,144);
end
for j=1:dim(2)
    if(dim(1)>1)
        txt=[txt am0];
    end
    for i=1:dim(1)
       txt=[txt obj2ubjson(name,item{i,j},level+(len>bracketlevel),varargin{:})];
    end
    if(dim(1)>1)
        txt=[txt Amarker{2}];
    end
end
if(len>bracketlevel)
    txt=[txt Amarker{2}];
end

%%-------------------------------------------------------------------------
function txt=struct2ubjson(name,item,level,varargin)
txt='';
if(~isstruct(item))
	error('input is not a struct');
end
dim=size(item);
if(ndims(squeeze(item))>2) % for 3D or higher dimensions, flatten to 2D for now
    item=reshape(item,dim(1),numel(item)/dim(1));
    dim=size(item);
end
len=numel(item);
forcearray= (len>1 || (jsonopt('SingletArray',0,varargin{:})==1 && level>0));
Imarker=jsonopt('IM_','UiIlL',varargin{:});
Amarker=jsonopt('AM_',{'[',']'},varargin{:});
Omarker=jsonopt('OM_',{'{','}'},varargin{:});

if(~strcmp(Amarker{1},'['))
    am0=Imsgpk_(dim(2),Imarker,220,144);
else
    am0=Amarker{1};
end

if(~isempty(name)) 
    if(forcearray)
        txt=[N_(checkname(name,varargin{:})) am0];
    end
else
    if(forcearray)
        txt=am0;
    end
end
if(~strcmp(Amarker{1},'['))
    am0=Imsgpk_(dim(1),Imarker,220,144);
end
for j=1:dim(2)
  if(dim(1)>1)
      txt=[txt am0];
  end
  for i=1:dim(1)
     names = fieldnames(item(i,j));
     if(~strcmp(Omarker{1},'{'))
        om0=Imsgpk_(length(names),Imarker,222,128);
     else
        om0=Omarker{1};
     end
     if(~isempty(name) && len==1 && ~forcearray)
        txt=[txt N_(checkname(name,varargin{:})) om0]; 
     else
        txt=[txt om0]; 
     end
     if(~isempty(names))
       for e=1:length(names)
	     txt=[txt obj2ubjson(names{e},item(i,j).(names{e}),...
             level+(dim(1)>1)+1+forcearray,varargin{:})];
       end
     end
     txt=[txt Omarker{2}];
  end
  if(dim(1)>1)
      txt=[txt Amarker{2}];
  end
end
if(forcearray)
    txt=[txt Amarker{2}];
end

%%-------------------------------------------------------------------------
function txt=map2ubjson(name,item,level,varargin)
txt='';
if(~isa(item,'containers.Map'))
	error('input is not a struct');
end
dim=size(item);
names = keys(item);
val= values(item);
Omarker=jsonopt('OM_',{'{','}'},varargin{:});
Imarker=jsonopt('IM_','UiIlL',varargin{:});
if(~strcmp(Omarker{1},'{'))
    om0=Imsgpk_(length(names),Imarker,222,128);
else
    om0=Omarker{1};
end
len=prod(dim);
forcearray= (len>1 || (jsonopt('SingletArray',0,varargin{:})==1 && level>0));

if(~isempty(name)) 
    if(forcearray)
        txt=[N_(checkname(name,varargin{:})) om0];
    end
else
    if(forcearray)
        txt=om0;
    end
end
for i=1:dim(1)
    if(~isempty(names{i}))
	    txt=[txt obj2ubjson(names{i},val{i},...
             level+(dim(1)>1),varargin{:})];
    end
end
if(forcearray)
    txt=[txt Omarker{2}];
end

%%-------------------------------------------------------------------------
function txt=str2ubjson(name,item,level,varargin)
txt='';
if(~ischar(item))
        error('input is not a string');
end
item=reshape(item, max(size(item),[1 0]));
len=size(item,1);
Amarker=jsonopt('AM_',{'[',']'},varargin{:});
Imarker=jsonopt('IM_','UiIlL',varargin{:});

if(~strcmp(Amarker{1},'['))
    am0=Imsgpk_(len,Imarker,220,144);
else
    am0=Amarker{1};
end
if(~isempty(name)) 
    if(len>1)
        txt=[N_(checkname(name,varargin{:})) am0];
    end
else
    if(len>1)
        txt=am0;
    end
end
for e=1:len
    val=item(e,:);
    if(len==1)
        obj=[N_(checkname(name,varargin{:})) '' '',S_(val),''];
        if(isempty(name))
            obj=['',S_(val),''];
        end
        txt=[txt,'',obj];
    else
        txt=[txt,'',['',S_(val),'']];
    end
end
if(len>1)
    txt=[txt Amarker{2}];
end

%%-------------------------------------------------------------------------
function txt=mat2ubjson(name,item,level,varargin)
if(~isnumeric(item) && ~islogical(item))
        error('input is not an array');
end

dozip=jsonopt('Compression','',varargin{:});
zipsize=jsonopt('CompressArraySize',100,varargin{:});
format=jsonopt('FormatVersion',2,varargin{:});

Zmarker=jsonopt('ZM_','Z',varargin{:});
FTmarker=jsonopt('FTM_','FT',varargin{:});
Imarker=jsonopt('IM_','UiIlL',varargin{:});
Omarker=jsonopt('OM_',{'{','}'},varargin{:});
isnest=jsonopt('NestArray',0,varargin{:});
ismsgpack=jsonopt('MessagePack',0,varargin{:});
if(ismsgpack)
    isnest=1;
end
if((length(size(item))>2 && isnest==0)  || issparse(item) || ~isreal(item) || ...
   jsonopt('ArrayToStruct',0,varargin{:}) || (~isempty(dozip) && numel(item)>zipsize))
      cid=I_(uint32(max(size(item))),Imarker,varargin{:});
      if(isempty(name))
    	txt=[Omarker{1} N_('_ArrayType_'),S_(class(item)),N_('_ArraySize_'),I_a(size(item),cid(1),Imarker,varargin{:}) ];
      else
          if(isempty(item))
              txt=[N_(checkname(name,varargin{:})),Zmarker];
              return;
          else
    	      txt=[N_(checkname(name,varargin{:})),Omarker{1},N_('_ArrayType_'),S_(class(item)),N_('_ArraySize_'),I_a(size(item),cid(1),Imarker,varargin{:})];
          end
      end
      childcount=2;
else
    if(isempty(name))
    	txt=matdata2ubjson(item,level+1,varargin{:});
    else
        if(numel(item)==1 && jsonopt('SingletArray',0,varargin{:})==0)
            numtxt=regexprep(regexprep(matdata2ubjson(item,level+1,varargin{:}),'^\[',''),']$','');
           	txt=[N_(checkname(name,varargin{:})) numtxt];
        else
    	    txt=[N_(checkname(name,varargin{:})),matdata2ubjson(item,level+1,varargin{:})];
        end
    end
    return;
end
if(issparse(item))
    [ix,iy]=find(item);
    data=full(item(find(item)));
    if(~isreal(item))
       data=[real(data(:)),imag(data(:))];
       if(size(item,1)==1)
           % Kludge to have data's 'transposedness' match item's.
           % (Necessary for complex row vector handling below.)
           data=data';
       end
       txt=[txt,N_('_ArrayIsComplex_'),FTmarker(2)];
       childcount=childcount+1;
    end
    txt=[txt,N_('_ArrayIsSparse_'),FTmarker(2)];
    childcount=childcount+1;
    if(~isempty(dozip) && numel(data*2)>zipsize)
        if(size(item,1)==1)
            % Row vector, store only column indices.
            fulldata=[iy(:),data'];
        elseif(size(item,2)==1)
            % Column vector, store only row indices.
            fulldata=[ix,data];
        else
            % General case, store row and column indices.
            fulldata=[ix,iy,data];
        end
        cid=I_(uint32(max(size(fulldata))),Imarker,varargin{:});
        txt=[txt, N_('_ArrayZipSize_'),I_a(size(fulldata),cid(1),Imarker,varargin{:})];
        txt=[txt, N_('_ArrayZipType_'),S_(dozip)];
	    compfun=str2func([dozip 'encode']);
	    txt=[txt,N_('_ArrayZipData_'), I_a(compfun(typecast(fulldata(:),'uint8')),Imarker(1),Imarker,varargin{:})];
        childcount=childcount+3;
    else
        if(size(item,1)==1)
            % Row vector, store only column indices.
            fulldata=[iy(:),data'];
        elseif(size(item,2)==1)
            % Column vector, store only row indices.
            fulldata=[ix,data];
        else
            % General case, store row and column indices.
            fulldata=[ix,iy,data];
        end
        varargin{:}.ArrayToStruct=0;
        txt=[txt,N_('_ArrayData_'),...
               cell2ubjson('',num2cell(fulldata',2)',level+2,varargin{:})];
        childcount=childcount+1;
    end
else
    if(format>1.9)
        item=permute(item,ndims(item):-1:1);
    end
    if(~isempty(dozip) && numel(item)>zipsize)
        if(isreal(item))
            fulldata=item(:)';
            if(islogical(fulldata))
                fulldata=uint8(fulldata);
            end
        else
            txt=[txt,N_('_ArrayIsComplex_'),FTmarker(2)];
            childcount=childcount+1;
            fulldata=[real(item(:)) imag(item(:))];
        end
        cid=I_(uint32(max(size(fulldata))),Imarker,varargin{:});
        txt=[txt, N_('_ArrayZipSize_'),I_a(size(fulldata),cid(1),Imarker,varargin{:})];
        txt=[txt, N_('_ArrayZipType_'),S_(dozip)];
	    compfun=str2func([dozip 'encode']);
	    txt=[txt,N_('_ArrayZipData_'), I_a(compfun(typecast(fulldata(:),'uint8')),Imarker(1),Imarker,varargin{:})];
        childcount=childcount+3;
    else
        if(isreal(item))
            txt=[txt,N_('_ArrayData_'),...
                matdata2ubjson(item(:)',level+2,varargin{:})];
            childcount=childcount+1;
        else
            txt=[txt,N_('_ArrayIsComplex_'),FTmarker(2)];
            txt=[txt,N_('_ArrayData_'),...
                matdata2ubjson([real(item(:)) imag(item(:))]',level+2,varargin{:})];
            childcount=childcount+2;
        end
    end
end
if(Omarker{1}~='{')
    idx=find(txt==Omarker{1},1,'first');
    if(~isempty(idx))
        txt=[txt(1:idx-1) Imsgpk_(childcount,Imarker,222,128) txt(idx+1:end)];
    end
end
txt=[txt,Omarker{2}];

%%-------------------------------------------------------------------------
function txt=matlabtable2ubjson(name,item,level,varargin)
if numel(item) == 0 %empty object
    st = struct();
else
    st = struct();
    propertynames = item.Properties.VariableNames;
    if(isfield(item.Properties,'RowNames') && ~isempty(item.Properties.RowNames))
        rownames=item.Properties.RowNames;
        for p = 1:(numel(propertynames)-1)
            for j = 1:size(item(:,p),1)
                st.(rownames{j}).(propertynames{p}) = item{j,p};
            end
        end
    else
        for p = 1:numel(propertynames)
            for j = 1:size(item(:,p),1)
                st(j).(propertynames{p}) = item{j,p};
            end
        end
    end
end
txt=struct2ubjson(name,st,level,varargin{:});

%%-------------------------------------------------------------------------
function txt=matlabobject2ubjson(name,item,level,varargin)
st = struct();
if numel(item) > 0 %non-empty object
    % "st = struct(item);" would produce an inmutable warning, because it
    % make the protected and private properties visible. Instead we get the
    % visible properties
    propertynames = properties(item);
    for p = 1:numel(propertynames)
        for o = numel(item):-1:1 % aray of objects
            st(o).(propertynames{p}) = item(o).(propertynames{p});
        end
    end
end
txt=struct2ubjson(name,st,level,varargin{:});

%%-------------------------------------------------------------------------
function txt=matdata2ubjson(mat,level,varargin)
Zmarker=jsonopt('ZM_','Z',varargin{:});
if(isempty(mat))
    txt=Zmarker;
    return;
end
FTmarker=jsonopt('FTM_','FT',varargin{:});
Imarker=jsonopt('IM_','UiIlL',varargin{:});
Fmarker=jsonopt('FM_','dD',varargin{:});
Amarker=jsonopt('AM_',{'[',']'},varargin{:});
isnest=jsonopt('NestArray',0,varargin{:});
ismsgpack=jsonopt('MessagePack',0,varargin{:});
format=jsonopt('FormatVersion',2,varargin{:});
isnum2cell=jsonopt('num2cell_',0,varargin{:});

if(ismsgpack)
    isnest=1;
end

if(~isvector(mat) && isnest==1)
   if(format>1.9 && isnum2cell==0)
        mat=permute(mat,ndims(mat):-1:1);
   end
   varargin{:}.num2cell_=1;
end

type='';
hasnegtive=(mat<0);

varargin{:}.num2cell_=1;
if(isa(mat,'integer') || isinteger(mat) || (isfloat(mat) && all(mod(mat(:),1) == 0)))
    if(isempty(hasnegtive))
       if(max(mat(:))<=2^8)
           type=Imarker(1);
       end
    end
    if(isempty(type))
        % todo - need to consider negative ones separately
        id= histc(abs(max(double(mat(:)))),[0 2^7 2^15 2^31 2^63]);
        if(isempty(id~=0))
            error('high-precision data is not yet supported');
        end
        key=Imarker(2:end);
	    type=key(id~=0);
    end
    if(~isvector(mat) && isnest==1)
        txt=cell2ubjson('',num2cell(mat,1),level,varargin{:});
    else
        txt=I_a(mat(:),type,Imarker,size(mat),varargin{:});
    end
elseif(islogical(mat))
    logicalval=FTmarker;
    if(numel(mat)==1)
        txt=logicalval(mat+1);
    else
        if(~isvector(mat) && isnest==1)
            txt=cell2ubjson('',num2cell(uint8(mat,1),level,varargin{:}));
        else
            txt=I_a(uint8(mat(:)),Imarker(1),Imarker,size(mat),varargin{:});
        end
    end
else
    am0=Amarker{1};
    if(Amarker{1}~='[')
        am0=char(145);
    end
    if(numel(mat)==1)
        txt=[am0 D_(mat,Fmarker,varargin{:}) Amarker{2}];
    else
        if(~isvector(mat) && isnest==1)
            txt=cell2ubjson('',num2cell(mat,1),level,varargin{:});
        else
            txt=D_a(mat(:),Fmarker(2),Fmarker,size(mat),varargin{:});
        end
    end
end

%%-------------------------------------------------------------------------
function newname=checkname(name,varargin)
isunpack=jsonopt('UnpackHex',1,varargin{:});
newname=name;
if(isempty(regexp(name,'0x([0-9a-fA-F]+)_','once')))
    return
end
if(isunpack)
    isoct=jsonopt('IsOctave',0,varargin{:});
    if(~isoct)
        newname=regexprep(name,'(^x|_){1}0x([0-9a-fA-F]+)_','${native2unicode(hex2dec($2))}');
    else
        pos=regexp(name,'(^x|_){1}0x([0-9a-fA-F]+)_','start');
        pend=regexp(name,'(^x|_){1}0x([0-9a-fA-F]+)_','end');
        if(isempty(pos))
            return;
        end
        str0=name;
        pos0=[0 pend(:)' length(name)];
        newname='';
        for i=1:length(pos)
            newname=[newname str0(pos0(i)+1:pos(i)-1) char(hex2dec(str0(pos(i)+3:pend(i)-1)))];
        end
        if(pos(end)~=length(name))
            newname=[newname str0(pos0(end-1)+1:pos0(end))];
        end
    end
end
%%-------------------------------------------------------------------------
function val=N_(str)
global ismsgpack
if(~bitget(ismsgpack, 1))
    val=[I_(int32(length(str)),'UiIlL',struct('Debug',bitget(ismsgpack,2))) str];
else
    val=S_(str);
end
%%-------------------------------------------------------------------------
function val=S_(str)
global ismsgpack
if(bitget(ismsgpack, 1))
    Smarker=char([161,219]);
    Imarker=char([204,208:211]);
else
    Smarker='CS';
    Imarker='UiIlL';
end
if(length(str)==1)
  val=[Smarker(1) str];
else
    if(bitget(ismsgpack, 1))
        val=[Imsgpk_(length(str),Imarker,218,160) str];
    else
        val=['S' I_(int32(length(str)),Imarker,struct('Debug',bitget(ismsgpack,2))) str];
    end
end

%%-------------------------------------------------------------------------
function val=Imsgpk_(num,markers,base1,base0)
if(num<16)
    val=char(uint8(num)+uint8(base0));
    return;
end
val=I_(uint32(num),markers);
if(val(1)>char(210))
    num=uint32(num);
    val=[char(210) data2byte(swapbytes(cast(num,'uint32')),'uint8')];
elseif(val(1)<char(209))
    num=uint16(num);
    val=[char(209) data2byte(swapbytes(cast(num,'uint16')),'uint8')];
end
val(1)=char(val(1)-209+base1);

%%-------------------------------------------------------------------------
function val=I_(num, markers, varargin)
if(~isinteger(num))
    error('input is not an integer');
end
Imarker='UiIlL';
if(nargin>=2)
    Imarker=markers;
end
isdebug=jsonopt('Debug',0,varargin{:});

if(Imarker(1)~='U')
    if(num>=0 && num<127)
       val=uint8(num);
       return;
    end
    if(num<0 && num>=-31)
       val=typecast(int8(num), 'uint8');
       return;
    end
end
if(Imarker(1)~='U' && num<0 && num<127)
   val=[data2byte((swapbytes(cast(num,'uint8')) & 127),'uint8')];
   return;
end
if(num>=0 && num<255)
   if(isdebug)
       val=[Imarker(1) sprintf('<%d>',num)];
   else
       val=[Imarker(1) data2byte(swapbytes(cast(num,'uint8')),'uint8')];
   end
   return;
end
key=Imarker(2:end);
cid={'int8','int16','int32','int64'};
for i=1:4
  if((num>0 && num<2^(i*8-1)) || (num<0 && num>=-2^(i*8-1)))
    if(isdebug)
        val=[key(i) sprintf('<%d>',num)];
    else
        val=[key(i) data2byte(swapbytes(cast(num,cid{i})),'uint8')];
    end
    return;
  end
end
error('unsupported integer');

%%-------------------------------------------------------------------------
function val=D_(num, markers, varargin)
if(~isfloat(num))
    error('input is not a float');
end
isdebug=jsonopt('Debug',0,varargin{:});
if(isdebug)
    output=sprintf('<%g>',num);
else
    output=data2byte(swapbytes(num),'uint8');
end
Fmarker='dD';
if(nargin>=2)
    Fmarker=markers;
end
if(isa(num,'single'))
  val=[Fmarker(1) output(:)'];
else
  val=[Fmarker(2) output(:)'];
end
%%-------------------------------------------------------------------------
function data=I_a(num,type,markers,dim,varargin)
Imarker='UiIlL';
Amarker={'[',']'};
if(nargin>=3)
    Imarker=markers;
end
if(Imarker(1)~='U' && type<=127)
    type=char(204);
end
id=find(ismember(Imarker,type));

if(id==0)
  error('unsupported integer array');
end

% based on UBJSON specs, all integer types are stored in big endian format

if(id==2)
  data=data2byte(swapbytes(int8(num)),'uint8');
  blen=1;
elseif(id==1)
  data=data2byte(swapbytes(uint8(num)),'uint8');
  blen=1;
elseif(id==3)
  data=data2byte(swapbytes(int16(num)),'uint8');
  blen=2;
elseif(id==4)
  data=data2byte(swapbytes(int32(num)),'uint8');
  blen=4;
elseif(id==5)
  data=data2byte(swapbytes(int64(num)),'uint8');
  blen=8;
end
if(isstruct(dim))
    varargin={dim};
end

isnest=jsonopt('NestArray',0,varargin{:});
isdebug=jsonopt('Debug',0,varargin{:});
if(isdebug)
    output=sprintf('<%g>',num);
else
    output=data(:);
end

if(isnest==0 && numel(num)>1 && Imarker(1)=='U')
  if(nargin>=4 && ~isstruct(dim) && (length(dim)==1 || (length(dim)>=2 && prod(dim)~=dim(2))))
      cid=I_(uint32(max(dim)));
      data=['$' type '#' I_a(dim,cid(1),Imarker,varargin{:}) output(:)'];
  else
      data=['$' type '#' I_(int32(numel(data)/blen),Imarker,varargin{:}) output(:)'];
  end
  data=['[' data(:)'];
else
  am0=Amarker{1};
  if(Imarker(1)~='U')
      Amarker={char(hex2dec('dd')),''};
      am0=Imsgpk_(numel(num),Imarker,220,144);
  end  
  if(isdebug)
      data=sprintf([type '<%g>'],num);
  else
      data=reshape(data,blen,numel(data)/blen);
      data(2:blen+1,:)=data;
      data(1,:)=type;
  end
  data=[am0 data(:)' Amarker{2}];
end
%%-------------------------------------------------------------------------
function data=D_a(num,type,markers,dim,varargin)
Fmarker='dD';
Imarker='UiIlL';
Amarker={'[',']'};
if(nargin>=3)
    Fmarker=markers;
end
id=find(ismember(Fmarker,type));

if(id==0)
  error('unsupported float array');
end

if(id==1)
  data=data2byte(swapbytes(single(num)),'uint8');
elseif(id==2)
  data=data2byte(swapbytes(double(num)),'uint8');
end

isnest=jsonopt('NestArray',0,varargin{:});
isdebug=jsonopt('Debug',0,varargin{:});
if(isdebug)
    output=sprintf('<%g>',num);
else
    output=data(:);
end

if(isnest==0 && numel(num)>1 && Fmarker(1)=='d')
  if(nargin>=4 && (length(dim)==1 || (length(dim)>=2 && prod(dim)~=dim(2))))
      cid=I_(uint32(max(dim)));
      data=['$' type '#' I_a(dim,cid(1),Imarker,varargin{:}) output(:)'];
  else
      data=['$' type '#' I_(int32(numel(data)/(id*4)),varargin{:}.IM_,varargin{:}) output(:)'];
  end
  data=['[' data];
else
  am0=Amarker{1};
  if(Fmarker(1)~='d')
      Amarker={char(hex2dec('dd')),''};
      am0=Imsgpk_(numel(num),char([204,208:211]),220,144);
  end
  if(isdebug)
      data=sprintf([type '<%g>'],num);
  else
      data=reshape(data,(id*4),length(data)/(id*4));
      data(2:(id*4+1),:)=data;
      data(1,:)=type;
  end
  data=[am0 data(:)' Amarker{2}];
end
%%-------------------------------------------------------------------------
function bytes=data2byte(varargin)
bytes=typecast(varargin{:});
bytes=char(bytes(:)');
