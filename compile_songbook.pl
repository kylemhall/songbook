#!/usr/bin/perl -w

use feature qw( say );

use Modern::Perl;

use Data::Dumper;
use File::stat;

my $chordpros_dir = $ENV{'CHORDPROS_DIR'} || '.';
my $songbook_dir = $ENV{'SONGBOOK_DIR'} || '.';

qx{cd $chordpros_dir} unless $chordpros_dir eq '.';

opendir( DIR, $chordpros_dir );
my @files = grep ( /\.chordpro$/, readdir(DIR) );
closedir( DIR );

@files = sort {
    qx{ git log --format=%aI "$a" | tail -1 }
    cmp
    qx{ git log --format=%aI "$b" | tail -1 }
} @files;

my @songs;
foreach my $file ( @files ) {
    say "FILE: $file";

    # Get date/time file was added to repo in ISO format
    my $dt = qx{git log --format=%aI "$file" | tail -1};

    my $pdf = $file;
    $pdf =~ s/chordpro/pdf/;

    qx{chordpro "$file" -o="$pdf"}; # Generate the PDF

    my $pages = qx{pdftk "$pdf" dump_data | grep NumberOfPages};
    $pages =~ s/NumberOfPages://;

    push(
        @songs,
        {
            chordpro => $file,
            pdf      => $pdf,
            dt       => $dt,
            pages    => $pages
        }
    );
}

@songs = sort { $a->{dt} cmp $b->{dt} } @songs;

my @toc;
my $filler = q{};
my $cmd = q{};
my $previous_song;
my $pages = 1;
foreach my $song ( @songs ) {
    my $title = $song->{pdf};
    $title =~ s/\.pdf$//;
    push( @toc, { page => sprintf("%3s", $pages), title => $title } );
    my $previous_song_pages = $previous_song ? $previous_song->{pages} : 0;
    if ( $previous_song && $previous_song_pages % 2 ) { # Odd number of pages
        if ( $song->{pages} eq '1' ) {                  # If this song is one page, just add it
            $cmd .= qq{"$song->{pdf}" };
        }
        else {
            # If this song is multiple pages, start on a fresh left-hand page
            $cmd .= qq{page.filler "$song->{pdf}" };
            $pages++; # Add one for the filler page
        }
    }
    else { # Even number of pages
        $cmd .= qq{"$song->{pdf}" };
    }
    $previous_song = $song;

    # Regenerate the pdf with the corrected page numbers
    unlink $song->{pdf};
    qx{chordpro -p=$pages "$song->{chordpro}" -o="$song->{pdf}"};
    say qq{chordpro -p=$pages "$song->{chordpro}" -o="$song->{pdf}"};
    $pages += $song->{pages};
}
$cmd .= qq{ songbook.pdf };

my $toc_html = q{};
$toc_html .= "<html><body><pre>";
$toc_html .= "$_->{page} $_->{title}\n" foreach @toc;
$toc_html .= "</pre></body></html>";
open(FH, '>', 'toc.html') or die $!;
print FH $toc_html;
close(FH);
qx{htmldoc --footer . --webpage -f toc.pdf toc.html};
my $toc_pages = qx{pdftk "toc.pdf" dump_data | grep NumberOfPages};
$toc_pages =~ s/NumberOfPages://;
$filler = $toc_pages % 2 ? "page.filler page.filler" : "page.filler";

$cmd = "pdfunite toc.pdf $filler $cmd";
say "CMD: $cmd";
qx{$cmd};

say "Songbook compilation complete!";
say "File: songbook.pdf";

qx{ mv songbook.pdf $songbook_dir/songbook.pdf } unless $songbook_dir eq '.';

unlink $_->{pdf} for @songs;
unlink "toc.html", "toc.pdf";
qx{ cd - } unless $chordpros_dir eq '.';
