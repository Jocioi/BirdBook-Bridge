package BirdBook::FocusFrame;
use strict;
use warnings;

# Coordinates must describe the final JPEG, never an unadjusted camera frame on an edited image.
sub for_export {
    my ($src, $dst) = @_;
    return ('missing') unless ($src->{Model} // '') eq 'ILCE-1M2'
        && ($src->{FocusMode} // 0) =~ /^(2|3|4|7)$/;
    # Camera JPEGs may already include geometric corrections not described by the AF coordinates.
    return ('unsupported-edits') if ($src->{FileType} // '') eq 'JPEG';
    my @focus = split ' ', ($src->{FocusLocation} // '');
    my @box = split ' ', ($src->{FocusFrameSize} // '');
    return ('missing') unless @focus == 4 && @box == 3
        && !grep { !/^\d+$/ } (@focus, @box);
    my ($sw, $sh, $cx, $cy) = @focus;
    return ('missing') unless $sw > 0 && $sh > 0 && $box[0] > 0 && $box[1] > 0 && $box[2] == 257;
    my ($x, $y, $w, $h) = (($cx-$box[0]/2)/$sw, ($cy-$box[1]/2)/$sh, $box[0]/$sw, $box[1]/$sh);
    return ('missing') if $x < 0 || $y < 0 || $x+$w > 1 || $y+$h > 1;
    # These transforms need a calibrated lens/perspective mapping; do not invent one.
    for my $key (qw(CropAngle LensProfileEnable LensManualDistortionAmount PerspectiveUpright
                    PerspectiveHorizontal PerspectiveVertical PerspectiveRotate PerspectiveAspect PerspectiveX PerspectiveY)) {
        return ('unsupported-edits') if abs($dst->{$key} // 0) > 0.000001;
    }
    return ('unsupported-edits') if abs(($dst->{PerspectiveScale} // 100) - 100) > 0.000001;
    my $orientation = $src->{Orientation} // 1;
    return ('unsupported-edits') unless defined $dst->{HasCrop};
    my $has_crop = $dst->{HasCrop} =~ /^(True|1)$/i;
    return ('unsupported-edits') if $has_crop && $orientation != 1;
    if ($orientation == 2) { $x = 1-$x-$w; }
    elsif ($orientation == 3) { ($x,$y) = (1-$x-$w,1-$y-$h); }
    elsif ($orientation == 4) { $y = 1-$y-$h; }
    elsif ($orientation == 5) { ($x,$y,$w,$h) = ($y,$x,$h,$w); }
    elsif ($orientation == 6) { ($x,$y,$w,$h) = (1-$y-$h,$x,$h,$w); }
    elsif ($orientation == 7) { ($x,$y,$w,$h) = (1-$y-$h,1-$x-$w,$h,$w); }
    elsif ($orientation == 8) { ($x,$y,$w,$h) = ($y,1-$x-$w,$h,$w); }
    elsif ($orientation != 1) { return ('unsupported-edits'); }
    ($sw,$sh) = ($sh,$sw) if $orientation >= 5;
    my ($left,$top,$right,$bottom) = $has_crop
        ? map { $dst->{$_} } qw(CropLeft CropTop CropRight CropBottom) : (0,0,1,1);
    return ('unsupported-edits') if grep { !defined($_) || !/^[-+]?\d*\.?\d+$/ } ($left,$top,$right,$bottom);
    return ('unsupported-edits') unless $left >= 0 && $top >= 0 && $right <= 1 && $bottom <= 1 && $right > $left && $bottom > $top;
    my ($cw,$ch) = ($right-$left,$bottom-$top);
    return ('outside-crop') if $x < $left || $y < $top || $x+$w > $right || $y+$h > $bottom;
    my ($dw,$dh) = @{$dst}{qw(ImageWidth ImageHeight)};
    return ('unsupported-edits') unless $dw && $dh && ($dst->{Orientation} // 1) == 1;
    return ('unsupported-edits') if abs(($dw/$dh) / (($sw*$cw)/($sh*$ch)) - 1) > 0.005;
    ($x,$y,$w,$h) = (($x-$left)/$cw,($y-$top)/$ch,$w/$cw,$h/$ch);
    return ('available', join(' ', 1,$dw,$dh,map { sprintf('%.10f',$_) } ($x,$y,$w,$h)));
}
1;
