use strict;
use warnings;

package App::backimap::Storage;
BEGIN {
  $App::backimap::Storage::VERSION = '0.00_13';
}
# ABSTRACT: manages backimap storage

use Moose;
use Moose::Util::TypeConstraints;
use MooseX::Types::Path::Class;
use File::HomeDir;
use Git::Wrapper;
use IO::Scalar;
use MIME::Parser;
use Encode;
use Storable;


has dir => (
    is => 'ro',
    isa => 'Path::Class::Dir',
    required => 1,
    coerce => 1,
    builder => '_build_dir',
);

sub _build_dir { return File::HomeDir->my_home . ".backimap" }


has init => (
    is => 'ro',
    isa => 'Bool',
    default => 0,
);


has clean => (
    is => 'ro',
    isa => 'Bool',
    default => 0,
);


has resume => (
    is => 'ro',
    isa => 'Bool',
    default => 0,
);


has author => (
    is => 'ro',
    isa => 'Str',
    default => 'backimap',
);


has email => (
    is => 'ro',
    isa => 'Str',
    default => 'backimap@example.org',
);

sub _git_reset {
    shift->reset( { hard => 1 } );
}

subtype 'Git::Wrapper' => as 'Object' => where { $_->isa('Git::Wrapper') };

has _git => (
    is => 'ro',
    isa => 'Git::Wrapper',
    lazy => 1,
    builder => '_build_git',
);

sub _build_git {
    my $self = shift;

    my $dir = $self->dir;
    my $git = Git::Wrapper->new("$dir");

    if ( $self->init ) {
        die "directory $dir already initialized\n"
            if -d $dir->subdir(".git");

        $dir->mkpath();
        $git->init();
        $git->config( "user.name", $self->author );
        $git->config( "user.email", $self->email );
    }

    if ( $git->status->is_dirty ) {
        die "directory $dir is dirty, consider --clean or --resume options\n"
            unless $self->clean or $self->resume;

        my @unknown = map { $_->from } $git->status->get("unknown");

        # --resume takes precedence over --clean
        if ( $self->resume ) {
            for my $file (@unknown) {
                $dir->file($file)->remove();
            }

            eval { $git->commit( { all => 1, message => 'resume previous backup' } ) }
                if $git->status->is_dirty;
        }
        elsif ( $self->clean ) {
            _git_reset($git);

            die "directory $dir has unknown files: @unknown\n"
                if @unknown;
        }
    }

    return $git;
}


sub BUILD {
    # This makes sure that git repo is properly initialized
    # before returning successfully from new() constructor.

    shift->_git();
}


sub find {
    my $self = shift;

    my @found = grep { -e $self->dir->file($_) } @_;
    return @found;
}


sub list {
    my $self = shift;
    my ($dir) = @_;

    $dir = $self->dir->subdir($dir);
    return unless -d $dir;

    my @list = grep !( $_->is_dir() ), $dir->children();

    @list = map { $_->relative($dir) } @list;
    return @list;
}


sub get {
    my $self = shift;
    my ($file) = @_;

    return $self->dir->file($file)->slurp();
}


sub put {
    my $self = shift;

    my $op = sub {
        my $self = shift;
        my ( $filename, $content_ref ) = @_;

        my $filepath = $self->dir->file($filename);
        $filepath->dir->mkpath()
            unless -d $filepath->dir;

        my $file = $filepath->open('w')
            or die "cannot open $filepath: $!";

        $file->print($$content_ref);
        $file->close();
    };

    $self->_put_files( $op, @_ );
}


sub explode {
    my $self = shift;

    my $op = sub {
        my $self = shift;
        my ( $dir, $content_ref ) = @_;

        my $filepath = $self->dir->subdir($dir);
        $filepath->mkpath()
            unless -d $filepath;

        my $parser = MIME::Parser->new();
        $parser->output_dir( Encode::decode( 'UTF-8', $filepath ) );
        $parser->decode_bodies(1);
        $parser->extract_nested_messages(1);
        $parser->extract_uuencode(1);
        $parser->ignore_errors(1);

        my $entity = $parser->parse( IO::Scalar->new($content_ref) );

        my $filename = $filepath->file('__MIME__');
        Storable::nstore( $entity, $filename )
            or die "cannot open $filename: $!";
    };

    $self->_put_files( $op, @_ );
}

sub _put_files {
    my $self = shift;
    my ( $op, %content_for ) = @_;
    my $git = $self->_git;

    for my $filename ( keys %content_for ) {
        $self->$op( $filename, \$content_for{$filename} );
        $git->add($filename);
    }
}


sub delete {
    my $self = shift;
    my $git = $self->_git;

    my @files = map { "$_" } @_;

    $git->rm(@files)
        if @files;
}


sub move {
    my $self = shift;
    my ( $from, $to ) = @_;
    my $git = $self->_git;

    $git->mv( $from, $to );
}


sub commit {
    my $self = shift;
    my $change = shift;
    my $git = $self->_git;

    if (@_) {
        $git->commit( { message => $change }, @_ );
    }
    else {
        $git->commit( { message => $change, all => 1 } );
    }
}


sub reset {
    _git_reset( shift->_git );
}

# Required methods in status for MooseX::Storage that don't perform any action
# since the storage backend does not support serialization.

sub pack   { }
sub unpack { }

1;

__END__
=pod

=head1 NAME

App::backimap::Storage - manages backimap storage

=head1 VERSION

version 0.00_13

=head1 ATTRIBUTES

=head2 dir

Sets pathname to the storage (defaults to ~/.backimap).

=head2 init

Tells that storage must be initialized.

=head2 clean

Tells that storage must be cleaned if dirty.

=head2 resume

Tells that storage should try to resume from a dirty state:
preserve previous scheduled files and purge unknown ones
before performing a commit.

=head2 author

Name of the committing author in local storage.

The name is configured on the storage initialization.

=head2 email

Author email address that will be used along with the author name
as the committing author.

The email is configured on the storage initialization.

=head1 METHODS

=head2 find( $file, ... )

Returns a list of files that are found in storage.

=head2 list( $dir )

Returns a list of files in a directory from storage.

=head2 get( $file )

Retrieves file from storage.

=head2 put( $file => $content, ... )

Adds files to storage.

=head2 explode( $dir => $content, ... )

Explodes content MIME parts in several files and adds them to storage.

=head2 delete( $file, ... )

Removes files from storage.

=head2 move( $from, $to )

Renames or moves files and directories from one place to another in storage.

=head2 commit( $change, [$file] ... )

Commits pending storage actions with a description of change.
If a list of files is provided, only those will be committed.
Otherwise all pending actions will be performed.

=head2 reset()

Rolls back any storage actions that were performed but not committed.
Returns storage back to last committed status.

=for Pod::Coverage BUILD

=for Pod::Coverage pack unpack

=head1 AUTHOR

Alex Muntada <alexm@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by Alex Muntada.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

