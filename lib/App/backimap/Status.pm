package App::backimap::Status;
# ABSTRACT: manages backimap status

use Moose;
use MooseX::Storage;
with Storage( 'format' => 'JSON' );

use English qw( -no_match_vars );


has timestamp => (
    is => 'ro',
    isa => 'Int',
    default => $BASETIME,
    required => 1,
);


has server => (
    is => 'ro',
    isa => 'Str',
    required => 1,
);


has user => (
    is => 'ro',
    isa => 'Str',
    required => 1,
);


has folder => (
    is => 'rw',
    isa => 'HashRef[App::backimap::Status::Folder]',
);


has storage => (
    is => 'ro',
    isa => 'App::backimap::Storage',
);

my $FILENAME = 'backimap.json';


sub BUILD {
    my $self = shift;

    return unless $self->storage;

    if ( $self->storage->init ) {
        $self->save();
    }
    else {
        my $json = $self->storage->get($FILENAME);
        my $status = App::backimap::Status->thaw($json);

        die "IMAP credentials do not match saved status\n"
            if $status->user ne $self->user ||
                $status->server ne $self->server;

        $self->folder( $status->folder )
            if $status->folder;
    }
}


sub save {
    my $self = shift;

    return unless $self->storage;

    my $json = $self->freeze();
    $self->storage->put( $FILENAME => $json );
}

1;

__END__
=pod

=head1 NAME

App::backimap::Status - manages backimap status

=head1 VERSION

version 0.00_07

=head1 ATTRIBUTES

=head2 timestamp

Time of last run started.

=head2 server

Server name used in IMAP.

=head2 user

User name used in IMAP.

=head2 folder

Collection of folder status.

=head2 storage

Object to use as the storage backend for status.

=head1 METHODS

=head2 save

Save status to storage backend.

=for Pod::Coverage BUILD

Extra status initialization is not documented.

=head1 AUTHOR

Alex Muntada <alexm@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by Alex Muntada.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

