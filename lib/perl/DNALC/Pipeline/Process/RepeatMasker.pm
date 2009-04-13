package DNALC::Pipeline::Process::RepeatMasker;

use lib q(/usr/local/RepeatMasker);
use CrossmatchSearchEngine ();

use base q(DNALC::Pipeline::Process);
use Data::Dumper;
#use strict;

{

	sub new {
		my ($class, $project_dir) = @_;

		__PACKAGE__->SUPER::new('REPEAT_MASKER', $project_dir);
	}

	sub convert2GFF3 {
		my ($self) = @_;

		#print "output_dir = ", $self->{conf}->{output_dir}, $/;
		my $gff_file = $self->{work_dir} . '/' . $self->{conf}->{gff3_file};
		my $dir = $self->{conf}->{output_dir};

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
		my $currentQueryName;
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
			  print $out "##sequence-region $currentQueryName 1 "
				  . ( $result->getQueryRemaining() + $result->getQueryEnd() ) . "\n";
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
				. $result->getSubjName . ";start="
				. $result->getSubjStart . ";end="
				. $result->getSubjEnd . "\n";

			}

			undef $out;
	}

	sub convert2GFF3_save {
		my ($self) = @_;

		#print "output_dir = ", $self->{conf}->{output_dir}, $/;
		my $gff_file = $self->{work_dir} . '/' . $self->{conf}->{gff3_file};
		my $dir = $self->{conf}->{output_dir};

		#find file to parse
		opendir(DIR, $dir) or die "Can't opendir $dir: $!";
		my @f = grep { /$self->{conf}->{file_to_parse}/ && -f "$dir/$_" } readdir(DIR);
		unless (@f == 1) {
			print STDERR "files: ", Dumper( \@f ), $/;
			print STDERR "RM gff2 file is missing.", $/;
			return;
		}
		
		my $file_to_parse = "$dir/$f[0]";
		print "file=", $file_to_parse, $/;
		my $counter = 1;

		my $in  = IO::File->new($file_to_parse) or die "Can't open gff2 file: $!\n";
		my $out = IO::File->new("> $gff_file") 
			or die "Can't write to gff file [$gff_file]: $!\n";
		print $out "##gff-version 3\n";
		while (<$in>) {
			next if /^#/;
			next if /^$/;
			my @d = split /\s+/;
			next if @d < 8;
			my ($seq_name, $start, $end, $score, $strand, $name) = @d[0, 3 .. 7];
			#my $strand = substr $d[6], 0, 1;
			$strand = substr $strand, 0, 1;
			my $num = sprintf("%04d", $counter);
			if ($name =~ /"Motif:(.*?)"/) {
				$name = $1;
			}
			print $out "$seq_name\tRepeatMasker\trepeat_region\t$start\t$end\t$score\t$strand\t.\tID=RepeatMasker$num;Name=RepeatMasker-$name-$num\n";

			$counter++;
		}

		undef $in;
		undef $out;
	}

	sub get_gff3_file {
		my ($self) = @_;

		$self->convert2GFF3;

		my $gff_file = $self->{work_dir} . '/' . $self->{conf}->{gff3_file};
		return $gff_file if (-e $gff_file);
	}
}

1;

