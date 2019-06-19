function newdata=jdatadecode(data,varargin)
%
% newdata=jdatadecode(data,opt,...)
%
% Convert all JData object (in the form of a struct array) into an array
% (accepts JData objects loaded from either loadjson/loadubjson or 
% jsondecode for MATLAB R2018a or later)
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
%               "_ArrayZipType_", "_ArrayZipSize", "_ArrayZipData_"
%      opt: (optional) a list of 'Param',value pairs for additional options 
%           The supported options include
%               'Recursive', if set to 1, will apply the conversion to 
%                            every child; 0 to disable
%               'Base64'. if set to 1, _ArrayZipData_ is assumed to
%                         be encoded with base64 format and need to be
%                         decoded first. This is needed for JSON but not
%                         UBJSON data
%               'Prefix', for JData files loaded via loadjson/loadubjson, the
%                         default JData keyword prefix is 'x0x5F'; if the
%                         json file is loaded using matlab2018's
%                         jsondecode(), the prefix is 'x'; this function
%                         attempts to automatically determine the prefix.
%               'FormatVersion' [2|float]: set the JSONLab output version; 
%                         since v2.0, JSONLab uses JData specification Draft 1
%                         for output format, it is incompatible with all
%                         previous releases; if old output is desired,
%                         please set FormatVersion to 1
%
% output:
%      newdata: the covnerted data if the input data does contain a JData 
%               structure; otherwise, the same as the input.
%
% examples:
%      obj=struct('_ArrayType_','double','_ArraySize_',[2 3],
%                 '_ArrayIsSparse_',1 ,'_ArrayData_',null);
%      jdata=jdatadecode(obj);
%
% license:
%     BSD or GPL version 3, see LICENSE_{BSD,GPLv3}.txt files for details 
%
% -- this function is part of JSONLab toolbox (http://iso2mesh.sf.net/cgi-bin/index.cgi?jsonlab)
%

    newdata=data;
    if(~isstruct(data))
        if(iscell(data))
            newdata=cellfun(@(x) jdatadecode(x),data,'UniformOutput',false);
        end
        return;
    end
    fn=fieldnames(data);
    len=length(data);
    opt=varargin2struct(varargin{:});
    needbase64=jsonopt('Base64',1,opt);
    format=jsonopt('FormatVersion',2,opt);
    prefix=jsonopt('Prefix',sprintf('x0x%X','_'+0),opt);
    if(isempty(strmatch(N_('_ArrayType_'),fn)) && ~isempty(strmatch('x_ArrayType_',fn)))
        prefix='x';
        opt.prefix='x';
    end

    if(jsonopt('Recursive',1,opt)==1)
      for i=1:length(fn) % depth-first
        for j=1:len
            if(isstruct(data(j).(fn{i})))
                newdata(j).(fn{i})=jdatadecode(data(j).(fn{i}),opt);
            elseif(iscell(data(j).(fn{i})))
                newdata(j).(fn{i})=cellfun(@(x) jdatadecode(x,opt),newdata(j).(fn{i}),'UniformOutput',false);
            end
        end
      end
    end

    if(~isempty(strmatch(N_('_ArrayType_'),fn)) && (~isempty(strmatch(N_('_ArrayData_'),fn)) || ~isempty(strmatch(N_('_ArrayZipData_'),fn))))
      newdata=cell(len,1);
      for j=1:len
        if(~isempty(strmatch(N_('_ArrayZipSize_'),fn)) && ~isempty(strmatch(N_('_ArrayZipData_'),fn)))
            zipmethod='zip';
            if(~isempty(strmatch(N_('_ArrayZipType_'),fn)))
                zipmethod=data(j).(N_('_ArrayZipType_'));
            end
            if(~isempty(strmatch(zipmethod,{'zlib','gzip','lzma','lzip'})))
                decompfun=str2func([zipmethod 'decode']);
                if(needbase64)
                    ndata=reshape(typecast(decompfun(base64decode(data(j).(N_('_ArrayZipData_')))),data(j).(N_('_ArrayType_'))),data(j).(N_('_ArrayZipSize_')));
                else
                    ndata=reshape(typecast(decompfun(data(j).(N_('_ArrayZipData_'))),data(j).(N_('_ArrayType_'))),data(j).(N_('_ArrayZipSize_')));
                end
            else
                error('compression method is not supported');
            end
        else
            if(iscell(data(j).(N_('_ArrayData_'))))
                data(j).(N_('_ArrayData_'))=cell2mat(cellfun(@(x) double(x(:)),data(j).(N_('_ArrayData_')),'uniformoutput',0));
            end
            ndata=cast(data(j).(N_('_ArrayData_')),data(j).(N_('_ArrayType_')));
        end
        iscpx=0;
        needtranspose=0;
        if(~isempty(strmatch(N_('_ArrayIsComplex_'),fn)))
            if(data(j).(N_('_ArrayIsComplex_')))
               iscpx=1;
               needtranspose=islogical(data(j).(N_('_ArrayIsComplex_')));
            end
        end
        if(~isempty(strmatch(N_('_ArrayIsSparse_'),fn)) && data(j).(N_('_ArrayIsSparse_')))
                if(islogical(data(j).(N_('_ArrayIsSparse_'))))
                    needtranspose=1;
                end
                if(~isempty(strmatch(N_('_ArraySize_'),fn)))
                    dim=double(data(j).(N_('_ArraySize_')));
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
        elseif(~isempty(strmatch(N_('_ArraySize_'),fn)))
            if(needtranspose)
                ndata=ndata';
            end
            if(iscpx)
                if(size(ndata,2)~=2 && size(ndata,1)==2)
                    ndata=ndata';
                end
                ndata=complex(ndata(:,1),ndata(:,2));
            end
            if(format>1.9)
                data(j).(N_('_ArraySize_'))=data(j).(N_('_ArraySize_'))(end:-1:1);
            end
            dims=data(j).(N_('_ArraySize_'));
            ndata=reshape(ndata(:),dims(:)');
            if(format>1.9)
                ndata=permute(ndata,ndims(ndata):-1:1);
            end
        end
        newdata{j}=ndata;
      end
      if(len==1)
          newdata=newdata{1};
      end
    end
    if(~isempty(strmatch(N_('_MapData_'),fn)))
        newdata=cell(len,1);
        for j=1:len
            key={};
            val={};
            for k=1:length(data(j).(N_('_MapData_')))
                key{k}=data(j).(N_('_MapData_')){k}{1};
                val{k}=data(j).(N_('_MapData_')){k}{2};
            end
            ndata=containers.Map(key,val);
            newdata{j}=ndata;
        end
        if(len==1)
            newdata=newdata{1};
        end
    end
    %% subfunctions 
    function escaped=N_(str)
      escaped=[prefix str];
    end
end