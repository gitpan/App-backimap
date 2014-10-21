package App::backimap::Status::Folder;
# ABSTRACT: backimap folder status

use Moose;
use MooseX::Storage;
with Storage;

has count => (
    is => 'rw',
    isa => 'Int',
    required => 1,
);

has unseen => (
    is => 'rw',
    isa => 'Int',
    required => 1,
);

1;

__END__
=pod

=head1 NAME

App::backimap::Status::Folder - backimap folder status

=head1 VERSION

version 0.00_06

=head1 AUTHOR

Alex Muntada <alexm@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by Alex Muntada.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

