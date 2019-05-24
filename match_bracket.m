function [endpos, maxlevel] = match_bracket(str,startpos,brackets)
if(nargin<3)
    brackets='[]';
end
count = str(startpos:end);
flag=cumsum(count==brackets(2))-cumsum(count==brackets(1));
flag=flag-min(flag);
maxlevel=max(flag);
endpos = find(flag==maxlevel,1) + startpos-1;