#!/usr/bin/perl -w

use feature qw(say);

use Modern::Perl;

use Data::Dumper;

opendir( DIR, "." );
my @files = grep( /\.chordpro$/, readdir(DIR) );
closedir(DIR);

my @songs;
foreach my $file (@files) {
    say "FILE: $file";

    # Get date/time file was added to repo in ISO format
    my $dt = qx{git log --format=%aI "$file" | tail -1};

    my $pdf = $file;
    $pdf =~ s/chordpro/pdf/;

    qx{chordpro "$file" -o="$pdf"};    # Generate the PDF

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

my $cmd = "pdfunite page.filler ";
my $previous_song;
foreach my $song (@songs) {
    my $previous_song_pages = $previous_song ? $previous_song->{pages} : 0;
    if ( $previous_song && $previous_song_pages % 2 ) {    # Odd number of pages
        if ( $song->{pages} eq '1' ) {   # If this song is one page, just add it
            $cmd .= qq{"$song->{pdf}" };
        }
        else { # If this song is multiple pages, start on a fresh left-hand page
            $cmd .= qq{page.filler "$song->{pdf}" };
        }
    }
    else {     # Even number of pages
        $cmd .= qq{"$song->{pdf}" };
    }
    $previous_song = $song;
}
$cmd .= qq{ songbook.pdf};

qx{$cmd};

#unlink $_->{pdf} for @songs;

say "Songbook compilation complete!";
say "File: songbook.pdf";
