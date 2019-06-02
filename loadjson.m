function data = loadjson(fname,varargin)
%
% data=loadjson(fname,opt)
%    or
% data=loadjson(fname,'param1',value1,'param2',value2,...)
%
% parse a JSON (JavaScript Object Notation) file or string
%
% authors:Qianqian Fang (q.fang <at> neu.edu)
% created on 2011/09/09, including previous works from 
%
%         Nedialko Krouchev: http://www.mathworks.com/matlabcentral/fileexchange/25713
%            created on 2009/11/02
%         François Glineur: http://www.mathworks.com/matlabcentral/fileexchange/23393
%            created on  2009/03/22
%         Joel Feenstra:
%         http://www.mathworks.com/matlabcentral/fileexchange/20565
%            created on 2008/07/03
%
% $Id$
%
% input:
%      fname: input file name, if fname contains "{}" or "[]", fname
%             will be interpreted as a JSON string
%      opt: a struct to store parsing options, opt can be replaced by 
%           a list of ('param',value) pairs - the param string is equivallent
%           to a field in opt. opt can have the following 
%           fields (first in [.|.] is the default)
%
%           opt.SimplifyCell [0|1]: if set to 1, loadjson will call cell2mat
%                         for each element of the JSON data, and group 
%                         arrays based on the cell2mat rules.
%           opt.FastArrayParser [1|0 or integer]: if set to 1, use a
%                         speed-optimized array parser when loading an 
%                         array object. The fast array parser may 
%                         collapse block arrays into a single large
%                         array similar to rules defined in cell2mat; 0 to 
%                         use a legacy parser; if set to a larger-than-1
%                         value, this option will specify the minimum
%                         dimension to enable the fast array parser. For
%                         example, if the input is a 3D array, setting
%                         FastArrayParser to 1 will return a 3D array;
%                         setting to 2 will return a cell array of 2D
%                         arrays; setting to 3 will return to a 2D cell
%                         array of 1D vectors; setting to 4 will return a
%                         3D cell array.
%           opt.ShowProgress [0|1]: if set to 1, loadjson displays a progress bar.
%           opt.ParseStringArray [0|1]: if set to 0, loadjson converts "string arrays" 
%                         (introduced in MATLAB R2016b) to char arrays; if set to 1,
%                         loadjson skips this conversion.
%
% output:
%      dat: a cell array, where {...} blocks are converted into cell arrays,
%           and [...] are converted to arrays
%
% examples:
%      dat=loadjson('{"obj":{"string":"value","array":[1,2,3]}}')
%      dat=loadjson(['examples' filesep 'example1.json'])
%      dat=loadjson(['examples' filesep 'example1.json'],'SimplifyCell',1)
%
% license:
%     BSD or GPL version 3, see LICENSE_{BSD,GPLv3}.txt files for details 
%
% -- this function is part of JSONLab toolbox (http://iso2mesh.sf.net/cgi-bin/index.cgi?jsonlab)
%

if(regexp(fname,'^\s*(?:\[.*\])|(?:\{.*\})\s*$','once'))
   string=fname;
elseif(exist(fname,'file'))
   try
       string = fileread(fname);
   catch
       try
           string = urlread(['file://',fname]);
       catch
           string = urlread(['file://',fullfile(pwd,fname)]);
       end
   end
else
   error('input file does not exist');
end

pos = 1; inputlen = length(string); inputstr = string;
arraytokenidx=find(inputstr=='[' | inputstr==']');
arraytoken=inputstr(arraytokenidx);

isoct=exist('OCTAVE_VERSION','builtin');

% String delimiters and escape chars identified to improve speed:
esc = find(inputstr=='"' | inputstr=='\' ); % comparable to: regexp(inputstr, '["\\]');
index_esc = 1;

opt=varargin2struct(varargin{:});
opt.arraytoken_=arraytoken;
opt.arraytokenidx_=arraytokenidx;

if(jsonopt('ShowProgress',0,opt)==1)
    opt.progressbar_=waitbar(0,'loading ...');
end
jsoncount=1;
while pos <= inputlen
    switch(next_char(inputstr))
        case '{'
            data{jsoncount} = parse_object(inputstr, esc, opt);
        case '['
            data{jsoncount} = parse_array(inputstr, esc, opt);
        otherwise
            error_pos('Outer level structure must be an object or an array',inputstr);
    end
    jsoncount=jsoncount+1;
end % while

jsoncount=length(data);
if(jsoncount==1 && iscell(data))
    data=data{1};
end

if(isfield(opt,'progressbar_'))
    close(opt.progressbar_);
end


%%-------------------------------------------------------------------------
%% subfunctions
%%-------------------------------------------------------------------------

    function object = parse_array(inputstr, esc, varargin) % JSON array is written in row-major order
        parse_char(inputstr, '[');
        object = cell(0, 1);
        arraydepth=jsonopt('arraydepth_',1,varargin{:});
        pbar=-1;
        if(isfield(varargin{1},'progressbar_'))
            pbar=varargin{1}.progressbar_;
        end

        if next_char(inputstr) ~= ']'
            try
                if(jsonopt('FastArrayParser',1,varargin{:})>=1 && arraydepth>=jsonopt('FastArrayParser',1,varargin{:}))
                    [endpos, maxlevel]=fast_match_bracket(varargin{1}.arraytoken_,varargin{1}.arraytokenidx_,pos);
                    if(~isempty(endpos))
                        arraystr=['[' inputstr(pos:endpos)];
                        arraystr=sscanf_prep(arraystr);
                        if(isempty(find(arraystr=='"', 1)))
                            % handle 1D array first
                            if(maxlevel==1)
                                astr=arraystr(2:end-1);
                                astr(astr==' ')='';
                                [obj, count, errmsg, nextidx]=sscanf(astr,'%f,',[1,inf]);
                                if(nextidx>=length(astr)-1)
                                        object=obj;
                                        pos=endpos;
                                        parse_char(inputstr, ']');
                                        return;
                                end
                            end

                            % next handle 2D array, these are most common ones
                            if(maxlevel==2 && ~isempty(regexp(arraystr(2:end),'^\s*\[','once')))
                                rowstart=find(arraystr(2:end)=='[',1)+1;
                                if(rowstart)
                                    [obj, nextidx]=parse2darray(inputstr,pos+rowstart,arraystr);
                                    if(nextidx>=length(arraystr)-1)
                                        object=obj;
                                        pos=endpos;
                                        parse_char(inputstr, ']');
                                        if(pbar>0)
                                            waitbar(pos/length(inStr),pbar,'loading ...');
                                        end
                                        return;
                                    end
                                end
                            end

                            % for N-D packed array in a nested array construct, 
                            % in the future can replace 1d and 2d cases
                            if(maxlevel>2 && ~isempty(regexp(arraystr(2:end),'^\s*\[\s*\[','once')))
                                astr=arraystr;
                                dims=nestbracket2dim(astr);
                                if(any(dims==0) || all(mod(dims(:),1) == 0)) % all dimensions are integers - this can be problematic
                                    astr=arraystr;
                                    astr(astr=='[')='';
                                    astr(astr==']')='';
                                    astr=regexprep(astr,'\s*,',',');
                                    astr=regexprep(astr,'\s*$','');
                                    [obj, count, errmsg, nextidx]=sscanf(astr,'%f,',inf);
                                    if(nextidx>=length(astr)-1)
                                            object=reshape(obj,dims);
                                            pos=endpos;
                                            parse_char(inputstr, ']');
                                            if(pbar>0)
                                                waitbar(pos/length(inStr),pbar,'loading ...');
                                            end
                                            return;
                                    end
                                end
                            end
                        end
                    end
                end
                if(isempty(regexp(arraystr,':','once')))
                    arraystr=regexprep(arraystr,'\[','{');
                    arraystr=regexprep(arraystr,'\]','}');
                    if(jsonopt('ParseStringArray',0,varargin{:})==0)
                        arraystr=regexprep(arraystr,'\"','''');
                    end
                    object=eval(arraystr);
                    if(iscell(object))
                        object=cellfun(@unescapejsonstring,object,'UniformOutput',false);
                    end
                    pos=endpos;
                end
            catch
            end
            if(isempty(endpos) || pos~=endpos)
                while 1
                    newopt=varargin2struct(varargin{:},'arraydepth_',arraydepth+1);
                    val = parse_value(inputstr, esc, newopt);
                    object{end+1} = val;
                    if next_char(inputstr) == ']'
                        break;
                    end
                    parse_char(inputstr, ',');
                end
            end
        end

        if(jsonopt('SimplifyCell',0,varargin{:})==1)
          try
            oldobj=object;
            object=cell2mat(object')';
            if(iscell(oldobj) && isstruct(object) && numel(object)>1 && jsonopt('SimplifyCellArray',1,varargin{:})==0)
                object=oldobj;
            elseif(size(object,1)>1 && ismatrix(object))
                object=object';
            end
          catch
          end
        end
        parse_char(inputstr, ']');

        if(pbar>0)
            waitbar(pos/length(inputstr),pbar,'loading ...');
        end
    end
    %%-------------------------------------------------------------------------

    function parse_char(inputstr, c)
        pos=skip_whitespace(pos, inputstr);
        if pos > length(inputstr) || inputstr(pos) ~= c
            error_pos(sprintf('Expected %c at position %%d', c),inputstr);
        else
            pos = pos + 1;
            pos=skip_whitespace(pos, inputstr);
        end
    end
    %%-------------------------------------------------------------------------

    function c = next_char(inputstr)
        pos=skip_whitespace(pos, inputstr);
        if pos > length(inputstr)
            c = [];
        else
            c = inputstr(pos);
        end
    end

    %%-------------------------------------------------------------------------
    function str = parseStr(inputstr, esc, varargin)
     % len, ns = length(inputstr), keyboard
        if inputstr(pos) ~= '"'
            error_pos('String starting with " expected at position %d',inputstr);
        else
            pos = pos + 1;
        end
        str = '';
        while pos <= length(inputstr)
            while index_esc <= length(esc) && esc(index_esc) < pos
                index_esc = index_esc + 1;
            end
            if index_esc > length(esc)
                str = [str inputstr(pos:end)];
                pos = length(inputstr) + 1;
                break;
            else
                str = [str inputstr(pos:esc(index_esc)-1)];
                pos = esc(index_esc);
            end
            nstr = length(str);
            switch inputstr(pos)
                case '"'
                    pos = pos + 1;
                    if(~isempty(str))
                        if(strcmp(str,'_Inf_'))
                            str=Inf;
                        elseif(strcmp(str,'-_Inf_'))
                            str=-Inf;
                        elseif(strcmp(str,'_NaN_'))
                            str=NaN;
                        end
                    end
                    return;
                case '\'
                    if pos+1 > length(inputstr)
                        error_pos('End of file reached right after escape character',inputstr);
                    end
                    pos = pos + 1;
                    switch inputstr(pos)
                        case {'"' '\' '/'}
                            str(nstr+1) = inputstr(pos);
                            pos = pos + 1;
                        case {'b' 'f' 'n' 'r' 't'}
                            str(nstr+1) = sprintf(['\' inputstr(pos)]);
                            pos = pos + 1;
                        case 'u'
                            if pos+4 > length(inputstr)
                                error_pos('End of file reached in escaped unicode character',inputstr);
                            end
                            str(nstr+(1:6)) = inputstr(pos-1:pos+4);
                            pos = pos + 5;
                    end
                otherwise % should never happen
                    str(nstr+1) = inputstr(pos);
                    keyboard;
                    pos = pos + 1;
            end
        end
        str=unescapejsonstring(str);
        error_pos('End of file while expecting end of inputstr',inputstr);
    end
    %%-------------------------------------------------------------------------

    function num = parse_number(inputstr, varargin)
        currstr=inputstr(pos:min(pos+30,end));
        if(isoct~=0)
            numstr=regexp(currstr,'^\s*-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+\-]?\d+)?','end');
            [num] = sscanf(currstr, '%f', 1);
            delta=numstr+1;
        else
            [num, one, err, delta] = sscanf(currstr, '%f', 1);
            if ~isempty(err)
                error_pos('Error reading number at position %d',inputstr);
            end
        end
        pos = pos + delta-1;
    end
    %%-------------------------------------------------------------------------

    function val = parse_value(inputstr, esc, varargin)
        len=length(inputstr);
        if(isfield(varargin{1},'progressbar_'))
            waitbar(pos/len,varargin{1}.progressbar_,'loading ...');
        end

        switch(inputstr(pos))
            case '"'
                val = parseStr(inputstr, esc, varargin{:});
                return;
            case '['
                val = parse_array(inputstr, esc, varargin{:});
                return;
            case '{'
                val = parse_object(inputstr, esc, varargin{:});
                return;
            case {'-','0','1','2','3','4','5','6','7','8','9'}
                val = parse_number(inputstr, varargin{:});
                return;
            case 't'
                if pos+3 <= len && strcmpi(inputstr(pos:pos+3), 'true')
                    val = true;
                    pos = pos + 4;
                    return;
                end
            case 'f'
                if pos+4 <= len && strcmpi(inputstr(pos:pos+4), 'false')
                    val = false;
                    pos = pos + 5;
                    return;
                end
            case 'n'
                if pos+3 <= len && strcmpi(inputstr(pos:pos+3), 'null')
                    val = [];
                    pos = pos + 4;
                    return;
                end
        end
        error_pos('Value expected at position %d',inputstr);
    end

    %%-------------------------------------------------------------------------
    function object = parse_object(inputstr, esc, varargin)
        parse_char(inputstr, '{');
        object = [];
        if next_char(inputstr) ~= '}'
            while 1
                str = parseStr(inputstr, esc, varargin{:});
                if isempty(str)
                    error_pos('Name of value at position %d cannot be empty',inputstr);
                end
                parse_char(inputstr, ':');
                val = parse_value(inputstr, esc, varargin{:});
                object.(valid_field(str,varargin{:}))=val;
                if next_char(inputstr) == '}'
                    break;
                end
                parse_char(inputstr, ',');
            end
        end
        parse_char(inputstr, '}');
        if(isstruct(object))
            object=struct2jdata(object,struct('Recursive',0));
        end
    end

    %%-------------------------------------------------------------------------

    function error_pos(msg, inputstr)
        poShow = max(min([pos-15 pos-1 pos pos+20],length(inputstr)),1);
        if poShow(3) == poShow(2)
            poShow(3:4) = poShow(2)+[0 -1];  % display nothing after
        end
        msg = [sprintf(msg, pos) ': ' ...
        inputstr(poShow(1):poShow(2)) '<error>' inputstr(poShow(3):poShow(4)) ];
        error( ['JSONparser:invalidFormat: ' msg] );
    end

    %%-------------------------------------------------------------------------

    function str = valid_field(str,varargin)
    % From MATLAB doc: field names must begin with a letter, which may be
    % followed by any combination of letters, digits, and underscores.
    % Invalid characters will be converted to underscores, and the prefix
    % "x0x[Hex code]_" will be added if the first character is not a letter.
        if(~isempty(regexp(str,'^[^A-Za-z]','once')))
            if(~isoct && str(1)+0 > 255)
                str=regexprep(str,'^([^A-Za-z])','x0x${sprintf(''%X'',unicode2native($1))}_','once');
            else
                str=sprintf('x0x%X_%s',char(str(1)),str(2:end));
            end
        end
        if(isvarname(str))
            return;
        end
        if(~isoct)
            str=regexprep(str,'([^0-9A-Za-z_])','_0x${sprintf(''%X'',unicode2native($1))}_');
        else
            cpos=regexp(str,'[^0-9A-Za-z_]');
            if(isempty(cpos))
                return;
            end
            str0=str;
            pos0=[0 cpos(:)' length(str)];
            str='';
            for i=1:length(cpos)
                str=[str str0(pos0(i)+1:cpos(i)-1) sprintf('_0x%X_',str0(cpos(i)))];
            end
            if(cpos(end)~=length(str))
                str=[str str0(pos0(end-1)+1:pos0(end))];
            end
        end
    end
end

%%-------------------------------------------------------------------------

function newpos=skip_whitespace(pos, inputstr)
    newpos=pos;
    while newpos <= length(inputstr) && isspace(inputstr(newpos))
        newpos = newpos + 1;
    end
end

%%-------------------------------------------------------------------------
function newstr=unescapejsonstring(str)
newstr=str;
if(~ischar(str))
    return;
end
escapechars={'\\','\"','\/','\a','\b','\f','\n','\r','\t','\v'};
for i=1:length(escapechars);
    newstr=regexprep(newstr,regexprep(escapechars{i},'\\','\\\\'), escapechars{i});
end
newstr=regexprep(newstr,'\\u([0-9A-Fa-f]{4})', '${char(base2dec($1,16))}');
end

%%-------------------------------------------------------------------------
function arraystr=sscanf_prep(str)
arraystr=str;
if(regexp(str,'"','once'))
    arraystr=regexprep(arraystr,'"_NaN_"','NaN');
    arraystr=regexprep(arraystr,'"([-+]*)_Inf_"','$1Inf');
end
arraystr(arraystr==sprintf('\n'))=[];
arraystr(arraystr==sprintf('\r'))=[];
end

%%-------------------------------------------------------------------------
function [obj, nextidx,nextdim]=parse2darray(inputstr,startpos,arraystr)
rowend=match_bracket(inputstr,startpos);
rowstr=sscanf_prep(inputstr(startpos-1:rowend));
[vec1, nextdim, errmsg, nextidx]=sscanf(rowstr,'%f,',[1 inf]);
if(nargin==2)
    obj=nextdim;
    return;
end
astr=arraystr;
astr(astr=='[')='';
astr(astr==']')='';
[obj, count, errmsg, nextidx]=sscanf(astr,'%f,',inf);
if(nextidx>=length(astr)-1)
        obj=reshape(obj,nextdim,numel(obj)/nextdim)';
        nextidx=length(arraystr)+1;
end
end