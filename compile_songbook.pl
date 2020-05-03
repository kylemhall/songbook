#!/usr/bin/perl -w

use feature qw( say );

use Modern::Perl;

use Data::Dumper;

opendir( DIR, "." );
my @files = grep ( /\.chordpro$/, readdir( DIR ) );
closedir( DIR );

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
my $cmd = "pdfunite toc.pdf page.filler ";
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
qx{htmldoc --webpage -f toc.pdf toc.html};

qx{$cmd};

unlink $_->{pdf} for @songs;

say "Songbook compilation complete!";
say "File: songbook.pdf";
