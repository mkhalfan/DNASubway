
use strict;
use warnings;
use IO::File ();
use List::Util qw(sum max);
use DNALC::Pipeline::Phylogenetics::DataSequence ();
use DNALC::Pipeline::Phylogenetics::DataFile ();
use Data::Dumper;
use Digest::MD5;

sub get_sequence {
    my ($ndx) = @_;
    $ndx ||= 0;


    my @seqs = ();
    
	# use "test/dump-abi-files.pl" to dump ABI trace file from a certain project
    my $fh = IO::File->new('/home/cornel/tmp/seq-dump-469.txt');
	while (my $seq = <$fh>) {
        my $qscores = <$fh>;
        chomp $seq;
        chomp $qscores;
        $qscores =~ s/^#//;
        
        my @qscores = split /,/, $qscores;
        #print "@qscores ", $/;
        
        push @seqs, [$seq, \@qscores];
	}

	return $ndx ? $seqs[$ndx] : @seqs;
}

sub _trim_quality_scores {
    my ($quality_scores, $window_size, $threshold) = @_;

    my @quality_scores = @$quality_scores;

    $window_size ||= 20;
    $threshold ||= 20;

    my $trim = 0;

    for (my $i = 0; $i <= $#quality_scores; $i++) {
        #$sum += $_ for @quality_scores[ $i .. ($i + $window_size-1) % $#quality_scores ];
        my $sum = sum(@quality_scores[ $i .. ($i + $window_size-1) % $#quality_scores ]);

		$sum ||= 0;
        
        my $avg = $sum/$window_size;
        
        #print $i, ' -> ', ($i + $window_size-1) , ' = ', $sum, ' // ', $avg, $/;
        #print $i, ' -> ', ($i + $window_size-1) % $#quality_scores, $/;
        
        if ($avg < $threshold) { $trim += 1; }
        else { return $trim; }
    }
    return $trim;
}



sub _trim_sequence_string {
    my ($seq, $window_length, $threshold) = @_;

    $window_length ||= 12;
    $threshold ||= 2;
    my $total = 0;

    for (my $i = 0; $i <= length $seq; $i++) {
        my $window = substr($seq, $i, $window_length);
        my $cnt = () = $window =~ /N/g;
        if (index($window, "N") == 0 || $cnt >= $threshold) {
            $total++;
        }
        else {
            last;
        }
    }
    return $total;

}

sub md5sum {
	my $file = shift;
	my $digest = "";
	eval {
		open(FILE, $file) or die "Can't find file $file\n";
		my $ctx = Digest::MD5->new;
		$ctx->addfile(*FILE);
		$digest = $ctx->hexdigest;
		close(FILE);
	};
	if($@) {
		print $@;
		return "";
	}
	return $digest;
}

#--------------------------------------
# main()
#

my $file_cache = {};
my $counter = {};

my $files = DNALC::Pipeline::Phylogenetics::DataFile->search(file_type => 'trace');
print $files->count, $/;
while (my $f = $files->next) {
	my @qscores = $f->quality_values;
	unless (@qscores) {
		$counter->{noqc}++;
		next 
	}
	my $proj_wd = '/var/www/vhosts/pipeline.dnalc.org/var/projects/phylogenetics';
	my $file_path = -e $f->file_path ? $f->file_path : File::Spec->catfile($proj_wd, $f->file_path);
	my $md5s = md5sum($file_path);
	#print $md5s, $/;
	if (defined $file_cache->{$md5s}) {
		$counter->{dup_files}++;
		next;
	}
	else {
		$file_cache->{$md5s} = 1;
	}
	my $seq = $f->seq;
	#print STDERR  "qscores: @qscores", $/;

	my $trim1 = _trim_sequence_string( $seq );

# 	#print length $seq,  ' == ', scalar @qscores, $/;
# 	print "S: ", substr($seq, 0, 80), $/;
# 	print "S: ", substr($seq, 0, $trim1), $/;
# 	print "Q: ", join(' ', @qscores[0 .. $trim1]), $/;
# 	#print "S: ", join(' ', @qscores[$trim1 .. 40]), $/;

# 	print "Q1: ", join(' ', @removed), $/;
	#print length $seq->[0],  ' == ', scalar @qscores, $/;
	my $trim2 = _trim_quality_scores( \@qscores, 18, 22 );

	# remove $trim1 number of bases
	my @removed = splice(@qscores, 0, $trim1);

	my $trim12 = _trim_quality_scores( \@qscores, 18, 22);

# 	print 'T1: ', $trim1, $/;
# 	print 'T2: ', $trim2, $/;

# 	print "S2: ", substr($seq, 0, $trim1 + $trim2), $/;
# 	print "Q2: ", join (' ', @removed, @qscores[$trim1 .. $trim2]), $/;

	next unless (defined $trim1 && defined $trim2);

	if ($trim2 > $trim1) {
		$counter->{t2}++;
	}
	else {
		$counter->{t1}++;
	}
	
	if (max($trim1, $trim2) == ($trim1 + $trim12)) {
		$counter->{t12}++;
	}
}

print STDERR Dumper( $counter), $/;
