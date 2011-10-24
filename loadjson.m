function data = loadjson(fname)
%
% data=loadjson(fname)
%
% parse a JSON (JavaScript Object Notation) file or string
%
% authors:Qianqian Fang (fangq<at> nmr.mgh.harvard.edu)
%            date: 2011/09/09
%         Nedialko Krouchev: http://www.mathworks.com/matlabcentral/fileexchange/25713
%            date: 2009/11/02
%         François Glineur: http://www.mathworks.com/matlabcentral/fileexchange/23393
%            date: 2009/03/22
%         Joel Feenstra: http://www.mathworks.com/matlabcentral/fileexchange/20565
%            date: 2008/07/03
%
% input:
%      fname: input file name, if fname contains "{}" or "[]", fname
%      will be interpreted as a JSON string
%
% output:
%      dat: a cell array, where {...} blocks are converted into cell arrays,
%           and [...] are converted to arrays
%
% license:
%     BSD or GPL version 3, see LICENSE_{BSD,GPLv3}.txt files for details 
%
% -- this function is part of jsonlab toolbox (http://iso2mesh.sf.net/cgi-bin/index.cgi?jsonlab)
%

global pos inStr len  esc index_esc len_esc isoct arraytoken

if(regexp(fname,'[\{\}\]\[]','once'))
   string=fname;
elseif(exist(fname,'file'))
   fid = fopen(fname,'rt');
   string = fscanf(fid,'%c');
   fclose(fid);
else
   error('input file does not exist');
end

pos = 1; len = length(string); inStr = string;
isoct=exist('OCTAVE_VERSION');
arraytoken=find(inStr=='[' | inStr==']' | inStr=='"');

% String delimiters and escape chars identified to improve speed:
esc = find(inStr=='"' | inStr=='\' ); % comparable to: regexp(inStr, '["\\]');
index_esc = 1; len_esc = length(esc);

jsoncount=1;
while pos <= len
    switch(next_char)
        case '{'
            data{jsoncount} = parse_object;
        case '['
            data{jsoncount} = parse_array;
        otherwise
            error_pos('Outer level structure must be an object or an array');
    end
    jsoncount=jsoncount+1;
end % while

jsoncount=length(data);
if(jsoncount==1 && iscell(data))
    data=data{1};
end
if(jsoncount==1 && isstruct(data))
    data=jstruct2array(data);
else
    if(~isempty(data))
      for i=1:jsoncount
        if(isstruct(data(i)))
            data(i)=jstruct2array(data(i));
        end
      end
    end
end

%%
function newdata=parse_collection(id,data,obj)

if(jsoncount>0 && exist('data','var')) 
    if(~iscell(data))
       newdata=cell(1);
       newdata{1}=data;
       data=newdata;
    end
end



%%-------------------------------------------------------------------------
function newdata=jstruct2array(data)
fn=fieldnames(data);
newdata=data;
for i=1:length(fn) % depth-first
    if(isstruct(getfield(data,fn{i})))
        newdata=setfield(newdata,fn{i},jstruct2array(getfield(data,fn{i})));
    end
end
if(~isempty(strmatch('x_ArrayType_',fn)) && ~isempty(strmatch('x_ArrayData_',fn)))
    newdata=cast(data.x_ArrayData_,data.x_ArrayType_);
    iscpx=0;
    if(~isempty(strmatch('x_ArrayIsComplex_',fn)))
        if(data.x_ArrayIsComplex_)
           iscpx=1;
        end
    end
    if(~isempty(strmatch('x_ArrayIsSparse_',fn)))
        if(data.x_ArrayIsSparse_)
            if(iscpx && size(newdata,2)==4)
                newdata(:,3)=complex(newdata(:,3),newdata(:,4));
            end
            if(~isempty(strmatch('x_ArraySize_',fn)))
                dim=data.x_ArraySize_;
                newdata=sparse(newdata(:,1),newdata(:,2),newdata(:,3),dim(1),prod(dim(2:end)));
            else
                newdata=sparse(newdata(:,1),newdata(:,2),newdata(:,3));
            end
        end
    elseif(~isempty(strmatch('x_ArraySize_',fn)))
        if(iscpx && size(newdata,2)==2)
             newdata=complex(newdata(:,1),newdata(:,2));
        end
        newdata=reshape(newdata(:),data.x_ArraySize_);
    end
end

%%-------------------------------------------------------------------------
function object = parse_object
    parse_char('{');
    object = [];
    if next_char ~= '}'
        while 1
            str = parseStr;
            if isempty(str)
                error_pos('Name of value at position %d cannot be empty');
            end
            parse_char(':');
            val = parse_value;
            eval( sprintf( 'object.%s  = val;', valid_field(str) ) );
            if next_char == '}'
                break;
            end
            parse_char(',');
        end
    end
    parse_char('}');

%%-------------------------------------------------------------------------

function object = parse_array % JSON array is written in row-major order
global pos inStr isoct
    parse_char('[');
    object = cell(0, 1);
    if next_char ~= ']'
        endpos=matching_bracket(inStr,pos);
        arraystr=['[' inStr(pos:endpos)];
        arraystr(find(arraystr==sprintf('\n')))=[];
        arraystr(find(arraystr==sprintf('\r')))=[];
        arraystr=regexprep(arraystr,'\]\s*,','];');
        arraystr=regexprep(arraystr,'"_NaN_"','NaN');
        arraystr=regexprep(arraystr,'"([-+]*)_Inf_"','$1Inf');
        try
           if(isoct && regexp(arraystr,'"','once'))
                error('Octave eval can produce empty cells for JSON-like input');
           end
           object=eval(arraystr);
           pos=endpos;
        catch
         while 1
            val = parse_value;
            object{end+1} = val;
            if next_char == ']'
                break;
            end
            parse_char(',');
         end
        end
    end
    try
        object=cell2mat(object')';
        if(size(object,1)>1 && ndims(object)==2)
            object=object';
        end
    catch
    end
    parse_char(']');

%%-------------------------------------------------------------------------

function parse_char(c)
    global pos inStr len
    skip_whitespace;
    if pos > len || inStr(pos) ~= c
        error_pos(sprintf('Expected %c at position %%d', c));
    else
        pos = pos + 1;
        skip_whitespace;
    end

%%-------------------------------------------------------------------------

function c = next_char
    global pos inStr len
    skip_whitespace;
    if pos > len
        c = [];
    else
        c = inStr(pos);
    end

%%-------------------------------------------------------------------------

function skip_whitespace
    global pos inStr len
    while pos <= len && isspace(inStr(pos))
        pos = pos + 1;
    end

%%-------------------------------------------------------------------------
function str = parseStr
    global pos inStr len  esc index_esc len_esc
 % len, ns = length(inStr), keyboard
    if inStr(pos) ~= '"'
        error_pos('String starting with " expected at position %d');
    else
        pos = pos + 1;
    end
    str = '';
    while pos <= len
        while index_esc <= len_esc && esc(index_esc) < pos
            index_esc = index_esc + 1;
        end
        if index_esc > len_esc
            str = [str inStr(pos:len)];
            pos = len + 1;
            break;
        else
            str = [str inStr(pos:esc(index_esc)-1)];
            pos = esc(index_esc);
        end
        nstr = length(str); switch inStr(pos)
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
                if pos+1 > len
                    error_pos('End of file reached right after escape character');
                end
                pos = pos + 1;
                switch inStr(pos)
                    case {'"' '\' '/'}
                        str(nstr+1) = inStr(pos);
                        pos = pos + 1;
                    case {'b' 'f' 'n' 'r' 't'}
                        str(nstr+1) = sprintf(['\' inStr(pos)]);
                        pos = pos + 1;
                    case 'u'
                        if pos+4 > len
                            error_pos('End of file reached in escaped unicode character');
                        end
                        str(nstr+(1:6)) = inStr(pos-1:pos+4);
                        pos = pos + 5;
                end
            otherwise % should never happen
                str(nstr+1) = inStr(pos), keyboard
                pos = pos + 1;
        end
    end
    error_pos('End of file while expecting end of inStr');

%%-------------------------------------------------------------------------

function num = parse_number
    global pos inStr len isoct
    currstr=inStr(pos:end);
    numstr=0;
    if(isoct~=0)
        numstr=regexp(currstr,'^\s*-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+\-]?\d+)?','end');
        [num, one] = sscanf(currstr, '%f', 1);
        delta=numstr+1;
    else
        [num, one, err, delta] = sscanf(currstr, '%f', 1);
        if ~isempty(err)
            error_pos('Error reading number at position %d');
        end
    end
    pos = pos + delta-1;

%%-------------------------------------------------------------------------

function val = parse_value
    global pos inStr len
    true = 1; false = 0;

    switch(inStr(pos))
        case '"'
            val = parseStr;
            return;
        case '['
            val = parse_array;
            return;
        case '{'
            val = parse_object;
            return;
        case {'-','0','1','2','3','4','5','6','7','8','9'}
            val = parse_number;
            return;
        case 't'
            if pos+3 <= len && strcmpi(inStr(pos:pos+3), 'true')
                val = true;
                pos = pos + 4;
                return;
            end
        case 'f'
            if pos+4 <= len && strcmpi(inStr(pos:pos+4), 'false')
                val = false;
                pos = pos + 5;
                return;
            end
        case 'n'
            if pos+3 <= len && strcmpi(inStr(pos:pos+3), 'null')
                val = [];
                pos = pos + 4;
                return;
            end
    end
    error_pos('Value expected at position %d');
%%-------------------------------------------------------------------------

function error_pos(msg)
    global pos inStr len
    poShow = max(min([pos-15 pos-1 pos pos+20],len),1);
    if poShow(3) == poShow(2)
        poShow(3:4) = poShow(2)+[0 -1];  % display nothing after
    end
    msg = [sprintf(msg, pos) ': ' ...
    inStr(poShow(1):poShow(2)) '<error>' inStr(poShow(3):poShow(4)) ];
    error( ['JSONparser:invalidFormat: ' msg] );

%%-------------------------------------------------------------------------

function str = valid_field(str)
global isoct
% From MATLAB doc: field names must begin with a letter, which may be
% followed by any combination of letters, digits, and underscores.
% Invalid characters will be converted to underscores, and the prefix
% "x_" will be added if first character is not a letter.
    if ~isletter(str(1)) || str(1)>'z'
        str = ['x' str];
    end
    if(isempty(regexp(str,'[^0-9A-Za-z_]', 'once' ))) return;  end
    if(~isoct)
        str=regexprep(str,'([^0-9A-Za-z_])','_0x${sprintf(''%X'',unicode2native($1))}_');
    else
        pos=regexp(str,'[^0-9A-Za-z_]');
        if(isempty(pos)) return; end
        str0=str;
        pos0=[0 pos(:)' length(str)];
        str='';
        for i=1:length(pos)
            str=[str str0(pos0(i)+1:pos(i)-1) sprintf('_0x%X_',str0(pos(i)))];
        end
        if(pos(end)~=length(str))
            str=[str str0(pos0(end-1)+1:pos0(end))];
        end
    end
    %str(~isletter(str) & ~('0' <= str & str <= '9')) = '_';

%%-------------------------------------------------------------------------
function endpos = matching_quote(str,pos)
len=length(str);
while(pos<len)
    if(str(pos)=='"')
        if(~(pos>1 && str(pos-1)=='\'))
            endpos=pos;
            return;
        end        
    end
    pos=pos+1;
end

%%-------------------------------------------------------------------------
function endpos = matching_bracket(str,pos)
global arraytoken
level=1;
endpos=0;
bpos=arraytoken(arraytoken>=pos);
tokens=str(bpos);
len=length(tokens);
pos=1;
while(pos<=len)
    c=tokens(pos);
    if(c==']')
        level=level-1;
        if(level==0)
            endpos=bpos(pos);
            return
        end
    end
    if(c=='[')
        level=level+1;
    end
    if(c=='"')
        pos=matching_quote(tokens,pos+1);
    end
    pos=pos+1;
end
if(endpos==0) 
    error('unmatched "]"');
end

