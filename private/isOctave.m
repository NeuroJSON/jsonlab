function bool = isOctave()
bool = exist('OCTAVE_VERSION', 'builtin') ~= 0;
end