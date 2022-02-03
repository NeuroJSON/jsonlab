function json=jsonget(fname,mmap,varargin)
%
% json=jsonget(fname,mmap,'$.jsonpath1','$.jsonpath2',...)
%
% Fast reading of JSON data records using memory-map (mmap) returned by
% loadjson and JSONPath-like keys
%
% authors:Qianqian Fang (q.fang <at> neu.edu)
% initially created on 2022/02/02
%
% input:
%      fname: a JSON/BJData/UBJSON string or stream, or a file name
%      mmap: memory-map returned by loadjson/loadbj of the same data
%            important: mmap must be produced from the same file/string,
%            otherwise calling this function may cause data corruption
%      '$.jsonpath1,2,3,...':  a series of strings in the form of JSONPath
%            as the key to each of the record to be retrieved
%
% output:
%      json: a cell array, made of elements {'$.jsonpath_i',json_string_i}
%
% examples:
%      str='[[1,2],"a",{"c":2}]{"k":"test"}';
%      [dat, mmap]=loadjson(str);
%      savejson('',dat,'filename','mydata.json','compact',1);
%      json=jsonget(str,mmap,'$.[0].[*]','$.[2].c')
%      json=jsonget('mydata.json',mmap,'$.[0].[*]','$.[2].c')
%
% license:
%     BSD or GPL version 3, see LICENSE_{BSD,GPLv3}.txt files for details 
%
% -- this function is part of JSONLab toolbox (http://iso2mesh.sf.net/cgi-bin/index.cgi?jsonlab)
%

if(regexp(fname,'^\s*(?:\[.*\])|(?:\{.*\})\s*$','once'))
    inputstr=fname;
elseif(isoctavemesh)
    if(exist(fname,'file'))
       try
           fid = fopen(fname,'rb');
           inputstr = fread(fid,'char',inf)';
           fclose(fid);
       catch
           try
               inputstr = urlread(['file://',fname]);
           catch
               inputstr = urlread(['file://',fullfile(pwd,fname)]);
           end
       end
    end
end

mmap=[mmap{:}];
keylist=mmap(1:2:end);

json={};
for i=1:length(varargin)
    if(regexp(varargin{i},'^\$'))
        [tf,loc]=ismember(varargin{i},keylist);
        if(tf)
            rec={'uint8',[1,mmap{loc*2}(2)],  'x'};
            if(exist('inputstr','var'))
                json{end+1}={varargin{i}, inputstr(mmap{loc*2}(1):mmap{loc*2}(1)+mmap{loc*2}(2)-1)};
            else
                fmap=memmapfile(fname,'writable',false, 'offset',mmap{loc*2}(1),'format', rec);
                json{end+1}={varargin{i}, char(fmap.Data(1).x)};
            end
        end
    end
end
