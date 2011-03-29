package  SWF::Editor::Tag::DefineBits::JPEG3;
use Mouse;
use Smart::Args;

use SWF::Editor::Utils::JPEGConverter;
use SWF::Editor::Utils::Header;
use Compress::Zlib;

extends qw/ SWF::Editor::Tag::DefineBits::JPEG2 /;

has '+header' => ( default => create_long_header(SWF::Editor::Tag->tag_number('DefineBitsJPEG3')) );

sub create_from_jpeg_and_rgb_file {
    args my $class => 'ClassName',
         my $file  => 'Str',
         my $rgb_file  => 'Str';

    my $data = do {
        local $/;
        open( my $fh, "<", $file ) or confess("Can't open jpeg image : ".$file);
        my $d = <$fh>;
        close $fh;
        $d;
    };
    my $mask_data = do {
        local $/;
        open( my $fh, "<", $rgb_file ) or confess("Can't open mask image : ".$rgb_file);
        my $d = <$fh>;
        close $fh;
        $d;
    };
    $mask_data = compress($mask_data);


    my $converter = SWF::Editor::Utils::JPEGConverter->new( data => $data );
    my $self = $class->new;
    my $jpeg_data = $converter->get_encoding_tables.$converter->get_image_data;
    my $alpha_offset = length $jpeg_data;

    $self->data(join '',pack('v',1),pack('V',$alpha_offset),$jpeg_data,$mask_data);
    return $self;
}

__PACKAGE__->meta->make_immutable;
