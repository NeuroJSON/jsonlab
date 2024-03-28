.. image:: https://neurojson.org/wiki/upload/neurojson_banner_long.png

########################################################################################
 JSONLab: compact, portable, robust JSON/binary-JSON encoder/decoder for MATLAB/Octave
########################################################################################

* Copyright (c) 2011-2024  Qianqian Fang <q.fang at neu.edu>
* License: BSD or GNU General Public License version 3 (GPL v3), see License*.txt
* Version: 2.9.8 (Micronus Prime - Beta)
* URL: https://neurojson.org/jsonlab
* User forum: https://github.com/orgs/NeuroJSON/discussions/categories/neurojson-json-format-specifications-and-parsers
* JData Specification Version: V1 Draft-3 (https://neurojson.org/jdata/draft3)
* Binary JData Specification Version: V1 Draft-2 (https://neurojson.org/bjdata/draft2)
* JSON-Mmap Specification Version: V1 Draft-1 (https://neurojson.org/jsonmmap/draft1)
* Compatibility: MATLAB R2008 or newer, GNU Octave 3.8 or newer
* Acknowledgement: This project is supported by US National Institute of Health (NIH) 
  grant `U24-NS124027 <https://reporter.nih.gov/project-details/10308329>`_

.. image:: https://github.com/fangq/jsonlab/actions/workflows/run_test.yml/badge.svg
    :target: https://github.com/fangq/jsonlab/actions/workflows/run_test.yml

#################
Table of Contents
#################
.. contents::
  :local:
  :depth: 3

============
What's New
============

We are excited to announce that the JSONLab project, as the official reference library
for both `JData <https://neurojson.org/jdata/draft3>`_ and `BJData <https://neurojson.org/bjdata/draft2>`_
specifications, has been funded by the US National Institute of Health (NIH) as
part of the NeuroJSON project (https://neurojson.org and https://neurojson.io).

The goal of the NeuroJSON project is to develop scalable, searchable, and
reusable neuroimaging data formats and data sharing platforms. All data
produced from the NeuroJSON project will be using JSON/Binary JData formats as the
underlying serialization standards and the lightweight JData specification as
language-independent data annotation standard, all of which have been evolved 
from the over a decade development of JSONLab.

JSONLab v2.9.8 - code named "Micronus Prime - beta" - is the beta-release of the next milestone (v3.0),
containing a number of key feature enhancements and bug fixes. The major
new features include

1. exporting JSON Memory-Map (``jsonget,jsonset``) for rapid disk-map like reading/writing of JSON/binary JSON files
   and writing, implementing `JSON-Mmap spec v1 Draft 1 <https://github.com/NeuroJSON/jsonmmap>`_
2. supporting JSONPath query (``jsonpath``) to MATLAB data and JSON/binary JSON file and streams, including
   deep-scan operators,
3. (**breaking**) upgrading the supported BJData spec to `V1 Draft 2 <https://neurojson.org/bjdata/draft2>`_
   where the default numerical data byte order changed from Big-Endian to **Little-Endian**,
4. adding initial support to JData `_DataLink_ <https://github.com/NeuroJSON/jdata/blob/master/JData_specification.md#data-referencing-and-links>`_ 
   decoding to link multiple JSON/binary JSON files
5. dynamically cache linked data files (``jsoncache``, ``jdlink``) to permit on-demand download and 
   processing of complex JSON-encoded datasets such as neuroimaging datasets hosted on https://neurojson.io
6. support high-performance Blosc2 meta-compressor for storing large N-D array data,
7. ``savejson/loadjson`` can use MATLAB/Octave built-in ``jsonencode/jsondecode`` using the ``BuiltinJSON`` option
8. automatically switch from ``struct`` to ``containers.Map`` when encoded key-length exceeds 63
9. provide fall-back zlib/gzip compression/decompression function (``octavezmat``) on Octave when ZMat is not installed
10. include built-in ``.nii/.nii.gz/.jnii/.h5/.snirf/.tsv/.csv`` parsers to allow loadjd.m to read wide range of files
11. include ``json2couch`` from jbids (https://github.com/NeuroJSON/jbids) to allow uploading json files to CouchDB server

There have been many major updates added to this release since the previous 
release v2.0 in June 2020. A list of the major changes are summarized below
(with key features marked by \*), including the support to BJData Draft-2 specification,
new interface functions ``savejd/loadjd``, and options to use MATLAB/Octave built-in
``jsonencode/jsondecode`` functions. The ``octave-jsonlab`` package has also been
included in the official distributions of Debian Bullseye and Ubuntu 21.04 or newer.

- 2024-03-28 [b39c374] [feat] add json2couch from jbids toolbox
- 2024-03-27*[2e43586] [feat] merge ``nii/jnii/hdf5/tsv`` reading functions self-contained
- 2024-03-27 [b482c8f] [test] pass all tests on matlab R2010b
- 2024-03-27 [2008934] [doc] additional documentations on decompression functions
- 2024-03-27 [0a582fb] [doc] add documentations for jsonpath, jsoncache, jdlink, and maxlinklevel
- 2024-03-27 [5dba1de] [bug] ``..`` searches deep level of struct, make jdlink work for Octave 4.2 and 5.2
- 2024-03-27 [fea481e] [doc] add line-by-line comment on examples, add ``jsonset/jsonget``
- 2024-03-26 [e1d386d] [feat] support saving dictionary to json and bjdata
- 2024-03-26 [dfc744b] [feat] support caching data from any URL using hash, add ``NO_ZMAT`` flag
- 2024-03-24 [22d297e] [doc] fix README.rst formatting issues
- 2024-03-24 [7e27db5] [doc] update documentation, preparing for v2.9.8 release
- 2024-03-24 [1227a0b] [format] reformat
- 2024-03-24 [67f30ca] [feat] support using \. or [] in JSONPath to escape dots in key names
- 2024-03-24 [ee830cd] [bug] fix error_pos error when giving a non-existant input file
- 2024-03-24 [d69686d] [feat] add jdlink to dynamically download and cache linked data
- 2024-03-22 [772a1ef] [ci] fix octave failed test
- 2024-03-22*[cff529a] [test] add jsonpath test, refine jsonpath syntax support
- 2024-03-22 [22435e4] [bug] fix jsonpath handling of recursive deep scans
- 2024-03-21 [c9f8a20] [bug] support deep scan in cell and struct, merge struct/containers.Map
- 2024-03-21 [394394a] [bug] improve jsonpath cell with deep scan
- 2024-03-20 [a599e71] [feat] add jsoncache to handle ``_DataLink_`` download cache, rename jsonpath
- 2024-02-19*[4f2edeb] [feat] support .. jsonpath operator for deep scan
- 2024-01-11 [c43a758] [bug] fix missing index_esc reset, add test for automap
- 2024-01-11*[ef5b472] [feat] automatically switch to map object when key length > 63
- 2023-11-17 [ee24122] use sprintf to replace unescapejsonstring
- 2023-11-12 [abe504f] [ci] test again on macos-12
- 2023-11-12 [d2ff26a] [ci] install octave via conda on macos to avoid hanged install
- 2023-11-07 [33263de] completely reformat m-files using miss_hit
- 2023-11-07 [3ff781f] make octavezmat work on matlab
- 2023-10-29 [ea4a4fd] make test script run on MATLAB R2010b
- 2023-10-27 [ca91e07] use older matlab due to matlab-actions/run-command#43
- 2023-10-27 [4bf8232] add NO_ZMAT flag, fix fread issue
- 2023-10-27*[ce3c0a0] add fallback zlib/glib support on Octave via file-based zip/unzip
- 2023-10-26 [7ab1b6e] fix error for expecting an ending object mark when count is given
- 2023-09-08 [6dfa58e] Fix typos found by codespell
- 2023-06-27 [7d7e7f7] fix typo of compression method
- 2023-06-27*[c25dd0f] support blosc2 codecs in save and load data, upgrade jsave/jload
- 2023-06-19 [b23181a] test root-level indentation
- 2023-06-19 [5bfde65] add indentation test
- 2023-06-19 [b267858] fix CI errors related to octave utf-8 handling
- 2023-06-19 [1e93d07] avoid octave 6.4+ regexp non-utf8 error see discussions at octave bug thread: https://savannah.gnu.org/bugs/index.php?57107
- 2023-06-15 [8f921ac] fix broken tests
- 2023-06-11*[6cb5f12] allow linking binary jdata files inside json
- 2023-06-10 [2d0649b] do not compress long string by default, read bjd from URI
- 2023-06-10 [5135dea] saving JSON with UTF-8 encoding, fix #71
- 2023-06-10*[a3c807f] add zstdencode and zstddecode via new version of zmat
- 2023-06-07 [837c8b5] fix containers.Map indentiation bug with a single element
- 2023-06-07 [747c99b] fix string indentation, add option EmptyArrayAsNull, fix #91
- 2023-06-05*[cf57326] support blosc2 meta compressors
- 2023-05-05 [d37a386] use {:} to expand varargin
- 2023-04-23 [03311d2] remove README.txt, no longer used, fix #88
- 2023-04-21 [49eceb0] Fix typo not found by codespell
- 2023-04-21 [75b1fdc] Fix typos found by codespell
- 2023-04-17 [8fea393] revert savejson change
- 2023-04-17 [9554a44] Merge branch 'master' of github.com:fangq/jsonlab
- 2023-04-17 [3c32aff] speed up string encoding and decoding
- 2023-04-09*[8c8464f] rename jamm files to pmat - portable mat, will add jsonmmap
- 2023-04-09 [aa1c2a4] drop ubuntu-18.04
- 2023-04-08 [9173525] replace regexp to ismember due to octave bug 57107; test mac
- 2023-04-08 [67065dc] fix matlab test
- 2023-04-08 [8dcedad] use alternative test to avoid octave bug 57107
- 2023-04-08*[9b6be7b] add github action based tests
- 2023-02-24 [cb43ed1] add bug fix test section
- 2023-02-24 [2412ebf] only simplify all-numeric or all-struct cells
- 2023-02-23 [d4e77e1] add missing file extension
- 2023-02-23 [408cc2e] fix loadjd and savejd file extension match, add jbids
- 2023-02-22 [29bac9d] fix broken jdatahash
- 2023-02-22*[69a7d01] add a portable data hash function
- 2023-02-09 [0448eb1] preventing matlab 2022b converting string to unicode
- 2022-11-21 [9ce91fc] handle empty struct with names, fix #85
- 2022-11-20 [9687d17] accept string typed file name, close #84
- 2022-08-12 [283e5f1] output data depends on nargout
- 2022-08-08 [c729048] avoid conjugating complex numbers, fix #83
- 2022-06-05*[fa35843] implementing JSON-Mmap spec draft 1, https://neurojson.org/jsonmmap/draft1
- 2022-05-18 [8b74d30] make savejd work for saveh5 to save hdf5 files
- 2022-04-19 [f1332e3] make banner image transparent background
- 2022-04-19 [6cf82a6] fix issues found by dependency check
- 2022-04-19 [94167bb] change neurojson urls to https
- 2022-04-19 [c4c4da1] create Contents.m from matlab
- 2022-04-19*[2278bb1] stop escaping / to \/ in JSON string, see https://mondotondo.com/2010/12/29/the-solidus-issue/
- 2022-04-01*[fb711bb] add loadjd and savejd as the unified JSON/binary JSON file interface
- 2022-03-30 [4433a21] improve datalink uri handling to consider : inside uri
- 2022-03-30 [6368409] make datalink URL query more robust
- 2022-03-29 [dd9e9c6] when file suffix is missing, assume JSON feed
- 2022-03-29*[07c58f3] initial support for ``_DataLink_`` of online/local file with JSONPath ref
- 2022-03-29 [897b7ba] fix test for older octave
- 2022-03-20 [bf03eff] force msgpack to use big-endian
- 2022-03-13 [46bbfa9] support empty name key, which is valid in JSON, fix #79
- 2022-03-12 [9ab040a] increase default float number digits from 10 to 16, fix #78
- 2022-03-11 [485ea29] update error message on the valid root-level markers
- 2022-02-23 [aa3913e] disable TFN marker in optimized header due to security risk and low benefit
- 2022-02-23 [f2c3223] support SCH{[ markers in optimized container type
- 2022-02-14 [540f95c] add optional preceding whitespace, explain format
- 2022-02-13 [3dfa904] debugged and tested mmap, add mmapinclude and mmapexclude options
- 2022-02-10*[6150ae1] handle uncompressed raw data (only base64 encoded) in jdatadecode
- 2022-02-10 [88a59eb] give a warning when jdatadecode fails, but still return the raw data
- 2022-02-03*[05edb7a] fast reading and writing json data record using mmap and jsonpath
- 2022-02-02*[b0f0ebd] return disk-map or memory-map table in loadjson
- 2022-02-01 [0888218] correct typos and add additional descriptions in README
- 2022-02-01*[03133c7] fix row-major ('formatversion',1.8) ND array storage order, update demo outputs
- 2022-02-01 [5998c70] revert variable name encoding to support unicode strings
- 2022-01-31 [16454e7] test flexible whitespaces in 1D/2D arrays, test mixed array from string
- 2022-01-31*[5c1ef15] accelerate fastarrayparser by 200%! jsonlab_speedtest cuts from 11s to 5.8s
- 2022-01-30 [9b25e20] fix octave 3.8 error on travis, it does not support single
- 2022-01-30 [5898f6e] add octave 5.2 to travis
- 2022-01-30*[2e3344c] [bjdata:breaking] Upgrade ``savebj/loadbj`` to BJData v1-draft 2, use little-endian by default
- 2022-01-30*[2e3344c] [bjdata:breaking] Fix optimized ND array element order (previously used column-major)
- 2022-01-30*[2e3344c] optimize loadjson and loadbj speed
- 2022-01-30*[2e3344c] add 'BuiltinJSON' option for ``savejson/loadjson`` to call ``jsonencode/jsondecode``
- 2022-01-30*[2e3344c] more robust tests on ND array when parsing JSON numerical array construct
- 2021-06-23 [632531f] fix inconsistency between singlet integer and float values, close #70
- 2021-06-23 [f7d8226] prevent function calls when parsing array strings using eval, fix #75
- 2021-06-23 [b1ae5fa] fix #73 as a regression to #22
- 2021-11-22*[       ] octave-jsonlab is officially in Debian Testing/Bullseye
- 2020-09-29 [d0cb3b8] Fix for loading objects.
- 2020-07-26 [d0fb684] Add travis badge
- 2020-07-25 [708c36c] drop octave 3.2
- 2020-07-25 [436d84e] debug octave 3.2
- 2020-07-25 [0ce96ec] remove windows and osx targets from travis-ci
- 2020-07-25 [0d8baa4] fix ruby does not support error on windows
- 2020-07-25*[faa7921] enable travis-ci for jsonlab
- 2020-07-08 [321ab1a] add Debian and Ubuntu installation commands
- 2020-07-08 [e686828] update author info
- 2020-07-08*[ce40fdf] supports ND cell array, fix #66
- 2020-07-07 [6a8ce93] fix string encoding over 399 characters, close #65
- 2020-06-14 [5a58faf] fix DESCRIPTION date bug
- 2020-06-14 [9d7e94c] match octave description file and upstream version number
- 2020-06-14 [a5b6170] fix warning about ``lz4encode`` file name


Please note that the ``savejson/loadjson`` in both JSONLab v2.0-v3.0 are
compliant with JData Spec Draft 3; the ``savebj/loadbj`` in JSONLab v3.0 is
compatible to BJData spec Draft 2, which contains breaking feature changes
compared to those in JSONLab v2.0.

The BJData spec was derived from UBJSON spec Draft 12, with the 
following breaking differences:

- BJData adds 4 new numeric data types: ``uint16 [u]``, ``uint32 [m]``, ``uint64 [M]`` 
  and ``float16 [h]`` (supported in JSONLab v2.0 or newer)
- BJData supports an optimized ND array container (supported in JSONLab since 2013)
- BJData does not convert ``NaN/Inf/-Inf`` to ``null`` (supported in JSONLab since 2013)
- BJData Draft 2 changes the default byte order to Little-Endian instead of Big-Endian (JSONLab 3.0 or later)
- BJData only permits non-zero-fixed-length data types as the optimized array type, i.e. only ``UiuImlMLhdDC`` are allowed

To avoid using the new features, one should attach ``'UBJSON',1`` and ``'Endian','B'``
in the ``savebj`` command as

.. code-block::

   savebj('',data,'FileName','myfile.bjd','UBJSON',1, 'Endian','B');

To read BJData data files generated by JSONLab v2.0, you should call

.. code-block::

   data=loadbj('my_old_data_file.bjd','Endian','B')

You are strongly encouraged to convert all pre-v2.9 JSONLab generated BJD or .pmat
files using the new format.


============
Introduction
============

JSONLab is an open-source JSON/UBJSON/MessagePack encoder and decoder written 
completely in the native MATLAB language. It can be used to convert most MATLAB 
data structures (array, struct, cell, struct array, cell array, and objects) into 
JSON/UBJSON/MessagePack formatted strings and files, or to parse a 
JSON/UBJSON/MessagePack file into a MATLAB data structure. JSONLab supports both 
MATLAB and `GNU Octave <http://www.gnu.org/software/octave>`_ (a free MATLAB clone).

Compared to other MATLAB/Octave JSON parsers, JSONLab is uniquely lightweight, 
ultra-portable, producing dependable outputs across a wide-range of MATLAB 
(tested on R2008) and Octave (tested on v3.8) versions. It also uniquely supports 
BinaryJData/UBJSON/MessagePack data files as binary-JSON-like formats, designed 
for efficiency and flexibility with loss-less binary storage. As a parser written
completely with the native MATLAB language, it is surprisingly fast when reading 
small-to-moderate sized JSON files (1-2 MB) with simple hierarchical structures,
and is heavily optimized for reading JSON files containing large N-D arrays
(known as the "fast array parser" in ``loadjson``).

JSON (`JavaScript Object Notation <http://www.json.org/>`_) is a highly portable, 
human-readable and `"fat-free" <http://en.wikipedia.org/wiki/JSON>`_ text format 
to represent complex and hierarchical data, widely used for data-exchange in applications.
UBJSON (`Universal Binary JSON <http://ubjson.org/>`_) is a binary JSON format,  
designed to specifically address the limitations of JSON, permitting the
storage of binary data with strongly typed data records, resulting in smaller
file sizes and fast encoding and decoding. MessagePack is another binary
JSON-like data format widely used in data exchange in web/native applications.
It is slightly more compact than UBJSON, but is not directly readable compared
to UBJSON.

We envision that both JSON and its binary counterparts will play important 
roles for storage, exchange and interoperation of large-scale scientific data
among the wide-variety of tools. As container-formats, they offer both the 
flexibility and generality similar to other more sophisticated formats such 
as `HDF5 <http://www.hdfgroup.org/HDF5/whatishdf5.html>`_, but are significantly 
simpler with a much greater software ecosystem.

Towards this goal, we have developed the JData Specification (http://github.com/NeuroJSON/jdata) 
to standardize serializations of complex scientific data structures, such as
N-D arrays, sparse/complex-valued arrays, trees, maps, tables and graphs using
JSON/binary JSON constructs. The text and binary formatted JData files are
syntactically compatible with JSON/UBJSON formats, and can be readily parsed 
using existing JSON and UBJSON parsers. JSONLab is not just a parser and writer 
of JSON/UBJSON data files, but one that systematically converts complex scientific
data structures into human-readable and universally supported JSON forms using the
standardized JData data annotations.


================
Installation
================

The installation of JSONLab is no different from installing any other
MATLAB toolbox. You only need to download/unzip the JSONLab package
to a folder, and add the folder's path to MATLAB/Octave's path list
by using the following command:

.. code:: shell

    addpath('/path/to/jsonlab');

If you want to add this path permanently, you can type ``pathtool``, 
browse to the JSONLab root folder and add to the list, then click "Save".
Then, run ``rehash`` in MATLAB, and type ``which savejson``, if you see an 
output, that means JSONLab is installed for MATLAB/Octave.

If you use MATLAB in a shared environment such as a Linux server, the
best way to add path is to type 

.. code:: shell

   mkdir ~/matlab/
   nano ~/matlab/startup.m

and type ``addpath('/path/to/jsonlab')`` in this file, save and quit the editor.
MATLAB will execute this file every time it starts. For Octave, the file
you need to edit is ``~/.octaverc``, where ``~`` is your home directory.

To use the data compression features, please download the ZMat toolbox from
https://github.com/NeuroJSON/zmat/releases/latest and follow the instruction to
install ZMat first. The ZMat toolbox is required when compression is used on 
MATLAB running in the ``-nojvm`` mode or GNU Octave, or 'lzma/lzip/lz4/lz4hc' 
compression methods are specified. ZMat can also compress large arrays that 
MATLAB's Java-based compression API does not support.

-------------------------------------
Install JSONLab on Fedora 24 or later
-------------------------------------

JSONLab has been available as an official Fedora package since 2015. You may
install it directly using the below command

.. code:: shell

   sudo dnf install octave-jsonlab

To enable data compression/decompression, you need to install ``octave-zmat`` using

.. code:: shell

   sudo dnf install octave-zmat
   
Then open Octave, and type ``pkg load jsonlab`` to enable jsonlab toolbox.

-------------------------
Install JSONLab on Debian
-------------------------

JSONLab is currently available on Debian Bullseye. To install, you may run

.. code:: shell

   sudo apt-get install octave-jsonlab

One can alternatively install ``matlab-jsonlab`` if MATLAB is available.

-------------------------
Install JSONLab on Ubuntu
-------------------------

JSONLab is currently available on Ubuntu 21.04 or newer as package
`octave-jsonlab`. To install, you may run

.. code:: shell

   sudo apt-get install octave-jsonlab

For older Ubuntu releases, one can add the below PPA

https://launchpad.net/~fangq/+archive/ubuntu/ppa

To install, please run

.. code:: shell

   sudo add-apt-repository ppa:fangq/ppa
   sudo apt-get update

to add this PPA, and then use

.. code:: shell

   sudo apt-get install octave-jsonlab

to install the toolbox. ``octave-zmat`` will be automatically installed.

------------------------------
Install JSONLab on Arch Linux
------------------------------

JSONLab is also available on Arch Linux. You may install it using the below command

.. code:: shell

   sudo pikaur -S jsonlab

================
Using JSONLab
================

JSONLab provides a pair of functions, ``loadjson`` -- a JSON parser, and ``savejson`` -- 
a MATLAB-to-JSON encoder, to read/write the text-based JSON; it also provides
three equivalent pairs -- ``loadbj/savebj`` for binary JData, ``loadubjson/saveubjson``
for UBJSON and ``loadmsgpack/savemsgpack`` for MessagePack. The ``load*`` functions 
for the 3 supported data formats share almost the same input parameter format, 
similarly for the 3 ``save*`` functions (``savejson/saveubjson/savemsgpack``).
These encoders and decoders are capable of processing/sharing almost all 
data structures supported by MATLAB, thanks to ``jdataencode/jdatadecode`` - 
a pair of in-memory data converters translating complex MATLAB data structures
to their easy-to-serialized forms according to the JData specifications.
The detailed help information can be found in the ``Contents.m`` file.

In JSONLab 2.9.8 and later versions, a unified file loading and saving interface
is provided for JSON, binary JSON and HDF5, including ``loadjd`` and ``savejd``
for reading and writing below files types:

- JSON based files: ``.json``, ``.jdt`` (text JData file), ``.jmsh`` (text JMesh file),
  ``.jnii`` (text JNIfTI file), ``.jnirs`` (text JSNIRF file)
- BJData based files: ``.bjd``, ``.jdb`` (binary JData file), ``.bmsh`` (binary JMesh file),
  ``.bnii`` (binary JNIfTI file), ``.bnirs`` (binary JSNIRF file), ``.pmat`` (MATLAB session file)
- UBJSON based files: ``.ubj``
- MessagePack based files: ``.msgpack``
- HDF5 based files: ``.h5``, ``.hdf5``, ``.snirf`` (SNIRF fNIRS data files) - require `EasyH5 toolbox <https://github.com/NeuroJSON/easyh5>`_


In the below section, we provide a few examples on how to us each of the 
core functions for encoding/decoding JSON/Binary JSON/MessagePack data.

----------
savejson.m
----------

.. code-block::

       jsonmesh=struct('MeshNode',[0 0 0;1 0 0;0 1 0;1 1 0;0 0 1;1 0 1;0 1 1;1 1 1],... 
                'MeshElem',[1 2 4 8;1 3 4 8;1 2 6 8;1 5 6 8;1 5 7 8;1 3 7 8],...
                'MeshSurf',[1 2 4;1 2 6;1 3 4;1 3 7;1 5 6;1 5 7;...
                           2 8 4;2 8 6;3 8 4;3 8 7;5 8 6;5 8 7],...
                'MeshCreator','FangQ','MeshTitle','T6 Cube',...
                'SpecialData',[nan, inf, -inf]);

       % convert any matlab variables to JSON (variable name is used as the root name)
       savejson(jsonmesh)

       % convert matlab variables to JSON with a root-name "jmesh"
       savejson('jmesh',jsonmesh)

       % an empty root-name directly embed the data in the root {}
       % the compact=1 flag prints JSON without white-space in a single-line
       savejson('',jsonmesh,'Compact',1)

       % if 3 inputs are given, the 3rd parameter defines the output file name
       savejson('jmesh',jsonmesh,'outputfile.json')

       % param/value pairs can be provided after the 2nd input to customize outputs
       % if you want to use params/values and save JSON to a file, you must use the 'filename' to set output file
       savejson('',jsonmesh,'FileName','outputfile2.json','ArrayIndent',0,'FloatFormat','\t%.5g')

       % jsonlab utilizes JData annotations to encode complex/sparse ND-arrays
       savejson('cpxrand',eye(5)+1i*magic(5))

       % when setting 'BuiltinJSON' to 1, savejson calls jsonencode.m in MATLAB (R2016+)
       % or Octave (v7+) to convert data to JSON; this is typically faster, but does not
       % support all features native savejson offers
       savejson('cpxrand',eye(5)+1i*magic(5), 'BuiltinJSON', 1)

       % JData annotations also allows one to compress binary strongly-typed data and store in the JSON
       % gzip/zlib are natively supported in MATLAB and Octave; using ZMat toolbox, one can use lz4, lzma, blosc2 etc compressors
       savejson('ziparray',eye(10),'Compression','zlib','CompressArraySize',1)

       % 'ArrayToStruct' flag forces all arrays to use the JData ND array annotations to preserve types
       savejson('',jsonmesh,'ArrayToStruct',1)

       % JData supports compact storage of special matrices using the '_ArrayShape_' annotation
       savejson('',eye(10),'UseArrayShape',1)

----------
loadjson.m
----------

.. code-block::

       % loadjson can directly parse a JSON string if it starts with "[" or "{", here is an empty object
       loadjson('{}')

       % loadjson can also parse complex JSON objects in a string form
       dat=loadjson('{"obj":{"string":"value","array":[1,2,3]}}')
       
       % if the input is a file name, loadjson reads the file and parse the data inside
       dat=loadjson(['examples' filesep 'example1.json'])

       % param/value pairs can be used following the 1st input to customize the parsing behavior
       dat=loadjson(['examples' filesep 'example1.json'],'SimplifyCell',0)

       % if a URL is provided, loadjson reads JSON data from the URL and return the parsed results,
       % similar to webread, except loadjson calls jdatadecode to decode JData annotations
       dat=loadjson('https://raw.githubusercontent.com/fangq/jsonlab/master/examples/example1.json')

       % using the 'BuildinJSON' flag, one can use the built-in jsondecode.m in MATLAB (R2016+)
       % or Octave (7.0+) to parse the JSON data for better speed, note that jsondecode encode
       % key names differently compared to loadjson
       dat=loadjson('{"_obj":{"string":"value","array":[1,2,3]}}', 'builtinjson', 1)

       % when the JSON data contains long key names, one can use 'UseMap' flag to
       % request loadjson to store the data in a containers.Map instead of struct (key name limited to 63)
       dat=loadjson('{"obj":{"an object with a key longer than 63":"value","array":[1,2,3]}}', 'UseMap', 1)

       % loadjson can further download the linked data pointed by _DataLink_ tag, and merge with the parent
       dat=loadjson('{"obj":{"_DataLink_":"https://raw.githubusercontent.com/fangq/jsonlab/master/examples/example1.json"},"array":[1,2]}','maxlinklevel',1)

       % a JSONPath can be attached to the URL to retrieve a sub element
       dat=loadjson('{"obj":{"_DataLink_":"https://raw.githubusercontent.com/fangq/jsonlab/master/examples/example1.json:$.address.city"},"array":[1,2]}','maxlinklevel',1)

       % loadjson can optionally return a JSON-memory-map object, which defines each JSON element's
       % memory buffer offset and length to enable disk-map like fast read/write operations
       [dat, mmap]=loadjson('{"obj":{"key":"value","array":[1,2,3]}}')

       % if set 'mmaponly' to 1, loadjson only returns the JSON-mmap structure
       mmap=loadjson('{"obj":{"key":"value","array":[1,2,3]}}', 'mmaponly', 1)

--------
savebj.m
--------

.. code-block::

       % savebj works almost exactly like savejson, except that the output is the more compact binary JSON
       a={single(rand(2)), struct('va',1,'vb','string'), 1+2i};
       savebj(a)

       % customizing the root-name using the 1st input, and the 3rd input setting the output file
       savebj('rootname',a,'testdata.ubj')

       % enabling the 'debug' flag to allow printing binary JSON in text-form, helping users to run tests or troubleshoot
       savebj('rootname',a, 'debug',1)

       % like savejson, savebj also allow data compression for even more compact storage
       savebj('zeros',zeros(100),'Compression','gzip')

       % binary JSON does not need base64-encoding, therefore, the output can be ~33% smaller than text-based JSON
       [length(savebj('magic',magic(100),'Compression','zlib')), length(savejson('magic',magic(100),'Compression','zlib'))]

       % savebj can output other popular binary JSON formats, such as MessagePack or UBJSON
       savebj('mesh',a,'FileName','meshdata.msgpk','MessagePack',1)  % same as calling savemsgpack
       savebj('mesh',a,'FileName','meshdata.ubj','UBJSON',1)         % same as calling saveubjson

--------
loadbj.m
--------

.. code-block::

       % similarly, loadbj does almost exactly the same as loadjson, but it parses binary JSON instead
       obj=struct('string','value','array',single([1 2 3]),'empty',[],'magic',uint8(magic(5)));
       ubjdata=savebj('obj',obj);

       % loadbj can load a binary JSON (BJData - a derived format from UBJSON) object from a buffer
       dat=loadbj(ubjdata)

       % you can test if loadbj parsed object still matches the data saved using savebj
       class(dat.obj.array)
       isequaln(obj,dat.obj)

       % similarly, savebj/loadbj can compress/decompress binary array data using various compressors
       dat=loadbj(savebj('',eye(10),'Compression','zlib','CompressArraySize',1))

       % if given a path to a binary JSON file (.jdb,.bnii,.pmat,.jmsh,...), it opens and parses the file
       dat=loadbj('/path/to/a/binary_json.jdb');

       % loadbj can directly load binary JSON data files from URL, here is a binary-JSON based NIfTI file
       dat=loadbj('https://neurojson.org/io/stat.cgi?action=get&db=abide&doc=CMU_b&file=0a429cb9101b733f594eefc1261d6985-zlib.bnii')

       % similar to loadjson, loadbj can also return JSON-memory-map to permit disk-map
       % like direct reading/writing of specific data elements
       [dat, mmap]=loadbj(ubjdata)
       mmap=loadbj(ubjdata, 'mmaponly', 1)

-------------
jdataencode.m
-------------

.. code-block::

       % jdataencode transforms complex MATLAB data structures (ND-array, sparse array, complex arrays,
       % table, graph, containers.Map etc) into JSON-serializable forms using portable JData annotations
       % here, we show how to save a complex-valued sparse array using JSON JData annotations
       testdata = struct('a',rand(5)+1i*rand(5),'b',[],'c',sparse(5,5));
       jd=jdataencode(testdata)
       savejson('',jd)

       % when setting 'annotatearray' to 1, jdataencode uses _ArrayType_/_ArraySize_/_ArrayData_
       % JData tags to store ND array to preserve data types; use 'prefix' to customize variable name prefix
       encodedmat=jdataencode(single(magic(5)),'annotatearray',1,'prefix','x')

       % when setting 'usearrayshape' to 1, jdataencode can use _ArrayShape_ to encode special matrices
       encodedtoeplitz=jdataencode(uint8(toeplitz([1,2,3,4],[1,5,6])),'usearrayshape',1)

-------------
jdatadecode.m
-------------

.. code-block::

       % jdatadecode does the opposite to jdataencode, it recognizes JData annotations and convert
       % those back to MATLAB native data structures, such as ND-arrays, tables, graph etc
       rawdata=struct('a',rand(5)+1i*rand(5),'b',[],'c',sparse(5,5));
       jd=jdataencode(rawdata)
       newjd=jdatadecode(jd)

       % we can test that the decoded data are the same as the original
       isequaln(newjd,rawdata)

       % if one uses jsondecode to parse a JSON object, the output JData annotation name prefix is different
       % jsondecode adds "x_" as prefix
       rawdecode_builtin = jsondecode(savejson('',rawdata));
       rawdecode_builtin.a
       finaldecode=jdatadecode(rawdecode_builtin)

       % in comparison, loadjson calls encodevarname.m, producing "x0x5F_" as prefix (hex for '_')
       % encodevarname encoded names can be reversed to original decodevarname.m
       rawdecode_jsonlab = loadjson(savejson('',rawdata), 'jdatadecode', 0);
       rawdecode_jsonlab.a
       finaldecode=jdatadecode(rawdecode_jsonlab)

--------
savejd.m
--------

.. code-block::

       % savejd is a unified interface for savejson/savebj/savemsgpack/saveh5 depending on the output file suffix
       a={single(rand(2)), struct('va',1,'vb','string'), 1+2i};
       savejd('', a, 'test.json')
       savejd('', a, 'test.jdb')
       savejd('', a, 'test.ubj')
       savejd('', a, 'test.h5')

--------
loadjd.m
--------

.. code-block::

       % loadjd is a unified interface for loadjson/loadbj/loadmsgpack/loadh5/load/loadjnifti depending on the input file suffix
       % supported types include .json,.jnii,.jdt,.jmsh,.jnirs,.jbids,.bjd,.bnii,.jdb,.bmsh,.bnirs,.ubj,.msgpack,
       % .h5,.hdf5,.snirf,.pmat,.nwb,.nii,.nii.gz,.tsv,.tsv.gz,.csv,.csv.gz,.mat,.bvec,.bval; input can be an URL
       data = loadjd('test.json');
       data = loadjd('test.jdb');
       data = loadjd('test.ubj');
       data = loadjd('test.h5');
       data = loadjd('file:///path/to/test.jnii');
       data = loadjd('https://neurojson.org/io/stat.cgi?action=get&db=abide&doc=CMU_b&file=0a429cb9101b733f594eefc1261d6985-zlib.bnii');

---------
jsonget.m
---------

.. code-block::

       % loadjson/loadbj JSON-memory-map (mmap) output returned by loadjson or loadbj
       % each mmap contains a pair of JSONPath and two numbers [offset, length] of the object in bytes in the buffer/file
       jsonstr = '{"obj":{"string":"value","array":[1,2,3]}}';
       mmap=loadjson(jsonstr, 'mmaponly', 1)

       % mmap = [ ["$",[1,42]], ["$.obj",[8,34]], ["$.obj.string",[18,7]], ["$.obj.array",[34,7]] ]
       % this means there are 4 objects, root '$', with its content starting byte 1, with a length of 42 bytes;
       % content of object '$.obj' starts byte 8, with a length of 34 bytes
       mmap{:}

       % using the above mmap, jsonget can return any raw data without needing to reparse jsonstr
       % below command returns '[1,2,3]' as a string by following the offset/length data in mmap
       jsonget(jsonstr, mmap, '$.obj.array')

       % you can request multiple objects by giving multiple JSONPath keys
       jsonget(jsonstr, mmap, '$.obj', '$.obj.string')

       % you can request multiple objects by giving multiple JSONPath keys
       jsonget(jsonstr, mmap, '$.obj', '$.obj.string')

       % jsonget not only can fast reading a JSON string buffer, it can also do disk-map read of a file
       mmap = loadjson('/path/to/data.json', 'mmaponly', 1);
       jsonget('/path/to/data.json', mmap, '$.obj')

---------
jsonset.m
---------

.. code-block::

       % using JSON mmap, one can rapidly modify the content of JSON object pointed by a path
       jsonstr = '{"obj":{"string":"value","array":[1,2,3]}}';
       mmap=loadjson(jsonstr, 'mmaponly', 1)

       % we can rewrite object $.obj.array by changing its value '[1,2,3]' to a string "test"
       % this returns the updated jsonstr as '{"obj":{"string":"value","array":"test" }}'
       % the new value of a key must not have longer bytes than the original value
       jsonset(jsonstr, mmap, '$.obj.array', '"test"')

       % one can change multiple JSON objects, below returns '{"obj":{"string":"new"  ,"array":[]     }}'
       jsonset(jsonstr, mmap, '$.obj.string', '"new"', '$.obj.array', '[]')

       % if mmap is parsed from a file, jsonset can perform disk-map like fast writing to modify the json content
       mmap = loadjson('/path/to/data.json', 'mmaponly', 1);
       jsonset('/path/to/data.json', mmap, '$.obj.string', '"new"', '$.obj.array', '[]')

----------
jsonpath.m
----------

.. code-block::

       % JSONPath is a widely supported standard to index/search a large struct, such as those loaded from a JSON file
       % the jsonpath.m function implements a subset of the features
       % the below command returns the value of obj.key subfield, which is "value"
       obj = loadjson('{"obj":{"key":"value1","array":[1,2,3],"sub":{"key":"value2","array":[]}}}');
       jsonpath(obj, '$.obj.key')

       % using [] operator, one can also index array elements, index start from 0; the output below is 2
       jsonpath(obj, '$.obj.array[1]')

       % [] operator supports range, for example below commands yields [1,2]
       jsonpath(obj, '$.obj.array[0:1]')

       % a negative index in [] counting elements backwards, -1 means the last element
       jsonpath(obj, '$.obj.array[-1]')

       % jsonpath.m supports JSONPath's deep-scan operator '..', it traverses through the struct
       % and find all keys following .., here the output is {"value1", "value2"}
       jsonpath(obj, '$.obj..key')

       % you can further concatenate JSONPath operators to select outputs from the earlier ones, this outputs {'value2'}
       jsonpath(obj, '$.obj..key[1]')

       % instead of .keyname, you can use [keyname], below command is the same as above
       jsonpath(obj, '$[obj]..[key][1]')

       % one can escape special char, such as ".", in the key using special\.key or [special.key]
       jsonpath(obj, '$.obj.special\.key.sub')


-----------
jsoncache.m
-----------

.. code-block::

       % the _DataLink_ annotation in the JData specification permits linking of external data files
       % in a JSON file - to make downloading/parsing externally linked data files efficient, such as
       % processing large neuroimaging datasets hosted on http://neurojson.io, we have developed a system
       % to download files on-demand and cache those locally. jsoncache.m is responsible of searching
       % the local cache folders, if found the requested file, it returns the path to the local cache;
       % if not found, it returns a SHA-256 hash of the URL as the file name, and the possible cache folders
       %
       % When loading a file from URL, below is the order of cache file search paths, ranking in search order
       %
       %    global-variable NEUROJSON_CACHE | if defined, this path will be searched first
       %    [pwd '/.neurojson']             | on all OSes
       %    /home/USERNAME/.neurojson       | on all OSes (per-user)
       %    /home/USERNAME/.cache/neurojson | if on Linux (per-user)
       %    /var/cache/neurojson            | if on Linux (system wide)
       %    /home/USERNAME/Library/neurojson| if on MacOS (per-user)
       %    /Library/neurojson              | if on MacOS (system wide)
       %    C:\ProgramData\neurojson        | if on Windows (system wide)
       %
       % When saving a file from a URL, under the root cache folder, subfolders can be created;
       % if the URL is one of a standard NeuroJSON.io URLs as below
       %
       %    https://neurojson.org/io/stat.cgi?action=get&db=DBNAME&doc=DOCNAME&file=sub-01/anat/datafile.nii.gz
       %    https://neurojson.io:7777/DBNAME/DOCNAME
       %    https://neurojson.io:7777/DBNAME/DOCNAME/datafile.suffix
       %
       % the file datafile.nii.gz will be downloaded to /home/USERNAME/.neurojson/io/DBNAME/DOCNAME/sub-01/anat/ folder
       % if a URL does not follow the neurojson.io format, the cache folder has the below form
       %
       %    CACHEFOLDER{i}/domainname.com/XX/YY/XXYYZZZZ...
       %
       % where XXYYZZZZ.. is the SHA-256 hash of the full URL, XX is the first two digit, YY is the 3-4 digits

       % below command searches CACHEFOLDER{i}/io/openneuro/ds000001/sub-01/anat/, and return the path/filename
       [cachepath, filename] = jsoncache('https://neurojson.org/io/stat.cgi?action=get&db=openneuro&doc=ds000001&file=sub-01/anat/sub-01_inplaneT2.nii.gz&size=669578')

       % this searches CACHEFOLDER{i}/raw.githubusercontent.com/55/d2, and the filename is 55d24a4bad6ecc3f5dc4d333be728e01c26b696ef7bc5dd0861b7fa672a28e8e.json
       [cachepath, filename] = jsoncache('https://raw.githubusercontent.com/fangq/jsonlab/master/examples/example1.json')

       % this searches cachefolder{i}/io/adhd200/Brown folder, and look for file Brown.json
       [cachepath, filename] = jsoncache('https://neurojson.io:7777/adhd200/Brown')

       % this searches cachefolder{i}/io/openneuro/ds003805 folder, and look for file ds003805.json
       [cachepath, filename] = jsoncache('https://neurojson.io:7777/openneuro/ds003805')

-----------
jdlink.m
-----------

.. code-block::

       % jdlink dynamically downloads, caches and parses data files from one or multiple URLs
       % jdlink calls jsoncache to scan cache folders first, if a cache copy exists, it loads the cache first

       % here we download a dataset from NeuroJSON.io, containing many linked data files
       data = loadjson('https://neurojson.io:7777/openneuro/ds000001');

       % we now use jsonpath to scan all linked resources under subfolder "anat"
       alllinks = jsonpath(data, '$..anat.._DataLink_')

       % let's download all linked nifti files (total 4) for sub-01 and sub-02, and load the files as niidata
       niidata = jdlink(alllinks, 'regex', 'sub-0[12]_.*\.nii');

       % if you just want to download/cache all files and do not want to parse the files, you can run
       jdlink(alllinks);

---------
examples
---------

Under the ``examples`` folder, you can find several scripts to demonstrate the
basic utilities of JSONLab. Running the ``demo_jsonlab_basic.m`` script, you 
will see the conversions from MATLAB data structure to JSON text and backward.
In ``jsonlab_selftest.m``, we load complex JSON files downloaded from the Internet
and validate the ``loadjson/savejson`` functions for regression testing purposes.
Similarly, a ``demo_ubjson_basic.m`` script is provided to test the ``saveubjson``
and ``loadubjson`` functions for various matlab data structures, and 
``demo_msgpack_basic.m`` is for testing ``savemsgpack`` and ``loadmsgpack``.

Please run these examples and understand how JSONLab works before you use
it to process your data.

------------
unit testing
------------

Under the ``test`` folder, you can find a script to test individual data types and
inputs using various encoders and decoders. This unit testing script also serves as
a **specification validator** to the JSONLab functions and ensure that the outputs
are compliant to the underlying specifications.

========================================
In-memory data compression/decompression
========================================

JSONLab contains a set of functions to perform in-memory buffer data compression and
decompression

----------------------------------------------------------------------------
Data Compression: {zlib,gzip,base64,lzma,lzip,lz4,lz4hc,zstd,blosc2}encode.m
----------------------------------------------------------------------------

.. code-block::

      % MATLAB running with jvm provides zlib and gzip compression natively
      % one can also install ZMat (https://github.com/NeuroJSON/zmat) to do zlib(.zip) or gzip (.gz) compression
      output = zlibencode(diag([1,2,3,4]))
      [output, info] = zlibencode(uint8(magic(8)))
      outputbase64 = char(base64encode(output(:)))

      % char, numeric and logical ND-arrays are acceptable inputs to the compression functions
      [output, info] = gzipencode(uint8(magic(8)))

      % setting a negative integer between -1 to -9 to set compression level: -9 being the highest
      [output, info] = zlibencode(uint8(magic(8)), -9)

      % other advanced compressions are supported but requires ZMat
      % lzma offers the highest compression rate, but slow compresison speed
      output = lzmaencode(uint8(magic(8)))

      % lz4 offers the fastest compression speed, but slightly low compression ratio
      output = lz4encode(peaks(10))
      output = lz4hcencode(uint8(magic(8)))

      % zstd has a good balanced speed/ratio, similar to zlib
      output = zstdencode(peaks(10))
      output = zstdencode(peaks(10), -9)

-----------------------------------------------------------------------------
Data Deompression: {zlib,gzip,base64,lzma,lzip,lz4,lz4hc,zstd,blosc2}decode.m
-----------------------------------------------------------------------------

.. code-block::

      % passing on a compressed byte-array buffer to *decode function decompresses the buffer
      [compressed, info] = zlibencode(eye(10));

      % the decompressed buffer is a byte-array
      decompressd = zlibdecode(compressed);

      % to fully recover the original data structure, one most use the info struct returned by the compressor
      decompressd = zlibdecode(compressed, info)

      % if one passes a zlib compressed buffer to a different decompressor, an error is reported
      decompressd = gzipdecode(compressed, info)
      outputbase64 = char(base64decode(base64encode('jsonlab test')))

========================================
Using ``jsave/jload`` to share workspace
========================================

Starting from JSONLab v2.0, we provide a pair of functions, ``jsave/jload`` to store
and retrieve variables from the current workspace, similar to the ``save/load`` 
functions in MATLAB and Octave. The files that ``jsave/jload`` reads/writes is by  
default a binary JData file with a suffix ``.pmat``. The file size is comparable
(can be smaller if use ``lzma`` compression) to ``.mat`` files. This feature
is currently experimental.

The main benefits of using .pmat file to share matlab variables include

* a ``.pmat`` file can be 50% smaller than a ``.mat`` file when using 
  ``jsave(..., "compression","lzma")``; the only drawback is longer saving time.
* a ``.pmat`` file can be readily read/opened among many programming environments, including 
  Python, JavaScript, Go, Java etc, where .mat file support is not generally available. 
  Parsers of ``.pmat`` files are largely compatible with BJData's parsers available at 
  https://neurojson.org/#software
* a ``.pmat`` file is quasi-human-readable, one can see the internal data fields 
  even in a command line, for example using ``strings -n 2 file.pmat | astyle``, 
  making the binary data easy to be understood, shared and reused. 
* ``jsave/jload`` can also use MessagePack and JSON formats as the underlying 
  data storage format, addressing needs from a diverse set of applications. 
  MessagePack parsers are readily available at https://msgpack.org/

----------
jsave.m
----------

.. code-block::

      jsave    % save the current workspace to default.pmat
      jsave mydata.pmat
      jsave('mydata.pmat','vars',{'var1','var2'})
      jsave('mydata.pmat','compression','lzma')
      jsave('mydata.json','compression','gzip')

----------
jload.m
----------

.. code-block::

      jload    % load variables from default.pmat to the current workspace
      jload mydata.pmat   % load variables from mydata.pmat
      vars=jload('mydata.pmat','vars',{'var1','var2'}) % return vars.var1, vars.var2
      jload('mydata.pmat','simplifycell',0)
      jload('mydata.json')


================================================
Sharing JSONLab created data files in Python
================================================

Despite the use of portable data annotation defined by the JData Specification, 
the output JSON files created by JSONLab are 100% JSON compatible (with
the exception that long strings may be broken into multiple lines for better
readability). Therefore, JSONLab-created JSON files (``.json, .jnii, .jnirs`` etc) 
can be readily read and written by nearly all existing JSON parsers, including
the built-in ``json`` module parser in Python.

However, we strongly recommend one to use a lightweight ``jdata`` module, 
developed by the same author, to perform the extra JData encoding and decoding
and convert JSON data directly to convenient Python/Numpy data structures.
The ``jdata`` module can also directly read/write UBJSON/Binary JData outputs
from JSONLab (``.bjd, .ubj, .bnii, .bnirs, .pmat`` etc). Using binary JData
files are expected to produce much smaller file sizes and faster parsing,
while maintaining excellent portability and generality.

In short, to conveniently read/write data files created by JSONLab into Python,
whether they are JSON based or binary JData/UBJSON based, one just need to download
the below two light-weight python modules:

* **jdata**: PyPi: https://pypi.org/project/jdata/  ; Github: https://github.com/NeuroJSON/pyjdata
* **bjdata** PyPi: https://pypi.org/project/bjdata/ ; Github: https://github.com/NeuroJSON/pybj

To install these modules on Python 2.x, please first check if your system has
``pip`` and ``numpy``, if not, please install it by running (using Ubuntu/Debian as example)

.. code-block:: shell

      sudo apt-get install python-pip python3-pip python-numpy python3-numpy

After the installation is done, one can then install the ``jdata`` and ``bjdata`` modules by

.. code-block:: shell

      pip install jdata --user
      pip install bjdata --user

To install these modules for Python 3.x, please replace ``pip`` by ``pip3``.
If one prefers to install these modules globally for all users, simply
execute the above commands using 

.. code-block:: shell

      sudo pip install jdata
      sudo pip install bjdata

The above modules require built-in Python modules ``json`` and NumPy (``numpy``).

Once the necessary modules are installed, one can type ``python`` (or ``python3``), and run

.. code-block::

      import jdata as jd
      import numpy as np

      data1=jd.loadt('myfile.json');
      data2=jd.loadb('myfile.bjd');
      data3=jd.loadb('myfile.pmat');

where ``jd.loadt()`` function loads a text-based JSON file, performs
JData decoding and converts the enclosed data into Python ``dict``, ``list`` 
and ``numpy`` objects. Similarly, ``jd.loadb()`` function loads a binary 
JData/UBJSON file and performs similar conversions. One can directly call
``jd.load()`` to open JSONLab (and derived toolboxes such as **jnifti**: 
https://github.com/NeuroJSON/jnifti or **jsnirf**: https://github.com/NeuroJSON/jsnirf) 
generated files based on their respective file suffix.

Similarly, the ``jd.savet()``, ``jd.saveb()`` and ``jd.save`` functions
can revert the direction and convert a Python/Numpy object into JData encoded
data structure and store as text-, binary- and suffix-determined output files,
respectively.

=======================
Known Issues and TODOs
=======================

JSONLab has several known limitations. We are striving to make it more general
and robust. Hopefully in a few future releases, the limitations become less.

Here are the known issues:

  * 3D or higher dimensional cell/struct-arrays will be converted to 2D arrays
  * When processing names containing multi-byte characters, Octave and MATLAB 
    can give different field-names; you can use 
    ``feature('DefaultCharacterSet','latin1')`` in MATLAB to get consistent results
  * ``savejson`` can only export the properties from MATLAB classes, but not the methods
  * ``saveubjson`` converts a logical array into a ``uint8`` (``[U]``) array
  * a special N-D array format, as defined in the JData specification, is 
    implemented in ``saveubjson``. You may use ``saveubjson(...,'NestArray',1)``
    to create UBJSON Draft-12 compliant files 
  * ``loadubjson`` can not parse all UBJSON Specification (Draft 12) compliant 
    files, however, it can parse all UBJSON files produced by ``saveubjson``.

==========================
Contribution and feedback
==========================

JSONLab is an open-source project. This means you can not only use it and modify
it as you wish, but also you can contribute your changes back to JSONLab so
that everyone else can enjoy the improvement. For anyone who want to contribute,
please download JSONLab source code from its source code repositories by using the
following command:


.. code:: shell

      git clone https://github.com/fangq/jsonlab.git jsonlab

or browsing the github site at

      https://github.com/fangq/jsonlab

Please report any bugs or issues to the below URL:

      https://github.com/fangq/jsonlab/issues

Sometimes, you may find it is necessary to modify JSONLab to achieve your 
goals, or attempt to modify JSONLab functions to fix a bug that you have 
encountered. If you are happy with your changes and willing to share those
changes to the upstream author, you are recommended to create a pull-request
on github. 

To create a pull-request, you first need to "fork" jsonlab on Github by 
clicking on the "fork" button on top-right of JSONLab's github page. Once you forked
jsonlab to your own directory, you should then implement the changes in your
own fork. After thoroughly testing it and you are confident the modification 
is complete and effective, you can then click on the "New pull request" 
button, and on the left, select fangq/jsonlab as the "base". Then type
in the description of the changes. You are responsible to format the code
updates using the same convention (tab-width: 8, indentation: 4 spaces) as
the upstream code.

We appreciate any suggestions and feedbacks from you. Please use the following
user forum to ask any question you may have regarding JSONLab:

      https://github.com/orgs/NeuroJSON/discussions/categories/neurojson-json-format-specifications-and-parsers



==========================
Acknowledgement
==========================

----------
loadjson.m
----------

The ``loadjson.m`` function was significantly modified from the earlier parsers 
(BSD 3-clause licensed) written by the below authors

* Nedialko Krouchev: http://www.mathworks.com/matlabcentral/fileexchange/25713
    created on 2009/11/02
* François Glineur: http://www.mathworks.com/matlabcentral/fileexchange/23393
    created on  2009/03/22
* Joel Feenstra:
    http://www.mathworks.com/matlabcentral/fileexchange/20565
    created on 2008/07/03

-------------
loadmsgpack.m
-------------

* Author: Bastian Bechtold
* URL: https://github.com/bastibe/matlab-msgpack/blob/master/parsemsgpack.m
* License: BSD 3-clause license

Copyright (c) 2014,2016 Bastian Bechtold
All rights reserved.

Redistribution and use in source and binary forms, with or without modification, 
are permitted provided that the following conditions are met:

* Redistributions of source code must retain the above copyright notice, this 
  list of conditions and the following disclaimer.

* Redistributions in binary form must reproduce the above copyright notice, 
  this list of conditions and the following disclaimer in the documentation 
  and/or other materials provided with the distribution.

* Neither the name of the copyright holder nor the names of its contributors 
  may be used to endorse or promote products derived from this software without 
  specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

---------------------------------------------------------------------------------------
zlibdecode.m, zlibencode.m, gzipencode.m, gzipdecode.m, base64encode.m, base64decode.m
---------------------------------------------------------------------------------------

* Author: Kota Yamaguchi
* URL: https://www.mathworks.com/matlabcentral/fileexchange/39526-byte-encoding-utilities
* License: BSD License, see below

Copyright (c) 2012, Kota Yamaguchi
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

* Redistributions of source code must retain the above copyright notice, this
  list of conditions and the following disclaimer.

* Redistributions in binary form must reproduce the above copyright notice,
  this list of conditions and the following disclaimer in the documentation
  and/or other materials provided with the distribution

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
