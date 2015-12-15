function bool = isOctave()
persistent tf
if isempty(tf)
    tf = exist('OCTAVE_VERSION', 'builtin') ~= 0;
end
bool = tf;
end