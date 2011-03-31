package App::backimap;
# ABSTRACT: backups imap mail


use strict;
use warnings;

use Moose;
use App::backimap::Status;
use App::backimap::Status::Folder;
use App::backimap::IMAP;
use App::backimap::Storage;
use Try::Tiny;
use Encode::IMAPUTF7();
use Encode();


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
use Path::Class qw( file );


sub new {
    my ( $class, @argv ) = @_;

    my %opt = (
        help    => 0,
        verbose => 0,
        dir     => undef,
        init    => 0,
        clean   => 0,
    );

    GetOptionsFromArray(
        \@argv,
        \%opt,

        'help|h',
        'verbose|v+',
        'dir=s',
        'init!',
        'clean!',
    )
        or __PACKAGE__->usage();

    $opt{'args'} = \@argv;

    return bless \%opt, $class;
}


sub setup {
    my ( $self, $str ) = @_;

    my $storage = App::backimap::Storage->new(
        dir   => $self->{'dir'},
        init  => $self->{'init'},
        clean => $self->{'clean'},
    );
    $self->storage($storage);

    my $uri  = URI->new($str);
    my $imap = App::backimap::IMAP->new( uri => $uri );
    $self->imap($imap);

    my $status = App::backimap::Status->new(
        storage => $storage,
        server  => $imap->host,
        user    => $imap->user,
    );
    $self->status($status);
}


sub backup {
    my ($self) = @_;

    my $storage = $self->storage;
    my $status_of = $self->status->folder;

    my $imap = $self->imap->client;
    my @folder_list = $self->imap->path ne ''
                    ? $self->imap->path
                    : $imap->folders;

    print STDERR "Examining folders...\n"
        if $self->{'verbose'};

    try {
        for my $folder (@folder_list) {
            my $folder_name = Encode::encode( 'utf-8', Encode::decode( 'imap-utf-7', $folder ) );
            my $count  = $imap->message_count($folder);
            next unless defined $count;
    
            my $unseen = $imap->unseen_count($folder);
    
            if ( $status_of && exists $status_of->{$folder_name} ) {
                $status_of->{$folder_name}->count($count);
                $status_of->{$folder_name}->unseen($unseen);
            }
            else {
                my $new_status = App::backimap::Status::Folder->new(
                    count => $count,
                    unseen => $unseen,
                );
    
                $self->status->folder({ $folder_name => $new_status });
            }
    
            print STDERR " * $folder_name ($unseen/$count)"
                if $self->{'verbose'};
    
            # list of potential files to purge
            my %purge = map { $_ => 1 } $storage->list($folder_name);
    
            $imap->examine($folder);
            for my $msg ( $imap->messages ) {
                # do not purge if still present in server
                delete $purge{$msg};
    
                my $file = file( $folder_name, $msg );
                next if $storage->find($file);
    
                my $fetch = $imap->fetch( $msg, 'RFC822' );
                $storage->put( "$file" => $fetch->[2] );
            }
    
            if (%purge) {
                local $, = q{ };
                print STDERR " (", keys %purge, ")"
                    if $self->{'verbose'};

                my @purge = map { file( $folder_name, $_ ) } keys %purge;
                $storage->delete(@purge);
            }
    
            print STDERR "\n"
                if $self->{'verbose'};
        }
    }
    catch {
        die "oops! error in IMAP transaction...\n\n" .
            $imap->Results .
            sprintf( "\ntime=%.2f\n", ( $^T - time ) / 60 );
    }
}


sub run {
    my ($self) = @_;

    my @args = @{ $self->{'args'} };
    $self->usage unless @args == 1;

    $self->setup(@args);

    my $start = time();
    $self->backup();
    my $spent = ( time() - $start ) / 60;
    my $message = sprintf "backup took %.2f minutes", $spent;

    $self->status->save();
    $self->storage->commit($message);

    printf STDERR "$message\n"
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

version 0.00_08

=head1 SYNOPSIS

    use App::backimap;
    App::backimap->new(@ARGV)->run();

=head1 ATTRIBUTES

=head2 status

Application persistent status.

=head2 imap

An object to encapsulate IMAP details.

=head2 storage

Storage backend where files and messages are stored.

=head1 METHODS

=head2 new

Creates a new program instance with command line arguments.

=head2 setup

Setups storage, IMAP connection and backimap status.

=head2 backup

Perform IMAP folder backup recursively.

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

