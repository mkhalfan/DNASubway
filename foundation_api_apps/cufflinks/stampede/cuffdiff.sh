# A little function to print to STDERR
echoerr() { echo "$@" 1>&2; }

JOB=${jobName}

# GTF files to merge
QUERY1=${query1}
QUERY2=${query2}
QUERY3=${query3}
QUERY4=${query4}
QUERY5=${query5}
QUERY6=${query6}
QUERY7=${query7}
QUERY8=${query8}
QUERY9=${query9}
QUERY10=${query10}
QUERY11=${query11}
QUERY12=${query12}

# Up to ten samples, up to four replicates each
# sam1_1,sam1_2,sam1_3,sam1_4...sam10_1,sam10_2,sam10_3,sam10_4
SAM1_F1=${sam1_f1}
SAM1_F2=${sam1_f2}
SAM1_F3=${sam1_f3}
SAM1_F4=${sam1_f4}
SAM2_F1=${sam2_f1}
SAM2_F2=${sam2_f2}
SAM2_F3=${sam2_f3}
SAM2_F4=${sam2_f4}
SAM3_F1=${sam3_f1}
SAM3_F2=${sam3_f2}
SAM3_F3=${sam3_f3}
SAM3_F4=${sam3_f4}
SAM4_F1=${sam4_f1}
SAM4_F2=${sam4_f2}
SAM4_F3=${sam4_f3}
SAM4_F4=${sam4_f4}
SAM5_F1=${sam5_f1}
SAM5_F2=${sam5_f2}
SAM5_F3=${sam5_f3}
SAM5_F4=${sam5_f4}
SAM6_F1=${sam6_f1}
SAM6_F2=${sam6_f2}
SAM6_F3=${sam6_f3}
SAM6_F4=${sam6_f4}
SAM7_F1=${sam7_f1}
SAM7_F2=${sam7_f2}
SAM7_F3=${sam7_f3}
SAM7_F4=${sam7_f4}
SAM8_F1=${sam8_f1}
SAM8_F2=${sam8_f2}
SAM8_F3=${sam8_f3}
SAM8_F4=${sam8_f4}
SAM9_F1=${sam9_f1}
SAM9_F2=${sam9_f2}
SAM9_F3=${sam9_f3}
SAM9_F4=${sam9_f4}
SAM10_F1=${sam10_f1}
SAM10_F2=${sam10_f2}
SAM10_F3=${sam10_f3}
SAM10_F4=${sam10_f4}

# Supplemental files
REFGTF=${ref_gtf}
REFSEQ=${ref_seq}

# --mask-file optional
MASK=${mask_gtf}

tar zxf ./bin.tgz
tar zxf ./R.tgz
tar zxf ./annotations.tgz

path=$(pwd);
export PATH=$PATH:${path}/bin

# get GTF and ref files
REFGTF_F=${REFGTF##*/}
iget -fT $REFGTF
REFGTF=$REFGTF_F

REFSEQ_F=${REFSEQ##*/}
iget -fT $REFSEQ
REFSEQ=$REFSEQ_F;

MASK_F= 
if [[ -n $MASK ]]; then
  MASK_F=${MASK##*/}
  iget -fT $MASK
fi



MANIFEST=gtf_to_merge.txt

touch $MANIFEST

QUERY3_F=
QUERY4_F=
QUERY3_F=
QUERY4_F=
QUERY5_F=
QUERY6_F=
QUERY7_F=
QUERY8_F=
QUERY9_F=
QUERY10_F=
QUERY11_F=
QUERY12_F=

if [[ -n $QUERY1 ]]; then
    QUERY1_F=${QUERY1##*/}
    iget -fT $QUERY1 .
    echo $QUERY1_F >> $MANIFEST
fi
if [[ -n $QUERY2 ]]; then
    QUERY2_F=${QUERY2##*/}
    iget -fT $QUERY2 .
    echo $QUERY2_F >> $MANIFEST
fi
if [[ -n $QUERY3 ]]; then
    QUERY3_F=${QUERY3##*/}
    iget -fT $QUERY3 .
    echo $QUERY3_F >> $MANIFEST
fi
if [[ -n $QUERY4 ]]; then
    QUERY4_F=${QUERY4##*/}
    iget -fT $QUERY4 .
    echo $QUERY4_F >> $MANIFEST
fi
if [[ -n $QUERY5 ]]; then
    QUERY5_F=${QUERY5##*/}
    iget -fT $QUERY5 .
    echo $QUERY5_F >> $MANIFEST
fi
if [[ -n $QUERY6 ]]; then
    QUERY6_F=${QUERY6##*/}
    iget -fT $QUERY6 .
    echo $QUERY6_F >> $MANIFEST
fi
if [[ -n $QUERY7 ]]; then
    QUERY7_F=${QUERY7##*/}
    iget -fT $QUERY7 .
    echo $QUERY7_F >> $MANIFEST
fi
if [[ -n $QUERY8 ]]; then
    QUERY8_F=${QUERY8##*/}
    iget -fT $QUERY8 .
    echo $QUERY8_F >> $MANIFEST
fi
if [[ -n $QUERY9 ]]; then
    QUERY9_F=${QUERY9##*/}
    iget -fT $QUERY9 .
    echo $QUERY9_F >> $MANIFEST
fi
if [[ -n $QUERY10 ]]; then
    QUERY10_F=${QUERY10##*/}
    iget -fT $QUERY10 .
    echo $QUERY10_F >> $MANIFEST
fi
if [[ -n $QUERY11 ]]; then
    QUERY11_F=${QUERY11##*/}
    iget -fT $QUERY11 .
    echo $QUERY11_F >> $MANIFEST
fi
if [[ -n $QUERY12 ]]; then
    QUERY12_F=${QUERY12##*/}
    iget -fT $QUERY12 .
    echo $QUERY12_F >> $MANIFEST
fi


THREADS=$(cat /proc/cpuinfo | grep processor | wc -l)

echoerr "Inspecting list of GTF files to merge..."
lines=$(cat $MANIFEST | wc -l)
unique=$(sort -u $MANIFEST | wc -l)

if ! [[ $unique -eq $lines ]]; then
    echoerr "Error: Each GTF file to be merged must have a unique filename"
    exit 1
fi

if ! [[ $unique -ge 2 ]]; then
    echoerr "Error: at least two GTF files are required for merging"
    exit 1
fi

if [[ -n $lines ]]; then
  ARGS="-p $THREADS -o cuffmerge_out -g $REFGTF -s $REFSEQ $MANIFEST";
  echoerr "Executing cuffmerge ${ARGS}..."
  cuffmerge $ARGS 
  cuffmerge_munge_ids.pl

  MERGEDONE=$(ls -alh cuffmerge_out)
  echoerr "DONE!
  $MERGEDONE
  "

  ANNOTATION='./cuffmerge_out/merged_with_ref_ids.gtf'
  OK=$(head -1 $ANNOTATION)
  if ! [[ -n $OK ]];then
    echoerr "No point going on, cuffmerge failed"
    exit 1
  fi
fi

if ! [[ -n $ANNOTATION ]]; then
  $ANNOTATION = $REFGTF
fi


# Conditional flags
# 0
treatAsTimeSeries=${treatAsTimeSeries}
# 0
multiReadCorrect=${multiReadCorrect}
# 0
upperQuartileNorm=${upperQuartileNorm}
# 0
totalHitsNorm=${totalHitsNorm}
# 1
compatibleHitsNorm=${compatibleHitsNorm}
# 0  --poisson-dispersion
poissonDispersion=${poissonDispersion}

# Mandatory parameters
# --min-alignment-count 10
MINALIGNMENTCOUNT=${minAlignmentCount}
# --FDR 0.05
FDR=${fdr}
# Force Replace spaces with empty characters
LABELS=${labels}
LABELS=${LABELS//\ /}

# --library-type fr-unstranded
LIBRARYTYPE=${libraryType}

OUTPUT_DIR=./cuffdiff_out

# Optional
# --frag-len-mean 200
FRAGLENMEAN=${fragLenMean}
# --frag-len-std-dev 80
FRAGLENSTDEV=${fragLenStdev}

# Create local temp directory
export TMPDIR="${CWD}/tmp"
mkdir -p $TMPDIR

# Fetch alignment files
SAM1_F=''
SAM1_F1=${SAM1_F1##*/}
iget -fT ${sam1_f1} .
SAM1_F=$SAM1_F1
if ! [[ -s $SAM_1F ]]; then;
    echoerr "$SAM1_F is missing! Abort!"
    exit 1
fi

if [[ -n $SAM1_F2 ]]; then
    SAM1_F2=${SAM1_F2##*/}
    iget -fT ${sam1_f2} .
    SAM1_F="$SAM1_F,$SAM1_F2"
fi

if [[ -n $SAM1_F3 ]]; then
    SAM1_F3=${SAM1_F3##*/}
    iget -fT ${sam1_f3} .
    SAM1_F="$SAM1_F,$SAM1_F3"
fi

if [[ -n $SAM1_F4 ]]; then
    SAM1_F4=${SAM1_F4##*/}
    iget -fT ${sam1_f3} .
    SAM1_F="$SAM1_F,$SAM1_F4"
fi

echoerr "
SAM1 files $SAM1_F
"

SAM2_F=''
SAM2_F1=${SAM2_F1##*/}
iget -fT ${sam2_f1} .
SAM2_F=$SAM2_F1

if [[ -n $SAM2_F2 ]]; then
    SAM2_F2=${SAM2_F2##*/}
    iget -fT ${sam2_f2} .
    SAM2_F="$SAM2_F,$SAM2_F2"
fi

if [[ -n $SAM2_F3 ]]; then
    SAM2_F3=${SAM2_F3##*/}
    iget -fT ${sam2_f3} .
    SAM2_F="$SAM2_F,$SAM2_F3"
fi

if [[ -n $SAM2_F4 ]]; then
    SAM2_F4=${SAM2_F4##*/}
    iget -fT ${sam2_f4} .
    SAM1_F="$SAM2_F,$SAM2_F4"
fi

echoerr "
SAM2 files $SAM2_F                                                                                                                                                   
"

SAM3_F=""
if [[ -n $SAM3_F1 ]]; then
    SAM3_F1=${SAM3_F1##*/}
    iget -fT ${sam3_f1} .
    SAM3_F=$SAM3_F1
fi

if [[ -n $SAM3_F2 ]]; then
    SAM3_F2=${SAM3_F2##*/}
    iget -fT ${sam_f2} .
    SAM3_F="$SAM3_F,$SAM3_F2"
fi

if [[ -n $SAM3_F3 ]]; then
    SAM3_F3=${SAM3_F3##*/}
    iget -fT ${sam3_f3} .
    SAM3_F="$SAM3_F,$SAM3_F3"
fi

if [[ -n $SAM3_F4 ]]; then
    SAM3_F4=${SAM3_F4##*/}
    iget -fT ${sam3_f4} .
    SAM3_F="$SAM3_F,$SAM3_F4"
fi

SAM4_F=""
if [[ -n $SAM4_F1 ]]; then
    SAM4_F1=${SAM4_F1##*/}
    iget -fT ${sam4_f1} .
    SAM4_F=$SAM4_F1
fi

if [[ -n $SAM4_F2 ]]; then
    SAM4_F2=${SAM4_F2##*/}
    iget -fT ${sam_f2} .
    SAM4_F="$SAM4_F,$SAM4_F2"
fi

if [[ -n $SAM4_F3 ]]; then
    SAM4_F3=${SAM4_F3##*/}
    iget -fT ${sam4_f3} .
    SAM4_F="$SAM4_F,$SAM4_F3"
fi

if [[ -n $SAM4_F4 ]]; then
    SAM4_F4=${SAM4_F4##*/}
    iget -fT ${sam4_f4} .
    SAM4_F="$SAM4_F,$SAM4_F4"
fi

SAM5_F=""
if [[ -n $SAM5_F1 ]]; then
    SAM5_F1=${SAM5_F1##*/}
    iget -fT ${sam5_f1} .
    SAM5_F=$SAM5_F1
fi

if [[ -n $SAM5_F2 ]]; then
    SAM5_F2=${SAM5_F2##*/}
    iget -fT ${sam_f2} .
    SAM5_F="$SAM5_F,$SAM5_F2"
fi

if [[ -n $SAM5_F3 ]]; then
    SAM5_F3=${SAM5_F3##*/}
    iget -fT ${sam5_f3} .
    SAM5_F="$SAM5_F,$SAM5_F3"
fi

if [[ -n $SAM5_F4 ]]; then
    SAM5_F4=${SAM5_F4##*/}
    iget -fT ${sam5_f4} .
    SAM5_F="$SAM5_F,$SAM5_F4"
fi

SAM6_F=""
if [[ -n $SAM6_F1 ]]; then
    SAM6_F1=${SAM6_F1##*/}
    iget -fT ${sam6_f1} .
    SAM6_F=$SAM6_F1
fi

if [[ -n $SAM6_F2 ]]; then
    SAM6_F2=${SAM6_F2##*/}
    iget -fT ${sam_f2} .
    SAM6_F="$SAM6_F,$SAM6_F2"
fi

if [[ -n $SAM6_F3 ]]; then
    SAM6_F3=${SAM6_F3##*/}
    iget -fT ${sam6_f3} .
    SAM6_F="$SAM6_F,$SAM6_F3"
fi

if [[ -n $SAM6_F4 ]]; then
    SAM6_F4=${SAM6_F4##*/}
    iget -fT ${sam6_f4} .
    SAM6_F="$SAM6_F,$SAM6_F4"
fi

SAM7_F=""
if [[ -n $SAM7_F1 ]]; then
    SAM7_F1=${SAM7_F1##*/}
    iget -fT ${sam7_f1} .
    SAM7_F=$SAM7_F1
fi

if [[ -n $SAM7_F2 ]]; then
    SAM7_F2=${SAM7_F2##*/}
    iget -fT ${sam_f2} .
    SAM7_F="$SAM7_F,$SAM7_F2"
fi

if [[ -n $SAM7_F3 ]]; then
    SAM7_F3=${SAM7_F3##*/}
    iget -fT ${sam7_f3} .
    SAM7_F="$SAM7_F,$SAM7_F3"
fi

if [[ -n $SAM7_F4 ]]; then
    SAM7_F4=${SAM7_F4##*/}
    iget -fT ${sam7_f4} .
    SAM7_F="$SAM7_F,$SAM7_F4"
fi

SAM8_F=""
if [[ -n $SAM8_F1 ]]; then
    SAM8_F1=${SAM8_F1##*/}
    iget -fT ${sam8_f1} .
    SAM8_F=$SAM8_F1
fi

if [[ -n $SAM8_F2 ]]; then
    SAM8_F2=${SAM8_F2##*/}
    iget -fT ${sam_f2} .
    SAM8_F="$SAM8_F,$SAM8_F2"
fi

if [[ -n $SAM8_F3 ]]; then
    SAM8_F3=${SAM8_F3##*/}
    iget -fT ${sam8_f3} .
    SAM8_F="$SAM8_F,$SAM8_F3"
fi

if [[ -n $SAM8_F4 ]]; then
    SAM8_F4=${SAM8_F4##*/}
    iget -fT ${sam8_f4} .
    SAM8_F="$SAM8_F,$SAM8_F4"
fi

SAM9_F=""
if [[ -n $SAM9_F1 ]]; then
    SAM9_F1=${SAM9_F1##*/}
    iget -fT ${sam9_f1} .
    SAM9_F=$SAM9_F1
fi

if [[ -n $SAM9_F2 ]]; then
    SAM9_F2=${SAM9_F2##*/}
    iget -fT ${sam_f2} .
    SAM9_F="$SAM9_F,$SAM9_F2"
fi

if [[ -n $SAM9_F3 ]]; then
    SAM9_F3=${SAM9_F3##*/}
    iget -fT ${sam9_f3} .
    SAM9_F="$SAM9_F,$SAM9_F3"
fi

if [[ -n $SAM9_F4 ]]; then
    SAM9_F4=${SAM9_F4##*/}
    iget -fT ${sam9_f4} .
    SAM9_F="$SAM9_F,$SAM9_F4"
fi

SAM10_F=""
if [[ -n $SAM10_F1 ]]; then
    SAM10_F1=${SAM10_F1##*/}
    iget -fT ${sam10_f1} .
    SAM10_F=$SAM10_F1
fi

if [[ -n $SAM10_F2 ]]; then
    SAM10_F2=${SAM10_F2##*/}
    iget -fT ${sam_f2} .
    SAM10_F="$SAM10_F,$SAM10_F2"
fi

if [[ -n $SAM10_F3 ]]; then
    SAM10_F3=${SAM10_F3##*/}
    iget -fT ${sam10_f3} .
    SAM10_F="$SAM10_F,$SAM10_F3"
fi

if [[ -n $SAM10_F4 ]]; then
    SAM10_F4=${SAM10_F4##*/}
    iget -fT ${sam10_f4} .
    SAM10_F="$SAM10_F,$SAM10_F4"
fi

# Initialize OPTIONS with mandatory parameters
OPTIONS="--no-update-check --num-threads ${THREADS} --output-dir ${OUTPUT_DIR}"
OPTIONS="$OPTIONS --library-type ${LIBRARYTYPE} --min-alignment-count ${MINALIGNMENTCOUNT} --labels ${LABELS}"

# Fetch annotation file (if specified)
ANNOTATION_F=
if [[ -n $ANNOTATION ]]; then
    ANNOTATION_F=$ANNOTATION

    ANNO_OK=$(grep p_id $ANNOTATION_F)
    if [[ ! -n $ANNO_OK  ]]; then
        bin/cuffdiff_fix_annotations.pl $ANNOTATION_F $REFSEQ_F
    fi
    CDS_OK=$(grep CDS $ANNOTATION_F)
    if [[ ! -n $CDS_OK ]]; then
	cat $ANNOTATION_F |sed 's/exon/CDS/' > CDS.gtf
	cat $ANNOTATION_F CDS.gtf |sort -k1,1 -k4,4n -k5,5n -k3,3r >rebuilt.gtf
	cp $ANNOTATION_F ${ANNOTATION_F}.bak 
	mv rebuilt.gtf $ANNOTATION_F
	rm -f CDS.gtf
    fi
fi

# Flag  OPTIONS
if [[ -n $treatAsTimeSeries ]] && [ $treatAsTimeSeries == 1 ]; then
	OPTIONS="${OPTIONS} --time-series"
fi

if [[ -n  $multiReadCorrect ]] && [ $multiReadCorrect == 1 ]; then
	OPTIONS="${OPTIONS} --multi-read-correct"
fi

if [[ -n $totalHitsNorm ]] && [ $upperQuartileNorm == 1 ]; then
	OPTIONS="${OPTIONS} --upper-quartile-norm"
fi

if [[ -n $totalHitsNorm ]] && [ $totalHitsNorm == 1 ]; then
	OPTIONS="${OPTIONS} --total-hits-norm"
fi

if [[ -n $compatibleHitsNorm ]] && [ $compatibleHitsNorm == 1 ]; then
	OPTIONS="${OPTIONS} --compatible-hits-norm"
fi

if [[ -n $poissonDispersion ]] && [ $poissonDispersion == 1 ]; then
	OPTIONS="${OPTIONS} --poisson-dispersion"
fi

# Parameter OPTIONS
if [[ -z ${FRAGLENMEAN} ]]; then
	OPTIONS="${OPTIONS} --frag-len-mean ${FRAGLENMEAN}"
fi
if [[ -z ${FRAGLENSTDEV} ]]; then
	OPTIONS="${OPTIONS} --frag-len-std-dev ${FRAGLENSTDEV}"
fi

if [[ -n $REFSEQ_F ]]; then
        OPTIONS="${OPTIONS} -b ${REFSEQ_F}"
fi

# and we pull the trigger...
SAMS="${SAM1_F} ${SAM2_F} ${SAM3_F} ${SAM4_F} ${SAM5_F} ${SAM6_F}"
SAMS="${SAMS} ${SAM7_F} ${SAM8_F} ${SAM9_F} ${SAM10_F}"
echoerr "Executing cuffdiff ${OPTIONS} ${ANNOTATION_F} $SAMS...
"
cuffdiff ${OPTIONS} ${ANNOTATION_F} $SAMS 2>cuffdiff.stderr

DIFFDONE=$(ls -alh cuffdiff_out)
if ! [[ -n $DIFFDONE ]]; then
  echoerr "Oh no, cuffdiff failed!  I quit'"
fi

echoerr "DONE!                                                                                                                                       
$DIFFDONE                                                                                                                                           
"

echoerr "Preparing global R plots...
"
export R_LOCAL=${PWD}/R
export PATH="${PATH}:${R_LOCAL}/bin";
cuffdiff_R_plots.pl $LABELS 

echoerr "Done!"

echoerr "Sorting output data...
"
cuffdiff_sort.pl $path $LABELS

echoerr "Done!"

rm -fr bin R tmp *.gtf *.fa* *.txt *.bam annotations cuffdiff_out/*db

