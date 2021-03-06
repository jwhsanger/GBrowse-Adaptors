#!/usr/bin/perl

use strict;
use Module::Build;

my $HeaderFile = "bam.h";
my $LibFile    = "libbam.a";
my $ReadLine;

my ($sam_include,$sam_lib) = find_sam(); # may exit with error here

my $class = Module::Build->subclass(code=><<EOF);
    sub process_c_bin_files {
	my \$self = shift;
	chomp(my \$make  = `which make`);
	chomp(my \$nmake = `which nmake`);
	\$make ||= \$nmake;
	system "cd c_bin; \$make INCLUDES=-I$sam_include LIBPATH=-L$sam_lib";
	mkdir "blib/bin" unless -e "blib/bin";
        my \@exec = grep {-x \$_} <c_bin/*>;
	\$self->copy_if_modified(from   =>\$_,
				 to_dir => "./blib/bin/",
				 flatten=>1,
	    ) foreach \@exec;
    }

    sub ACTION_clean {
	my \$self = shift;
	\$self->SUPER::ACTION_clean();
        system "cd c_bin; make -s clean";
    }
EOF

my $build = $class->new(
    module_name        => 'Bio::SamTools',
    dist_version_from  => 'lib/Bio/DB/Sam.pm',
    dist_author        => 'Lincoln Stein <lincoln.stein@gmail.com>',
    dist_abstract      => 'Perl interface to SamTools library for DNA sequencing',
    license            => 'perl',
    include_dirs       => [$sam_include],
    extra_linker_flags => ["-L$sam_lib",'-lbam','-lpthread','-lz'],

    extra_compiler_flags=>[

        # must match DFLAGS in Samtools Makefile
	'-D_IOLIB=2','-D_FILE_OFFSET_BITS=64', 

	# turn off warnings originating in Perl's Newx* calls
	'-Wformat=0'
    ],

    c_source    => 'c_bin',
    c_bin_files => {'./bin/bam2bedgraph' => 'bin/bam2bedgraph'},

    build_requires => {
      'ExtUtils::CBuilder' => 0,
    },
    requires     => {
	'perl'                => '5.008',
	'Bio::Root::Version'  => '1.006009001',
    },
#    create_makefile_pl => 'passthrough',
    );

$build->add_build_element('c_bin');
$build->create_build_script;

exit 0;

sub find_sam {
    my ($sam_include,$sam_lib);

    if (my $samtools = $ENV{SAMTOOLS}) {
	$sam_include = $samtools
	    if -e "$samtools/$HeaderFile";
	$sam_include = "$samtools/include"
	    if -e "$samtools/include/$HeaderFile";
	$sam_lib     = $samtools
	    if -e "$samtools/$LibFile";
	$sam_lib     = "$samtools/lib"
	    if -e "$samtools/lib/$LibFile";
    }

    my @search_path = qw(/ /usr /usr/share /usr/local);

    unless ($sam_include) {
	for my $p (@search_path) {
	    $sam_include ||= "$p/include" if
		-e "$p/include/$HeaderFile";
	}
    }

    unless ($sam_lib) {
	for my $p (@search_path) {
	    $sam_lib ||= "$p/lib" if
		-e "$p/lib/$LibFile";
	}
    }


    unless ($sam_include && $sam_lib) {
	print STDOUT "This module requires samtools 0.1.10 or higher (samtools.sourceforge.net).\n";
	my $prompt = "Please enter the location of the bam.h and compiled libbam.a files: ";
	my $found;
	while (!$found) {
	    my $path = prompt($prompt);
	    print STDOUT "\n";
	    last unless $path;
	    $sam_include = $path
		if -e "$path/$HeaderFile";
	    $sam_include = "$path/include"
		if -e "$path/include/$HeaderFile";
	    $sam_lib = $path
		if -e "$path/$LibFile";
	    $sam_lib = "$path/lib"
		if -e "$path/lib/$LibFile";
	    $found = $sam_include && $sam_lib;
	    unless ($found) {
		print STDOUT "That didn't seem to be right.\n";
		$prompt = "Try again, or hit <enter> to cancel: ";
	    }
	}
    }

    unless ($sam_include && $sam_lib) {
	die <<END;
Can\'t find $LibFile and/or $HeaderFile!

If you haven\'t done so already, please compile samtools 0.1.10 or
higher from http://samtools.sourceforge.net and set the SAMTOOLS
environment variable to point to a samtools distribution directory
containing the compiled $LibFile and $HeaderFile files.
END
}

    print STDOUT "Found $sam_include/$HeaderFile and $sam_lib/$LibFile.\n";
    return ($sam_include,$sam_lib);
}


sub prompt {
    my $msg = shift;

    unless (defined $ReadLine) {
	eval "require Term::ReadLine";
	$ReadLine   = Term::ReadLine->can('new') || 0;
	$ReadLine &&= Term::ReadLine->new(\*STDOUT);
	eval {readline::rl_set('TcshCompleteMode','On')};
    }

    
    unless ($ReadLine) {
	print STDOUT $msg;
	chomp (my $in = <>);
	return $in;
    }

    my $in = $ReadLine->readline($msg);
    chomp $in;
    $in=~ s/\s+//;
    $ReadLine->addhistory($in) if $in =~ /\S/;
    return $in;
}
