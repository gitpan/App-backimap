package App::backimap::Status;
# ABSTRACT: manages backimap status

use Moose;
use MooseX::Storage;
with Storage( 'format' => 'JSON', 'io' => 'File' );

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

1;

__END__
=pod

=head1 NAME

App::backimap::Status - manages backimap status

=head1 VERSION

version 0.00_06

=head1 ATTRIBUTES

=head2 timestamp

Time of last run started.

=head2 server

Server name used in IMAP.

=head2 user

User name used in IMAP.

=head2 folder

Collection of folder status.

=head1 AUTHOR

Alex Muntada <alexm@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by Alex Muntada.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

