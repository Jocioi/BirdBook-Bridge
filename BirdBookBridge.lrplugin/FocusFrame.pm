package BirdBook::FocusFrame;
use strict;
use warnings;

# Coordinates must describe the final JPEG, never an unadjusted camera frame on an edited image.
sub for_export {
    my ($src, $dst, $allow_rotation) = @_;
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
    for my $key (qw(LensProfileEnable LensManualDistortionAmount PerspectiveUpright
                    PerspectiveHorizontal PerspectiveVertical PerspectiveRotate PerspectiveAspect PerspectiveX PerspectiveY)) {
        return ('unsupported-edits') if abs($dst->{$key} // 0) > 0.000001;
    }
    return ('unsupported-edits') if abs(($dst->{PerspectiveScale} // 100) - 100) > 0.000001;
    my $angle = $dst->{CropAngle} // 0;
    return ('unsupported-edits') unless $angle =~ /^[-+]?\d*\.?\d+$/ && abs($angle) <= 45;
    return ('unsupported-edits') if abs($angle) > 0.000001 && !$allow_rotation;
    my $orientation = $src->{Orientation} // 1;
    return ('unsupported-edits') unless defined $dst->{HasCrop};
    my $has_crop = $dst->{HasCrop} =~ /^(True|1)$/i;
    # Lightroom crop bounds use the unrotated source axes, including portrait RAWs.
    my ($left,$top,$right,$bottom) = $has_crop
        ? map { $dst->{$_} } qw(CropLeft CropTop CropRight CropBottom) : (0,0,1,1);
    return ('unsupported-edits') if grep { !defined($_) || !/^[-+]?\d*\.?\d+$/ } ($left,$top,$right,$bottom);
    return ('unsupported-edits') unless $left >= 0 && $left <= 1 && $top >= 0 && $top <= 1 && $right >= 0 && $right <= 1 && $bottom >= 0 && $bottom <= 1;
    return ('unsupported-edits') if !$has_crop && abs($angle) > 0.000001;
    # Lightroom stores opposite corners of the tilted crop in source pixel axes.
    my $radians = $angle * atan2(0,-1) / 180;
    my ($c,$s) = (cos($radians),sin($radians));
    my ($dx,$dy) = (($right-$left)*$sw,($bottom-$top)*$sh);
    my ($cw,$ch) = ($c*$dx+$s*$dy,-$s*$dx+$c*$dy);
    return ('unsupported-edits') unless $cw > 0 && $ch > 0;
    # The other two crop corners must also lie on the source, not on generated fill.
    for my $corner ([$left*$sw+$c*$cw,$top*$sh+$s*$cw],
                    [$left*$sw-$s*$ch,$top*$sh+$c*$ch]) {
        return ('unsupported-edits') if $corner->[0] < -0.01 || $corner->[0] > $sw+0.01
            || $corner->[1] < -0.01 || $corner->[1] > $sh+0.01;
    }
    my (@xs,@ys);
    for my $px ($x*$sw,($x+$w)*$sw) { for my $py ($y*$sh,($y+$h)*$sh) {
        my ($u,$v) = ($px-$left*$sw,$py-$top*$sh);
        push @xs, ($c*$u+$s*$v)/$cw;
        push @ys, (-$s*$u+$c*$v)/$ch;
    } }
    @xs=sort {$a<=>$b} @xs; @ys=sort {$a<=>$b} @ys;
    # Keep a partially cropped frame only when its recorded centre remains visible.
    return ('outside-crop') if ($xs[0]+$xs[-1])/2 < 0 || ($xs[0]+$xs[-1])/2 > 1
        || ($ys[0]+$ys[-1])/2 < 0 || ($ys[0]+$ys[-1])/2 > 1;
    ($x,$y) = ($xs[0]<0?0:$xs[0],$ys[0]<0?0:$ys[0]);
    ($w,$h) = (($xs[-1]>1?1:$xs[-1])-$x,($ys[-1]>1?1:$ys[-1])-$y);
    return ('outside-crop') unless $w > 0 && $h > 0;
    ($sw,$sh) = ($cw,$ch);
    if ($orientation == 2) { $x = 1-$x-$w; }
    elsif ($orientation == 3) { ($x,$y) = (1-$x-$w,1-$y-$h); }
    elsif ($orientation == 4) { $y = 1-$y-$h; }
    elsif ($orientation == 5) { ($x,$y,$w,$h) = ($y,$x,$h,$w); }
    elsif ($orientation == 6) { ($x,$y,$w,$h) = (1-$y-$h,$x,$h,$w); }
    elsif ($orientation == 7) { ($x,$y,$w,$h) = (1-$y-$h,1-$x-$w,$h,$w); }
    elsif ($orientation == 8) { ($x,$y,$w,$h) = ($y,1-$x-$w,$h,$w); }
    elsif ($orientation != 1) { return ('unsupported-edits'); }
    ($sw,$sh) = ($sh,$sw) if $orientation >= 5;
    my ($dw,$dh) = @{$dst}{qw(ImageWidth ImageHeight)};
    return ('unsupported-edits') unless $dw && $dh && ($dst->{Orientation} // 1) == 1;
    return ('unsupported-edits') if abs(($dw/$dh) / ($sw/$sh) - 1) > 0.005;
    return ('available', join(' ', 1,$dw,$dh,map { sprintf('%.10f',$_) } ($x,$y,$w,$h)));
}
1;
