function run_save_test(testname,fhandle,input,expected,varargin)
res=fhandle('',input,varargin{:});
if(~isequal(strtrim(res),expected))
    warning('%s: failed: expected ''%s'', obtained ''%s''',testname,expected,res);
else
    fprintf(1,'%s: ok\n\toutput:''%s''\n',testname,strtrim(res));
    if(regexp(res,'^[\[\{]'))
        handleinfo=functions(fhandle);
        loadfunname=regexprep(handleinfo.function,'^save','load');
        loadfun=str2func(loadfunname);
        if(strcmp(loadfunname,'loadubjson'))
            newres=loadfun(fhandle('',input,varargin{:},'debug',0),varargin{:});
        else
            newres=loadfun(res,varargin{:});
        end
        if(exist('isequaln'))
            try
              if(isequaln(newres,input))
                  fprintf(1,'\t%s successfully restored the input\n',loadfunname);
              end
            catch
            end
        else
            try
                if(newres==input)
                    fprintf(1,'\t%s successfully restored the input\n',loadfunname);
                end
            catch
            end
        end
    end
end