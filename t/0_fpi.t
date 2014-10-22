use Test::Simple 'no_plan';
use strict;
use lib './lib';
use File::PathInfo;
use Cwd;
use warnings;
$ENV{DOCUMENT_ROOT} = cwd().'/t/public_html';

use Carp;

# test ones we know are in docroot
for (
'./t/public_html/demo',
'demo',
'./t/public_html/demo/hellokitty.gif',
'./t/public_html/demo/../demo/civil.txt',
'demo/../demo/civil.txt',

'demo/civil.txt',
){
	
	my $argument = $_;
	my $f = new File::PathInfo or die( $File::PathInfo::errstr );

	$f->set($argument) or die($File::PathInfo::errstr);
	
	ok($f);

	ok($f->rel_path);
	ok($f->filename);
	ok($f->abs_path);
	ok($f->abs_loc);
	ok($f->is_in_DOCUMENT_ROOT);

	

	my $status = {
		docroot => $f->DOCUMENT_ROOT,
		filename => $f->filename,
		rel_loc => $f->rel_loc,
		rel_path => $f->rel_path,
		is_topmost => $f->is_topmost,
		is_docroot => $f->is_DOCUMENT_ROOT,
		is_in_docroot => $f->is_in_DOCUMENT_ROOT,
		abs_path => $f->abs_path,
		abs_loc => $f->abs_loc,
	};	
		
	
	### $status
}	





# test ones we know are NOT in doc root
for (
'./t/public_html',
'./t/0_fpi.t',
){
	
	my $argument = $_;
	my $f = new File::PathInfo or die( $File::PathInfo::errstr );
	$f->set($argument);
	ok($f);
	ok($f->filename);
	ok($f->abs_path);
	ok($f->abs_loc);
	ok(!$f->is_in_DOCUMENT_ROOT);

	

}	



my $f = new File::PathInfo;
$f->set('./t/public_html/demo/../demo/civil.txt');
ok($f->is_text);
ok($f->ext eq 'txt');
ok($f->filename_only eq 'civil');


my $b = new File::PathInfo;
$b->set('demo/hellokitty.gif');
#print $b->DOCUMENT_ROOT." -- \n";
#print $b->rel_path." -- \n";
#print $b->rel_loc." -- \n";


ok($b->is_binary);
ok($b->ext eq 'gif');
ok($b->filename_only eq 'hellokitty');
ok($b->rel_loc eq 'demo');



$b->set('./t/public_html/demo/../demo/civil.txt');
ok($b->is_text);
ok($b->ext eq 'txt');
ok($b->filename_only eq 'civil');
ok($b->rel_path eq 'demo/civil.txt');



$b->set('./t/public_html/demo/../demo/cvil.txt');
# calling susequent methods would throw exception




# test non exist

for (
'./t/public_html/de41zmo',
'demvo2',
'./t/public_html/demo/../demo/civil.txt/',
){
	
	my $argument = $_;
	my $f = new File::PathInfo;
	my $exists = $f->set($argument);
   $exists ||= 0;

   ok(!$exists);
}   

