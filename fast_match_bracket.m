function [endpos, maxlevel] = fast_match_bracket(key,pos,startpos,brackets)
if(nargin<4)
    brackets='[]';
end
startpos=find( pos >= startpos, 1 );
count = key(startpos:end);
if(length(count)==1 && count==']')
    endpos=pos(end);
    maxlevel=1;
    return;
end
flag=cumsum(count==brackets(1))-cumsum(count==brackets(2))+1;
endpos = find(flag==0,1);
maxlevel=max([1,max(flag(1:endpos))]);
endpos = pos(endpos + startpos-1);