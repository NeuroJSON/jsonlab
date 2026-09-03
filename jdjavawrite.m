function jdjavawrite(stream, bytes)
%
% jdjavawrite(stream,bytes)
%
% write a byte buffer to a Java OutputStream, in bulk when the Java bridge
% supports it, one byte at a time when it does not
%
% author: Qianqian Fang, <q.fang at neu.edu>
%
% input:
%    stream: a Java object derived from java.io.OutputStream
%    bytes: a numeric or char array; it is flattened and cast to uint8
%
% Writing a whole buffer in one call is orders of magnitude faster than
% looping over single bytes, because each Java method call from
% MATLAB/Octave costs a full JNI round trip. Older Java bridges could not
% marshal a MATLAB array into a Java byte[], which is why the byte-at-a-time
% loop existed; rather than tie the choice to an interpreter version, the
% capability is probed once per session and cached.
%
% -- this function is part of JSONLab toolbox (http://openjdata.org/jsonlab)
%

persistent bulkmode

if (isempty(bulkmode))
    bulkmode = jdjavabulkmode;
end

if (ischar(bytes))
    bytes = uint8(bytes);
else
    bytes = typecast(bytes(:).', 'uint8');
end

len = numel(bytes);
if (len == 0)
    return
end

% A one-element array marshals to a Java scalar byte rather than a byte[],
% so write(byte[],int,int) does not resolve and the bulk call is guaranteed
% to fail; go straight to the single-byte write instead of raising.
if (bulkmode > 0 && len > 1)
    try
        if (bulkmode == 1)
            stream.write(typecast(bytes, 'int8'), 0, len);
        else
            stream.write(bytes, 0, len);
        end
        return
    catch
        % Fall back for this call only. The probe already proved the bridge
        % can marshal a byte[], so a failure here is a property of this
        % stream or this input shape, not a lost capability -- clearing the
        % cache would silently drop every later call to the slow path.
    end
end

for i = 1:len
    stream.write(int32(bytes(i)));
end

%% -------------------------------------------------------------------------
function mode = jdjavabulkmode
%
% probe how, if at all, this Java bridge marshals an array into a byte[]
%
% output:
%    mode: 1 if int8 arrays are accepted, 2 if uint8 arrays are accepted,
%          0 if neither works and the caller must write byte by byte
%
probe = uint8([7, 0, 255]);
mode = 0;

for trymode = [1, 2]
    try
        baos = javaObject('java.io.ByteArrayOutputStream');
        if (trymode == 1)
            baos.write(typecast(probe, 'int8'), 0, 3);
        else
            baos.write(probe, 0, 3);
        end
        readback = typecast(baos.toByteArray(), 'uint8');
        if (isequal(readback(:).', probe))
            mode = trymode;
            return
        end
    catch
        % this marshalling form is unavailable; try the next
    end
end
