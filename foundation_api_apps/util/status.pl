#!/usr/bin/perl -w
use strict;
use CGI qw(param pre);
use JSON;

use constant USER  => '';
use constant TOKEN => ''; 

my $jid = param('jid');

my $auth = join(':',USER,TOKEN);

my $json = `curl -sku "$auth" https://foundation.iplantc.org/apps-v1/job/$jid |json_xs`;

print pre(decode_json $json);


