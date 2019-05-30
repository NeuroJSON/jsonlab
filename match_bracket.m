function [endpos, maxlevel] = match_bracket(str,startpos,brackets)
if(nargin<3)
    brackets='[]';
end
count = str(startpos:end);
flag=cumsum(count==brackets(1))-cumsum(count==brackets(2))+1;
endpos = find(flag==0,1);
maxlevel=max(flag(1:endpos));
endpos = endpos + startpos-1;
