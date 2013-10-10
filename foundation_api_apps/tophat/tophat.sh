#query1=WT_rep1t.fastq
#genome=genome.fas
#annotation=annotation.gtf
#read_mismatches=2
#max_insertion_length=3
#mate_inner_dist=200
#min_intron_length=70
#min_anchor_length=8
#max_multihits=20
#library_type=fr-unstranded
#max_deletion_length=3
#splice_mismatches=0
#max_intron_length=50000
#min_isoform_fraction=0.15
#mate_std_dev=20
#segment_length=20


QUERY1=${query1}
QUERY2=${query2}
GENOME=${genome}
GTF=${annotation}
JOB=${jobName}

output_dir=./tophat_out
Mate_inner_dist=${mate_inner_dist}
Mate_std_dev=${mate_std_dev}
Min_anchor_length=${min_anchor_length}
Splice_mismatches=${splice_mismatches}
Min_intron_length=${min_intron_length}
Max_intron_length=${max_intron_length}
Max_insertion_length=${max_insertion_length}
Max_deletion_length=${max_deletion_length}
Min_isoform_fraction=${min_isoform_fraction}
Max_multihits=${max_multihits}
Segment_length=${segment_length}
Library_type=${library_type}
Read_mismatches=${read_mismatches}

echoerr() { echo "$@" 1>&2; }

tar xzf bin.tgz

export CWD=${PWD}
export PATH="${PATH}:${CWD}/bin"

# Create local temp directory
export TMPDIR="${CWD}/tmp"
mkdir -p $TMPDIR
# Automatically find out how many cores the node
# has and create this many threads
export THREADS=`cat /proc/cpuinfo | grep processor | wc -l`

# Copy reference sequence...
GENOME_F=$(basename ${GENOME})
CHECKSUM=0
echoerr "Copying $GENOME_F"
iget -fT ${GENOME} .


# Quick sanity check before committing to do anything compute intensive
if ! [ -e $GENOME_F ]; then echo "Error: Genome sequence not found."; exit 1; fi

# Create temp .fa
if [[ ! $GENOME_F =~ ".fa$" ]]; then 
    ln -s $GENOME_F ${GENOME_F}.fa;
    echo "Created symbolic link () to $GENOME_F";
fi


for J in 1.bt2 2.bt2 3.bt2 4.bt2 rev.1.bt2 rev.2.bt2
do
    echoerr "I am grabbing ${GENOME}.${J}"
    iget -f "${GENOME}.${J}" .
done

index_files=$(ls *.bt2 2>/dev/null|wc -l)
echoerr "INDEX FILES $index_files"
if ! [[ "$index_files" = "6" ]];then
    echoerr "I am building bowtie2 indices here"
    bowtie2-build -q $GENOME_F $GENOME_F
fi


# Determine pair-end or not
PE=0
if [[ -n $QUERY1 ]] && [[ -n $QUERY2 ]]; then let PE=1; echo "Paired-end"; fi

# Query sequences
QUERY1_F=$(basename ${QUERY1})
iget -fT ${QUERY1} .

QUERY2_F=
if [ "$PE" = "1" ]; then
    QUERY2_F=$(basename ${QUERY2})
    iget -fT ${QUERY2} .
fi

GTF_F==
if [[ -n $GTF ]]; then
    iget -fT ${GTF} .
    GTF_F=$(basename ${GTF})
fi


# Are we Sanger quals or...
QUAL=$(bin/check_qual_score.pl $QUERY1_F)
if [[ -n $QUAL ]]; then
    echoerr "Quality scaling is $QUAL
"
fi


ARGS="--num-threads $THREADS --output-dir $output_dir"
if [[ -n $QUAL  ]];then
    ARGS="$ARGS $QUAL"
fi
if [[ -n $Mate_inner_dist  ]];then
    ARGS="$ARGS --mate-inner-dist $Mate_inner_dist"
fi
if [[ -n $Mate_std_dev  ]];then
    ARGS="$ARGS --mate-std-dev $Mate_std_dev"
fi
if [[ -n $Min_anchor_length  ]];then
    ARGS="$ARGS --min-anchor-length $Min_anchor_length"
fi
if [[ -n $Splice_mismatches  ]];then
    ARGS="$ARGS --splice-mismatches $Splice_mismatches"
fi
if [[ -n $Min_intron_length  ]];then
    ARGS="$ARGS --min-intron-length $Min_intron_length"
fi
if [[ -n $Max_intron_length  ]];then
    ARGS="$ARGS --max-intron-length $Max_intron_length"
fi
if [[ -n $Max_insertion_length  ]];then
    ARGS="$ARGS  --max-insertion-length $Max_insertion_length"
fi
if [[ -n $Max_deletion_length  ]];then
    ARGS="$ARGS --max-deletion-length $Max_deletion_length"
fi
if [[ -n $Min_isoform_fraction  ]];then
    ARGS="$ARGS --min-isoform-fraction $Min_isoform_fraction"
fi
if [[ -n $Max_multihits  ]];then
    ARGS="$ARGS --max-multihits $Max_multihits"
fi
if [[ -n  $Library_type ]];then
    ARGS="$ARGS --library-type $Library_type"
fi
if [[ -n $Segment_length  ]];then
    ARGS="$ARGS --segment-length $Segment_length"
fi
if [[ -n $Read_mismatches  ]];then
    ARGS="$ARGS --read-mismatches $Read_mismatches"
fi
if [[ -n $GTF_F  ]];then
    ARGS="$ARGS  -G $GTF_F"
fi

ARGS="$ARGS $GENOME_F $QUERY1_F $QUERY2_F"

echoerr "Executing tophat $ARGS..."
tophat $ARGS 2> tophat.stderr
echoerr "Done!"

if ! [[ -d $output_dir ]]; then
	echo "ERROR: output dir $output_dir not found"
	exit 1
fi
if ! [[ -f $output_dir/accepted_hits.bam ]]; then
        echo "ERROR: output files not found in $output_dir"
        exit 1
fi

samtools sort  "$output_dir/accepted_hits.bam" "$output_dir/accepted_hits_sorted"
samtools index "$output_dir/accepted_hits_sorted.bam"

name=${QUERY1_F/\.*/}
realName=${name/_processed_reads/}
mv "$output_dir/accepted_hits_sorted.bam" "$output_dir/${realName}-${JOB}.bam"
mv "$output_dir/accepted_hits_sorted.bam.bai" "$output_dir/${realName}-${JOB}.bam.bai"

rm -f *.fa *.bt2 $GTF_F $QUERY1_F $QUERY2_F $GENOME_F $GTF_F
rm -rfv tmp bin

