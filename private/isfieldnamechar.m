function tf = isfieldnamechar(str)
% True for characters that are allowed in a fieldname
%
%   TF = ISFIELDNAMECHAR(STR)
%       STR must a row char array and returns a boolean array TF of the
%       same size as STR with true for char that are allowed in a
%       variable name.
%
% See also: ISSTRPROP, ISVARNAME

% ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz
tf = isstrprop(str,'alphanum') | str == '_';
end