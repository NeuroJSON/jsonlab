function [dims,maxlevel, count] = nestbracket2dim(str,brackets)
if(nargin<2)
    brackets='[]';
end
str=str(str==brackets(1) | str==brackets(2) | str==',');
count=cumsum(str==brackets(1)) - cumsum(str==brackets(2));
maxlevel=max(count);
dims=histc(count,1:maxlevel);
dims(1:end-1)=dims(1:end-1)*0.5;
dims(2:end)=dims(2:end)./dims(1:end-1);
dims=fliplr(dims);