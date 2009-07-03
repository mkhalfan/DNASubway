#!/usr/bin/perl -w
use warnings;
use strict;

use Bio::DB::Das::Chado ();
use Bio::GMOD::Config ();
use Bio::GMOD::DB::Config ();
use IO::File ();
use Getopt::Long;
use Pod::Usage;

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


my ($PROFILE, $FILE, $SEQID, $HELP);

GetOptions(
  'profiles=s'	=> \$PROFILE,
  'file=s'		=> \$FILE,
  'seqid=s'		=> \$SEQID,
  'help'		=> \$HELP,
) or pod2usage(-verbose => 1, -exitval => 1);

pod2usage (-verbose => 2, -exitval => 1) if $HELP;

die 'Profile is missing.' unless $PROFILE;
die 'File is missing' unless $FILE;
die 'Sequence ID is missing' unless $SEQID;

my $fh = IO::File->new;
unless ($fh->open($FILE, 'w')) {
	print STDERR  "FILE [$FILE] is not writable", $/;
	exit 0;
}

my $gmod_conf = Bio::GMOD::Config->new();
my $db_conf   = Bio::GMOD::DB::Config->new($gmod_conf, $PROFILE);

my $driver = $db_conf->driver || 'Pg';
my $dsn = "dbi:$driver:dbname=".$db_conf->name();
$dsn .= ";host=".$db_conf->host if $db_conf->host;
$dsn .= ";port=".$db_conf->port if $db_conf->port;

my $db = Bio::DB::Das::Chado->new(
            -dsn  => $dsn,
            -user => $db_conf->user || '',
            -pass => $db_conf->password || '',
            -inferCDS => 1,
         );
my @features = $db->features(-type   =>'gene:user',
                             -seq_id => $SEQID,
						 );

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

