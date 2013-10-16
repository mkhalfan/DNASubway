#jobName="fxtest$RANDOM"
#seq1='/iplant/home/smckay/fastq/WT_rep1.fastq'
#quality_threshold=20
#min_length=25
#min_quality=20
#percent_bases=50

# Collection of fastx QC utilities for DNA Subway

JOB=${jobName}

# inputs
SEQ1=${seq1}

# fastx trimmer
FIRST=${first}
LAST=${last}
FTRIM=
if [[ -n $FIRST ]] || [[ -n $LAST ]]; then
    FTRIM=1
fi

# fastx quality trimmer
TQUAL=${quality_threshold}
MINLEN=${min_length}
QTRIM=
if [[ -n $TQUAL ]] || [[ -n $MINLEN ]]; then
    QTRIM=1
fi

# fastx quality filter
MQUAL=${min_quality}
MPERCENT=${percent_bases}
QFILT=
if [[ -n $MQUAL ]] || [[ -n $MPERCENT ]]; then
    QFILT=1
fi


tar zxf FastQC.tgz
tar zxf bin.tgz


# A little function to print to STDERR
echoerr() { echo "$@" 1>&2; }

# output directory
OUTDIR=./fastx_out 
mkdir $OUTDIR

# fetch the input file
iget -fT $SEQ1
infile=$(basename $SEQ1)
outfile=${infile/\.*/}
outfile="${OUTDIR}/$outfile";

# Is our fastq file zipped?
zipper=
if [[ "$infile" =~ ".gz" ]]; then
    zipper=gzip
    $zipper -d $infile;
    infile=${infile//.gz/}
    echoerr "Decompressing $infile with $zipper"
fi
if [[ "$infile" =~ ".bz2" ]]; then
    zipper=bzip2
    $zipper -d $infile;
    infile=${infile//.bz2/}
    echoerr "Decompressing $infile with $zipper"
fi
basename=$infile;

ARGS=

# are we Sanger or not?
Q=$(bin/check_qual_score.pl $infile) 

if [[ -n $Q ]]; then
    echoerr "Quality scaling is $Q
";
    ARGS=$Q;
fi


if [[ -n $FTRIM ]]; then
    if [[ -n $FIRST ]]; then
	LARGS="$ARGS -f $FIRST";
    fi
    if [[ -n $LAST ]]; then
	LARGS="$LARGS -l $LAST";
    fi

    outfile="${outfile}.trim";
    echoerr "Running fastx_trimmer $LARGS -i $infile -o ${outfile}..."
    fastx_trimmer $LARGS -i $infile -o $outfile
    echoerr "Done!
        "
    infile=$outfile

    LARGS=''
fi

if [[ -n $QTRIM ]]; then 
    if [[ -n $TQUAL ]]; then
	LARGS="$ARGS -t $TQUAL"
    fi
    if [[ -n $MINLEN ]]; then
	LARGS="$LARGS -l $MINLEN"
    fi


    outfile="${outfile}.qtrim"
    echoerr "Running fastq_quality_trimmer $LARGS -i $infile -o ${outfile}..."
    fastq_quality_trimmer $LARGS -i $infile -o $outfile
    echoerr "Done!
        "
    infile=$outfile

    LARGS=''
fi
    
if [[ -n $QFILT ]]; then
    if [[ -n $MQUAL ]]; then
        LARGS="$ARGS -q $MQUAL"
    fi
    if [[ -n $MPERCENT ]]; then
        LARGS="$LARGS -p $MPERCENT"
    fi

    outfile="${outfile}.qfilt"
    echoerr "Running fastq_quality_filter $LARGS -i $infile -o ${outfile}..."
    fastq_quality_filter $LARGS -i $infile -o $outfile
    echoerr "Done!
        "
fi

mv $outfile ${outfile}.fq
outfile="${outfile}.fq"

base=${basename/\.*/}
final_outfile=${OUTDIR}/${base}-${JOB}.fastq
cp $outfile $final_outfile

echoerr "                                                                                                                                                                                                      
  OUTFILE is $final_outfile                                                                                                                                                                                    
"
cd $OUTDIR

file_to_check=$(basename $final_outfile);

if  [[ -z $file_to_check  ]]; then
    echoerr "hey, the outfile $file_to_check is empty!\n";
    exit 1;
fi

if  ! [[ -e $file_to_check  ]]; then
    echoerr "Hey, the outfile $file_to_check does not exist\n";
    exit 1;
fi


# Since we have trimmed, let's remove the length assertion
# from the sequence headers
echoerr "Removing explit read-lengths from header"
perl -i -pe 's/Length=\d+//i' $file_to_check

# let's also make the file a bit smaller by removing the 
# header
echoerr "Shrinking $file_to_check by removing redundant headers"
../bin/shrink_fq_a_little.pl $file_to_check > smaller_file.fq 
mv smaller_file.fq $file_to_check
 
../FastQC/fastqc *.fastq

if [[ -n $zipper ]]; then
    echoerr "compressing output file with $zipper"
    $zipper $file_to_check
fi

cd ..

rm -f ${basename}*
rm -fr ${OUTDIR}/*filt* ${OUTDIR}/*trim* ${OUTDIR}/*fastqc
rm -rf bin FastQC



