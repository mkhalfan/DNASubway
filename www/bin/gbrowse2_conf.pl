#!/usr/bin/perl 

use lib '/var/www/lib/perl';

use common::sense;

use DNALC::Pipeline::Config ();

my $cf = DNALC::Pipeline::Config->new->cf('PIPELINE');

my $username = $ARGV[0];
my $pid = $ARGV[1];

my $file = File::Spec->catfile($cf->{GBROWSE2_CONF_DIR}, 'user_configs', sprintf("%s_db_%d.conf", $username, $pid));


#print STDERR  $file, $/;
#print $file, $/;

open(FILE, $file) or die "Couldn't open $file: $!";
while (<FILE>){
	print $_;
}
close(FILE);

