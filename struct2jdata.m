function newdata=struct2jdata(data,varargin)
%
% newdata=struct2jdata(data,opt,...)
%
% convert a JData object (in the form of a struct array) into an array
%
% authors:Qianqian Fang (q.fang <at> neu.edu)
%
% input:
%      data: a struct array. If data contains JData keywords in the first
%            level children, these fields are parsed and regrouped into a
%            data object (arrays, trees, graphs etc) based on JData 
%            specification. The JData keywords are
%               "_ArrayType_", "_ArraySize_", "_ArrayData_"
%               "_ArrayIsSparse_", "_ArrayIsComplex_", 
%               "_ArrayCompressionMethod_", "_ArrayCompressionSize",
%               "_ArrayCompressedData_"
%      opt: (optional) a list of 'Param',value pairs for additional options 
%           The supported options include
%               'Recursive', if set to 1, will apply the conversion to 
%                            every child; 0 to disable
%               'Base64'. if set to 1, _ArrayCompressedData_ is assumed to
%                         be encoded with base64 format and need to be
%                         decoded first. This is needed for JSON but not
%                         UBJSON data
%
% output:
%      newdata: the covnerted data if the input data does contain a JData 
%               structure; otherwise, the same as the input.
%
% examples:
%      obj=struct('_ArrayType_','double','_ArraySize_',[2 3],
%                 '_ArrayIsSparse_',1 ,'_ArrayData_',null);
%      ubjdata=struct2jdata(obj);
%
% license:
%     BSD or GPL version 3, see LICENSE_{BSD,GPLv3}.txt files for details 
%
% -- this function is part of JSONLab toolbox (http://iso2mesh.sf.net/cgi-bin/index.cgi?jsonlab)
%

newdata=data;
if(~isstruct(data))
    if(iscell(data))
        newdata=cellfun(@(x) struct2jdata(x),data,'UniformOutput',false);
    end
    return;
end
fn=fieldnames(data);
len=length(data);
needbase64=jsonopt('Base64',1,varargin{:});
if(jsonopt('Recursive',1,varargin{:})==1)
  for i=1:length(fn) % depth-first
    for j=1:len
        if(isstruct(data(j).(fn{i})))
            newdata(j).(fn{i})=struct2jdata(data(j).(fn{i}));
        elseif(iscell(data(j).(fn{i})))
            newdata(j).(fn{i})=cellfun(@(x) struct2jdata(x),newdata(j).(fn{i}),'UniformOutput',false);
        end
    end
  end
end
if(~isempty(strmatch('x0x5F_ArrayType_',fn)) && (~isempty(strmatch('x0x5F_ArrayData_',fn)) || ~isempty(strmatch('x0x5F_ArrayCompressedData_',fn))))
  newdata=cell(len,1);
  for j=1:len
    if(~isempty(strmatch('x0x5F_ArrayCompressionSize_',fn)) && ~isempty(strmatch('x0x5F_ArrayCompressedData_',fn)))
        zipmethod='zip';
        if(~isempty(strmatch('x0x5F_ArrayCompressionMethod_',fn)))
            zipmethod=data(j).x0x5F_ArrayCompressionMethod_;
        end
        if(~isempty(strmatch(zipmethod,{'zlib','gzip','lzma','lzip'})))
            decompfun=str2func([zipmethod 'decode']);
            if(needbase64)
                ndata=reshape(typecast(decompfun(base64decode(data(j).x0x5F_ArrayCompressedData_)),data(j).x0x5F_ArrayType_),data(j).x0x5F_ArrayCompressionSize_);
            else
                ndata=reshape(typecast(decompfun(data(j).x0x5F_ArrayCompressedData_),data(j).x0x5F_ArrayType_),data(j).x0x5F_ArrayCompressionSize_);
            end
        else
            error('compression method is not supported');
        end
    else
        if(iscell(data(j).x0x5F_ArrayData_))
            data(j).x0x5F_ArrayData_=cell2mat(data(j).x0x5F_ArrayData_);
        end
        ndata=cast(data(j).x0x5F_ArrayData_,data(j).x0x5F_ArrayType_);
    end
    iscpx=0;
    needtranspose=0;
    if(~isempty(strmatch('x0x5F_ArrayIsComplex_',fn)))
        if(data(j).x0x5F_ArrayIsComplex_)
           iscpx=1;
           needtranspose=islogical(data(j).x0x5F_ArrayIsComplex_);
        end
    end
    if(~isempty(strmatch('x0x5F_ArrayIsSparse_',fn)) && data(j).x0x5F_ArrayIsSparse_)
            if(islogical(data(j).x0x5F_ArrayIsSparse_))
                needtranspose=1;
            end
            if(needtranspose)
                ndata=ndata';
            end
            if(~isempty(strmatch('x0x5F_ArraySize_',fn)))
                dim=double(data(j).x0x5F_ArraySize_);
                if(iscpx && size(ndata,2)==4-any(dim==1))
                    ndata(:,end-1)=complex(ndata(:,end-1),ndata(:,end));
                end
                if isempty(ndata)
                    % All-zeros sparse
                    ndata=sparse(dim(1),prod(dim(2:end)));
                elseif dim(1)==1
                    % Sparse row vector
                    if(size(ndata,2)~=2 && size(ndata,1)==2) 
                        ndata=ndata';
                    end
                    ndata=sparse(1,ndata(:,1),ndata(:,2),dim(1),prod(dim(2:end)));
                elseif dim(2)==1
                    % Sparse column vector
                    if(size(ndata,2)~=2 && size(ndata,1)==2) 
                        ndata=ndata';
                    end
                    ndata=sparse(ndata(:,1),1,ndata(:,2),dim(1),prod(dim(2:end)));
                else
                    % Generic sparse array.
                    if(size(ndata,2)~=3 && size(ndata,1)==3) 
                        ndata=ndata';
                    end
                    ndata=sparse(ndata(:,1),ndata(:,2),ndata(:,3),dim(1),prod(dim(2:end)));
                end
            else
                if(iscpx && size(ndata,2)==4)
                    ndata(:,3)=complex(ndata(:,3),ndata(:,4));
                end
                ndata=sparse(ndata(:,1),ndata(:,2),ndata(:,3));
            end
    elseif(~isempty(strmatch('x0x5F_ArraySize_',fn)))
        if(needtranspose)
            ndata=ndata';
        end
        if(iscpx)
            if(size(ndata,2)~=2 && size(ndata,1)==2)
                ndata=ndata';
            end
            ndata=complex(ndata(:,1),ndata(:,2));
        end
        ndata=reshape(ndata(:),data(j).x0x5F_ArraySize_);
    end
    newdata{j}=ndata;
  end
  if(len==1)
      newdata=newdata{1};
  end
end