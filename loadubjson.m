function data = loadubjson(fname,varargin)
%
% data=loadubjson(fname,opt)
%    or
% data=loadubjson(fname,'param1',value1,'param2',value2,...)
%
% parse a JSON (JavaScript Object Notation) file or string
%
% authors:Qianqian Fang (q.fang <at> neu.edu)
% created on 2013/08/01
%
% $Id$
%
% input:
%      fname: input file name, if fname contains "{}" or "[]", fname
%             will be interpreted as a UBJSON string
%      opt: a struct to store parsing options, opt can be replaced by 
%           a list of ('param',value) pairs - the param string is equivallent
%           to a field in opt. opt can have the following 
%           fields (first in [.|.] is the default)
%
%           opt.SimplifyCell [0|1]: if set to 1, loadubjson will call cell2mat
%                         for each element of the JSON data, and group 
%                         arrays based on the cell2mat rules.
%           opt.IntEndian [B|L]: specify the endianness of the integer fields
%                         in the UBJSON input data. B - Big-Endian format for 
%                         integers (as required in the UBJSON specification); 
%                         L - input integer fields are in Little-Endian order.
%           opt.NameIsString [0|1]: for UBJSON Specification Draft 8 or 
%                         earlier versions (JSONLab 1.0 final or earlier), 
%                         the "name" tag is treated as a string. To load 
%                         these UBJSON data, you need to manually set this 
%                         flag to 1.
%
% output:
%      dat: a cell array, where {...} blocks are converted into cell arrays,
%           and [...] are converted to arrays
%
% examples:
%      obj=struct('string','value','array',[1 2 3]);
%      ubjdata=saveubjson('obj',obj);
%      dat=loadubjson(ubjdata)
%      dat=loadubjson(['examples' filesep 'example1.ubj'])
%      dat=loadubjson(['examples' filesep 'example1.ubj'],'SimplifyCell',1)
%
% license:
%     BSD or GPL version 3, see LICENSE_{BSD,GPLv3}.txt files for details 
%
% -- this function is part of JSONLab toolbox (http://iso2mesh.sf.net/cgi-bin/index.cgi?jsonlab)
%

if(regexp(fname,'[\{\}\]\[]','once'))
   string=fname;
elseif(exist(fname,'file'))
   fid = fopen(fname,'rb');
   string = fread(fid,inf,'uint8=>char')';
   fclose(fid);
else
   error('input file does not exist');
end

pos = 1; inputlen = length(string); inputstr = string;
arraytoken=find(inputstr=='[' | inputstr==']' | inputstr=='"');
jstr=regexprep(inputstr,'\\\\','  ');
escquote=regexp(jstr,'\\"');
arraytoken=sort([arraytoken escquote]);

isoct=exist('OCTAVE_VERSION','builtin');

opt=varargin2struct(varargin{:});
opt.arraytoken_=arraytoken;

[os,maxelem,systemendian]=computer;
opt.flipendian_=(systemendian ~= upper(jsonopt('IntEndian','B',opt)));

jsoncount=1;
while pos <= inputlen
    switch(next_char(inputstr))
        case '{'
            data{jsoncount} = parse_object(inputstr, opt);
        case '['
            data{jsoncount} = parse_array(inputstr, opt);
        otherwise
            error_pos(inputstr, 'Outer level structure must be an object or an array');
    end
    jsoncount=jsoncount+1;
end % while

jsoncount=length(data);
if(jsoncount==1 && iscell(data))
    data=data{1};
end

%%-------------------------------------------------------------------------
%% subfunctions
%%-------------------------------------------------------------------------

    function [data, adv]=parse_block(inputstr, type,count,varargin)
        [cid,len]=elem_info(inputstr, type);
        datastr=inputstr(pos:pos+len*count-1);
        newdata=uint8(datastr);
        id=strfind('iUIlLdD',type);
        if(jsonopt('flipendian_',1,varargin{:}))
            newdata=swapbytes(typecast(newdata,cid));
        end
        data=typecast(newdata,cid);
        adv=double(len*count);
    end
    %%-------------------------------------------------------------------------

    function object = parse_array(inputstr, varargin) % JSON array is written in row-major order
        parse_char(inputstr, '[');
        object = cell(0, 1);
        dim=[];
        type='';
        count=-1;
        if(next_char(inputstr) == '$')
            type=inputstr(pos+1);
            pos=pos+2;
        end
        if(next_char(inputstr) == '#')
            pos=pos+1;
            if(next_char(inputstr)=='[')
                dim=parse_array(inputstr, varargin{:});
                count=prod(double(dim));
            else
                count=double(parse_number(inputstr,varargin{:}));
            end
        end
        if(~isempty(type))
            if(count>=0)
                [object, adv]=parse_block(inputstr, type,count,varargin{:});
                if(~isempty(dim))
                    object=reshape(object,dim);
                end
                pos=pos+adv;
                return;
            else
                endpos=match_bracket(inputstr,pos);
                [cid,len]=elem_info(inputstr, type);
                count=(endpos-pos)/len;
                [object, adv]=parse_block(inputstr, type,count,varargin{:});
                pos=pos+adv;
                parse_char(inputstr, ']');
                return;
            end
        end
        if next_char(inputstr) ~= ']'
             while 1
                val = parse_value(inputstr, varargin{:});
                object{end+1} = val;
                if next_char(inputstr) == ']'
                    break;
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
        if(count==-1)
            parse_char(inputstr, ']');
        end
    end

    %%-------------------------------------------------------------------------

    function parse_char(inputstr, c)
        skip_whitespace(inputstr);
        if pos > length(inputstr) || inputstr(pos) ~= c
            error_pos(inputstr, sprintf('Expected %c at position %%d', c));
        else
            pos = pos + 1;
            skip_whitespace(inputstr);
        end
    end

    %%-------------------------------------------------------------------------

    function c = next_char(inputstr)
        skip_whitespace(inputstr);
        if pos > length(inputstr)
            c = [];
        else
            c = inputstr(pos);
        end
    end

    %%-------------------------------------------------------------------------

    function skip_whitespace(inputstr)
        while pos <= length(inputstr) && isspace(inputstr(pos))
            pos = pos + 1;
        end
    end

    %%-------------------------------------------------------------------------
    function str = parse_name(inputstr, varargin)
        bytelen=double(parse_number(inputstr,varargin{:}));
        if(length(inputstr)>=pos+bytelen-1)
            str=inputstr(pos:pos+bytelen-1);
            pos=pos+bytelen;
        else
            error_pos(inputstr, 'End of file while expecting end of name');
        end
    end

    %%-------------------------------------------------------------------------

    function str = parseStr(inputstr, varargin)
        type=inputstr(pos);
        if type ~= 'S' && type ~= 'C' && type ~= 'H'
            error_pos('String starting with S expected at position %d');
        else
            pos = pos + 1;
        end
        if(type == 'C')
            str=inputstr(pos);
            pos=pos+1;
            return;
        end
        bytelen=double(parse_number(inputstr,varargin{:}));
        if(length(inputstr)>=pos+bytelen-1)
            str=inputstr(pos:pos+bytelen-1);
            pos=pos+bytelen;
        else
            error_pos(inputstr, 'End of file while expecting end of inputstr');
        end
    end

    %%-------------------------------------------------------------------------

    function num = parse_number(inputstr, varargin)
        id=strfind('iUIlLdD',inputstr(pos));
        if(isempty(id))
            error_pos(inputstr, 'expecting a number at position %d');
        end
        type={'int8','uint8','int16','int32','int64','single','double'};
        bytelen=[1,1,2,4,8,4,8];
        datastr=inputstr(pos+1:pos+bytelen(id));
        newdata=uint8(datastr);
        if(jsonopt('flipendian_',1,varargin{:}))
            newdata=swapbytes(typecast(newdata,type{id}));
        end
        num=typecast(newdata,type{id});
        pos = pos + bytelen(id)+1;
    end

    %%-------------------------------------------------------------------------

    function val = parse_value(inputstr, varargin)
        switch(inputstr(pos))
            case {'S','C','H'}
                val = parseStr(inputstr, varargin{:});
                return;
            case '['
                val = parse_array(inputstr, varargin{:});
                return;
            case '{'
                val = parse_object(inputstr, varargin{:});
                return;
            case {'i','U','I','l','L','d','D'}
                val = parse_number(inputstr, varargin{:});
                return;
            case 'T'
                val = true;
                pos = pos + 1;
                return;
            case 'F'
                val = false;
                pos = pos + 1;
                return;
            case {'Z','N'}
                val = [];
                pos = pos + 1;
                return;
        end
        error_pos(inputstr, 'Value expected at position %d');
    end
    %%-------------------------------------------------------------------------

    function error_pos(inputstr, msg)
        poShow = max(min([pos-15 pos-1 pos pos+20],length(inputstr)),1);
        if poShow(3) == poShow(2)
            poShow(3:4) = poShow(2)+[0 -1];  % display nothing after
        end
        msg = [sprintf(msg, pos) ': ' ...
        inputstr(poShow(1):poShow(2)) '<error>' inputstr(poShow(3):poShow(4)) ];
        error( ['JSONparser:invalidFormat: ' msg] );
    end

    %%-------------------------------------------------------------------------
    function object = parse_object(inputstr, varargin)
        parse_char(inputstr,'{');
        object = [];
        type='';
        count=-1;
        if(next_char(inputstr) == '$')
            type=inputstr(pos+1); % TODO
            pos=pos+2;
        end
        if(next_char(inputstr) == '#')
            pos=pos+1;
            count=double(parse_number(inputstr,varargin{:}));
        end
        if next_char(inputstr) ~= '}'
            num=0;
            while 1
                if(jsonopt('NameIsString',0,varargin{:}))
                    str = parseStr(inputstr, varargin{:});
                else
                    str = parse_name(inputstr, varargin{:});
                end
                if isempty(str)
                    error_pos(inputstr, 'Name of value at position %d cannot be empty');
                end
                val = parse_value(inputstr, varargin{:});
                num=num+1;
                object.(valid_field(str,varargin{:}))=val;
                if next_char(inputstr) == '}' || (count>=0 && num>=count)
                    break;
                end
            end
        end
        if(count==-1)
            parse_char(inputstr, '}');
        end
        if(isstruct(object))
            object=struct2jdata(object,struct('Recursive',0, 'Base64',0));
        end
    end

    %%-------------------------------------------------------------------------
    function [cid,len]=elem_info(inputstr, type)
        id=strfind('iUIlLdD',type);
        dataclass={'int8','uint8','int16','int32','int64','single','double'};
        bytelen=[1,1,2,4,8,4,8];
        if(id>0)
            cid=dataclass{id};
            len=bytelen(id);
        else
            error_pos(inputstr, 'unsupported type at position %d');
        end
    end
    %%-------------------------------------------------------------------------

    function str = valid_field(str,varargin)
    % From MATLAB doc: field names must begin with a letter, which may be
    % followed by any combination of letters, digits, and underscores.
    % Invalid characters will be converted to underscores, and the prefix
    % "x0x[Hex code]_" will be added if the first character is not a letter.
        cpos=regexp(str,'^[^A-Za-z]','once');
        if(~isempty(cpos))
            if(~isoct)
                str=regexprep(str,'^([^A-Za-z])','x0x${sprintf(''%X'',unicode2native($1))}_','once');
            else
                str=sprintf('x0x%X_%s',char(str(1)),str(2:end));
            end
        end
        if(isempty(regexp(str,'[^0-9A-Za-z_]', 'once' )))
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

