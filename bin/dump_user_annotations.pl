#!/usr/bin/perl -w
use warnings;
use strict;

use Bio::DB::Das::Chado ();
use IO::File ();
use Getopt::Long;
use Pod::Usage;
use Data::Dumper;

=head1 NAME

dump_user_annotations.pl - Dumps user annotations for a certain seq_id

=head1 SYNOPSIS

  % dump_user_annotations.pl --username <name> --file <path> --seqid <seqence_id>

=head1 AUTHORS

Scott Cain E<lt>cain.cshl@gmail.orgE<gt>, Cornel Ghiban E<lt>ghiban@cshl.eduE<gt>

Copyright (c) 2009

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


my ($USERNAME, $FILE, $SEQID, $HELP);

GetOptions(
  'username=s'	=> \$USERNAME,
  'file=s'		=> \$FILE,
  'seqid=s'		=> \$SEQID,
  'help'		=> \$HELP,
) or pod2usage(-verbose => 1, -exitval => 1);

pod2usage (-verbose => 2, -exitval => 1) if $HELP;

die 'Username is missing.' unless $USERNAME;
die 'File is missing' unless $FILE;
die 'Sequence id is missing' unless $SEQID;


my $fh = IO::File->new;
unless ($fh->open($FILE, 'w')) {
	print STDERR  "FILE [$FILE] is not writable", $/;
	exit 0;
}

my $db = Bio::DB::Das::Chado->new(
            -dsn  => 'dbi:Pg:dbname=' . $USERNAME,
            -user => 'cain',
            -inferCDS => 1,
         );
#my $seq_id = 'mouse_ear_cress_411';
my @features = $db->features(-type   =>'gene:user',
                             -seq_id => $SEQID,);
#                             -start  => 1,
#                             -end    => 20000,);

for my $f (@features) {
	$f->seq_id($SEQID);

    print_gff($f, 'g');


    my @mrnas = $f->sub_SeqFeature();

    for my $m (@mrnas) {
        print_gff($m, 'm');

        my @kids = $m->sub_SeqFeature();
        for my $k (@kids) {
            print_gff($k, 'k');

        }
    }
}

undef $fh;

sub print_gff {
    my $obj = shift;
    my $rank= shift;

    my $ref    = $obj->seq_id;
    my $source = $obj->type->source;
    my $type   = $obj->type->method;
    my $start  = $obj->start;
    my $end    = $obj->end;
    my $strand = $obj->strand;
    my $name   = $obj->uniquename;

    my $col9;
    if ($rank eq 'g') {
        $col9 = "ID=$name";
    }
    elsif ($rank eq 'm') {
        my $parent_name = $obj->parent->uniquename;
        $col9 = "Parent=$parent_name;ID=$name";
    }
    elsif ($rank eq 'k') {
        my $parent_name = $obj->parent->uniquename;
        $col9 = "Parent=$parent_name";
    }

    print $fh join("\t",$ref,
                    $source ? $source : '.',
                    $type,
                    $start,
                    $end,
                    '.',
                    $strand > 0 ? '+' : '-',
                    '.',
                    $col9), "\n";
}

