function bytes = jdjavaread(stream)
%
% bytes=jdjavaread(stream)
%
% read a Java InputStream to its end and return the contents as a uint8 row
% vector, in bulk when the Java runtime supports it, one byte at a time when
% it does not
%
% author: Qianqian Fang, <q.fang at neu.edu>
%
% input:
%    stream: a Java object derived from java.io.InputStream
%
% output:
%    bytes: a uint8 row vector holding everything the stream produced
%
% This is the counterpart of jdjavawrite for the cases where no
% OutputStream-shaped decompressor exists (gzip), so the payload must be
% pulled out of an InputStream. InputStream.transferTo arrived in Java 9;
% Apache commons-io ships with MATLAB and is the next best thing; the byte
% loop is the last resort. The working tier is probed once and cached.
%
% -- this function is part of JSONLab toolbox (http://openjdata.org/jsonlab)
%

persistent readmode

baos = javaObject('java.io.ByteArrayOutputStream');

if (isempty(readmode))
    readmode = 0;
end

% tier 1: InputStream.transferTo, Java 9 and newer
if (readmode == 0 || readmode == 1)
    try
        stream.transferTo(baos);
        readmode = 1;
        bytes = jdjavabytes(baos);
        return
    catch
        if (readmode == 1)
            readmode = 0;
        end
    end
end

% tier 2: org.apache.commons.io, bundled with MATLAB
if (readmode == 0 || readmode == 2)
    try
        javaMethod('copy', 'org.apache.commons.io.IOUtils', stream, baos);
        readmode = 2;
        bytes = jdjavabytes(baos);
        return
    catch
        if (readmode == 2)
            readmode = 0;
        end
    end
end

% tier 3: one byte at a time
readmode = 3;
onebyte = stream.read();
while (onebyte >= 0)
    baos.write(onebyte);
    onebyte = stream.read();
end
bytes = jdjavabytes(baos);

%% -------------------------------------------------------------------------
function bytes = jdjavabytes(baos)
%
% convert a java.io.ByteArrayOutputStream to a uint8 row vector
%
raw = baos.toByteArray();
if (isempty(raw))
    bytes = uint8([]);
else
    bytes = typecast(raw, 'uint8');
    bytes = bytes(:).';
end
