package App::backimap::IMAP;
# ABSTRACT: manages IMAP connections

use Moose;
use Moose::Util::TypeConstraints;
use IO::Prompt();
use Mail::IMAPClient();

use 5.010;


subtype 'URI::imap'  => as Object => where { $_->isa('URI::imap')  };
subtype 'URI::imaps' => as Object => where { $_->isa('URI::imaps') };

has uri => (
    is => 'ro',
    isa => 'URI::imap | URI::imaps',
    required => 1,
);


has host => (
    is => 'ro',
    isa => 'Str',
    lazy => 1,
    default => sub { return shift->uri->host },
);


has port => (
    is => 'ro',
    isa => 'Int',
    lazy => 1,
    default => sub { return shift->uri->port },
);


has secure => (
    is => 'ro',
    isa => 'Bool',
    lazy => 1,
    default => sub { return shift->uri->secure },
);


has user => (
    is => 'ro',
    isa => 'Str',
    lazy => 1,
    default => sub { return ( split /:/, shift->uri->userinfo )[0] },
);


has password => (
    is => 'ro',
    isa => 'Str',
    lazy => 1,
    default => sub {
        my $self = shift;

        my $password = ( split /:/, $self->uri->userinfo )[1];
        # note that return value must be stringified, hence the .= op
        $password .= IO::Prompt::prompt( 'Password: ', -te => '*' )
            unless defined $password;

        return $password;
    },
);


has path => (
    is => 'ro',
    isa => 'Str',
    lazy => 1,
    default => sub { shift->uri->path },
);


subtype 'App::backimap::Types::Authenticated'
    => as 'Mail::IMAPClient'
    => where { $_->IsAuthenticated }
    => message { 'Could not authenticate to IMAP server.'  };

has client => (
    is => 'ro',
    isa => 'App::backimap::Types::Authenticated',
    lazy => 1,
    default => sub {
        my $self = shift;

        require IO::Socket::SSL
            if $self->secure;

        my $client = Mail::IMAPClient->new(
            Server   => $self->host,
            Port     => $self->port,
            Ssl      => $self->secure,
            User     => $self->user,
            Password => $self->password,

            # enable imap uid per folder
            Uid => 1,
        );

        return $client;
    },
);

# FIXME: URI::imaps does not override secure method with a true value
#        https://rt.cpan.org/Ticket/Display.html?id=65679
package URI::imaps;

sub secure { 1 }

1;

__END__
=pod

=head1 NAME

App::backimap::IMAP - manages IMAP connections

=head1 VERSION

version 0.00_06

=head1 ATTRIBUTES

=head2 uri

An L<URI::imap> or L<URI::imaps> object with the details
to establish an IMAP connection. Password is optional but
a prompt will ask for it if not provided.

=head2 host

Host name of the IMAP server.

(This attribute is derived from C<uri> above.)

=head2 port

Port number of the IMAP server.

(This attribue is derived from C<uri> above.)

=head2 secure

Boolean describing whether the connection is secure.

(This attribute is derived from C<uri> above.)

=head2 user

User name used to login on the IMAP server.

(This attribute is derived from C<uri> above.)

=head2 password

The password the user has to provide to login on the IMAP server.
If password is not provided either in the C<uri> or as an
argument to the constructor, a prompt will be shown in order to
provide it.

(This attribute can be derived from C<uri> above, if provided.)

=head2 path

Path name to select from the IMAP server. If not provided
all the IMAP folders will be selected recursively.

=head2 client

IMAP client connection.

=head1 AUTHOR

Alex Muntada <alexm@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by Alex Muntada.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

