package App::backimap;
# ABSTRACT: backups imap mail


use strict;
use warnings;

use Moose;
use App::backimap::Status;
use App::backimap::Status::Folder;
use App::backimap::IMAP;
use App::backimap::Storage;

has status => (
    is => 'rw',
    isa => 'App::backimap::Status',
);

has imap => (
    is => 'rw',
    isa => 'App::backimap::IMAP',
);

has storage => (
    is => 'rw',
    isa => 'App::backimap::Storage',
);

use Getopt::Long         qw( GetOptionsFromArray );
use Pod::Usage;
use URI;
use File::Spec::Functions qw( catfile );
use File::Path            qw( mkpath );
use Git::Wrapper;
use File::HomeDir;
use Carp;


sub new {
    my ( $class, @argv ) = @_;

    my %opt = (
        help    => 0,
        verbose => 0,
        dir     => catfile( File::HomeDir->my_home, ".backimap" ),
        init    => 0,
    );

    GetOptionsFromArray(
        \@argv,
        \%opt,

        'help|h',
        'verbose|v',
        'dir=s',
        'init',
    )
        or __PACKAGE__->usage();

    $opt{'args'} = \@argv;

    return bless \%opt, $class;
}


sub setup {
    my ( $self, $str ) = @_;

    my $uri = URI->new($str);

    $self->imap(
        App::backimap::IMAP->new( uri => $uri )
    );

    $self->status(
        App::backimap::Status->new(
            server    => $self->imap->host,
            user      => $self->imap->user,
        )
    );

    my $dir = $self->{'dir'};
    my $filename = catfile( $dir, "backimap.json" );

    $self->storage(
        App::backimap::Storage->new(
            dir => $dir,
            init => $self->{'init'},
        ),
    );

    # save initial status
    $self->save()
        if $self->{'init'};

    my $status = App::backimap::Status->load($filename);

    die "imap details do not match with previous status\n"
        if $status->user ne $self->status->user ||
            $status->server ne $self->status->server;

    $self->status->folder( $status->folder )
        if $status->folder;
}


sub save {
    my ($self) = @_;

    my $git = $self->{'git'};

    croak "must define status first"
        unless defined $self->status;

    $self->status->store( catfile( $self->{'dir'}, "backimap.json" ) );
    $self->storage->put("save status");
}


sub backup {
    my ($self) = @_;

    my $imap = $self->imap->client;

    my $path = $self->imap->path;
    $path =~ s#^/+##;

    my @folder_list = $path ne '' ? $path : $imap->folders;

    print STDERR "Examining folders...\n"
        if $self->{'verbose'};

    for my $folder (@folder_list) {
        my $count  = $imap->message_count($folder);
        next unless defined $count;

        my $unseen = $imap->unseen_count($folder);

        if ( $self->status->folder ) {
            $self->status->folder->{$folder}->count($count);
            $self->status->folder->{$folder}->unseen($unseen);
        }
        else {
            my %status = (
                $folder => App::backimap::Status::Folder->new(
                    count => $count,
                    unseen => $unseen,
                ),
            );

            $self->status->folder(\%status);
        }

        print STDERR " * $folder ($unseen/$count)"
            if $self->{'verbose'};

        $imap->examine($folder);
        for my $msg ( $imap->messages ) {
            my $file = catfile( $folder, $msg );
            next if $self->storage->get($file);

            my $fetch = $imap->fetch( $msg, 'RFC822' );
            $self->storage->put( "save message $file", $file => $fetch->[2] );
        }

        print STDERR "\n"
            if $self->{'verbose'};
    }
}


sub run {
    my ($self) = @_;

    my @args = @{ $self->{'args'} };
    $self->usage unless @args == 1;

    $self->setup(@args);
    $self->backup();
    $self->save();

    my $spent = ( time - $^T ) / 60;
    printf STDERR "Backup took %.2f minutes.\n", $spent
        if $self->{'verbose'};
}


sub usage {
    my ($self) = @_;

    pod2usage( verbose => 0, exitval => 1 );
}

1;

__END__
=pod

=head1 NAME

App::backimap - backups imap mail

=head1 VERSION

version 0.00_06

=head1 SYNOPSIS

    use App::backimap;
    App::backimap->new(@ARGV)->run();

=head1 METHODS

=head2 new

Creates a new program instance with command line arguments.

=head2 setup

Setups configuration and prompts for password if needed.
Then opens Git repository (initialize if asked) and
load previous status.

=head2 save

Save current status into Git repository.

=head2 backup

Perform IMAP folder backup recursively into Git repository.

=head2 run

Parses command line arguments and starts the program.

=head2 usage

Shows an usage summary.

=head1 AUTHOR

Alex Muntada <alexm@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by Alex Muntada.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

