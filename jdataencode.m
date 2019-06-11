function newdata=jdataencode(data,varargin)
%
% newdata=jdataencode(data,opt,...)
%
% encode special MATLAB objects (cells, structs, sparse and complex arrays, 
% maps, graphs, function handles, etc) to the JData format
%
% authors:Qianqian Fang (q.fang <at> neu.edu)
%
% input:
%      data: a matlab object
%      opt: (optional) a list of 'Param',value pairs for additional options.
%           For all supported options, please see the help info for savejson.m 
%           and loadjson.m
%
% output:
%      newdata: the covnerted data containing JData structures
%
% examples:
%      jd=jdataencode(struct('a',rand(5)+1i*rand(5),'b',[],'c',sparse(5,5)))
%
% license:
%     BSD or GPL version 3, see LICENSE_{BSD,GPLv3}.txt files for details 
%
% -- this function is part of JSONLab toolbox (http://iso2mesh.sf.net/cgi-bin/index.cgi?jsonlab)
%

newdata=loadjson(savejson('',data,varargin{:}),varargin{:},'JDataDecode',0);