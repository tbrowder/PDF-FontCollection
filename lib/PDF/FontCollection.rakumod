unit module PDF::FontCollection;

=begin comment
# freefont locations by OS
my $Ld = "/usr/share/fonts/opentype/freefont";

my $Md = "/opt/homebrew/Caskroom/font-freefont/20120503/freefont-20120503";
my $Wd = "/usr/share/fonts/opentype/freefont";
=end comment

use QueryOS;
use Font::FreeType;
use Font::FreeType::Glyph;
use File::Find;
use Text::Utils :strip-comment;
use Bin::Utils;
use YAMLish;
use PDF::Lite;

# Some hard-wired data for the current font collection by sets
#   (file directories):
my $Ekey = "E"; # E B Garamond
my $Ukey = "U"; # URW Base 35
my $Fkey = "F"; # FreeFonts
my $Lkey = "L"; # Linux Libertine (may need subsets)
my $Ckey = "C"; # Cantrell

# Additional sets may require two or more letters

class FontData {
    use Font::FreeType;

    has $.filename is required;

    has $.adobe-equiv = "";
    has $.colkey      = ""; # one or two letters for the collection key
    has $.famkey      = ""; # digit for alpha order of family in the collection
    has $.style       = ""; # add one or two letters for bold, italic (or oblique)
    has $.code2       = ""; # for the base Adobe names Times, Helvetica, Courier

    my $p;
    my $face;

    submethod TWEAK {
        $p    = $!filename;
        $face = Font::FreeType.new.face: $!filename.Str;

        # need a unique key for each font. based on
        #   collection (directory) 
        #   a number for the alpha order of the family name 
        #   if bold or italic (oblique) add 'b' and 'i' (also recognize 'o'
        #     for italic)
        with $p {
            when / urw '-' base35 / { $!colkey = $Ukey }
            when / ebgaramond     / { $!colkey = $Ekey }
            when / freefont       / { $!colkey = $Fkey }
        }

        # URW fonts and FreeFonts have an Adobe match, so we need to
        # encode that as 'adobe-equiv' and 'code2' for a shorthand
        # version
    }

    method basename        { $p.IO.basename                   }
    method family-name     { $face.family-name                }
    method style-name      { $face.style-name                 }
    method postscript-name { $face.postscript-name            }
    method is-bold         { $face.is-bold   ?? True !! False }
    method is-italic       { $face.is-italic ?? True !! False }
    method font-format     { $face.font-format                }

}

my $o = OS.new;
my $onam = $o.name;

# list of font file directories of primary
# interest on Debian (and Ubuntu)
our @fdirs is export;
with $onam {
    when /:i deb|ubu / {
        @fdirs = <
            /usr/share/fonts/opentype/freefont
            /usr/share/fonts/opentype/urw-base35
            /usr/share/fonts/opentype/ebgaramond
        >;
        =begin comment
        =end comment

        #   /usr/share/fonts/opentype/linux-libertine
        #   /usr/share/fonts/opentype/cantarell
    }
    when /:i macos / {
        @fdirs = <
            /opt/homebrew/Caskroom/font-freefont/20120503/freefont-20120503
        >;
    }
    when /:i windows / {
        @fdirs = <
            /usr/share/fonts/opentype/freefont
        >;
    }
    default {
        die "FATAL: Unhandled OS name: '$_'. Please file an issue."
    }
}

sub help() is export {
    print qq:to/HERE/;
    Usage: {$*PROGRAM.basename} <mode> [...options...]

    Creates various font-related files based on the user's OS
    (recognized operating systems: Debian, Ubuntu, MacOS, and
    Windows.  This OS is '$onam'.

    Modes:
      show   - Show details of font files on STDOUT
      create - Create master lists for generating font data hashes and
               classes for a set of font directories

    Options:
      dir=X  - Where X is the desired font directory for investigation
    HERE
    exit;
}

# options
my $Rshow   = 0;
my $Rcreate = 0;
my $debug   = 0;
my $dir;

sub use-args(@*ARGS) is export {
    for @*ARGS {
        when /^ :i s / {
            ++$Rshow;
        }
        when /^ :i c / {
            ++$Rcreate;
        }
        when /^ :i 'dir=' (\S+) / {
            my $s = ~$0; # must be a directory
            if $s.IO.d {
                $dir = $s;
            }
            else {
                die qq:to/HERE/;
                FATAL: Unknown directory '$s'
                HERE
            }
        }
        when /^ :i d / {
            ++$debug;
        }
        default {
            die "FATAL: Uknown arg '$_'";
        }
    }

    if $debug {
        say "DEBUG is on";
    }

    if $Rcreate {
        my @dirs;
        if $dir.defined {
            @dirs.push: $dir;
        }
        else {
            @dirs = @fdirs;
        }

        for @dirs -> $dir {
            # need a name for the collection
            my $prefix;
            with $dir {
                when /:i freefont / {
                    $prefix = "FreeFonts";
                }
                when /:i urw / {
                    $prefix = "URW-Fonts";
                }
                when /:i ebg / {
                    $prefix = "EBGaramond-Fonts";
                }
                when /:i linux\-liber / {
                    $prefix = "Linux-libertine-Fonts";
                }
                when /:i cantar / {
                    $prefix = "Cantarell-Fonts";
                }
                default {
                    die "FATAL: Unknown font collection '$_'";
                }
            }
            my $jnam = "$prefix.json";

            my @fils = find :$dir, :type<file>, :name(/:i '.' [o|t] tf $/);
            for @fils {
                my %h;
                %h<font-dir> = $dir;
                get-font-info $_, :%h, :$debug;
                if $debug {
                    say "DEBUG: \%h.gist:";
                    say %h.gist;
                    say "debug early exit"; exit;
                }
            }
        }
        exit;
    }

    if $Rshow {
        my @dirs;
        if $dir.defined {
            @dirs.push: $dir;
        }
        else {
            @dirs = @fdirs;
        }

        my %fam; # keyed by family name
        my %nam; # keyed by postscript name

        for @dirs -> $dir {
            my @fils = find :$dir, :type<file>, :name(/:i '.' [o|t] tf $/);
            for @fils {
                my $o = FontData.new: :filename($_);
                my $nam = $o.postscript-name;
                my $fam = $o.family-name;
                %fam{$fam} = 1;
                %nam{$nam} = $_;

         #      say "name: {$o.postscript-name}";
         #      say "  family: {$o.family-name}";

                #show-font-info $_, :$debug;
            }
        }

        my @fams = %fam.keys.sort;
        my @nams = %nam.keys.sort;
        my $idx;

        say "Font family names:";
        $idx = 0;
        for @fams {
            ++$idx;
            say "$idx   $_";
        }

        say "Font PostScript  names:";
        $idx = 0;
        for @nams {
            ++$idx;
            say "$idx   $_";
        }

        exit;
    }
}

sub get-font-info($path, :$debug --> FontData) is export {

    my $filename = $path.Str; # David's sub REQUIRES a Str for the $filename
    my $o = FontData.new: :$filename;

    =begin comment
    # methods in FontData class:
    my $face     = Font::FreeType.new.face($filename);
    %h<basename>        = $path.IO.basename;
    %h<family-name>     = $face.family-name;
    %h<style-name>      = $face.style-name;
    %h<postscript-name> = $face.postscript-name;
    %h<is-bold>         = 1 if $face.is-bold;
    %h<is-italic>       = 1 if $face.is-italic;
    %h<font-format>     = $face.font-format;
    =end comment

    # URW fonts and FreeFonts have an Adobe match, so we need to
    # encode that as 'adobe-equiv' and 'code2' for a shorthand
    # version
    my ($adobe-equiv, $code2);
    =begin comment
    with $face.postscript-name {
        }
        # FreeFonts
        when /:i freeserif $/ {
        when /:i freeserif bold $/ {
        when /:i freeserif italic $/ {
        when /:i freeserif bold italic $/ {

        # URW Fonts
        when // {
        }
    }
    if $debug {
        my $bi = 0;
        my $b  = 0;
        my $i  = 0;
        if %h<is-bold>:exists {
            $bi = 1;
            $b  = 1;
        }
        if %h<is-italic>:exists {
            $bi = 1;
            $i  = 1;
        }
        say "PS name: ", %h<postscript-name>;
        if $bi {
            say "  is-bold"   if $b;
            say "  is-italic" if $i;
        }
    }
    =end comment
}

sub show-font-info($path, :$debug) is export {
    my $filename = $path.Str; # David's sub REQUIRES a Str for the $filename
    my $face = Font::FreeType.new.face($filename);

    say "Path: $filename";
    my $bname = $path.IO.basename;

    say "  Basename: ", $bname;
    say "  Family name: ", $face.family-name;
    say "  Style name: ", $_
        with $face.style-name;
    say "  PostScript name: ", $_
        with $face.postscript-name;
    say "  Format: ", $_
        with $face.font-format;

    my @properties;
    @properties.push: '  Bold' if $face.is-bold;
    @properties.push: '  Italic' if $face.is-italic;
    say @properties.join: '  ' if @properties;

    @properties = ();

    @properties.push: 'Scalable'    if $face.is-scalable;
    @properties.push: 'Fixed width' if $face.is-fixed-width;
    @properties.push: 'Kerning'     if $face.has-kerning;
    @properties.push: 'Glyph names' ~
                      ($face.has-reliable-glyph-names ?? '' !! ' (unreliable)')
      if $face.has-glyph-names;
    @properties.push: 'SFNT'        if $face.is-sfnt;
    @properties.push: 'Horizontal'  if $face.has-horizontal-metrics;
    @properties.push: 'Vertical'    if $face.has-vertical-metrics;
    with $face.charmap {
        @properties.push: 'enc:' ~ .key.subst(/^FT_ENCODING_/, '').lc
            with .encoding;
    }
    #say @properties.join: '  ' if @properties;
    my $prop = @properties.join(' ');
    say "  $prop";


    say "  Units per em: ", $face.units-per-EM if $face.units-per-EM;
    if $face.is-scalable {
        with $face.bounding-box -> $bb {
            say sprintf('  Global BBox: (%d,%d):(%d,%d)',
                        <x-min y-min x-max y-max>.map({ $bb."$_"() }) );
        }
        say "  Ascent: ", $face.ascender;
        say "  Descent: ", $face.descender;
        say "  Text height: ", $face.height;
    }
    say "  Number of glyphs: ", $face.num-glyphs;
    say "  Number of faces: ", $face.num-faces
      if $face.num-faces > 1;
    if $face.fixed-sizes {
        say "  Fixed sizes:";
        for $face.fixed-sizes -> $size {
            say "    ",
            <size width height x-res y-res>\
                .grep({ $size."$_"(:dpi)})\
                .map({ sprintf "$_ %g", $size."$_"(:dpi) })\
                .join: ", ";
        }
    }
}

sub hex2dec($hex, :$debug) is export {
    # converts an input hex sring to a decimal number
    my $dec = parse-base $hex, 16;
    $dec;
}

sub pdf-font-samples(
    # given a list of font files and a text string
    # prints PDF pages in the given font sizes
    @fonts,
    :$text!,
    :$size  = 12,
    :$media = 'Letter',
    :$orientation = 'portrait',
    :$margins = 72,
    :$debug,
    ) is export {
} # sub pdf-font-samples

sub make-page(
              PDF::Lite :$pdf!,
              PDF::Lite::Page :$page!,
              :$font!,
              :$font-size = 10,
              :$title-font!,
              :$landscape = False,
              :$font-name!,
              :%h!, # data
) is export {
    my ($cx, $cy);

    =begin comment
    my $up = $font.underlne-position;
    my $ut = $font.underlne-thickness;
    note "Underline position:  $up";
    note "Underline thickness: $ut";
    =end comment

    # portrait
    # use the page media-box
    $cx = 0.5 * ($page.media-box[2] - $page.media-box[0]);
    $cy = 0.5 * ($page.media-box[3] - $page.media-box[1]);

    if not $landscape {
        die "FATAL: Tom, fix this";
        return
    }

    my (@bbox, @position);


    =begin comment
    $page.graphics: {
        .Save;
        .transform: :translate($page.media-box[2], $page.media-box[1]);
        .transform: :rotate(90 * pi/180); # left (ccw) 90 degrees

        # is this right? yes, the media-box values haven't changed,
        # just its orientation with the transformations
        my $w = $page.media-box[3] - $page.media-box[1];
        my $h = $page.media-box[2] - $page.media-box[0];
        $cx = $w * 0.5;

        # get the font's values from FontFactory
        my ($leading, $height, $dh);
        $leading = $height = $dh = $sm.height; #1.3 * $font-size;

        # use 1-inch margins left and right, 1/2-in top and bottom
        # left
        my $Lx = 0 + 72;
        my $x = $Lx;
        # top baseline
        my $Ty = $h - 36 - $dh; # should be adjusted for leading for the font/size
        my $y = $Ty;

        # start at the top left and work down by leading
        #@position = [$lx, $by];
        #my @bbox = .print: "Fourth page (with transformation and rotation)", :@position, :$font,
        #              :align<center>, :valign<center>;

        # print a page title
        my $ptitle = "FontFactory Language Samples for Font: $font-name";
        @position = [$cx, $y];
        @bbox = .print: $ptitle, :@position,
                       :font($title-font), :font-size(16), :align<center>, :kern;
my $pn = "Page $curr-page of $npages"; # upper-right, right-justified
        @position = [$rx, $y];
        @bbox = .print: $pn, :@position,
                       :font($pn-font), :font-size(10), :align<right>, :kern;

        if 1 {
            note "DEBUG: \@bbox with :align\<center>: {@bbox.raku}";
        }

#        =begin comment
#        # TODO file bug report: @bbox does NOT recognize results of
#        #   :align (and probably :valign)
#        # y positions are correct, must adjust x left by 1/2 width
#        .MoveTo(@bbox[0], @bbox[1]);
#        .LineTo(@bbox[2], @bbox[1]);
#        =end comment
        my $bwidth = @bbox[2] - @bbox[0];
        my $bxL = @bbox[0] - 0.5 * $bwidth;
        my $bxR = $bxL + $bwidth;

#        =begin comment
#        # wait until underline can be centered easily
#
#        # underline the title
#        # underline thickness, from docfont
#        my $ut = $sm.underline-thickness; # 0.703125;
#        # underline position, from docfont
#        my $up = $sm.underline-position; # -0.664064;
#        .Save;
#        .SetStrokeGray(0);
#        .SetLineWidth($ut);
#        # y positions are correct, must adjust x left by 1/2 width
#        .MoveTo($bxL, $y + $up);
#        .LineTo($bxR, $y + $up);
#        .CloseStroke;
#        .Restore;
#        =end comment

        # show the text font value
        $y -= 2* $dh;

        $y -= 2* $dh;

        for %h.keys.sort -> $k {
            my $country-code = $k.uc;
            my $lang = %h{$k}<lang>;
            my $text = %h{$k}<text>;

#            =begin comment
#            @position = [$x, $y];
#            my $words = qq:to/HERE/;
#            -------------------------
#              Country code: {$k.uc}
#                  Language: $lang
#                  Text:     $text
#            -------------------------
#            =end comment

            # print the dashed in one piece
            my $dline = "-------------------------";
            @bbox = .print: $dline, :position[$x, $y], :$font, :$font-size,
                            :align<left>, :kern; #, default: :valign<bottom>;

            # use the @bbox for vertical adjustment [1, 3];
            $y -= @bbox[3] - @bbox[1];

            #  Country code / Language: {$k.uc} / German
            @bbox = .print: "{$k.uc} - Language: $lang", :position[$x, $y],
                    :$font, :$font-size, :align<left>, :!kern;

            # use the @bbox for vertical adjustment [1, 3];
            $y -= @bbox[3] - @bbox[1];

            # print the line data in two pieces
            #     Text:     $text
            @bbox = .print: "Text: $text", :position[$x, $y],
                    :$font, :$font-size, :align<left>, :kern;

            # use the @bbox for vertical adjustment [1, 3];
            $y -= @bbox[3] - @bbox[1];
        }
        # add a closing dashed line
        # print the dashed in one piece
        my $dline = "-------------------------";
        @bbox = .print: $dline, :position[$x, $y], :$font, :$font-size,
                :align<left>, :kern; #, default: :valign<bottom>;

        #=== end of all data to be printed on this page
        .Restore; # end of all data to be printed on this page
    }
    =end comment
} # sub make-page


sub rescale(
    $font,
    :$debug,
    --> Numeric
    ) is export {
    # Given a font object with its size setting (.size) and a string of text you
    # want to be an actual height X, returns the calculated setting
    # size to achieve that top bearing.
} # sub rescale(


sub write-line(
    $page,
    :$font!,  # DocFont object
    :$text!,
    :$x!, :$y!,
    :$align = "left", # left, right, center
    :$valign = "baseline", # baseline, top, bottom
    :$debug,
) is export {

    $page.text: -> $txt {
        $txt.font = $font.font, $font.size;
        $txt.text-position = [$x, $y];
        # collect bounding box info:
        my ($x0, $y0, $x1, $y1) = $txt.say: $text, :$align, :kern;
        # bearings from baseline origin:
        my $tb = $y1 - $y;
        my $bb = $y0 - $y;
        my $lb = $x0 - $x;
	my $rb = $x1 - $x;
        my $width  = $rb - $lb;
        my $height = $tb - $bb;
        if $debug {
            say "bbox: llx, lly, urx, ury = $x0, $y0, $x1, $y1";
            say " width, height = $width, $height";
            say " lb, rb, tb, bb = $lb, $rb, $tb, $bb";
        }
    }
} # sub write-line


sub to-string($cplist, :$debug --> Str) is export {
    # Given a list of hex codepoints, convert them to a string repr
    # the first item in the list may be a string label
    my @list;
    if $cplist ~~ Str {
        @list = $cplist.words;
    }
    else {
        @list = @($cplist);
    }
    if @list.head ~~ Str { @list.shift };
    my $s = "";
    for @list -> $cpair {
        say "char pair '$cpair'" if $debug;
        # convert from hex to decimal
        my $x = parse-base $cpair, 16;
        # get its char
        my $c = $x.chr;
        say "   its character: '$c'" if $debug;
        $s ~= $c
    }
    $s
} # sub to-string($cplist, :$debug --> Str) is export {


=finish

# to be exported when the new repo is created
sub help is export {
    print qq:to/HERE/;
    Usage: {$*PROGRAM.basename} <mode>

    Modes:
      a - all
      p - print PDF of font samples
      d - download example programs
      L - download licenses
      s - show /resources contents
    HERE
    exit
}

sub with-args(@args) is export {
    for @args {
        when /:i a / {
            exec-d;
            exec-p;
            exec-L;
            exec-s;
        }
        when /:i d / {
            exec-d
        }
        when /:i p / {
            exec-p
        }
        when /:i L / {
            exec-L
        }
        when /:i s / {
            exec-s
        }
        default {
            say "ERROR: Unknown arg '$_'";
        }
    }
}

# local subs, non-exported
sub exec-d() {
    say "Downloading example programs...";
}
sub exec-p() {
    say "Downloading a PDF with font samples...";
}
sub exec-L() {
    say "Downloading font licenses...";
}
sub exec-s() {
    say "List of /resources:";
    my %h = get-resources-hash;
    my %m = get-meta-hash;
    my @arr = @(%m<resources>);
    for @arr.sort -> $k {
        say "  $k";
    }
}
