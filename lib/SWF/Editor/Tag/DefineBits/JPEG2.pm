package  SWF::Editor::Tag::DefineBits::JPEG2;
use Mouse;
use Smart::Args;

use SWF::Editor::Utils::JPEGConverter;
use SWF::Editor::Utils::Header;

extends qw/ SWF::Editor::Tag /;

has '+header' => ( default => create_long_header(SWF::Editor::Tag->tag_number('DefineBitsJPEG2')) );

before get_binary => sub {
    my $self = shift;

    if ( $self->has_object_id ) {
        my $data = $self->data;

        substr( $data, 0, 2, pack('v', $self->object_id) );

        $self->data( $data );
    }
};

sub create_from_jpeg_file {
    args my $class => 'ClassName',
         my $file  => 'Str';

    my $data = do {
        local $/;
        open( my $fh, "<", $file ) or confess("Can't open jpeg image : ".$file);
        my $d = <$fh>;
        close $fh;
        $d;
    };

    my $converter = SWF::Editor::Utils::JPEGConverter->new( data => $data );
    my $self = $class->new;

    $self->data(join '',pack('v',1),$converter->get_encoding_tables,$converter->get_image_data);
    return $self;
}


__PACKAGE__->meta->make_immutable;
