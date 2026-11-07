use strict;
use warnings;
no warnings 'once';
use FindBin;
use lib "$FindBin::Bin/lib";
use Image::ExifTool;
require "$FindBin::Bin/FocusFrame.pm";
require "$FindBin::Bin/RegisterFocus.pm";
require "$FindBin::Bin/BirdBookInfo.pm";

%Image::ExifTool::UserDefined = (
    'Image::ExifTool::XMP::Main' => { bbfocus => { SubDirectory => { TagTable => 'Image::ExifTool::UserDefined::BirdBookFocus' } } },
);
%Image::ExifTool::UserDefined::BirdBookFocus = (
    GROUPS => { 0 => 'XMP', 1 => 'XMP-bbfocus', 2 => 'Image' },
    NAMESPACE => { bbfocus => 'https://bird.uioiu.com/ns/focus/1.0/' },
    WRITABLE => 'string', Frame => {}, ReferenceFrame => {}, Status => {},
);

BirdBook::Info::register();

my ($raw, $jpeg) = @ARGV;
die "Expected an ARW or camera JPEG source and a rendered image\n" unless @ARGV == 2 && $raw =~ /\.(arw|jpe?g)\z/i && -f $raw && -f $jpeg && !-l $jpeg;
my @src = stat $raw;
my @dst = stat $jpeg;
die "Source and destination must differ\n" if $src[0] == $dst[0] && $src[1] == $dst[1];
my $reader = Image::ExifTool->new;
$reader->Options(PrintConv => 0);
my $tags = $reader->ImageInfo($raw, qw(FileType Model Sony:FocusPosition2 Composite:FocusDistance2
                                    EXIF:DistortionCorrection Sony:DistortionCorrectionSetting Sony:FocusMode Sony:FocusLocation Sony:FocusFrameSize EXIF:Orientation Error),
                                    map { "EXIF:$_" } @BirdBook::Info::standard);
die "Could not read source image\n" if $tags->{Error};
unless (($tags->{FileType} // '') =~ /^(ARW|JPEG)$/ && ($tags->{Model} // '') eq 'ILCE-1M2') {
    print "unsupported-camera\n";
    exit 0;
}
my $writer = Image::ExifTool->new;
$writer->Options(PrintConv => 0);
my $existing = $writer->ImageInfo($jpeg, qw(FileType XMP-aux:ApproximateFocusDistance ImageWidth ImageHeight
    EXIF:Orientation XMP-xmp:Rating XMP-crs:RawFileName XMP-crs:HasCrop XMP-crs:CropLeft XMP-crs:CropRight XMP-crs:CropTop XMP-crs:CropBottom
    XMP-crs:CropAngle XMP-crs:LensProfileEnable XMP-crs:LensManualDistortionAmount XMP-crs:PerspectiveUpright
    XMP-crs:PerspectiveHorizontal XMP-crs:PerspectiveVertical XMP-crs:PerspectiveRotate XMP-crs:PerspectiveAspect
    XMP-crs:PerspectiveX XMP-crs:PerspectiveY XMP-crs:PerspectiveScale Error), @BirdBook::Info::standard);
die "Expected JPEG, TIFF or PNG output\n" unless !$existing->{Error} && ($existing->{FileType} // '') =~ /^(JPEG|TIFF|PNG)$/;
my $code = $tags->{FocusPosition2} // 0;
my $meters = $code == 255 ? 4294967295 : $tags->{FocusDistance2};
if (!defined $existing->{ApproximateFocusDistance} && $code > 0 && $code <= 255
    && defined $meters && $meters > 0 && ($code == 255 || $meters < 4294967295)) {
    $writer->SetNewValue('XMP-aux:ApproximateFocusDistance', $meters, Type => 'ValueConv') or die "Invalid focus distance\n";
}
BirdBook::Info::supplement($writer, $raw, $tags, $existing);
my ($status,$frame) = BirdBook::FocusFrame::for_export($tags,$existing);
my $reference;
if ($status eq 'unsupported-edits') {
    $reference = BirdBook::RegisterFocus::for_export($raw,$jpeg,$tags,$existing,"$FindBin::Bin/register-focus");
    $status = 'registered-reference' if defined $reference;
}
$writer->SetNewValue('XMP-bbfocus:Frame', undef);
$writer->SetNewValue('XMP-bbfocus:ReferenceFrame', undef);
if (defined $reference) {
    $writer->SetNewValue('XMP-bbfocus:ReferenceFrame', $reference) or die "Invalid reference frame\n";
}
$writer->SetNewValue('XMP-bbfocus:Status', $status) or die "Invalid focus status\n";
if (defined $frame) { $writer->SetNewValue('XMP-bbfocus:Frame', $frame) or die "Invalid focus frame\n"; }
$writer->WriteInfo($jpeg) == 1 or die "Unable to write focus information\n";
print (($status eq 'available' || $status eq 'registered-reference') ? "completed\n" : "partial-focus\n");
