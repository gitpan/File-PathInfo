use Test::Simple 'no_plan';
use strict;
use Cwd;
use lib './lib';
use File::PathInfo;
$ENV{DOCUMENT_ROOT} = cwd()."/t/public_html";




my $r = new File::PathInfo;
ok( $r->set('./t/public_html/house.txt') );

ok(my $hash = $r->get_datahash);
###  $hash



for (qw(./t/public_html/hhahahahahahahouse.txt /nons/ense /moreneo/nensense )){

   ### $_


   my $r = new File::PathInfo;
   my $set_worked = $r->set($_);
   ### $set_worked

#   $r->abs_loc;

 #  $r->abs_path;

   my $exists = $r->exists; 
   ok(!$exists);
   

   

   ok(my $hash = $r->get_datahash);
   ### $hash
   




}

