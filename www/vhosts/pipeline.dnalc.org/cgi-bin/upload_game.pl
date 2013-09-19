#!/usr/bin/perl 
use strict;
use warnings;
use Time::HiRes qw/gettimeofday/; 
use CGI qw/:standard/;
use Bio::GMOD::CAS::Util;
use lib '/var/www/lib/perl';
use DNALC::Pipeline::Chado::Utils;
use DNALC::Pipeline::Utils qw/random_string/;
use Data::Dumper;

$ENV{'GMOD_ROOT'} = '/usr/local/gmod';

my $config = Bio::GMOD::CAS::Util->new();

warn Dumper($config);
warn $config->SAVEONLOAD;

my $SAVEONLOAD  = $config->SAVEONLOAD;
my $STORE_DIR = $config->UPLOAD_DIR || "/usr/local/gmod/tmp/apollo";
my $hostname  = $config->PROJECT_HOME;
my $apollo_path = $config->HEADLESS_APOLLO;

warn "SAVEONLOAD:$SAVEONLOAD";
warn "apollopath:$apollo_path";

my $cgi = CGI->new();

if (!$cgi->param() ) {
    #print a form to do the uploading
    print $cgi->header,
          $cgi->start_html(-title=>"upload a GAME-XML file",
                           -style=>{src=>'/gbrowse/gbrowse.css'},),
          $cgi->h1("Upload a GAME-XML file"),
          $SAVEONLOAD ? p("The uploaded file will go straight into Chado")
                    : p("The uploaded file will be held for approval by site admin"),
          $cgi->start_form,
       
          "Username:<br />", 
          $cgi->textfield(-name=>'username'),
          $cgi->br,
          "Password:<br />",
          $cgi->password_field(-name=>'password'),
          $cgi->br,
          $cgi->filefield(-name=>'fileupload'), 
          $cgi->submit, 
 
          $cgi->end_form,
          $cgi->end_html;
}
else {  #process the uploaded file
    print $cgi->header,
          $cgi->start_html(-title=>"upload a GAME-XML file",
                           -style=>{src=>'/gbrowse/gbrowse.css'},),
          $cgi->h1("result"),
#           "username:",
#           $cgi->param('username'),
#           $cgi->br,
#           "password:",
#           $cgi->param('password'),
#           $cgi->br,
# 		  
# 		  $cgi->p("Config stuff: autoload:$SAVEONLOAD, store_dir:$STORE_DIR"),
#
#          $cgi->hr,
          "<pre style=\"display: none\">\n";

          my $fh = $cgi->upload( 'fileupload' );

          my $filename = random_string(); 
 
          die "ERROR: the store directory isn't configured" unless $STORE_DIR;
          my ($s, $ms) = gettimeofday;
          $filename = "$s.$ms.$filename.xml";
          my $fullfilename = $STORE_DIR . "/" . $filename;
          open OUT, ">$fullfilename" or die "couldn't open file: $!";
          #seek $fh, 0, 0; #can be removed after debug prints are removed
          while (<$fh>) {
              print OUT $_;
          }
          close OUT;
          print $cgi->p(param('fileupload')." was written to $fullfilename");

          #now write username and password
          my $userinfofile = $fullfilename.".userinfo";
          my $username =  $cgi->param('username');
          my $password =  $cgi->param('password');
          open OUT, ">$userinfofile" or die "couldn't open file $!";
          print OUT "$username\n";
          print OUT "$password\n";
          close OUT;
          
		  my $ok = 0;

          if ($SAVEONLOAD) {
              my $cutil = DNALC::Pipeline::Chado::Utils->new();
              #determine project_id
              my $project_id;
              open XML, $fullfilename or die;
              while(my $line=<XML> and !$project_id) {
                  if ($line =~ /_(\d+)\:\d+\-\d+\<\/name/) {
                      $project_id = $1;
                  }
              }

              die unless $project_id;

              $cutil->create_chado_config($project_id);

              # note that the -G user below is supposed to be plain text so that the GFF_source
              # of the added annotations is "user"
              my $javacmd = "$apollo_path -H -G user -f '$fullfilename' -i game  -o chadoDB"; 
              print "writing to the database; here's the command:\n$javacmd\n";
              system($javacmd);

              $cutil->remove_lock_file();
			  $ok = 1;
          }

          print "</pre>\n";
		  if ($ok) {
			print $cgi->p("OK.. file uploaded and data is saved in the database.");
		  }
          print $cgi->end_html;
}

exit(0);

=pod

=head1 AUTHOR

Scott Cain, cain.cshl@gmail.com

=head1 COPYRIGHT

2008, All rights reserved

=cut
