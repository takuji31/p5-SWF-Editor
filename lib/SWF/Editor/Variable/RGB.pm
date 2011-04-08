package  SWF::Editor::Variable::RGB;
use Mouse;

use SWF::Editor::Utils::IOBit;

has r => (is => 'rw', isa => 'Int', lazy_build => 1);
has g => (is => 'rw', isa => 'Int', lazy_build => 1);
has b => (is => 'rw', isa => 'Int', lazy_build => 1);


sub get_binary {
    my $self = shift;
    unless ( $self->has_r && $self->has_g && $self->has_b ) {
        confess("Property r, g and b are required!");
    }
    my $iobit = SWF::Editor::Utils::IOBit->new;
    for my $c ( qw/ r g b / ) {
        $iobit->put_ui8($self->$c);
    }

    return $iobit->output;
}

__PACKAGE__->meta->make_immutable;
