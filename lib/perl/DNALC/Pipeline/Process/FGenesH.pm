package DNALC::Pipeline::Process::FGenesH;

use base q(DNALC::Pipeline::Process);
use IO::File ();
use Bio::Tools::Fgenesh ();

use Data::Dumper;
use strict;

{
	sub new {
		my ($class, $project_dir, $group) = @_;

		my $self = __PACKAGE__->SUPER::new('FGENESH', $project_dir);

		$group ||= 'Monocots';
		$self->{group} = $group;
		if ($group eq 'Monocots') {
			unshift @{ $self->{work_options} }, $self->{conf}->{monocots_matrix};
		}
		elsif ($group eq 'Dicots') {
			unshift @{ $self->{work_options} }, $self->{conf}->{dicots_matrix};
		}

		return $self;
	}

	sub get_gff3_file {
		my ($self) = @_;

		my $dir = $self->{work_dir};
		my $gff_file = $dir . '/' . $self->{conf}->{gff3_file};
		return $gff_file if (-e $gff_file);


		#find file to parse
		opendir(DIR, $dir) or die "Can't opendir $dir: $!";
		my @f = grep { /$self->{conf}->{file_to_parse}/ && -f "$dir/$_" } readdir(DIR);
		unless (@f == 1) {
			print STDERR "FGENESH: output file is missing.", $/;
			return;
		}
		closedir DIR;

		my $program = 'FGenesH' . '_' . $self->{group};
		my $gene_count = 0;
		my $seq_id;

		my $file_to_parse = "$dir/$f[0]";

		my $out = IO::File->new("> $gff_file") 
			or die "Can't write to gff file [$gff_file]: $!\n";

		my $fgenesh = Bio::Tools::Fgenesh->new(-file => $file_to_parse);

		while(my $gene = $fgenesh->next_prediction) {

			my $loc = $gene->location;
			$gene_count++;
			$seq_id = $seq_id ? $seq_id : $gene->seq_id ;

			my $gene_name = sprintf("Name=FGENESH%03d", $gene_count);
			my $gene_id = sprintf("gf%03d", $gene_count);
			my $strand = $loc->strand > 0 ? '+' : '-';
			my @exons = $gene->exons;

			next unless @exons; #?!?!

			print $out $seq_id . "\t" . $program . "\t" . 'gene' . "\t"
						. $loc->start . "\t"	. $loc->end . "\t" . '.' . "\t"
						. $strand . "\t" . '.' . "\t". "$gene_name;ID=$gene_id\n";

			# compute mRNA location
			my $mstart = $exons[0]->location->start;
			my $mend = $exons[ $#exons ]->location->end;

			print $out $seq_id . "\t" . $program . "\t" . 'mRNA' . "\t"
						. $mstart . "\t"	. $mend . "\t" . '.' . "\t"
						. $strand . "\t" . '.' . "\t". "ID=$gene_id.1;Parent=$gene_id\n";
			
			for my $e ( @exons ) {
				my $loc = $e->location;
				print $out $seq_id . "\t" . $program . "\t" . 'exon' . "\t"
						. $loc->start . "\t"	. $loc->end . "\t" . sprintf("%.2f", $e->score) . "\t"
						. $strand . "\t" . '.' . "\t". "Parent=$gene_id.1\n";
			}

		}

		$fgenesh->close;
		undef $out;
		#end parse file

		return $gff_file if (-e $gff_file);

	}


}

1;

