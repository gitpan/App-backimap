
use strict;
use warnings;

BEGIN { require 5.010; }

use ExtUtils::MakeMaker 6.31;



my %WriteMakefileArgs = (
  'ABSTRACT' => 'backups imap mail',
  'AUTHOR' => 'Alex Muntada <alexm@cpan.org>',
  'BUILD_REQUIRES' => {
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
    'English' => '0',
    'File::HomeDir' => '0',
    'Getopt::Long' => '0',
    'Git::Wrapper' => '0',
    'IO::Prompt' => '0',
    'IO::Socket::SSL' => '0',
    'Mail::IMAPClient' => '0',
    'Moose' => '0',
    'Moose::Util::TypeConstraints' => '0',
    'MooseX::Storage' => '0',
    'MooseX::Types::Path::Class' => '0',
    'Path::Class' => '0',
    'Pod::Usage' => '0',
    'URI' => '0'
  },
  'VERSION' => '0.00_07',
  'test' => {
    'TESTS' => 't/*.t'
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



