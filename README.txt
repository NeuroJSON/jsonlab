===============================================================================
=                                 JSONlab                                     =
=           An open-source MATLAB/Octave JSON encoder and decoder             =
===============================================================================

*Copyright (c) 2011,2012  Qianqian Fang <fangq at nmr.mgh.harvard.edu>
*License: BSD or GNU General Public License version 3 (GPL v3), see License*.txt
*Version: 0.9.0 (Rodimus)

-------------------------------------------------------------------------------

Table of Content:

I.  Introduction
II. Installation
III.Using JSONlab
IV. Known Issues and TODOs
V.  Contribution and feedback

-------------------------------------------------------------------------------

I.  Introduction

JSON ([http://www.json.org/ JavaScript Object Notation]) is a highly portable, 
human-readable and "[http://en.wikipedia.org/wiki/JSON fat-free]" text format 
to represent complex and hierarchical data. It is as powerful as 
[http://en.wikipedia.org/wiki/XML XML], but less verbose. JSON format is widely 
used for data-exchange in applications, and is essential for the wild success 
of [http://en.wikipedia.org/wiki/Ajax_(programming) Ajax] and 
[http://en.wikipedia.org/wiki/Web_2.0 Web2.0]. With the fast advance of 
web-based technologies, We envision that JSON will serve as a mainstream 
data-exchange format for scientific research in the future, and
fulfill part of the roles achieved by [http://www.hdfgroup.org/HDF5/whatishdf5.html HDF5].

JSONlab is a free and open-source implementation of a JSON encoder and a 
decoder in the native MATLAB language. It can be used to convert a MATLAB 
data structure (array, struct, cell, struct array and cell array) into 
JSON formatted text, or to decode a JSON file into MATLAB data. JSONlab 
supports both MATLAB and  
[http://www.gnu.org/software/octave/ GNU Octave] (a free MATLAB clone).

-------------------------------------------------------------------------------

II. Installation

The installation of JSONlab is no different than any other simple
MATLAB toolbox. You only need to download/unzip the JSONlab package
to a folder, and add the folder's path to MATLAB/Octave's path list
by using the following command:

    addpath('/path/to/jsonlab');

If you want to add this path permanently, you need to type "pathtool", 
browse to the jsonlab root folder and add to the list, then click "Save".
Then, run "rehash" in MATLAB, and type "which loadjson", if you see an 
output, that means JSONlab is installed for MATLAB/Octave.

-------------------------------------------------------------------------------

III.Using JSONlab

JSONlab provides two functions, loadjson.m -- a MATLAB->JSON decoder, 
and savejson.m -- a MATLAB->JSON encoder. The detailed help info for 
the two functions can be found below:

=== loadjson.m ===
<pre>
  data=loadjson(fname,opt)
     or
  data=loadjson(fname,'param1',value1,'param2',value2,...)
 
  parse a JSON (JavaScript Object Notation) file or string
 
  authors:Qianqian Fang (fangq<at> nmr.mgh.harvard.edu)
             date: 2011/09/09
          Nedialko Krouchev: http://www.mathworks.com/matlabcentral/fileexchange/25713
             date: 2009/11/02
          François Glineur: http://www.mathworks.com/matlabcentral/fileexchange/23393
             date: 2009/03/22
          Joel Feenstra:
          http://www.mathworks.com/matlabcentral/fileexchange/20565
             date: 2008/07/03
 
  $Id: loadjson.m 371 2012-06-20 12:43:06Z fangq $
 
  input:
       fname: input file name, if fname contains "{}" or "[]", fname
              will be interpreted as a JSON string
       opt: a struct to store parsing options, opt can be replaced by 
            a list of ('param',value) pairs. The param string is equivallent
            to a field in opt.
 
  output:
       dat: a cell array, where {...} blocks are converted into cell arrays,
            and [...] are converted to arrays
</pre>

=== savejson.m ===

<pre>
  json=savejson(rootname,obj,filename)
     or
  json=savejson(rootname,obj,opt)
  json=savejson(rootname,obj,'param1',value1,'param2',value2,...)
 
  convert a MATLAB object (cell, struct or array) into a JSON (JavaScript
  Object Notation) string
 
  author: Qianqian Fang (fangq<at> nmr.mgh.harvard.edu)
             created on 2011/09/09
 
  $Id: savejson.m 371 2012-06-20 12:43:06Z fangq $
 
  input:
       rootname: name of the root-object, if set to '', will use variable name
       obj: a MATLAB object (array, cell, cell array, struct, struct array)
       filename: a string for the file name to save the output JSON data
       opt: a struct for additional options, use [] if all use default
         opt can have the following fields (first in [.|.] is the default)
 
         opt.FileName [''|string]: a file name to save the output JSON data
         opt.FloatFormat ['%.10g'|string]: format to show each numeric element
                          of a 1D/2D array;
         opt.ArrayIndent [1|0]: if 1, output explicit data array with
                          precedent indentation; if 0, no indentation
         opt.ArrayToStruct[0|1]: when set to 0, savejson outputs 1D/2D
                          array in JSON array format; if sets to 1, an
                          array will be shown as a struct with fields
                          "_ArrayType_", "_ArraySize_" and "_ArrayData_"; for
                          sparse arrays, the non-zero elements will be
                          saved to _ArrayData_ field in triplet-format i.e.
                          (ix,iy,val) and "_ArrayIsSparse_" will be added
                          with a value of 1; for a complex array, the 
                          _ArrayData_ array will include two columns 
                          (4 for sparse) to record the real and imaginary 
                          parts, and also "_ArrayIsComplex_":1 is added. 
         opt.ParseLogical [0|1]: if this is set to 1, logical array elem
                          will use true/false rather than 1/0.
         opt.NoRowBracket [1|0]: if this is set to 1, arrays with a single
                          numerical element will be shown without a square
                          bracket, unless it is the root object; if 0, square
                          brackets are forced for any numerical arrays.
         opt.ForceRootName [0|1]: when set to 1 and rootname is empty, savejson
                          will use the name of the passed obj variable as the 
                          root object name; if obj is an expression and 
                          does not have a name, 'root' will be used; if this 
                          is set to 0 and rootname is empty, the root level 
                          will be merged down to the lower level.
         opt.Inf ['"$1_Inf_"'|string]: a customized regular expression pattern
                          to represent +/-Inf. The matched pattern is '([-+]*)Inf'
                          and $1 represents the sign. For those who want to use
                          1e999 to represent Inf, they can set opt.Inf to '$11e999'
         opt.NaN ['"_NaN_"'|string]: a customized regular expression pattern
                          to represent NaN
         opt.JSONP [''|string]: to generate a JSONP output (JSON with padding),
                          for example, if opt.JSON='foo', the JSON data is
                          wrapped inside a function call as 'foo(...);'
         opt.UnpackHex [1|0]: conver the 0x[hex code] output by loadjson 
                          back to the string form
         opt can be replaced by a list of ('param',value) pairs. The param 
         string is equivallent to a field in opt.
  output:
       json: a string in the JSON format (see http://json.org)
 
  examples:
       a=struct('node',[1  9  10; 2 1 1.2], 'elem',[9 1;1 2;2 3],...
            'face',[9 01 2; 1 2 3; NaN,Inf,-Inf], 'author','FangQ');
       savejson('mesh',a)
       savejson('',a,'ArrayIndent',0,'FloatFormat','\t%.5g')
</pre>

=== examples ===

Under the "examples" folder, you can find several scripts to demonstrate the
basic utilities of JSONlab. Running the "demo_jsonlab_basic.m" script, you 
will see the conversions from MATLAB data structure to JSON text and backward.
In "jsonlab_selftest.m", we load complex JSON files downloaded from the Internet
and validate the loadjson/savejson functions for regression testing purposes.

Please run these examples and understand how JSONlab works before you use
it to process your data.

-------------------------------------------------------------------------------

IV. Known Issues and TODOs

JSONlab has several known limitations. We are striving to make it more general
and robust. Hopefully in a few future releases, the limitations become less.

Here are the known issues:

# Any high-dimensional cell-array will be converted to a 1D array;
# When processing names containing multi-byte characters, Octave and MATLAB \
can give different field-names; you can use feature('DefaultCharacterSet','latin1') \
in MATLAB to get consistant results
# Can not handle classes.

-------------------------------------------------------------------------------

V. Contribution and feedback

JSONlab is an open-source project. This means you can not only use it and modify
it as you wish, but also you can contribute your changes back to JSONlab so
that everyone else can enjoy the improvement. For anyone who want to contribute,
please download JSONlab source code from it's subversion repository by using the
following command:

 svn co https://iso2mesh.svn.sourceforge.net/svnroot/iso2mesh/trunk/jsonlab jsonlab

You can make changes to the files as needed. Once you are satisfied with your
changes, and ready to share it with others, please cd the root directory of 
JSONlab, and type

 svn diff > yourname_featurename.patch

You then email the .patch file to JSONlab's maintainer, Qianqian Fang, at
the email address shown in the beginning of this file. Qianqian will review 
the changes and commit it to the subversion if they are satisfactory.

We appreciate any suggestions and feedbacks from you. Please use iso2mesh's
mailing list to report any questions you may have with JSONlab:

http://groups.google.com/group/iso2mesh-users?hl=en&pli=1

(Subscription to the mailing list is needed in order to post messages).
