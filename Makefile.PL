use ExtUtils::MakeMaker;
WriteMakefile(
	NAME				=> "File::PathInfo",
	VERSION_FROM	=> 'lib/File/PathInfo.pm',
	PREREQ_PM 		=> {
		'Time::Format' => '1',
		'Cwd'	=> '3',
	},
	'dist'			=> { COMPRESS => 'gzip', SUFFIX => 'gz' },
);
