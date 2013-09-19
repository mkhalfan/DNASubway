#!/usr/bin/perl
use warnings;
use strict;

use CGI qw/:standard start_div start_span start_pre start_ul/;
use Bio::GMOD::CAS::Util;
use Bio::GMOD::Config;
use Bio::GMOD::DB::Config;
use lib '/var/www/lib/perl';
use DNALC::Pipeline::Chado::Utils;


$ENV{'GMOD_ROOT'} = '/usr/local/gmod';

my $config = Bio::GMOD::CAS::Util->new();

my $working_dir = $config->HTDOCS;
my $apollo      = $config->HEADLESS_APOLLO;
my $hostname    = $config->PROJECT_HOME;
my $web_path    = $config->WEB_PATH;
my $vendor      = $config->VENDOR;
my $apollo_desc = $config->APOLLO_DESC;

unless(param()) { #print the starting page

    print header,
         start_html(-title=>'Script for generating game on the fly from apollo',
                    -style=>{src=>'/gbrowse/gbrowse.css'},),
         h1('Request a GAME-XML file from the database'),
         start_form(-method=>'GET'),
         'Chromosome:',
         popup_menu(-name=>'chromosome',
                    -values=>['daffodil']),p,
         'start:',
         textfield('start'),p,
         'end:',
         textfield('end'),p,
         radio_group(
             -name=>'xml_type',
             -values=>['game','chado'],
             -default=>'game',
             -labels=>{'GAME-XML','chadoxml'}
         ),p,
         submit,
         end_form,
         end_html;
         exit(0);
}


my ($chromosome,$start,$end,$failure,$xmltype,$project_id);
my $t_chromosome = param('chromosome');
my $t_start      = param('start');
my $t_end        = param('end');
my $t_selection  = param('selection');
my $t_xmltype    = param('xml_type');

if ($t_chromosome and $t_chromosome =~ /^(\w+)$/) {
    $chromosome = $1; 
}
if ($t_start      and $t_start      =~ /^(\d+)$/) {
    $start      = $1;
    if ($start < 1) {
        $start = 1;
    }
}
if ($t_end        and $t_end        =~ /^(\d+)$/) {
    $end        = $1;
}
if ($t_selection  and $t_selection  =~ /^(\S+):(-?\d+)\.\.(\d+)$/) {
    $chromosome = $1;
    $start      = $2;
    $end        = $3;
    if ($start < 1) {
        $start = 1;
    }
}

warn $chromosome;
#DNALC specific project_id stuff
if ($chromosome =~ /\_(\d+)$/) {
    $project_id = $1;
}
else {
    die "no project_id--can't go on";
}


if ($t_xmltype and ($t_xmltype =~ /^chado$/ or $t_xmltype =~ /^game$/)) {
    $xmltype = $t_xmltype;
}
else {
    $xmltype = 'game';
}
    
unless ($chromosome && $start && $end) {
    $failure = "The parameters used for this script were not understood; here is what I got: "
		          . "chromosome = $chromosome, "
	              . "start = $start, "
                  . "end = $end";
    handle_error($failure);
}

my $filename = "$chromosome:$start\-$end";

#before Apollo can read from the database, chado-adaptor.xml needs to be modified
#to modify it, we need to know dbname, which we can get from the project's gmod conf file
#and we should put a lock file in place to make only one apollo instance runs at a time.
my $cutil = DNALC::Pipeline::Chado::Utils->new();
$cutil->create_chado_config($project_id);


print header;

my $javacmd = "$apollo -H -w $working_dir/$filename.xml -o $xmltype -l $filename -i chadoDB > /dev/null";

system($javacmd);

my $error_flag;
my $error_msg = '';

if (-e "$working_dir/$filename.xml") {
	#print p("The file $filename.xml has been created");
}
else {
    $error_msg = "The file $filename.xml was not created; check the Apollo output for errors";
    $error_flag = 1;
}

open OUT, ">$working_dir/$filename.jnlp" 
   or do {
		print STDERR  "Error creating JNPL file: $working_dir/$filename.jnlp\n", $!, $/;
		handle_error( "Error creating JNPL file.");
	};

print OUT write_jnlp();
close OUT;

if (-e "$working_dir/$filename.jnlp") {
	print STDERR "Created the file $filename.jnlp.", $/;
}
else {
    $error_msg = "The file $filename.jnlp was not created; I don't know why";
    $error_flag = 1;
}

print STDERR  "flg = ", $error_flag, $/;

if (!$error_flag) { 
	print "{'status':'success', 'file':'$hostname/$web_path/$filename.jnlp'}";
	#  . a({href=>"$hostname/cgi-bin/upload_game.pl"},
	#      "Upload game-xml")
	#  ." link to upload your annotations."),
}
else {
	print "{'status':'error', 'message':'$error_msg'}";
}


$cutil->remove_lock_file();

exit(0);

sub handle_error {
    my $failure = shift;

    print "{'status':'error','message':'" . $failure . "'}";
    exit(0);
}

sub write_jnlp {

    return <<END;
<?xml version="1.0" encoding="UTF-8"?>
<jnlp codebase="$hostname/apollo/webstart" 
href="$hostname/$web_path/$filename.jnlp" spec="1.0+">
  <information>
    <title>Apollo</title>
    <vendor>$vendor</vendor>
    <description>$apollo_desc</description>
    <!-- location of your project's web page -->
    <homepage href="$hostname/"/>
    <!-- if you want to have WebStart add a specific image as your icon,
            point to the location of the image -->
    <icon href="images/head-of-apollo.gif" kind="shortcut"/>
    <!-- allow users to launch Apollo when offline -->
    <offline-allowed/>
  </information>
  <!-- request all permissions - might be needed since Apollo might write to local
          file system -->
  <security>
    <all-permissions/>
  </security>
  <!-- we require at least Java 1.5, set to start using 64m and up to 500m -->
  <resources>
    <j2se initial-heap-size="64m" max-heap-size="500m" version="1.5+"/>
    <jar href="jars/apollo.jar"/>
    <jar href="jars/bbop.jar"/>
    <jar href="jars/biojava.jar"/>
    <jar href="jars/crimson.jar"/>
    <jar href="jars/ecp1_0beta.jar"/>
    <jar href="jars/ensj-compatibility-19.0.jar"/>
    <jar href="jars/ensj.jar"/>
    <jar href="jars/jakarta-oro-2.0.6.jar"/>
    <jar href="jars/jaxp.jar"/>
    <jar href="jars/jnlp.jar"/>
    <jar href="jars/junit.jar"/>
    <jar href="jars/log4j-1.2.14.jar"/>
    <jar href="jars/macify-1.1.jar"/>
    <jar href="jars/mysql-connector-java-3.1.8-bin.jar"/>
    <jar href="jars/obo.jar"/>
    <jar href="jars/oboedit.jar"/>
    <jar href="jars/org.mortbay.jetty.jar"/>
    <jar href="jars/patbinfree153.jar"/>
    <jar href="jars/pg74.213.jdbc3.jar"/>
    <jar href="jars/psgr2.jar"/>
    <jar href="jars/servlet-tomcat.jar"/>
    <jar href="jars/te-common.jar"/>
    <jar href="jars/xerces.jar"/>
  </resources>
  <!-- where the main method is locate - don't change this -->
  <application-desc main-class="apollo.main.Apollo">
    <!-- we can add arguments when launching Apollo - this particular one allows us to
              load chromosome 1, from 11650000 to 11685000 - great way to have Apollo load
              specific regions -->
    <argument>-i</argument>
    <argument>game</argument>
    <argument>-f</argument>
    <argument>$hostname/$web_path/$filename.xml</argument>
  </application-desc>
</jnlp>
END
;
}

=pod

=head1 AUTHOR

Scott Cain, cain.cshl@gmail.com

=head1 COPYRIGHT

2008, All rights reserved

=cut
