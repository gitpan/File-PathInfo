package File::PathInfo;
use Cwd;
use Carp;
use strict;
use warnings;
require Exporter;
use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS $VERSION);
@ISA = qw(Exporter);
@EXPORT_OK = qw(abs_path_n);
%EXPORT_TAGS = (
	all => \@EXPORT_OK,
);
$VERSION = sprintf "%d.%02d", q$Revision: 1.22 $ =~ /(\d+)/g;

$File::PathInfo::DEBUG =0;

sub DEBUG : lvalue { $File::PathInfo::DEBUG }
$file::PathInfo::RESOLVE_SYMLINKS=1; 
sub RESOLVE_SYMLINKS : lvalue { $File::PathInfo::RESOLVE_SYMLINKS }
$File::PathInfo::TIME_FORMAT = 'yyyy/mm/dd hh::mm'; 
sub TIME_FORMAT : lvalue { $File::PathInfo::TIME_FORMAT }


sub new {
	my ($class, $self) = (shift, shift);
	$self ||= {};		
	
	my $arg;
	unless( ref $self ){
		print STDERR "arg is not a ref, treating as arg\n" if DEBUG;
		# assume to be path argument
		$arg = $self;
		$self = {};	
	}
	
	bless $self, $class;			

	if ($arg){
		print STDERR "will run set, " if DEBUG;
		$self->set($arg);
		print STDERR "ok\n" if DEBUG;
	}	
		
	return $self;	
}


sub set {
	my $self= shift;
	$self->{_data} = undef;	
   my $arg = shift;
	$self->{_data}->{_argument} = $arg;	
	unless($self->_abs){
      carp("set() '$arg' is not on disk.");
      $self->{_data}->{exists} = 0 ;
      return 0;
   }  
   $self->{_data}->{exists} = 1 ;
	return 1;
}

sub _argument {
	my $self = shift;
	$self->{_data}->{_argument} or confess("you must call set() before any other methods");
	return $self->{_data}->{_argument};
}


sub _abs {
	my $self = shift;	

#	croak($self->errstr) if $self->errstr;	

	unless( defined $self->{_data}->{_abs} ){

		my $_abs = {
         abs_loc => undef,
         filename => undef,
         abs_path => undef,
         filename_only => undef,
         ext => undef,       
      };	
	   $self->{_data}->{_abs} = $_abs;
      
		my $abs_path;		
		my $argument = $self->_argument;

		
		
		# IS ARGUMENT ABS PATH ?
		if ( $argument =~/^\// ) {			

			if (RESOLVE_SYMLINKS){		
				$abs_path = Cwd::abs_path($argument);
			}

			else {
				$abs_path = abs_path_n($argument);
			}
				
			unless($abs_path){ 
				print STDERR "argument : '$argument', cant resolve with Cwd::abs_path\n" if DEBUG;
				 return ;
			}	
		}



		# IS ARG REL TO CWD ?
		# if starts with dot.. resolve to cwd
		elsif ( $argument =~/^\.\// ){
			unless( $abs_path = Cwd::abs_path(cwd().'/'.$argument) ){
					print STDERR "argument: '$argument', "
					."cant resolve as path rel to current working dir with Cwd abs_path\n" if DEBUG;
					return 0 ;
			}	
		}


		# IS ARG REL TO DOC ROOT ?
		else {
			### assume to be rel path then	
			unless( $self->DOCUMENT_ROOT ){
				print STDERR "argument: '$argument'- DOCUMENT_ROOT "
				."is not set, needed for an argument starting with a dot\n" if DEBUG
				and return 0;
			}	
	
			unless( $abs_path = Cwd::abs_path($self->DOCUMENT_ROOT .'/'.$argument) ){
            print STDERR 
               "argument: '$argument' cant resolve as relative to DOCUMENT ROOT either\n" 
               if DEBUG;
            return 0 ;
			}	
	
		}




		# set main vars
	
		$_abs->{abs_path} = $abs_path or return 0; 

	   unless (defined $self->{check_exist}){
         $self->{check_exist} = 1;
      } 
		if ($self->{check_exist}){
			unless( -e $_abs->{abs_path} ){ 
				print STDERR "'$$_abs{abs_path}' is not on disk\n" if DEBUG;
				#$self->_error( $_abs->{abs_path} ." is not on disk.");
            ### $abs_path 
            ### is explicitely !-e on disk            
            return 0; 
			}					
		}

		$abs_path=~/^(\/.+)\/([^\/]+)$/ 
			or die("problem matching abs loc and filename in [$abs_path], ".
			"argument was [$argument] - maybe you are trying to use a path like /etc,"
			."bad juju."); # should not happen
		$_abs->{abs_loc} = $1;
		$_abs->{filename} = $2;
		if ($_abs->{filename}=~/^(.+)\.(\w{1,4})$/){
			$_abs->{filename_only} =$1;
			$_abs->{ext} = $2;
		}
		else { #may be a dir
			$_abs->{filename_only} = $_abs->{filename};	
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
sub _rel {
	my $self = shift;

	croak($self->errstr) if $self->errstr;	

	unless( defined $self->{_data}->{_rel}){
		my $_rel = {
         rel_path => undef,
         rel_loc => undef,         
      };
	   $self->{_data}->{_rel} = $_rel;
      $self->DOCUMENT_ROOT or warn('cant use rel methods because DOCUMENT ROOT is not set')
			and return $_rel;
      
		my $doc_root = $self->DOCUMENT_ROOT;
		my $abs_path = $self->abs_path or return $_rel;

		if ($doc_root eq $abs_path){
			$_rel->{rel_path} = '';
			$_rel->{rel_loc} = '';			
		}

		else {
         
         unless( $self->is_in_DOCUMENT_ROOT ){ 
				warn("cant use rel methods because this file [$abs_path] is "
				."NOT WITHIN DOCUMENT ROOT:".$self->DOCUMENT_ROOT) if DEBUG;
				return $_rel;
			}	
         
			my $rel_path = $abs_path; #  by now if it was the same as document root, should have been detected
			$rel_path=~s/^$doc_root\/// or croak("abs path [$abs_path] is NOT within DOCUMENT ROOT [$doc_root]");
	
			$_rel->{rel_path} = $rel_path;

			if ($rel_path=~/^(.+)\/([^\/]+)$/){
				my $rel_loc = $1;
				my $filename = $2;

				$filename eq $self->filename or 
					die("filename from abs path not same as filename from init rel regex, why??");
		
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
	defined $self->DOCUMENT_ROOT or return 0;
	$self->abs_loc eq $self->DOCUMENT_ROOT or return 0;
	return 1;
}

sub is_DOCUMENT_ROOT {
	my $self = shift;	
	defined $self->DOCUMENT_ROOT or return 0;	
	$self->abs_path eq $self->DOCUMENT_ROOT or return 0;
	return 1;
}
sub is_in_DOCUMENT_ROOT {
	my $self = shift;
   $self->exists or return;
	my $abs_path = $self->abs_path;
	my $document_root = $self->DOCUMENT_ROOT;

	$abs_path=~/^$document_root\// or return 0; # the trailing slash is imperative

	return 1;
}

sub DOCUMENT_ROOT_set {
   my ($self,$abs)=@_;
   defined $abs or confess("missing argument");
   -d $abs or warn("[$abs] not a dir");
   
   $self->{_data}->{DOCUMENT_ROOT} = $abs;
   return 1;
}




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


# init stat
sub _stat {
	my $self = shift;
   unless( $self->exists ){
		carp('File::PathInfo : no file is set(). Use set().') if DEBUG;
		return {};
	}	
	croak($self->errstr) if $self->errstr;

	unless( defined $self->{_data}->{_stat}){	

	
		my @stat =  stat $self->abs_path or die("$! - cant stat ".$self->abs_path);

		my $data = {
			is_file				=> -f _ ? 1 : 0,
			is_dir				=> -d _ ? 1 : 0,
			is_binary			=> -B _ ? 1 : 0,
			is_text				=> -T _ ? 1 : 0,		
         is_topmost			=> $self->is_topmost,
         is_document_root	=> $self->DOCUMENT_ROOT ? $self->is_DOCUMENT_ROOT : undef,
         is_in_document_root =>  $self->DOCUMENT_ROOT ? $self->is_in_DOCUMENT_ROOT : undef,		
		};
		
		my @keys = qw(dev ino mode nlink uid gid rdev size atime mtime ctime blksize blocks);
		#map { $data->{ shift @keys } = $_ } @stat; 
		for (@stat) {
		 	my $v= $_;
		 	my $key = shift @keys;		
			$data->{$key} = $v;		
		}
		
		$data->{ filesize_pretty }	= ( sprintf "%d",($data->{size} / 1024 )).'k';

      require Time::Format;      
      for my $v (qw(ctime atime mtime)){
         $data->{$v.'_pretty'} = Time::Format::time_format($self->_time_format, $data->{$v} );
      }
         
		$data->{ filesize }		= $data->{size};
	
		$self->{_data}->{_stat} = $data;		
	}

	return $self->{_data}->{_stat};	
}

sub _time_format {
   my $self = shift;
   $self->{time_format} ||= 'yyyy/mm/dd hh:mm';
   return $self->{time_format};
}

sub is_binary {
	my $self = shift;
	return $self->_stat->{is_binary};
}

sub is_dir {
	my $self = shift;
	return $self->_stat->{is_dir};
}

sub is_text {
	my $self = shift;
	return $self->_stat->{is_text};
}

sub is_file {
	my $self = shift;
	return $self->_stat->{is_file};
}
sub filesize {	
 my $self = shift;
 return $self->_stat->{filesize};
}

sub size {	
 my $self = shift;
 return $self->_stat->{size};
}
sub ctime  {
 my $self = shift;
 return $self->_stat->{ctime};
}
sub atime  { 
 my $self = shift;
 return $self->_stat->{atime};
}



sub ctime_pretty  { 
 my $self = shift;
 return $self->_stat->{ctime_pretty};
}

sub mtime_pretty  { 
 my $self = shift;
 return $self->_stat->{mtime_pretty}; 
}

sub atime_pretty  { 
 my $self = shift;
 return $self->_stat->{atime_pretty};
}



sub filesize_pretty  { 
 my $self = shift;
 return $self->_stat->{filesize_pretty};
}

sub mtime  { 
 my $self = shift;
 return $self->_stat->{mtime};
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
	
	for (keys %{$self->_stat}){
		if (defined $self->_stat->{$_}){
			$data->{$_} = $self->_stat->{$_};
		}
	}	

	return $data;	
}

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

sub exists {
   my $self = shift;

   defined $self->{_data}->{exists} or croak('must call set() first');
      
   return $self->{_data}->{exists};
}

sub abs_path_n {
	my $absPath = shift;
	return $absPath if $absPath =~ m{^/$};
   my @elems = split m{/}, $absPath;
   my $ptr = 1;
   while($ptr <= $#elems)
    {
        if($elems[$ptr] eq q{})
        {
            splice @elems, $ptr, 1;
        }
        elsif($elems[$ptr] eq q{.})
        {
            splice @elems, $ptr, 1;
        }
        elsif($elems[$ptr] eq q{..})
        {
            if($ptr < 2)
            {
                splice @elems, $ptr, 1;
            }
            else
            {
                $ptr--;
                splice @elems, $ptr, 2;
            }
        }
        else
        {
            $ptr++;
        }
    }
    return $#elems ? join q{/}, @elems : q{/};

	# by JohnGG 
	# http://perlmonks.org/?node_id=603442	
}

1;

__END__

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

=head1 METHODS

=head2 new()

Argument is either a hash ref or an absolute or relative path to a file.

	my $fi = new File::PathInfo;
	$fi->set('/home/myself/html/file.txt');

	# or

	my $fi = new File::PathInfo('/home/myself/html/file.txt');

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

=head2 set()

Unless you provide an argument to the constructor, set() must be called.
You can use set() to iterate through a list of paths.
Argument is a relative or absolute file path.
	
	$f->set('/tmp/trashdir'); # absolute path

	$f->set('gfx/logo.gif'); # relative to DOCUMENT ROOT

	$f->set('./thisfile.png'); # relative to current working directory

Method C<set()> returns boolean, true or false. If the file cannot be resolved to disk
then it returns undef.
If you then call any methods, exceptions are thrown with Carp::croak.

You can do this too:

	$f->set('/home/myself/html/documents/manual.pdf') or die( $File::PathInfo::errstr );
	
	$f->set('documents/manual.pdf') or print "Location: 404.html\n\n" and exit; 

=head2 get_datahash()

Takes no argument. Returns all elements, in a hash. 

Try it out:

	#!/usr/bin/perl -w
	use File::PathInfo;
	use Smart::Comments '###';
	my $f = new File::PathInfo;	
	$f->set '/home/bubba'
	my $hash = $f->get_datahash;
	### $hash

Prints out:

	### $hash: {
	###          abs_loc => '/home',
	###          abs_path => '/home/bubba',
	###          atime => 1173859680,
	###          atime_pretty => '2007/03/14 04:08',
	###          blksize => 4096,
	###          blocks => 8,
	###          ctime => 1173216034,
	###          ctime_pretty => '2007/03/06 16:20',
	###          dev => 2049,
	###          filename => 'bubba',
	###          filename_only => 'bubba',
	###          filesize => '4096',
	###          filesize_pretty => '4k',
	###          gid => 0,
	###          ino => 3626597,
	###          is_binary => 1,
	###          is_dir => 1,
	###          is_file => 0,
	###          is_text => 0,
	###          is_topmost => 0,
	###          mode => 16877,
	###          mtime => 1173216034,
	###          mtime_pretty => '2007/03/06 16:20',
	###          nlink => 3,
	###          rdev => 0,
	###          size => '4096',
	###          uid => 0
	###        }



=head2 errstr()

Returns errot string or undef if no errors are present.

To check for errors you can query the error string.

	$f->set('/home/myself/this') or die($f->errstr);	
	
=head1 ABSOLUTE METHODS

The absolute path methods. 

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

=head2 rel_path()

relative to DOCUMENT_ROOT

=head2 rel_loc()

location relative to DOCUMENT_ROOT

=head2 is_DOCUMENT_ROOT()

if this *is* the document root
returns undef if DOCUMENT ROOT is not set.

=head2 is_topmost()

if the parent directory is document root.
boolean.
returns undef if DOCUMENT ROOT is not set.

=head2 is_in_DOCUMENT_ROOT()

does this file reside in the DOCUMENT_ROOT tree ?
note that DOCUMENT_ROOT itself *is* the document root, does is not
considered to be *in* the document root. this is partly for security
reasons.

=head2 DOCUMENT_ROOT()

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

You can also call DOCUMENT_ROOT_set() 

=head2 DOCUMENT_ROOT_set()

argumnent is abs path to document root
will warn if not a dir on disk

=head1 STAT METHODS

These methods ask useful things like, is the file a directory, is it binary,
is it text, what is the mtime, etc. These methods load data on call, they can 
be expensive if you are looping through thousands of files. So don't worry 
because if you don't need them, they are not called.
Using one or more of these methods makes one stat call only.

=head2 is_binary()

returns boolean true or false.

=head2 is_text()

returns boolean true or false.

=head2 is_dir()

returns boolean true or false.

=head2 is_file()

returns boolean true or false.

=head2 ctime()

=head2 atime()

=head2 mtime()

=head2 uid()

=head2 ino()

=head2 blksize()

=head2 blocks()

=head2 dev()

=head2 gid()

=head2 mode()

=head2 nlink()

=head2 rdev()

=head2 size()

=head2 filesize_pretty()

Returns filesize in k, with the letter k in the end returns 0k if filesize is 0 .

=head2 ctime_pretty()

=head2 atime_pretty()

=head2 mtime_pretty()

Returns these timestamps formatted to 'yyyy/mm/dd hh:mm' by default. 
To change the format, pass it as argument to object constructor as such:

	my $r = new File::PathInfo({ time_format => 'yyyy_mm_dd' });
	
	$r->set('/home/myself/archive1.zip');
	
	$r->ctime_pretty; # now holds 1999_11_13
   
=head2 filesize()

Returns filesize in bites.


=head1 PROCEDURAL SUBROUTINES

None of these functions are exported by default.
These subs are used by the oo methods internally, and you can use them in your code also
by the normal import ways:

	use File::PathInfo ':all';

	use File::PathInfo qw(abs_path_n);

=head2 abs_path_n()

just like Cwd::abs_path() but, does not resolve symlinks. Just cleans up the path.
argument is an absolute path.

=head1 PACKAGE SETTINGS

Resolve symlinks? Default is 1 ( Not Yet Implemented )

	File::PathInfo::RESOLVE_SYMLINKS = 0;	

Debug

	File::PathInfo::DEBUG = 1;	
	
=head1 CAVEATS

This is currently for unix filesystems. File::PathInfo will NOT work on non POSIX operating
systems. Trying to set an abs path like C:/something will throw an exception.

The module gets very angry when you set() seomthing like '/etc', anything that sits close to
the root of the filesystem. This is on purpose.

=head1 TODO

Let people specify a file delimiter for mac and windoze.

Maybe Time::Format is not appropriate here.

=head1 BUGS

Please report any bugs to developer.

=head1 AUTHOR

Leo Charre	leocharre at cpan dot org

L<http://leocharre.com>

=head1 PREREQUISITES

L<Cwd>, L<Carp>, L<Time::Format>

=head1 LICENSE

This program is free software; you can redistribute it
and/or modify it under the same terms and conditions as
Perl itself.

=head1 SEE ALSO

L<File::PathInfo::Ext>
L<Cwd>

=cut


