package BirdBook::Info;
use strict;
use warnings;
no warnings 'once';

our @settings = qw(FocusMode AFAreaModeSetting AFAreaMode AFTracking ImageStabilization ReleaseMode
    ElectronicFrontCurtainShutter WhiteBalance WhiteBalanceFineTune ColorTemperature HighISONoiseReduction
    LongExposureNoiseReduction MultiFrameNoiseReduction DynamicRangeOptimizer CreativeStyle PictureEffect
    SequenceNumber LensFirmwareVersion LensMount LensFormat BatteryLevel AmbientTemperature
    SourceCameraSoftware CameraEMountVersion LensEMountVersion APSCSizeCapture ISOSetting ExposureStandardAdjustment FlashExposureComp RAWFileType Quality FileFormat OriginalImageSize WBShiftAB_GM_Precise PrioritySetInAWB Saturation Sharpness SharpnessRange Highlights Shadows Fade PictureProfile HDR SoftSkinEffect VignettingCorrection LateralChromaticAberration DistortionCorrectionSetting CameraOrientation OriginalFileName OriginalFileSizeBytes OriginalFileType);
our @retired = qw(OriginalBitDepth Brightness Clarity Contrast ISOAutoMin ISOAutoMax);

our %sourceTags = (
    SourceCameraSoftware => "IFD0:Software", CameraEMountVersion => "Sony:CameraE-mountVersion",
    LensEMountVersion => "Sony:LensE-mountVersion", APSCSizeCapture => "Sony:APS-CSizeCapture",
    OriginalImageSize => "Sony:FullImageSize", OriginalFileName => "System:FileName",
    OriginalFileSizeBytes => "System:FileSize", OriginalFileType => "File:FileType",
);
our @standard = qw(Make Model LensModel LensMake LensInfo FileSource ExposureTime FNumber ISO FocalLength FocalLengthIn35mmFormat
    ExposureCompensation ExposureMode ExposureProgram MeteringMode Flash WhiteBalance);

sub register {
    $Image::ExifTool::UserDefined{'Image::ExifTool::XMP::Main'}{bbinfo} = {
        SubDirectory => { TagTable => 'Image::ExifTool::UserDefined::BirdBookInfo' }
    };
    %Image::ExifTool::UserDefined::BirdBookInfo = (
        GROUPS => { 0 => 'XMP', 1 => 'XMP-bbinfo', 2 => 'Image' },
        NAMESPACE => { bbinfo => 'https://bird.uioiu.com/ns/capture/1.0/' }, WRITABLE => 'string',
        map { $_ => {} } (@settings, @retired, qw(Version SourceModel OriginalFocusLocation OriginalFocusFrameSize OriginalOrientation FocusPosition2)),
    );
}

sub clean {
    my ($v) = @_;
    return undef unless defined $v && !ref $v && length($v) <= 256;
    $v =~ s/^\s+|\s+$//g;
    return undef if $v eq '' || $v =~ /[\x00-\x1f\x7f]/ || $v =~ /^(Unknown\b|n\/a$|\(none\)$)/i;
    return $v;
}

sub clean_setting {
    my ($tag,$raw,$existing)=@_;my $value=clean($raw);return undef unless defined $value;
    # EXIF already expresses Auto/Manual; retain Sony's more specific presets when available.
    if($tag eq 'WhiteBalance' && ref($existing) eq 'HASH' && defined $existing->{WhiteBalance}) {
        return undef if ($value eq 'Auto' && $existing->{WhiteBalance} == 0)
            || ($value eq 'Manual' && $existing->{WhiteBalance} == 1);
    }
    if($tag eq 'SourceCameraSoftware') {
        return undef unless $value =~ /^ILCE-1M2 v[0-9]+(?:\.[0-9]+)*$/i;
    }
    if($tag eq 'BatteryLevel') {
        return undef unless $value =~ /^(\d+(?:\.\d+)?)%$/ && $1 >= 0 && $1 <= 100;
    } elsif($tag eq 'AmbientTemperature') {
        return undef unless $value =~ /^(-?\d+(?:\.\d+)?) C$/ && $1 >= -100 && $1 <= 150;
    }
    return $value;
}

sub supplement {
    my ($writer,$raw,$source,$existing) = @_;
    my $r = Image::ExifTool->new;
    my $settings = $r->ImageInfo($raw, 'Error', 'Sony:Rating', map { $sourceTags{$_} // "Sony:$_" } @settings);
    die "Unable to read capture settings\n" if $settings->{Error};
    my %native = (WhiteBalance => defined($existing->{WhiteBalance}) && "$existing->{WhiteBalance}" ne ''
        ? $existing->{WhiteBalance} : $source->{WhiteBalance});
    my %values = (Version => '1', SourceModel => $source->{Model},
        OriginalFocusLocation => $source->{FocusLocation}, OriginalFocusFrameSize => $source->{FocusFrameSize},
        OriginalOrientation => $source->{Orientation}, FocusPosition2 => $source->{FocusPosition2});
    for my $tag (@settings) {
        my ($group, $name) = split /:/, ($sourceTags{$tag} // "Sony:$tag"), 2;
        # Duplicate EXIF and Sony names may be returned as "Sharpness (1)".
        my ($key) = sort { length($a) <=> length($b) || $a cmp $b } grep {
            Image::ExifTool::GetTagName($_) eq $name && $r->GetGroup($_, 1) eq $group
        } keys %$settings;
        $values{$tag} = defined $key ? clean_setting($tag,$settings->{$key},\%native) : undef;
    }
    # These are source-file facts, never the exported JPEG's own size or format.
    $values{OriginalFileSizeBytes} = -s $raw;
    $values{OriginalFileName} = undef if defined clean($existing->{RawFileName});
    for my $tag (@retired) { $writer->SetNewValue("XMP-bbinfo:$tag", undef); }
    # Lightroom's current rating wins; only fill an absent rating from the camera.
    my $rating = clean($settings->{Rating});
    if (!defined $existing->{Rating} && defined $rating && $rating =~ /^[0-5]$/) {
        $writer->SetNewValue('XMP-xmp:Rating', $rating) or die "Unable to preserve rating\n";
    }
    for my $tag (sort keys %values) {
        $writer->SetNewValue("XMP-bbinfo:$tag", undef);
        my $value = clean($values{$tag});
        if (defined $value) { $writer->SetNewValue("XMP-bbinfo:$tag", $value) or die "Unable to preserve $tag\n"; }
    }
    # Never replace the export's edited values, dimensions, orientation, colour profile or date.
    for my $tag (@standard) {
        next if defined $existing->{$tag} && "$existing->{$tag}" ne '';
        next unless defined $source->{$tag} && !ref $source->{$tag};
        $writer->SetNewValue("EXIF:$tag", $source->{$tag}, Type => 'ValueConv') or die "Unable to supplement $tag\n";
    }
}
1;
