package SWF::Editor::Tag;

use Mouse;

use SWF::Editor::Utils::Header;

has data       => ( is => "rw" );
has header     => ( is => "rw" );
has type       => ( is => "rw" );
has object_id  => ( is => "rw", isa => 'Int', lazy_build => 1 );

sub get_binary {
    my $self = shift;

    if ( is_long_header($self->header) ) {
        pack("vVa*", $self->header, $self->length, $self->data);
    }
    else {
        pack("va*",  $self->header,                $self->data);
    }
}

sub _build_object_id {
    my $self = shift;

    unpack('v', substr($self->data, 0, 2));
}

sub length {
    my $self = shift;
    return length $self->data;
}

__PACKAGE__->meta->make_immutable;

