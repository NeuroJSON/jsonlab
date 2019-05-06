
                            < M A T L A B (R) >
                  Copyright 1984-2010 The MathWorks, Inc.
                Version 7.11.0.584 (R2010b) 64-bit (glnxa64)
                              August 16, 2010

 
  To get started, type one of these: helpwin, helpdesk, or demo.
  For product information, visit www.mathworks.com.
 
>> >> >> >> >> >> >> >> >> 
%=================================================
>> %  a simple scalar value 
>> %=================================================

>> >> 
data2json =

    3.1416

>> 
ans =

[D@	!ûTD-]

>> 
json2data = 

    [3.1416]

>> >> 
%=================================================
>> %  a complex number
>> %=================================================

>> >> >> 
data2json =

   1.0000 + 2.0000i

>> 
ans =

{U_ArrayType_SUdoubleU_ArraySize_[$U#UU_ArrayIsComplex_TU_ArrayData_[$i#U}

>> 
json2data =

   1.0000 + 2.0000i

>> >> 
%=================================================
>> %  a complex matrix
>> %=================================================

>> >> >> 
data2json =

  35.0000 +26.0000i   1.0000 +19.0000i   6.0000 +24.0000i
   3.0000 +21.0000i  32.0000 +23.0000i   7.0000 +25.0000i
  31.0000 +22.0000i   9.0000 +27.0000i   2.0000 +20.0000i
   8.0000 +17.0000i  28.0000 +10.0000i  33.0000 +15.0000i
  30.0000 +12.0000i   5.0000 +14.0000i  34.0000 +16.0000i
   4.0000 +13.0000i  36.0000 +18.0000i  29.0000 +11.0000i

>> 
ans =

{U_ArrayType_SUdoubleU_ArraySize_[$U#UU_ArrayIsComplex_TU_ArrayData_[$i#[$U#U# 	$!"
}

>> 
json2data =

  35.0000 +26.0000i   1.0000 +19.0000i   6.0000 +24.0000i
   3.0000 +21.0000i  32.0000 +23.0000i   7.0000 +25.0000i
  31.0000 +22.0000i   9.0000 +27.0000i   2.0000 +20.0000i
   8.0000 +17.0000i  28.0000 +10.0000i  33.0000 +15.0000i
  30.0000 +12.0000i   5.0000 +14.0000i  34.0000 +16.0000i
   4.0000 +13.0000i  36.0000 +18.0000i  29.0000 +11.0000i

>> >> 
%=================================================
>> %  MATLAB special constants
>> %=================================================

>> >> 
data2json =

   NaN   Inf  -Inf

>> 
ans =

{Uspecials[$D#Uÿø      ð      ÿð      }

>> 
json2data = 

    specials: [NaN Inf -Inf]

>> >> 
%=================================================
>> %  a real sparse matrix
>> %=================================================

>> >> 
data2json =

   (1,2)       0.6557
   (9,2)       0.7577
   (3,5)       0.8491
  (10,5)       0.7431
  (10,8)       0.3922
   (7,9)       0.6787
   (2,10)      0.0357
   (6,10)      0.9340
  (10,10)      0.6555

>> 
ans =

{Usparse{U_ArrayType_SUdoubleU_ArraySize_[$U#U

U_ArrayIsSparse_TU_ArrayData_[$D#[$U#U	?ð      @"      @      @$      @$      @      @       @      @$      @       @       @      @      @       @"      @$      @$      @$      ?äûÓë12?è?h:öl;?ë,8Ù±?çÇ½½æ'#?Ù?[`o?å¸2ÉNé?¢HÍpà?íãEÎ¹¶P?äù¬Ä²	¶}}

>> 
json2data = 

    sparse: [10x10 double]

>> >> 
%=================================================
>> %  a complex sparse matrix
>> %=================================================

>> >> 
data2json =

   (1,2)      0.6557 - 0.6557i
   (9,2)      0.7577 - 0.7577i
   (3,5)      0.8491 - 0.8491i
  (10,5)      0.7431 - 0.7431i
  (10,8)      0.3922 - 0.3922i
   (7,9)      0.6787 - 0.6787i
   (2,10)     0.0357 - 0.0357i
   (6,10)     0.9340 - 0.9340i
  (10,10)     0.6555 - 0.6555i

>> 
ans =

{Ucomplex_sparse{U_ArrayType_SUdoubleU_ArraySize_[$U#U

U_ArrayIsComplex_TU_ArrayIsSparse_TU_ArrayData_[$D#[$U#U	?ð      @"      @      @$      @$      @      @       @      @$      @       @       @      @      @       @"      @$      @$      @$      ?äûÓë12?è?h:öl;?ë,8Ù±?çÇ½½æ'#?Ù?[`o?å¸2ÉNé?¢HÍpà?íãEÎ¹¶P?äù¬Ä²	¶¿äûÓë12¿è?h:öl;¿ë,8Ù±¿çÇ½½æ'#¿Ù?[`o¿å¸2ÉNé¿¢HÍpà¿íãEÎ¹¶P¿äù¬Ä²	¶}}

>> 
json2data = 

    complex_sparse: [10x10 double]

>> >> 
%=================================================
>> %  an all-zero sparse matrix
>> %=================================================

>> >> >> 
ans =

{Uall_zero_sparse{U_ArrayType_SUdoubleU_ArraySize_[$U#UU_ArrayIsSparse_TU_ArrayData_Z}}

>> 
json2data = 

    all_zero_sparse: [2x3 double]

>> >> 
%=================================================
>> %  an empty sparse matrix
>> %=================================================

>> >> >> 
ans =

{Uempty_sparseZ}

>> 
json2data = 

    empty_sparse: []

>> >> 
%=================================================
>> %  an empty 0-by-0 real matrix
>> %=================================================

>> >> >> 
ans =

{Uempty_0by0_realZ}

>> 
json2data = 

    empty_0by0_real: []

>> >> 
%=================================================
>> %  an empty 0-by-3 real matrix
>> %=================================================

>> >> >> 
ans =

{Uempty_0by3_realZ}

>> 
json2data = 

    empty_0by3_real: []

>> >> 
%=================================================
>> %  a sparse real column vector
>> %=================================================

>> >> >> 
ans =

{Usparse_column_vector{U_ArrayType_SUdoubleU_ArraySize_[$U#UU_ArrayIsSparse_TU_ArrayData_[$i#[$U#U}}

>> 
json2data = 

    sparse_column_vector: [5x1 double]

>> >> 
%=================================================
>> %  a sparse complex column vector
>> %=================================================

>> >> >> 
ans =

{Ucomplex_sparse_column_vector{U_ArrayType_SUdoubleU_ArraySize_[$U#UU_ArrayIsComplex_TU_ArrayIsSparse_TU_ArrayData_[$i#[$U#Uýÿü}}

>> 
json2data = 

    complex_sparse_column_vector: [5x1 double]

>> >> 
%=================================================
>> %  a sparse real row vector
>> %=================================================

>> >> >> 
ans =

{Usparse_row_vector{U_ArrayType_SUdoubleU_ArraySize_[$U#UU_ArrayIsSparse_TU_ArrayData_[$i#[$U#U}}

>> 
json2data = 

    sparse_row_vector: [0 3 0 1 4]

>> >> 
%=================================================
>> %  a sparse complex row vector
>> %=================================================

>> >> >> 
ans =

{Ucomplex_sparse_row_vector{U_ArrayType_SUdoubleU_ArraySize_[$U#UU_ArrayIsComplex_TU_ArrayIsSparse_TU_ArrayData_[$i#[$U#Uýÿü}}

>> 
json2data = 

    complex_sparse_row_vector: [1x5 double]

>> >> 
%=================================================
>> %  a structure
>> %=================================================

>> >> 
data2json = 

        name: 'Think Different'
        year: 1997
       magic: [3x3 double]
     misfits: [Inf NaN]
    embedded: [1x1 struct]

>> 
ans =

{Uastruct{UnameSUThink DifferentUyearIÍUmagic[$i#[$U#U	Umisfits[$D#Uð      ÿø      Uembedded{UleftTUrightF}}}

>> 
json2data = 

    astruct: [1x1 struct]

>> >> 
%=================================================
>> %  a structure array
>> %=================================================

>> >> >> >> >> 
ans =

{USupreme Commander[{UnameSUNexus PrimeUranki	}{UnameSUSentinel PrimeUranki	}{UnameSUOptimus PrimeUranki	}]}

>> 
json2data = 

    Supreme_0x20_Commander: {[1x1 struct]  [1x1 struct]  [1x1 struct]}

>> >> 
%=================================================
>> %  a cell array
>> %=================================================

>> >> >> >> >> 
data2json = 

    [1x1 struct]
    [1x1 struct]
    [1x4 double]

>> 
ans =

{Udebian[[{UbuzzD?ñUrexD?ó333333UboD?ôÌÌÌÌÌÍUhammiUslinkD@ ÌÌÌÌÌÍUpotatoD@UwoodyiUsargeD@ÌÌÌÌÌÍUetchiUlennyiUsqueezeiUwheezyi}{UUbuntu[SUKubuntuSUXubuntuSULubuntu]}[$D#U@$záG®@$333333@&záG®@&333333]]}

>> 
json2data = 

    debian: {{1x3 cell}}

>> >> 
%=================================================
>> %  invalid field-name handling
>> %=================================================

>> >> 
json2data = 

               ValidName: 1
       x0x5F_InvalidName: 2
       x0x3A_Field_0x3A_: 3
    x0xEFBFBD__0xEFBFBD_: '绝密'

>> >> 
%=================================================
>> %  a 2D cell array
>> %=================================================

>> >> >> 
ans =

{U	data2json[[[[i][[i][i]]][[i]]][[[i][i]][[i][i	]]][[[i]][[i
]]]]}

>> 
json2data = 

    data2json: {{1x2 cell}  {1x2 cell}  {1x2 cell}}

>> >> 
%=================================================
>> %  a 2D struct array
>> %=================================================

>> >> 
data2json = 

2x3 struct array with fields:
    idx
    data

>> >> 
ans =

{U	data2json[[{UidxiUdataSUstructs}{UidxiUdataSUstructs}][{UidxiUdataSUstructs}{UidxiUdataSUstructs}][{UidxiUdataSUstructs}{UidxiUdataSUstructs}]]}

>> 
json2data = 

    data2json: {{1x2 cell}  {1x2 cell}  {1x2 cell}}

>> >> >> >> 