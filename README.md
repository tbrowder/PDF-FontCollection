[![Actions Status](https://github.com/tbrowder/PDF-FontCollection/actions/workflows/linux.yml/badge.svg)](https://github.com/tbrowder/PDF-FontCollection/actions) [![Actions Status](https://github.com/tbrowder/PDF-FontCollection/actions/workflows/macos.yml/badge.svg)](https://github.com/tbrowder/PDF-FontCollection/actions) [![Actions Status](https://github.com/tbrowder/PDF-FontCollection/actions/workflows/windows.yml/badge.svg)](https://github.com/tbrowder/PDF-FontCollection/actions)

NAME
====

**PDF::FontCollection** - Provides easy access, information, and loading of installed OpenType fonts

SYNOPSIS
========

```raku
$ zef install PDF::FontCollection;
$ pdf-fonts list c=f       # list fonts in collection 'f'
f1   FreeSerif
f2b  FreeSerifBold
f2i  FreeSerifItalic
f2bi FreeSerifBoldItalic
...
```

DESCRIPTION
===========

**PDF::FontCollection** is a curated set of five collections of OpenType fonts available to install on Linux and MacOS. For Windows systems only the 'FreeFonts' collection is available, but that set of fonts can handle most needs as it represents fonts equivalent to the classic Adobe fonts Time, Helvetica, and Courier, but with many more glyphs (800 or more).

This package enables easy handling of the NN (or NN for Windows) fonts by a mmemonic set of keys to show details by listing them, showing all their attributes, getting their file path, or loading them into a PDF document being generated with module 'PDF::Lite'.

Keys
====

The font keys consist of several alphanumeric characters (not case-sensitive). The first one or two alphabetic characters represent a font collection:

  * C - Cantarell

  * E - E B Garamond

  * F - FreeFonts

  * L - Linux Libertine

  * U - URW Base 35

The next one or two numbers represent the font families in the set. The remaining characters, if any, represent the bold and italic (or oblique) versions of that font family. For example, using FreeFonts we list several of the fonts:

  * f1 - FreeSerif

  * f1b - FreeSerifBold

  * f1bi - FreeSerifBoldItalic

  * f1ob - FreeSerifBoldItalic

Notes: 1. The base font is also the name of the font family. 2. The style characters can be in any order, and the 'i' (italic) and 'o' (oblique) mean the same in this context.

For certain font collections, there are fonts specifically designed to be substitutes for the classic Adobe PostScript fonts: Times, Helvetica, and Courier. Those can be selected by using only the collection character followed by all alphabetic characters. For example, the FreeFonts were designed thusly and they can be referenced this way:

  * ft - Times

  * fh - Helvetica

  * fc - Courier

The URW Base 35 fonts also have Adobe PostScript equivalents:

  * ut - Times

  * uh - Helvetica

  * uc - Courier

Of course the bold or italic (or oblique) styles can indicated in the usual way:

  * utb - TimesBold

AUTHOR
======

Tom Browder <tbrowder@acm.org>

COPYRIGHT AND LICENSE
=====================

© 2024 Tom Browder

This library is free software; you may redistribute it or modify it under the Artistic License 2.0.

