package App::backimap::Storage;
# ABSTRACT: manages backimap storage

use Moose;
use Moose::Util::TypeConstraints;
use MooseX::Types::Path::Class;
use File::HomeDir;
use Git::Wrapper;


has dir => (
    is => 'ro',
    isa => 'Path::Class::Dir',
    required => 1,
    coerce => 1,
    default => sub { File::HomeDir->my_home . ".backimap" },
);


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
        die "directory $dir is dirty, consider --clean option\n"
            unless $self->clean;

        _git_reset($git);

        if ( $git->status->is_dirty ) {
            my @unknown = map { $_->from } $git->status->get("unknown");
            die "directory $dir still has unknown files: @unknown\n";
        }
    }

    return $git;
}


sub find {
    my $self = shift;

    my @found = grep { -f $self->dir->file($_) } @_;
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
    my %files = @_;

    # This makes sure that git repo is properly initialized
    # before any new file is added. Otherwise it would fail
    # because repo would be dirty.
    my $git = $self->_git;

    my $dir = $self->dir;

    for my $filename ( keys %files ) {
        my $filepath = $dir->file($filename);
        $filepath->dir->mkpath()
            unless -d $filepath->dir;

        my $file = $filepath->open('w')
            or die "cannot open $filepath: $!";

        $file->print( $files{$filename} );
        $file->close();

        $git->add($filename);
    }
}


sub delete {
    my $self = shift;

    my @files = map { $self->dir->file($_)->stringify() } @_;

    $self->_git->rm(@files)
        if @files;
}


sub move {
    my $self = shift;
    my ( $from, $to ) = @_;

    $self->_git->mv( $from, $to );
}


sub commit {
    my $self = shift;
    my $change = shift;

    if (@_) {
        $self->_git->commit( { message => $change }, @_ );
    }
    else {
        $self->_git->commit( { message => $change, all => 1 } );
    }
}


sub reset {
    _git_reset( shift->_git );
}


sub pack   { }
sub unpack { }

1;

__END__
=pod

=head1 NAME

App::backimap::Storage - manages backimap storage

=head1 VERSION

version 0.00_09

=head1 ATTRIBUTES

=head2 dir

Sets pathname to the storage (defaults to ~/.backimap).

=head2 init

Tells that storage must be initialized.

=head2 clean

Tells that storage must be cleaned if dirty.

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

Adds files to storage with a text describing the change.

=head2 delete( $file, ... )

Removes files from storage.

=head2 move

Renames or moves files and directories from one place to another in storage.

=head2 commit($change, [$file] ...)

Commits pending storage actions with a description of change.
If a list of files is provided, only those will be committed.
Otherwise all pending actions will be performed.

=head2 reset

Rolls back any storage actions that were performed but not committed.
Returns storage back to last committed status.

=for Pod::Coverage pack unpack

Required methods in status for MooseX::Storage that don't perform any action
since the storage backend does not support serialization.

=head1 AUTHOR

Alex Muntada <alexm@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by Alex Muntada.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

