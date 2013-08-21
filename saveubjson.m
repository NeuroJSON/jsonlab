function json=saveubjson(rootname,obj,varargin)
%
% json=saveubjson(rootname,obj,filename)
%    or
% json=saveubjson(rootname,obj,opt)
% json=saveubjson(rootname,obj,'param1',value1,'param2',value2,...)
%
% convert a MATLAB object (cell, struct or array) into a Universal 
% Binary JSON (JavaScript Object Notation) string
%
% author: Qianqian Fang (fangq<at> nmr.mgh.harvard.edu)
%            created on 2013/08/17
%
% $Id: saveubjson.m 394 2012-12-18 17:58:11Z fangq $
%
% input:
%      rootname: name of the root-object, if set to '', will use variable name
%      obj: a MATLAB object (array, cell, cell array, struct, struct array)
%      filename: a string for the file name to save the output JSON data
%      opt: a struct for additional options, use [] if all use default
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
%        opt.ParseLogical [1|0]: if this is set to 1, logical array elem
%                         will use true/false rather than 1/0.
%        opt.NoRowBracket [1|0]: if this is set to 1, arrays with a single
%                         numerical element will be shown without a square
%                         bracket, unless it is the root object; if 0, square
%                         brackets are forced for any numerical arrays.
%        opt.ForceRootName [0|1]: when set to 1 and rootname is empty, saveubjson
%                         will use the name of the passed obj variable as the 
%                         root object name; if obj is an expression and 
%                         does not have a name, 'root' will be used; if this 
%                         is set to 0 and rootname is empty, the root level 
%                         will be merged down to the lower level.
%        opt.Inf ['"$1_Inf_"'|string]: a customized regular expression pattern
%                         to represent +/-Inf. The matched pattern is '([-+]*)Inf'
%                         and $1 represents the sign. For those who want to use
%                         1e999 to represent Inf, they can set opt.Inf to '$11e999'
%        opt.NaN ['"_NaN_"'|string]: a customized regular expression pattern
%                         to represent NaN
%        opt.JSONP [''|string]: to generate a JSONP output (JSON with padding),
%                         for example, if opt.JSON='foo', the JSON data is
%                         wrapped inside a function call as 'foo(...);'
%        opt.UnpackHex [1|0]: conver the 0x[hex code] output by loadjson 
%                         back to the string form
%        opt can be replaced by a list of ('param',value) pairs. The param 
%        string is equivallent to a field in opt.
% output:
%      json: a string in the JSON format (see http://json.org)
%
% examples:
%      a=struct('node',[1  9  10; 2 1 1.2], 'elem',[9 1;1 2;2 3],...
%           'face',[9 01 2; 1 2 3; NaN,Inf,-Inf], 'author','FangQ');
%      saveubjson('mesh',a)
%      saveubjson('',a,'ArrayIndent',0,'FloatFormat','\t%.5g')
%
% license:
%     BSD or GPL version 3, see LICENSE_{BSD,GPLv3}.txt files for details
%
% -- this function is part of jsonlab toolbox (http://iso2mesh.sf.net/cgi-bin/index.cgi?jsonlab)
%

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
   opt=struct('FileName',varargin{1});
else
   opt=varargin2struct(varargin{:});
end
opt.IsOctave=exist('OCTAVE_VERSION');
rootisarray=0;
rootlevel=1;
forceroot=jsonopt('ForceRootName',0,opt);
if((isnumeric(obj) || islogical(obj) || ischar(obj) || isstruct(obj) || iscell(obj)) && isempty(rootname) && forceroot==0)
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
if(rootisarray)
    json=sprintf('%s',json);
else
    json=sprintf('{%s}',json);
end

jsonp=jsonopt('JSONP','',opt);
if(~isempty(jsonp))
    json=sprintf('%s(%s);',jsonp,json);
end

% save to a file if FileName is set, suggested by Patrick Rapin
if(~isempty(jsonopt('FileName','',opt)))
    fid = fopen(opt.FileName, 'wt');
    fwrite(fid,json,'char');
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
else
    txt=mat2ubjson(name,item,level,varargin{:});
end

%%-------------------------------------------------------------------------
function txt=cell2ubjson(name,item,level,varargin)
txt='';
if(~iscell(item))
        error('input is not a cell');
end

dim=size(item);
len=numel(item); % let's handle 1D cell first
padding1='';
padding0='';
if(len>1) 
    if(~isempty(name))
        txt=sprintf('%s%s[',padding0, S_(checkname(name,varargin{:}))); name=''; 
    else
        txt=sprintf('%s[',padding0); 
    end
elseif(len==0)
    if(~isempty(name))
        txt=sprintf('%s%sZ',padding0, S_(checkname(name,varargin{:}))); name=''; 
    else
        txt=sprintf('%sZ',padding0); 
    end
end
for i=1:len
    txt=sprintf('%s%s%s',txt,padding1,obj2ubjson(name,item{i},level+(len>1),varargin{:}));
    if(i<len) txt=sprintf('%s%s',txt,sprintf('')); end
end
if(len>1) txt=sprintf('%s%s]',txt,padding0); end

%%-------------------------------------------------------------------------
function txt=struct2ubjson(name,item,level,varargin)
txt='';
if(~isstruct(item))
	error('input is not a struct');
end
len=numel(item);
padding1='';
padding0='';
sep=',';

if(~isempty(name)) 
    if(len>1) txt=sprintf('%s%s[',padding0,S_(checkname(name,varargin{:}))); end
else
    if(len>1) txt=sprintf('%s[',padding0); end
end
for e=1:len
  names = fieldnames(item(e));
  if(~isempty(name) && len==1)
        txt=sprintf('%s%s%s{',txt,'', S_(checkname(name,varargin{:}))); 
  else
        txt=sprintf('%s%s{',txt,''); 
  end
  if(~isempty(names))
    for i=1:length(names)
	txt=sprintf('%s%s',txt,obj2ubjson(names{i},getfield(item(e),...
             names{i}),level+1+(len>1),varargin{:}));
        if(i<length(names)) txt=sprintf('%s%s',txt,''); end
        txt=sprintf('%s%s',txt,sprintf(''));
    end
  end
  txt=sprintf('%s%s}',txt,'');
  if(e==len) sep=''; end
  if(e<len) txt=sprintf('%s%s',txt,sprintf('')); end
end
if(len>1) txt=sprintf('%s%s]',txt,padding0); end

%%-------------------------------------------------------------------------
function txt=str2ubjson(name,item,level,varargin)
txt='';
if(~ischar(item))
        error('input is not a string');
end
item=reshape(item, max(size(item),[1 0]));
len=size(item,1);
sep=sprintf('');

padding1='';
padding0='';

if(~isempty(name)) 
    if(len>1) txt=sprintf('%s%s[',padding1,S_(checkname(name,varargin{:}))); end
else
    if(len>1) txt=sprintf('%s[',padding1); end
end
isoct=jsonopt('IsOctave',0,varargin{:});
for e=1:len
    if(isoct)
        val=regexprep(item(e,:),'\\','\\');
        val=regexprep(val,'"','\"');
        val=regexprep(val,'^"','\"');
    else
        val=regexprep(item(e,:),'\\','\\\\');
        val=regexprep(val,'"','\\"');
        val=regexprep(val,'^"','\\"');
    end
    if(len==1)
        obj=['' S_(checkname(name,varargin{:})) '' '',S_(val),''];
	if(isempty(name)) obj=['',S_(val),'']; end
        txt=sprintf('%s%s%s%s',txt,'',obj);
    else
        txt=sprintf('%s%s%s%s',txt,'',['',S_(val),'']);
    end
    if(e==len) sep=''; end
    txt=sprintf('%s%s',txt,sep);
end
if(len>1) txt=sprintf('%s%s%s',txt,padding1,']'); end

%%-------------------------------------------------------------------------
function txt=mat2ubjson(name,item,level,varargin)
if(~isnumeric(item) && ~islogical(item))
        error('input is not an array');
end

padding1='';
padding0='';

if(length(size(item))>2 || issparse(item) || ~isreal(item) || ...
   isempty(item) || jsonopt('ArrayToStruct',0,varargin{:}))
      cid=I_(uint32(max(size(item))));
      if(isempty(name))
    	txt=sprintf('%s{%s%s%s%s%s%s',...
              padding1,padding0,S_('_ArrayType_'),S_(class(item)),padding0,S_('_ArraySize_'),I_a(size(item),cid(1)) );
      else
    	txt=sprintf('%s%s{%s%s%s%s%s',...
              padding1,S_(checkname(name,varargin{:})),padding0,S_('_ArrayType_'),S_(class(item)),padding0,S_('_ArraySize_'),I_a(size(item),cid(1)) );
      end
else
    if(isempty(name))
    	txt=sprintf('%s%s',padding1,matdata2ubjson(item,level+1,varargin{:}));
    else
        if(numel(item)==1 && jsonopt('NoRowBracket',1,varargin{:})==1)
            numtxt=regexprep(regexprep(matdata2ubjson(item,level+1,varargin{:}),'^\[',''),']','');
           	txt=sprintf('%s%s%s',padding1,S_(checkname(name,varargin{:})),numtxt);
        else
    	    txt=sprintf('%s%s%s',padding1,S_(checkname(name,varargin{:})),matdata2ubjson(item,level+1,varargin{:}));
        end
    end
    return;
end
dataformat='%s%s%s%s%s';

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
       txt=sprintf(dataformat,txt,padding0,S_('_ArrayIsComplex_'),'T', sprintf(''));
    end
    txt=sprintf(dataformat,txt,padding0,S_('_ArrayIsSparse_'),'T', sprintf(''));
    if(size(item,1)==1)
        % Row vector, store only column indices.
        txt=sprintf(dataformat,txt,padding0,S_('_ArrayData_'),...
           matdata2ubjson([iy(:),data'],level+2,varargin{:}), sprintf(''));
    elseif(size(item,2)==1)
        % Column vector, store only row indices.
        txt=sprintf(dataformat,txt,padding0,S_('_ArrayData_'),...
           matdata2ubjson([ix,data],level+2,varargin{:}), sprintf(''));
    else
        % General case, store row and column indices.
        txt=sprintf(dataformat,txt,padding0,S_('_ArrayData_'),...
           matdata2ubjson([ix,iy,data],level+2,varargin{:}), sprintf(''));
    end
else
    if(isreal(item))
        txt=sprintf(dataformat,txt,padding0,S_('_ArrayData_'),...
            matdata2ubjson(item(:)',level+2,varargin{:}), sprintf(''));
    else
        txt=sprintf(dataformat,txt,padding0,S_('_ArrayIsComplex_'),'T', sprintf(''));
        txt=sprintf(dataformat,txt,padding0,S_('_ArrayData_'),...
            matdata2ubjson([real(item(:)) imag(item(:))],level+2,varargin{:}), sprintf(''));
    end
end
txt=sprintf('%s%s%s',txt,padding1,'}');

%%-------------------------------------------------------------------------
function txt=matdata2ubjson(mat,level,varargin)
if(isempty(mat))
    txt='Z';
    return;
end
if(size(mat,1)==1)
    pre='';
    post='';
    level=level-1;
else
    pre=sprintf('');
    post=sprintf('');
end

if(isa(mat,'integer') || (isfloat(mat) && all(mod(mat(:),1) == 0)))
    id= hist(abs(max(mat(:))),[0 2^8 2^16 2^32 2^64]);
    key='iIlL';
    txt=[I_a(mat(:),key(find(id)),size(mat))];
elseif(islogical(mat))
    txt=mat2str(uint8(mat(:)'));
    txt=regexprep(txt,'1','T');
    txt=regexprep(txt,'0','F');
    txt=regexprep(txt,'\s','');
else
    if(numel(mat)==1)
        txt=['[' D_(mat) ']'];
    else
        txt=D_a(mat(:),'D',size(mat));
    end
end

if(islogical(mat) && jsonopt('ParseLogical',0,varargin{:})==1)
   txt=regexprep(txt,'1','T');
   txt=regexprep(txt,'0','F');
end
%txt=regexprep(mat2str(mat),'\s+',',');
%txt=regexprep(txt,';',sprintf('],['));
% if(nargin>=2 && size(mat,1)>1)
%     txt=regexprep(txt,'\[',[repmat(sprintf('\t'),1,level) '[']);
% end
txt=[pre txt post];
if(any(isinf(mat(:))))
    txt=regexprep(txt,'([-+]*)Inf',jsonopt('Inf','"$1_Inf_"',varargin{:}));
end
if(any(isnan(mat(:))))
    txt=regexprep(txt,'NaN',jsonopt('NaN','"_NaN_"',varargin{:}));
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
        if(isempty(pos)) return; end
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

function val=S_(str)
if(length(str)==1)
  val=['C' str];
else
  val=['S' I_(int32(length(str))) str];
end

function val=I_(num)
if(~isinteger(num))
    error('input is not an integer');
end
key='iIlL';
cid={'int8','int16','int32','int64'};
for i=1:4
  if(num<2^(i*8))
    val=[key(i) typecast(cast(num,cid{i}),'uint8')];
    return;
  end
end
error('unsupported integer');


function val=D_(num)
if(~isfloat(num))
    error('input is not a float');
end
if(isa(num,'single'))
  val=['d' typecast(num,'uint8')];
else
  val=['D' typecast(num,'uint8')];
end

function data=I_a(num,type,dim,format)
id=find(ismember('iIlL',type));

if(id==0)
  error('unsupported integer array');
end

if(id==1)
  data=typecast(int8(num),'uint8');
elseif(id==2)
  data=typecast(int16(num),'uint8');
elseif(id==3)
  data=typecast(int32(num),'uint8');
elseif(id==4)
  data=typecast(int64(num),'uint8');
end
blen=2^(id-1);

if(nargin>=3 && length(dim)>=2 && prod(dim)~=dim(2))
  format='opt';
end
if((nargin<4 || strcmp(format,'opt')) && numel(num)>1)
  if(nargin>=3 && (length(dim)==1 || (length(dim)>=2 && prod(dim)~=dim(2))))
      cid=I_(uint32(max(dim)));
      data=['$' type '#' I_a(dim,cid(1)) data(:)'];
  else
      data=['$' type '#' I_(int32(numel(data)/blen)) data(:)'];
  end
else
  data=reshape(data,id,numel(data)/blen);
  data(2:blen+1,:)=data;
  data(1,:)=type;
  data=data(:)';
end
data=['[' data(:)' ']'];

function data=D_a(num,type,dim,format)
id=find(ismember('dD',type));

if(id==0)
  error('unsupported float array');
end

if(id==1)
  data=typecast(single(num),'uint8');
elseif(id==2)
  data=typecast(double(num),'uint8');
end

if(nargin>=3 && length(dim)>=2 && prod(dim)~=dim(2))
  format='opt'
end
if((nargin<4 || strcmp(format,'opt')) && numel(num)>1)
  if(nargin>=3 && (length(dim)==1 || (length(dim)>=2 && prod(dim)~=dim(2))))
      cid=I_(uint32(max(dim)));
      data=['$' type '#' I_a(dim,cid(1)) data(:)'];
  else
      data=['$' type '#' I_(int32(numel(data)/(id*4))) data(:)'];
  end
else
  data=reshape(data,(id*4),length(data)/(id*4));
  data(2:(id*4+1),:)=data;
  data(1,:)=type;
  data=data(:)';
end
data=['[' data(:)' ']'];
