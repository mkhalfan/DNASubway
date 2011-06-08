package DNALC::Pipeline::Miner::Bold;

#use URI::Escape;

use Data::Dumper;
use HTTP::Tiny ();
use JSON::XS ();
use XML::Simple;
use IO::Uncompress::Gunzip qw(gunzip $GunzipError);
use DNALC::Pipeline::Utils qw(random_string);

{
	my $base_url = "http://services.boldsystems.org/eFetch.php";
	
	my $id_type = "processid";  #ex: id_type=processid
	my $record_type = "full";   #ex: record_type=full
	my $file_type = "gzip";     #ex: file_type=gzip
	my $return_type = "xml";    #ex: return_type=xml

	my $query = "?id_type=$id_type&record_type=$record_type&file_type=$file_type&return_type=$return_type&ids=";

	sub new {
		my ($class, $work_dir);
		return bless {
				work_dir => $work_dir || "/tmp",
				xml_file => undef,
			}, __PACKAGE__;
	}

	sub extract {
		my ($self, $input, $store_path) = @_;
		my $status = gunzip $input => $store_path
			or do { print STDERR "gunzip failed: $GunzipError\n";};
		return $status;
	}

	sub build_uri{
		my ($ids) = @_;
		my $uri = $base_url . $query . '(' . $ids . ')';
		return $uri;
	}


	sub fetch {
		my ($self, $ids) = @_;
		my $ht = HTTP::Tiny->new(timeout => 30);
		#	print $base_url . $query, "\n";
		#my $response = $ht->get($base_url . $query);
		my $response = $ht->get(build_uri($ids));
		if ($response->{success} && length $response->{content}){
			#return "header: ", %{$response->{headers}};
			#return $response->{content};
			my $data = $response->{content};

			my $store_path = File::Spec->catfile($self->{work_dir}, "bold_" . random_string(5,10));
			#print STDERR  "Extracted file: ", $store_path, $/;
			$self->extract(\$data, $store_path);
			if (-f $store_path) {
				$self->{xml_file} = $store_path;
				return $store_path;
			}
		}
		else{
			return "error \n";
		}


	}

	sub store_sequence {
		my ($self) = @_;
		my $xml = XMLin($self->{xml_file});
		#use Data::Dumper; 
		#print STDERR Dumper( $xml), $/;
		if ($xml->{record}){
			my $seq_id = $xml->{record}->{recordID};
			if ($xml->{record}->{taxonomy}->{species}->{taxon}->{name}){
				$seq_id = $seq_id . "|" . $xml->{record}->{taxonomy}->{species}->{taxon}->{name}
			}
			$seq_id =~ s/\s+/_/;
			$seq_id = $seq_id . "\n";
			my $seq = $xml->{record}->{sequences}->{sequence}->{nucleotides};
			my $fasta = File::Spec->catfile($self->{work_dir}, random_string(4,8));
			my $fh = IO::File->new;
			if ($fh->open($fasta, 'w' )) {
				print $fh ">$seq_id";
				print $fh $seq;
			}
			return $fasta if -f $fasta;
		}
	}

	sub DESTROY {
		my ($self) = @_;
		if (-f  $self->{xml_file}) {
			#print STDERR  "rm: ", $self->{xml_file}, $/;
			unlink $self->{xml_file};
		}
	}


}
__END__
package main;

use common::sense;

sub main {
	#my $bold = DNALC::Pipeline::Miner::Bold->new($pm->work_dir);
	my $bold = DNALC::Pipeline::Miner::Bold->new();
#	my $tmp_xml =
#	#$bold->fetch('?id_type=processid&ids=(WEEMX018-10)&record_type=full&file_type=gzip&return_type=xml');
#	$bold->fetch('?id_type=processid&ids=(mk2)&record_type=full&file_type=gzip&return_type=xml');
	$bold->fetch(1);
	#print $tmp_xml;
	my $fasta = $bold->store_sequence;
	print "Fasta: ", $fasta, $/;
}

main();
