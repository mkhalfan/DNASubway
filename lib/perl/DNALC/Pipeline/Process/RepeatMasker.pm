package DNALC::Pipeline::Process::RepeatMasker;

use lib q(/usr/local/RepeatMasker);
use CrossmatchSearchEngine ();

use base q(DNALC::Pipeline::Process);
use File::Path;

use Data::Dumper;
use strict;

{

	sub new {
		my ($class, $project_dir) = @_;

		__PACKAGE__->SUPER::new('REPEAT_MASKER', $project_dir);
	}

	sub _setup {
		my ($self, $project_dir) = @_;

		$self->SUPER::_setup($project_dir);

		# extra work
		if ($self->{conf}->{output_dir}) {
			my $out_dir = $self->{work_dir} . '/' . $self->{conf}->{output_dir};
			unless (-e $out_dir) {
				mkpath($out_dir);
			}
			if (defined $self->{conf}->{option_output_dir}) {
				my $opt_dir = $self->{conf}->{option_output_dir};
				if ($self->{conf}->{option_glue}) {
					push @{$self->{work_options}}, 
						$opt_dir . $self->{conf}->{option_glue} . $out_dir;
				}
				else {
					push @{$self->{work_options}}, (
							$opt_dir, $out_dir
						);
				}
			}
		}
	}


	sub convert2GFF3 {
		my ($self) = @_;

		my $gff_file = $self->{work_dir} . '/' . $self->{conf}->{gff3_file};
		my $dir = $self->{work_dir} . '/' . $self->{conf}->{output_dir};

		#find file to parse
		opendir(DIR, $dir) or die "Can't opendir $dir: $!";
		my @f = grep { /$self->{conf}->{file_to_parse}/ && -f "$dir/$_" } readdir(DIR);
		unless (@f == 1) {
			print STDERR "files: ", Dumper( \@f ), $/;
			print STDERR "RM out file is missing.", $/;
			return;
		}
		
		my $file_to_parse = "$dir/$f[0]";
		#print "file=", $file_to_parse, $/;

		#print "$self->{conf}->{parser_program} $file_to_parse > $gff_file", $/;
		#system("$self->{conf}->{parser_program} $file_to_parse > $gff_file") 
		#	and die "rmOutToGFF3.pl died: $!\n";
		#/usr/local/RepeatMasker/util/rmOutToGFF3.pl
		my $currentQueryName = '';
		my $searchResults =
		    CrossmatchSearchEngine::parseOutput( searchOutput => $file_to_parse );

		my $out = IO::File->new("> $gff_file") 
			or die "Can't write to gff file [$gff_file]: $!\n";
		print $out "##gff-version 3\n";
		for ( my $i = 0 ; $i < $searchResults->size() ; $i++ ) {
			my $result = $searchResults->get( $i );

			# First annotation of a region
			if ( $result->getQueryName() ne $currentQueryName ) {
			  $currentQueryName = $result->getQueryName();

			  # it turns out gff bulk loader complains about this line
			  #print $out "##sequence-region $currentQueryName 1 "
			  #	  . ( $result->getQueryRemaining() + $result->getQueryEnd() ) . "\n";
			}

			# FORMAT:
			#   ##gff-version   3
			#   ##sequence-region   ctg123 1 1497228
			#   SeqID:     QueryName
			#   Source:    Constant - "RepeatMasker"
			#   Type:      similarity => dispersed_repeat
			#   Start:     Query Start
			#   End:       Query End
			#   Score:     New!
			#   Strand:    "+" or "-"
			#   Phase:     0
			#   Attributes: ID=;Name=;Target=FAM 24 180
			print $out "" . $currentQueryName . "\t";
			print $out "RepeatMasker\t";
			print $out "repeat_region\t";
			print $out $result->getQueryStart() . "\t";
			print $out $result->getQueryEnd() . "\t";
			print $out $result->getScore() . "\t";
			if ( $result->getOrientation() eq "C" ) {
			  print $out "-\t";
			}
			else {
			  print $out "+\t";
			}
			print $out ".\t";
			my $type = $result->getSubjType;
			print $out "ID=RepeatMasker$i;Name=RepeatMasker$i-$type;Target="
				. $result->getSubjName . ' '
				. $result->getSubjStart . ' '
				. $result->getSubjEnd . "\n";

			}

			undef $out;
	}


	sub get_gff3_file {
		my ($self) = @_;

		my $gff_file = $self->{work_dir} . '/' . $self->{conf}->{gff3_file};
		return $gff_file if (-e $gff_file);

		$self->convert2GFF3;

		$gff_file = $self->{work_dir} . '/' . $self->{conf}->{gff3_file};
		return $gff_file if (-e $gff_file);
	}
}

1;

