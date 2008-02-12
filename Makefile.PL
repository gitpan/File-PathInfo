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
);
