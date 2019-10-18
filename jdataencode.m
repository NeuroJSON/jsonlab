function jdata=jdataencode(data, varargin)
%
%    jdata=jdataencode(data)
%       or
%    jdata=jdataencode(data, options)
%    jdata=jdataencode(data, 'Param1',value1, 'Param2',value2,...)
%
%    Serialize a MATLAB struct or cell array into a JData-compliant 
%    structure as defined in the JData spec: http://github.com/fangq/jdata
%
%    author: Qianqian Fang (q.fang <at> neu.edu)
%
%    input:
%        data: a structure (array) or cell (array) to be encoded.
%        options: (optional) a struct or Param/value pairs for user specified options
%            Compression: ['zlib'|'gzip','lzma','lz4','lz4hc'] - use zlib method 
%                         to compress data array
%            CompressArraySize: [100|int]: only to compress an array if the  
%                         total element count is larger than this number.
%
%    example:
%        jd=jdataencode(struct('a',rand(5)+1i*rand(5),'b',[],'c',sparse(5,5)))
%
%    license:
%        BSD or GPL version 3, see LICENSE_{BSD,GPLv3}.txt files for details 
%
% -- this function is part of JSONLab toolbox (http://iso2mesh.sf.net/cgi-bin/index.cgi?jsonlab)
%


if(nargin==0)
    help jdataencode
    return;
end

opt=varargin2struct(varargin{:});
opt.prefix=jsonopt('Prefix',sprintf('x0x%X','_'+0),opt);

jdata=obj2jd(data,opt);

%%-------------------------------------------------------------------------
function newitem=obj2jd( item,varargin)

if(iscell(item))
    newitem=cell2jd(item,varargin{:});
elseif(isstruct(item))
    newitem=struct2jd(item,varargin{:});
elseif(ischar(item) || isa(item,'string'))
    newitem=mat2jd(item,varargin{:});
elseif(isa(item,'containers.Map'))
    newitem=map2jd(item,varargin{:});
elseif(isa(item,'categorical'))
    newitem=cell2jd(cellstr(item),varargin{:});
elseif(islogical(item) || isnumeric(item))
    newitem=mat2jd(item,varargin{:});
elseif(isa(item,'table'))
    newitem=table2jd(item,varargin{:});
elseif(isa(item,'digraph') || isa(item,'graph'))
    newitem=graph2jd(item,varargin{:});
else
    newitem=any2jd(item,varargin{:});
end

%%-------------------------------------------------------------------------
function newitem=cell2jd(item,varargin)

newitem=cellfun(@(x) obj2jd(x, varargin{:}), item, 'UniformOutput',false);

%%-------------------------------------------------------------------------
function newitem=struct2jd(item,varargin)

num=numel(item);
if(num>1)
    newitem=obj2jd(num2cell(item),varargin{:});
    try
       newitem=cell2mat(newitem);
    catch
    end
else
    names=fieldnames(item);
    newitem=struct;
    for i=1:length(names)
        newitem.(names{i})=obj2jd(item.(names{i}),varargin{:});
    end
end

%%-------------------------------------------------------------------------
function newitem=map2jd(item,varargin)

names=item.keys;
newitem=containers.Map;
for i=1:length(names)
    newitem(names{i})=obj2jd(item(names{i}),varargin{:});
end

%%-------------------------------------------------------------------------
function newitem=mat2jd(item,varargin)
if(isempty(item) || isa(item,'string') || ischar(item) || (isvector(item) && isreal(item) && ~issparse(item)))
    newitem=item;
    return;
end

zipmethod=jsonopt('Compression','',varargin{:});
minsize=jsonopt('CompressArraySize',100,varargin{:});

if(isa(item,'logical'))
    item=uint8(item);
end

newitem=struct(N_('_ArraySize_'),size(item),N_('_ArrayType_'),class(item));

if(isreal(item))
    if(issparse(item))
	    fulldata=full(item(find(item)));
        newitem.(N_('_ArrayIsSparse_'))=true;
	    newitem.(N_('_ArrayZipSize_'))=[2+(~isvector(item)),length(fulldata)];
        if(isvector(item))
            newitem.(N_('_ArrayData_'))=[find(item)', fulldata(:)'];
        else
            [ix,iy]=find(item);
	        newitem.(N_('_ArrayData_'))=[ix(:)' , iy(:)', fulldata(:)'];
	    end
    else
        item=permute(item,ndims(item):-1:1);
	    newitem.(N_('_ArrayData_'))=item(:)';
    end
else
    newitem.(N_('_ArrayIsComplex_'))=true;
    if(issparse(item))
	    fulldata=full(item(find(item)));
        newitem.(N_('_ArrayIsSparse_'))=true;
	    newitem.(N_('_ArrayZipSize_'))=[3+(~isvector(item)),length(fulldata)];
        if(isvector(item))
            newitem.(N_('_ArrayData_'))=[find(item)', real(fulldata(:)'), imag(fulldata(:)')];
        else
            [ix,iy]=find(item);
            newitem.(N_('_ArrayData_'))=[ix(:)' , iy(:)' , real(fulldata(:)'), imag(fulldata(:)')];
	    end
    else
        newitem.(N_('_ArrayZipSize_'))=[2,numel(item)];
	    newitem.(N_('_ArrayData_'))=[real(item(:)'), imag(item(:)')];
    end
end

if(~isempty(zipmethod) && numel(item)>minsize)
    compfun=str2func([zipmethod 'encode']);
    newitem.(N_('_ArrayZipType_'))=lower(zipmethod);
    newitem.(N_('_ArrayZipSize_'))=size(newitem.(N_('_ArrayData_')));
    newitem.(N_('_ArrayZipData_'))=compfun(typecast(newitem.(N_('_ArrayData_')),'uint8'));
    newitem=rmfield(newitem,N_('_ArrayData_'));
    if(jsonopt('Base64',1,varargin{:}))
        newitem.(N_('_ArrayZipData_'))=char(base64encode(newitem.(N_('_ArrayZipData_'))));
    end
end

%%-------------------------------------------------------------------------
function newitem=table2jd(item,varargin)
newitem=struct;
newitem(N_('_TableRows_'))=item.Properties.RowNames';
newitem(N_('_TableCols_'))=item.Properties.VariableNames;
newitem(N_('_TableRecords_'))=table2cell(item);

%%-------------------------------------------------------------------------
function newitem=graph2jd(item,varargin)
newitem=struct;
nodedata=table2struct(item.Nodes);
if(isfield(nodedata,'Name'))
    nodedata=rmfield(nodedata,'Name');
    newitem.(N_('_GraphNodes_'))=containers.Map(item.Nodes.Name,num2cell(nodedata),'uniformValues',false);
else
    newitem.(N_('_GraphNodes_'))=containers.Map(1:max(item.Edges.EndNodes(:)),num2cell(nodedata),'uniformValues',false);
end
edgenodes=item.Edges.EndNodes;
edgedata=table2struct(item.Edges);
if(isfield(edgedata,'EndNodes'))
    edgedata=rmfield(edgedata,'EndNodes');
end
edgenodes(:,3)=num2cell(edgedata);
newitem.(N_('_GraphEdges_'))=edgenodes;

%%-------------------------------------------------------------------------
function newname=N_(name,varargin)
prefix=jsonopt('Prefix',sprintf('x0x%X','_'+0),varargin{:});
newname=[prefix name];
