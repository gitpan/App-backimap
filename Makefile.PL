
use strict;
use warnings;



use ExtUtils::MakeMaker 6.31;



my %WriteMakefileArgs = (
  'ABSTRACT' => 'backups imap mail',
  'AUTHOR' => 'Alex Muntada <alexm@cpan.org>',
  'BUILD_REQUIRES' => {
    'Test::Moose' => '0',
    'Test::More' => '0'
  },
  'CONFIGURE_REQUIRES' => {
    'ExtUtils::MakeMaker' => '6.31'
  },
  'DISTNAME' => 'App-backimap',
  'EXE_FILES' => [
    'bin/backimap'
  ],
  'LICENSE' => 'perl',
  'NAME' => 'App::backimap',
  'PREREQ_PM' => {
    'Data::Dump' => '0',
    'Encode' => '0',
    'Encode::IMAPUTF7' => '0',
    'English' => '0',
    'File::HomeDir' => '0',
    'Git::Wrapper' => '0',
    'IO::Prompt' => '0',
    'IO::Socket::SSL' => '0',
    'Mail::IMAPClient' => '0',
    'Moose' => '0',
    'Moose::Util::TypeConstraints' => '0',
    'MooseX::Getopt' => '0',
    'MooseX::Storage' => '0',
    'MooseX::Types::Path::Class' => '0',
    'Path::Class' => '0',
    'Term::ProgressBar' => '0',
    'Try::Tiny' => '0',
    'URI' => '0',
    'URI::Escape' => '0'
  },
  'VERSION' => '0.00_09',
  'test' => {
    'TESTS' => 't/*.t t/status/*.t'
  }
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.56) } ) {
  my $br = delete $WriteMakefileArgs{BUILD_REQUIRES};
  my $pp = $WriteMakefileArgs{PREREQ_PM};
  for my $mod ( keys %$br ) {
    if ( exists $pp->{$mod} ) {
      $pp->{$mod} = $br->{$mod} if $br->{$mod} > $pp->{$mod};
    }
    else {
      $pp->{$mod} = $br->{$mod};
    }
  }
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);



