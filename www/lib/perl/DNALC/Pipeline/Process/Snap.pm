#
#===============================================================================
#
#         FILE:  Snap.pm
#
#  DESCRIPTION:  
#
#        FILES:  ---
#         BUGS:  ---
#        NOTES:  ---
#       AUTHOR:  Cornel Ghiban (), ghiban@cshl.edu
#      COMPANY:  DNALC, Cold Spring Harbor
#      VERSION:  1.0
#      CREATED:  06/01/09 11:17:56
#     REVISION:  ---
#===============================================================================
package DNALC::Pipeline::Process::Snap;
use strict;
use warnings;
use Data::Dumper;

use base q(DNALC::Pipeline::Process);

{
	sub new {
		my ($class, $project_dir, $clade) = @_;

		my $self = __PACKAGE__->SUPER::new('SNAP', $project_dir);

		my $species_map = $self->{conf}->{species_map};
		if (defined $species_map && %$species_map) {
			unless ($clade && $clade =~ /^(?:m|d|h|a|f)$/) {
				$clade = 'default';
			}
			$self->{clade} = $clade;
			if (defined $species_map->{$clade}) {
				unshift @{ $self->{work_options} }, $species_map->{$clade};
			}
		}

		return $self;
	}

	sub get_gff3_file {
		my ($self, $dont_parse) = @_;
		my $dir = $self->{work_dir};
		my $gff_file = $dir . '/' . $self->{conf}->{gff3_file};
		return $gff_file if (-e $gff_file || $dont_parse);

		#find file to parse
		opendir(DIR, $dir) or die "Can't opendir $dir: $!";
		my @f = grep { /$self->{conf}->{file_to_parse}/ && -f "$dir/$_" } readdir(DIR);
		unless (@f == 1) {
			print STDERR "FGENESH: output file is missing.", $/;
			return;
		}
		closedir DIR;

		my $file = "$dir/$f[0]";
		#print STDERR  "FILE = ", $file, $/;

		my $in  = IO::File->new;
		my $out = IO::File->new;
		if ($in->open($file, 'r') && $out->open($gff_file, 'w')) {
			my $last_gene = '';
			my $snippet = '';
			my %genes = ();
			while (<$in>) {
				chomp;
				next if $_ =~ /^#/;
				next if $_ =~ /\tEsngl\t/;
				my @data = split /\t/;
				next if @data != 9;
				$data[8] =~ s/\.(\d+)$/sprintf(".%03d", $1)/e;
				my $gene_name = $data[8];
				if (exists $genes{$gene_name}) {
					push @{$genes{$gene_name}->{data}}, \@data;
					#$genes{$gene_name}->{end} = $data[4];
					# start <= minimum of the 3rd column
					$genes{$gene_name}->{start} = $data[3] < $genes{$gene_name}->{start}
													? $data[3]
													: $genes{$gene_name}->{start};
					# end <= maximum of the 4th column
					$genes{$gene_name}->{end} = $data[4] > $genes{$gene_name}->{end}
													? $data[4]
													: $genes{$gene_name}->{end};
				}
				else {
					$genes{$gene_name}->{data} = [\@data];
					$genes{$gene_name}->{sign} = $data[6];
					$genes{$gene_name}->{start} = $data[3];
					$genes{$gene_name}->{end} = $data[4];
				}

			}

			my $gene_cnt = 1;
			foreach my $gene_name (sort keys %genes) {
				my $g = $genes{$gene_name};
				my @data = @{$genes{$gene_name}->{data} };
				#if ($g->{sign} eq '-' && $g->{start} > $g->{end}) {
				#	($g->{start}, $g->{end}) = ($g->{end}, $g->{start});
				#}
				print $out $data[0]->[0], "\t", $data[0]->[1], "\tgene\t", $g->{start}, "\t", $g->{end}, 
							"\t0\t", $g->{sign}, "\t.\t", "ID=g$gene_name;Name=SNAPGENE.$gene_cnt", "\n";
				print $out $data[0]->[0], "\t", $data[0]->[1], "\tmRNA\t", $g->{start}, "\t", $g->{end}, 
							"\t0\t", $g->{sign}, "\t.\t", "ID=m$gene_name;Parent=g$gene_name", "\n";
				for (@data) {
					my $col3 = $_->[2];
					$col3 =~ s/(?:Eterm|Einit|Exon)/CDS/;
					$_->[2] = $col3;
					$_->[8] = "Parent=m" . $_->[8];
					print $out join ("\t", @$_), "\n";

					$col3 =~ s/CDS/exon/;
					$_->[2] = $col3;
					print $out join ("\t", @$_), "\n";
				}
				$gene_cnt++;
			}
		}
		undef $in;
		undef $out;

		return $gff_file if (-e $gff_file);
	}

}

1;

