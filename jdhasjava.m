function tf = jdhasjava
%
% tf=jdhasjava
%
% report whether a usable Java runtime is present, caching the answer for
% the rest of the session
%
% author: Qianqian Fang, <q.fang at neu.edu>
%
% output:
%    tf: 1 if Java is available, 0 otherwise
%
% usejava('jvm') is not a cheap predicate -- on Octave it costs roughly half
% a millisecond per call, which is several times the cost of actually
% deflating a small buffer, so calling it once per codec invocation dominates
% the run time of chunked data. Whether a JVM exists cannot change within a
% session, so the answer is cached. Callers must still guard the Java code
% itself: every caller in this toolbox wraps it in try/catch and falls back
% to ZMat or the pure-M path, so a cached answer that later turns out to be
% over-optimistic degrades rather than fails.
%
% -- this function is part of JSONLab toolbox (http://openjdata.org/jsonlab)
%

persistent hasjvm

if (isempty(hasjvm))
    hasjvm = double(usejava('jvm') ~= 0);
end

tf = hasjvm;
