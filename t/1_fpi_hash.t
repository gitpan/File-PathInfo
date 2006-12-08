use Test::Simple tests=>2;
use strict;
use Cwd;
use lib './lib';
use File::PathInfo;
#use Smart::Comments '###';
$ENV{DOCUMENT_ROOT} = cwd()."/t/public_html";


my $r = new File::PathInfo;
ok( $r->set('./t/public_html/house.txt') );

ok(my $hash = $r->get_datahash);
### $hash
