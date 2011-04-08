package  SWF::Editor::Variable::RGB;
use Mouse;

use Smart::Args;

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
        my $byte = $self->$c;
        unless ( 0 <= $byte && $byte <= 255 ) {
            confess("Property over range! $c => $byte");
        }
        $iobit->put_ui8($byte);
    }

    return $iobit->output;
}

sub parse {
    args my $class => 'ClassName',
         my $data  => 'Str';

    warn length $data;
    if ( length $data != 3 ) {
        confess("RGB record length must be 3bytes!");
    }

    my $iobit = SWF::Editor::Utils::IOBit->new( data => $data );
    my %args;
    for my $c ( qw/ r g b / ) {
        $args{$c} = $iobit->get_ui8;
    }

    return $class->new(%args);
}

__PACKAGE__->meta->make_immutable;
