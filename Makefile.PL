if( $^O=~/mswin32|cygwin/i ){ die("Unsupported OS."); }

use ExtUtils::MakeMaker;
WriteMakefile(
	NAME				=> "File::PathInfo",
	VERSION_FROM	=> 'lib/File/PathInfo.pm',
	PREREQ_PM 		=> {
		'Time::Format' => '0.01',
      'Smart::Comments' => '0',
		'Cwd'	=> '0.1',
	},
	'dist'			=> { COMPRESS => 'gzip', SUFFIX => 'gz' },
   ABSTRACT_FROM => 'lib/File/PathInfo.pod',
   LICENSE => 'perl',
   AUTHOR => 'Leo Charre leocharre at cpan dot org',
);
