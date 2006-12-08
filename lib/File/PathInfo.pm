package File::PathInfo;
use Cwd;
use Carp;
#use Smart::Comments '###','####';
use strict;
use warnings;
use Time::Format qw(%time);

our $VERSION = sprintf "%d.%02d", q$Revision: 1.1 $ =~ /(\d+)/g;

=pod

=head1 NAME

File::PathInfo - access to path variables, stat data, misc info about a file 

=head1 SYNOPSIS

	use File::PathInfo;
	
	my $f = new File::PathInfo;

	$f->set('/home/myself/public_html/folder/stew.txt) or die('file does not exist');
	
	$f->is_text; # returns 1

	$f->ext; # returns 'txt'

	$f->abs_loc; # returns '/home/myself/public_html/folder'


=head1 DESCRIPTION
	
A lot of times you need to know a file's absolute path, it's absolute
location, maybe it's relative location to something else (like DOCUMENT ROOT),
then you need to maybe know the relative path and relative location for a file.
You need to know if a file is a directory, what it's extension is. 
You can commonly use regexes to do this.

This module provides commonly needed variables.

Works with relative paths like in a website too:

	use File::PathInfo;
	
	my $f = new File::PathInfo;

	$f->set('folder/stew.txt) or die('file does not exist');

	$f->abs_path; # returns '/home/myself/public_html/folder/stew.txt'

	$f->rel_path; # returns 'folder/stew.txt'
	
	$f->rel_loc; # returns 'folder'

	$f->is_in_DOCUMENT_ROOT; # returns 1

Also safeguards from cgi accessing files outside of document root

	use File::PathInfo;
	
	my $f = new File::PathInfo;

	$f->set('/home/myself/stew.txt) or die('file does not exist');

	$f->rel_path; # throws exception and complains that it is not in document root


You can define also, that document root is something else. To
assure the files you are dealing with remain in a certain part of the 
filesystem tree.
Also lets you set a different document root, if you want an application to serve files
in some other place, but you still want to restrict what the script can access to
within that slice of the filesystem:

	use File::PathInfo;
	
	my $f = new File::PathInfo({ DOCUMENT_ROOT => '/home/myself/sharethese' });

	$f->set('/home/myself/sharethese/stew.txt) or die('file does not exist');

	$f->rel_path; # returns 'stew.txt'

Realize that for the rest of your cgi, ENV DOCUMENT ROOT is still your webshare, public
html, etc. It's just that you can override for the object instance, what the DOCUMENT
ROOT is. 



By default if you want to get path info on a file that is not on disk, an exception is thrown.
If you want to disable that:

	use File::PathInfo({ check_exist => 0 });
	
	my $f = new File::PathInfo;

	$f->set('/home/myself/html/sty54wyw5/4y54yy4ew.txt') ;

	$f->rel_path; # returns 'sty54wyw5/4y54yy4ew.txt'

Maybe this could be useful if you wanted to work with a path string that *was* present or *will be*.


=head1 METHODS

=cut

sub new {
	my ($class, $self) = (shift, shift);
	$self ||= {};		
	bless $self, $class;			
	return $self;	
}
=head2 new()

Argument is optional hash ref.

	my $fi = new File::PathInfo;

Optional parameters to constructor:

	my $fi = new File::PathInfo({ 
		DOCUMENT_ROOT => '/home/myself/html',
		check_exist => 0,
		time_format => 'yyyy/mm/dd hh::mm',
	});

=over 4

=item 'check_exist'

Defaults to true. If a file does not exist, methods return undef.	
	
=item 'DOCUMENT_ROOT'

Set a different document root variable from the one currently on server.
This variable must be set either in the server or via this argument if you will
use the relative file path methods.

=back

Absolute path methods are accessible always. 
The relative path methods are accessible *if* you have DOCUMENT ROOT environment variable
set or if you pass the argument DOCUMENT_ROOT to object constructor.

If you are using cgi, ENV DOCUMENT_ROOT is set when you call the program via http (the 
browser). But when you call the program via the cli (command line) it will likely not
be set! This causes some programs to crash when you run then on the command line, and you
scratch your head and ask 'how come?'.
The same goes for the environment variable 'HOME', which is not set when you call your
cgi script via http (browser) but is set if you call it via cli (the command line, shell
access, etc.).

=cut

sub set {
	my $self= shift;
	$self->{_data} = undef;	
	$self->{_data}->{_argument} = shift;	
	$self->_abs or warn($self->errstr) and return 0;
	return 1;
}
=head1 set()

Argument is a relative or absolute file path.
	
	$f->set('/tmp/trashdir'); # absolute path

	$f->set('gfx/logo.gif'); # relative to DOCUMENT ROOT

	$f->set('./thisfile.png'); # relative to current working directory

set() returns boolean, true or false. If the file cannot be resolved to disk
then it returns undef.
If you then call any methods, exceptions are thrown with Carp::croak.

You can do this too:

	$f->set('/home/myself/html/documents/manual.pdf') or die( $File::PathInfo::errstr );
	
	$f->set('documents/manual.pdf') or print "Location: 404.html\n\n" and exit; 

=cut





=head1 ABSOLUTE METHODS

The absolute path methods. 

=cut

sub _abs {
	my $self = shift;	

	croak($self->errstr) if $self->errstr;
	

	unless( defined $self->{_data}->{_abs} ){

		my $_abs= {};	
	
		my $abs_path;
		my $argument = $self->{_data}->{_argument} or croak("you must call set() before any other methods");
		#### $argument	
		if ( $argument =~/^\// ){ # assume to be abs
			$abs_path = Cwd::abs_path($argument) or ( 
				$self->_error("cant resolve [$argument] as abs path") and return );		
		}

		# if starts with dot.. resolve to cwd
		elsif ( $argument =~/^\./ ){
			$abs_path = Cwd::abs_path(cwd().'/'.$argument) or (
				$self->_error("cant resolve [$argument] as path rel to cwd") and return );
		}

		else {
			### assume to be rel path then	
			unless( $self->DOCUMENT_ROOT ){
				$self->_error("cant resolve [$argument] as rel_path to doc root because DOCUMENT_ROOT is not set");
				return;
			}	
	
			$abs_path = Cwd::abs_path($self->DOCUMENT_ROOT .'/'.$argument);
			$abs_path or $self->_error("cant resolve [$argument] as rel_path to doc root") and return;	
	
			### supposedly resolved..  
		}

		# set main vars
	
		$_abs->{abs_path} = $abs_path;

		$abs_path=~/^(\/.+)\/([^\/]+)$/ or die("problem matching abs loc and filename in [$abs_path]"); # should not happen
		$_abs->{abs_loc} = $1;
		$_abs->{filename} = $2;
		if ($_abs->{filename}=~/^(.+)\.(\w{1,4})$/){
			$_abs->{filename_only} =$1;
			$_abs->{ext} = $2;
		}
		
		(defined $self->{check_exist}) or ($self->{check_exist} = 1);
		if ($self->{check_exist}){
			#print STDERR "checking exist\n";
			unless( -e $_abs->{abs_path} ){ 
				$self->_error( $_abs->{abs_path} ." is not on disk.");
				return; 
			}	
				
		}

		$self->{_data}->{_abs} = $_abs;	
	}
	
	return $self->{_data}->{_abs};
}

sub abs_path {
	my $self = shift;
	return $self->_abs->{abs_path};
}

sub filename {
	my $self = shift;
	return $self->_abs->{filename};
}

sub abs_loc {
	my $self = shift;
	return $self->_abs->{abs_loc};
}
sub ext {
	my $self = shift;
	return $self->_abs->{ext};
}
sub filename_only {
	my $self = shift;
	return $self->_abs->{filename_only};
}
=head2 abs_loc()

Returns absolute location on disk. Everything but the filename, no trailing file
delimiter (slash).

=head2 abs_path()

Returns absolute path on disk. Notice that all symlinks are resolved with Cwd::abs_path,
so any /../ etc are gone.

=head2 filename()

Returns filename, no leading directories, no leading file delimiter (slash).

=head2 filename_only()

Returns filename without extension. 
'/home/myself/this.txt' would return 'this'
Does not return undef.

=head2 ext()

Returns filename ext, if none found, returns undef.


=head1 RELATIVE METHODS

These methods are only available if a DOCUMENT ROOT is defined. 


=cut

sub _rel {
	my $self = shift;

	croak($self->errstr) if $self->errstr;	

	unless( defined $self->{_data}->{_rel}){
		my $_rel = {};
	
		my $doc_root = $self->DOCUMENT_ROOT or croak('cant init rel path methods, DOCUMENT_ROOT not resolving. ' . $self->errstr);
		my $abs_path = $self->abs_path;

		if ($doc_root eq $abs_path){
			$_rel->{rel_path} = '';
			$_rel->{rel_loc} = '';			
		}

		else {

			my $rel_path = $abs_path; #  by now if it was the same as document root, should have been detected
			$rel_path=~s/^$doc_root\/// or croak("abs path [$abs_path] is NOT within DOCUMENT ROOT [$doc_root]");
	
			$_rel->{rel_path} = $rel_path;

			if ($rel_path=~/^(.+)\/([^\/]+)$/){
				my $rel_loc = $1;
				my $filename = $2;

				$filename eq $self->filename or die("filename from abs path not same as filename from init rel regex, why??");
		
				$_rel->{rel_loc} = $1;	
			}
			else {
				$_rel->{rel_loc} = ''; # file is in topmost dir in doc root	
			}
		}

		$self->{_data}->{_rel} = $_rel;	
	}
	
	return $self->{_data}->{_rel};
}


sub rel_path {
	my $self = shift;
	return $self->_rel->{rel_path};
}

sub rel_loc {
	my $self = shift;
	return $self->_rel->{rel_loc};
}

sub is_topmost {
	my $self = shift;
	$self->abs_loc eq $self->DOCUMENT_ROOT or return 0;
	return 1;
}

sub is_DOCUMENT_ROOT {
	my $self = shift;	
	$self->abs_path eq $self->DOCUMENT_ROOT or return 0;
	return 1;
}
=head1 rel_path()

relative to DOCUMENT_ROOT

=head1 rel_loc()

location relative to DOCUMENT_ROOT

=head1 is_DOCUMENT_ROOT()

if this *is* the document root

=head1 is_topmost()

if the parent directory is document root.
boolean.

=cut

sub is_in_DOCUMENT_ROOT {
	my $self = shift;

	my $abs_path = $self->abs_path;
	my $document_root = $self->DOCUMENT_ROOT;

	$abs_path=~/^$document_root\// or return 0; # the trailing slash is imperative

	return 1;
}
=head1 is_in_DOCUMENT_ROOT()

does this file reside in the DOCUMENT_ROOT tree ?
note that DOCUMENT_ROOT itself *is* the document root, does is not
considered to be *in* the document root. this is partly for security
reasons.

=cut

sub DOCUMENT_ROOT {
	my $self = shift;	

	croak($self->errstr) if $self->errstr;

	
	unless ( defined $self->{_data}->{DOCUMENT_ROOT}){	
	
		my $abs_document_root;

		if( $self->{DOCUMENT_ROOT} ){
			$abs_document_root = Cwd::abs_path(	$self->{DOCUMENT_ROOT} ) or 
				$self->_error(" DOCUMENT_ROOT [$$self{DOCUMENT_ROOT}] does not resolve to disk") and return;
		}	

		elsif ( $ENV{DOCUMENT_ROOT} ){
			$abs_document_root = Cwd::abs_path(	$ENV{DOCUMENT_ROOT} ) or 
				$self->_error(" ENV DOCUMENT_ROOT [$ENV{DOCUMENT_ROOT}] does not resolve to disk") and return;		
		}
		
		$self->{_data}->{DOCUMENT_ROOT} = $abs_document_root;
	}	
	return $self->{_data}->{DOCUMENT_ROOT};
}
=head1 DOCUMENT_ROOT()

Returns doc root, returns undef if not set, or if it cant resolve to abs path on disk.
You can override the DOCUMENT root like this:

	my $fi = new File::PathInfo('./path/to/file.tmp',{ DOCUMENT_ROOT => '/home/myself' });

Doc root is also resolved for symlinks and . and .. etc.

Using a custom DOCUMENT_ROOT variable for the object instance does not alter the variable
for other cgi programs, etc. Just for the object you created. It is only used internally,
If this class is inherited, $ENV{DOCUMENT_ROOT} is whatever it is set at on the server.
If you provide a different DOCUMENT_ROOT as an argument, $ENV{DOCUMENT_ROOT} still returns
the server set variable. It is method DOCUMENT_ROOT() that returns the internally used value.

You do not have to provide a DOCUMENT_ROOT value to the constructor, the variable is not needed
unless you use the relative path methods

Again, the order of priority to define what the DOCUMENT ROOT is for an instance
of File::PathInfo is:

First, in argument to contructor

Second, if your environment variable DOCUMENT_ROOT is set. 

=cut












=head1 EXTENDED METHODS

These methods ask useful things like, is the file a directory, is it binary,
is it text, what is the mtime, etc. These methods load data on call, they can 
be expensive if you are looping through thousands of files. So don'nt worry 
because if you don't need them, they are not called.

=cut

sub _ask { #TODO: should be part of stat, stat can tell if it's -d -l or whatever
	my $self = shift;

	croak($self->errstr) if $self->errstr;

	unless( defined $self->{_data}->{_basic}){		
		
		my $basic = { #TODO this is wasteful
			is_file => ( -f $self->abs_path or 0 ),
			is_dir => ( -d $self->abs_path or 0 ),
			is_binary => ( -B $self->abs_path() or 0 ),
			is_text => ( -T $self->abs_path() or 0 ),		
		};
		$self->{_data}->{_basic} =$basic;
	
	}
	return $self->{_data}->{_basic};
}

sub is_binary {
	my $self = shift;
	return $self->_ask->{is_binary};
}

sub is_dir {
	my $self = shift;
	return $self->_ask->{is_dir};
}

sub is_text {
	my $self = shift;
	return $self->_ask->{is_text};
}

sub is_file {
	my $self = shift;
	return $self->_ask->{is_file};
}
=head1 is_binary(), is_text(), is_dir(), and is_file()

all return boolean true or false.

=cut

# init stat
sub _stat {
	my $self = shift;

	croak($self->errstr) if $self->errstr;

	unless( defined $self->{_data}->{_stat}){	


		$self->{time_format} ||= 'yyyy/mm/dd hh:mm';

		my $data = {};
	
		my @stat =  stat $self->abs_path or die("$! - cant stat ".$self->abs_path);
		my @keys = qw(dev ino mode nlink uid gid rdev size atime mtime ctime blksize blocks);
		for (@stat) {
		 	my $v= $_;
		 	my $key = shift @keys;		
			$data->{$key} = $v;		
		}
		
		$data->{ filesize_pretty }	= ( sprintf "%d",($data->{size} / 1024 )).'k';
		$data->{ ctime_pretty }		= $time{$self->{time_format},$data->{ctime}};
		$data->{ atime_pretty }		= $time{$self->{time_format},$data->{atime}};
		$data->{ mtime_pretty }		= $time{$self->{time_format},$data->{mtime}};
		$data->{ filesize }		= $data->{size};	
	
		$self->{_data}->{_stat} = $data;
		
	}

	return $self->{_data}->{_stat};	
}
=head1 STAT METHODS

These return values just as stat would.

=cut
sub filesize {	
 my $self = shift;
 return $self->_stat->{filesize};
}

sub size {	
 my $self = shift;
 return $self->_stat->{size};
}

sub filesize_pretty  { 
 my $self = shift;
 return $self->_stat->{filesize_pretty};
}

sub ctime  {
 my $self = shift;
 return $self->_stat->{ctime};
}

sub ctime_pretty  { 
 my $self = shift;
 return $self->_stat->{ctime_pretty};
}

sub atime  { 
 my $self = shift;
 return $self->_stat->{atime};
}

sub atime_pretty  { 
 my $self = shift;
 return $self->_stat->{atime_pretty};
}

sub mtime  { 
 my $self = shift;
 return $self->_stat->{mtime};
}

sub mtime_pretty  { 
 my $self = shift;
 return $self->_stat->{mtime_pretty}; 
}

sub ino  { 
 my $self = shift;
 return $self->_stat->{ino};
}

sub rdev  { 
 my $self = shift;
 return $self->_stat->{rdev};
}

sub gid  { 
 my $self = shift;
 return $self->_stat->{gid};
}

sub uid  { 
 my $self = shift;
 return $self->_stat->{uid};
}

sub dev  { 
 my $self = shift;
 return $self->_stat->{dev};
}

sub blocks  { 
 my $self = shift;
 return $self->_stat->{blocks};
}

sub blksize  { 
 my $self = shift;
 return $self->_stat->{blksize};
}

sub mode  { 
 my $self = shift;
 return $self->_stat->{mode};
}

sub nlink  { 
 my $self = shift;
 return $self->_stat->{nlink};
}

=head2 filesize()

Returns filesize in bites.

=head2 filesize_pretty()

Returns filesize in k, with the letter k in the end returns 0k if filesize is 0 

=head2 ctime(), atime(), mtime()

These return unix timestamps. You can run the command 'perldoc -f stat' for more details.

=head2 ctime_pretty(), atime_pretty(), mtime_pretty()

Returns these timestamps formatted to 'yyyy/mm/dd hh:mm' by default. 
To change the format, pass it as argument to object constructor as such:

	my $r = new File::PathInfo({ time_format => 'yyyy_mm_dd' });
	
	$r->set('/home/myself/archive1.zip');
	
	$r->ctime_pretty; # now holds 1999_11_13

=head2 uid(), ino(), blksize(), blocks(), dev(), gid(), mode(), nlink(), rdev(),
uid(), and size()

Return user id number, inode number, block size, blocks, device number, group id number,
mode, number of links, rdev, user id number, and size in bites.

=cut


sub get_datahash {
	my $self = shift;
	
	my $data = {};	
		
	for (keys %{$self->_abs}){
		if (defined $self->_abs->{$_}){
			$data->{$_} = $self->_abs->{$_};
		}
	}
	
	for (keys %{$self->_rel}){
		if (defined $self->_rel->{$_}){
			$data->{$_} = $self->_rel->{$_};
		}
	}
	
	for (keys %{$self->_ask}){
		if (defined $self->_ask->{$_}){
			$data->{$_} = $self->_ask->{$_};
		}
	}
	
	for (keys %{$self->_stat}){
		if (defined $self->_stat->{$_}){
			$data->{$_} = $self->_stat->{$_};
		}
	}	

	return $data;	
}

=head1 get_datahash()

Returns all elements, in a hash.

=cut



=head1 errstr()

Returns errostring or undef if no errors are present.

To check for errors you can query the error string.

	$f->set('/home/myself/this') or die($f->errstr);
	
	
=cut

sub _error {
	my $self = shift;
	my $arg = shift;
	$self->{_data}->{_errors}.="File::Info, $arg\n";
	return;
}
sub errstr {
	my $self = shift;
	defined $self->{_data}->{_errors} or return;
	return $self->{_data}->{_errors};
}

=head1 CAVEATS

This is currently for unix filesystems.

=head1 TODO

Let people specify a file delimiter for mac and windoze.

Maybe Time::Format is not appropriate here.

=head1 BUGS

Please report any bugs to developer.

=head1 AUTHOR

Leo Charre leo (at) leocharre (dot) com

http://leocharre.com

=head1 PREREQUISITES

Cwd, Carp, Time::Format

=head1 LICENSE

This program is free software; you can redistribute it
and/or modify it under the same terms and conditions as
Perl itself.

=head1 SEE ALSO

Cwd

=cut

1;
