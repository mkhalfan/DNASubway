# Collection of fastx QC utilities for DNA Subway

# inputs
SEQ1=${input}

iget -fT $SEQ1
infile=$(basename $SEQ1)

if ( "$infile" =~ 'gz$' ); then
    gunzip $infile
    infile=$(basename $infile .gz);
fi;
if ( "$infile" =~ 'bz2$' ); then
    bunzip2 $infile
    infile=$(basename $infile .bz2);
fi;

tar zxf FastQC.tgz

mkdir fastqc_out
mv $infile fastqc_out
cd fastqc_out
../FastQC/fastqc $infile
cd ..

rm -fr fastqc_out/*_fastqc
rm -f fastqc_out/$infile
rm -rf FastQC*



