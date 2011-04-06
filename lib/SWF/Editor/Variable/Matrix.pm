package  SWF::Editor::Variable::Matrix;
use Mouse;

use SWF::Editor::Utils::IOBit;

has translate_x => (is => 'rw', isa => 'Num', lazy_build => 1);
has translate_y => (is => 'rw', isa => 'Num', lazy_build => 1);


sub get_binary {
    my $self = shift;
    unless ( $self->has_translate_x && $self->has_translate_y ) {
        confess("Property translate_x and translate_y are required!");
    }
    #TODO Support scale and rotate
    my $iobit = SWF::Editor::Utils::IOBit->new;
    $iobit->put_ui_bit(0);
    $iobit->put_ui_bit(0);
    my $need_bits = 0;
    my $translate_x = px2twip($self->translate_x);
    my $translate_y = px2twip($self->translate_y);
    
    #Calculate need signed bits
    for my $bits ( ($self->translate_x, $self->translate_y) ) {
        my $b = $iobit->need_bits_signed($bits * 20);
        $need_bits = $b if $b >= $need_bits;
    }
    $iobit->put_ui_bits($need_bits,5);
    $iobit->put_si_bits($translate_x,$need_bits);
    $iobit->put_si_bits($translate_y,$need_bits);

    return $iobit->output;
}


sub px2twip {  
    my $px = shift;

    return $px * 20;
}

__PACKAGE__->meta->make_immutable;
