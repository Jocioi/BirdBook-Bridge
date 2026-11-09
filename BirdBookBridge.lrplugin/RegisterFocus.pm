package BirdBook::RegisterFocus;
use strict;
use warnings;
use File::Temp qw(tempdir);
use JSON::PP qw(encode_json decode_json);
use Image::ExifTool;

sub for_export {
    my ($raw, $jpeg, $src, $dst, $helper) = @_;
    return if ($src->{FileType} // '') eq 'JPEG';
    return unless -x $helper && ($dst->{LensProfileEnable} // 0) == 1
        && ($src->{Orientation} // 1) =~ /^[1-8]$/ && defined($src->{DistortionCorrection})
        && $src->{DistortionCorrection} == 0 && ($src->{DistortionCorrectionSetting} // -1) == 0;
    # Keep every other geometry guard; registration is only validated for mild lens correction.
    my %uncorrected = %$dst;
    $uncorrected{LensProfileEnable} = 0;
    my ($state, $frame) = BirdBook::FocusFrame::for_export($src, \%uncorrected);
    return unless $state eq 'available';
    my @frame = split ' ', $frame;
    my $crop = ($dst->{HasCrop} // '') =~ /^(True|1)$/i;
    my ($l,$t,$r,$b) = $crop ? @{$dst}{qw(CropLeft CropTop CropRight CropBottom)} : (0,0,1,1);
    my $reader = Image::ExifTool->new;
    $reader->Options(Binary => 1);
    my $data = $reader->ImageInfo($raw, 'PreviewImage')->{PreviewImage};
    return unless ref($data) eq 'SCALAR' && length($$data) > 100 && length($$data) < 16_777_216;
    my $dir = tempdir('birdbook-focus-XXXXXXXX', TMPDIR => 1, CLEANUP => 1);
    open my $preview, '>:raw', "$dir/preview.jpg" or return;
    print {$preview} $$data; close $preview or return;
    open my $config, '>', "$dir/input.json" or return;
    print {$config} encode_json({crop=>[$l,$t,$r-$l,$b-$t], frame=>[map {0+$_} @frame[3..6]],
        orientation=>0+($src->{Orientation} // 1)});
    close $config or return;
    # List-form process launch preserves filenames, with no shell evaluation.
    my $pid = open my $output, '-|', $helper, "$dir/preview.jpg", $jpeg, "$dir/input.json";
    return unless $pid;
    my $json = do { local $/; <$output> };
    my $ok = close $output;
    return unless $ok && defined($json) && length($json) < 2048;
    my $result = eval { decode_json($json) };
    return unless ref($result) eq 'HASH' && ref($result->{rect}) eq 'ARRAY' && @{$result->{rect}} == 4;
    my @v = @{$result->{rect}};
    return if grep { !defined($_) || ref($_) || !/^[-+]?\d*\.?\d+(?:[eE][-+]?\d+)?$/ } @v;
    return unless $v[0] >= 0 && $v[1] >= 0 && $v[2] > 0 && $v[3] > 0 && $v[0]+$v[2] <= 1 && $v[1]+$v[3] <= 1;
    return join(' ', 1,@frame[1..2],map {sprintf('%.10f',$_)} @v);
}
1;
