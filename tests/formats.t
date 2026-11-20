use strict;
use warnings;
use Test::More;
use File::Copy qw(copy);
use File::Temp qw(tempdir);
use FindBin;
use Image::ExifTool;
use JSON::PP qw(decode_json);
my ($fixtures,$fingerprint)=@ARGV;
die 'Pass fixture directory and fingerprint program' unless $fixtures && $fingerprint;
my $dir=tempdir(CLEANUP=>1);
my $source="$dir/camera.JPG";
copy("$fixtures/image.jpg",$source) or die $!;
my $s=Image::ExifTool->new;
$s->SetNewValue('EXIF:Make','SONY');
$s->SetNewValue('EXIF:Model','ILCE-1M2');
$s->SetNewValue('EXIF:ISO',1600);
$s->SetNewValue('EXIF:Software','ILCE-1M2 v4.00');
$s->SetNewValue('EXIF:FNumber',4);
$s->SetNewValue('EXIF:GPSLatitude',0);
$s->SetNewValue('EXIF:GPSLongitude',0);
ok($s->WriteInfo($source),'create synthetic camera JPEG source');
sub bytes {
    open my $f,'<:raw',$_[0] or die $!;local $/;return <$f>;
}
sub pixels {
    open my $f,'-|',$fingerprint,'fingerprint',$_[0] or die $!;local $/;my $json=<$f>;
    close $f or die 'fingerprint failed';return decode_json($json);
}
sub image_payload {
    my($path,$ext)=@_;my $b=bytes($path);
    if($ext eq 'png') {
        my($i,$out)=(8,'');
        while($i+12<=length($b)) {
            my $n=unpack('N',substr($b,$i,4));my $type=substr($b,$i+4,4);
            $out.=substr($b,$i+8,$n) if $type eq 'IDAT';$i+=12+$n;
        }
        return $out;
    }
    if($ext eq 'jpg') {
        my $i=2;
        while($i+4<=length($b)) {
            return substr($b,$i) if ord(substr($b,$i+1,1))==218;
            $i+=2+unpack('n',substr($b,$i+2,2));
        }
        die 'no JPEG scan';
    }
    my $e=Image::ExifTool->new;$e->ImageInfo($path);
    my $offsets=$e->GetValue('StripOffsets','Raw');my $counts=$e->GetValue('StripByteCounts','Raw');
    $offsets=[$offsets] unless ref($offsets);$counts=[$counts] unless ref($counts);
    die 'invalid TIFF strips' unless @$offsets==@$counts && @$offsets;
    return join('',map{substr($b,$offsets->[$_],$counts->[$_])}0..$#$offsets);
}
my $original=bytes($source);
my $helper="$FindBin::Bin/../BirdBookBridge.lrplugin/write-focus.pl";
for my $ext (qw(jpg png tif)) {
    my $out="$dir/exported's image.$ext";
    copy("$fixtures/image.$ext",$out) or die $!;
    my $w=Image::ExifTool->new;
    $w->SetNewValue('EXIF:ISO',800);
    $w->SetNewValue('EXIF:DateTimeOriginal','2020:01:02 03:04:05');
    $w->SetNewValue('XMP-crs:HasCrop','False');
    $w->SetNewValue('XMP-crs:RawFileName','native-original.JPG');
    $w->SetNewValue('XMP-xmp:Rating',4);
    ok($w->WriteInfo($out),"$ext: prepare existing exported metadata");
    my $before=pixels($out);my $payload=image_payload($out,$ext);
    open my $run,'-|','/usr/bin/perl',$helper,$source,$out or die $!;
    my $status=do{local $/;<$run>};ok(close($run),"$ext: supplement from camera JPEG");
    is($status,"partial-focus\n","$ext: reports missing focus information honestly");
    my $r=Image::ExifTool->new;$r->Options(PrintConv=>0);
    my $info=$r->ImageInfo($out);
    is($info->{ISO},800,"$ext: existing ISO retained");
    is($info->{FNumber},4,"$ext: missing aperture filled");
    is($info->{Make},'SONY',"$ext: camera make filled");
    is($info->{DateTimeOriginal},'2020:01:02 03:04:05',"$ext: existing date retained");
    ok(!defined($info->{GPSLatitude})&&!defined($info->{GPSLongitude}),"$ext: removed location not restored");
    is($info->{SourceModel},'ILCE-1M2',"$ext: source model in XMP");
    is($info->{SourceCameraSoftware},'ILCE-1M2 v4.00',"$ext: camera firmware from source IFD0");
    is($info->{OriginalFileSizeBytes},length($original),"$ext: exact source byte count, not output size");
    is($info->{OriginalFileType},'JPEG',"$ext: source file type, not output type");
    is($info->{RawFileName},'native-original.JPG',"$ext: native source filename retained");
    ok(!defined($info->{OriginalFileName}),"$ext: native source filename is not duplicated");
    is($info->{Rating},4,"$ext: Lightroom rating retained");
    is($info->{Status},'missing',"$ext: no fabricated focus frame");
    ok(!defined($info->{Frame})&&!defined($info->{ReferenceFrame}),"$ext: no invented frame fields");
    is_deeply(pixels($out),$before,"$ext: decoded pixels, bit depth and alpha unchanged");
    is(image_payload($out,$ext),$payload,"$ext: encoded image payload unchanged");
    if($ext eq 'tif'){is($before->{bits},16,'TIFF fixture exercises 16-bit pixels')}
    if($ext eq 'png'){ok($before->{alpha}!=0,'PNG fixture has alpha')}
    open $run,'-|','/usr/bin/perl',$helper,$source,$out or die $!;
    $status=do{local $/;<$run>};ok(close($run),"$ext: repeat succeeds");
    is_deeply(pixels($out),$before,"$ext: repeat retains pixel data");
    is(image_payload($out,$ext),$payload,"$ext: repeat retains encoded image payload");
}
is(bytes($source),$original,'camera JPEG source unchanged');
my $other="$dir/other.jpeg";copy($source,$other) or die $!;
$s=Image::ExifTool->new;$s->SetNewValue('Model','UNSUPPORTED');$s->WriteInfo($other) or die;
my $out="$dir/skipped.jpg";copy("$fixtures/image.jpg",$out) or die $!;
my $before=bytes($out);
open my $run,'-|','/usr/bin/perl',$helper,$other,$out or die $!;
my $status=do{local $/;<$run>};ok(close($run),'unsupported camera returns controlled result');
is($status,"unsupported-camera\n",'unsupported camera is explicitly reported');
is(bytes($out),$before,'unsupported source leaves export bytes unchanged');
ok(system('/usr/bin/perl',$helper,$source,$source)!=0,'source cannot be overwritten in place');
is(bytes($source),$original,'source protected after rejected in-place write');
my $arw="$dir/apsc.ARW";
my @buf=(0)x700;
sub put_le { my($a,$v,$o,$w)=@_; for my $i (0..$w-1){ $a->[$o+$i]=($v>>(8*$i))&255; } }
sub tiff_entry { my($a,$o,$t,$ty,$c,$v)=@_; put_le($a,$t,$o,2); put_le($a,$ty,$o+2,2); put_le($a,$c,$o+4,4); put_le($a,$v,$o+8,4); }
$buf[0]=0x49; $buf[1]=0x49; put_le(\@buf,42,2,2); put_le(\@buf,8,4,4);
put_le(\@buf,3,8,2);
tiff_entry(\@buf,10,0x10f,2,5,50);
tiff_entry(\@buf,22,0x110,2,9,60);
tiff_entry(\@buf,34,0x8769,4,1,100);
@buf[50..54]=unpack('C*',"SONY\0");
@buf[60..68]=unpack('C*',"ILCE-1M2\0");
put_le(\@buf,3,100,2); tiff_entry(\@buf,102,0x920a,5,1,160); tiff_entry(\@buf,114,0xa405,3,1,900); tiff_entry(\@buf,126,0x927c,7,450,200);
put_le(\@buf,600,160,4); put_le(\@buf,1,164,4);
put_le(\@buf,2,200,2); tiff_entry(\@buf,202,0x201b,1,1,2); tiff_entry(\@buf,214,0x9402,7,400,250);
sub enc9402 { my($n)=@_; return $n<249 ? ($n*$n*$n)%249 : $n; }
$buf[250]=enc9402(41); $buf[251]=enc9402(1); $buf[272]=enc9402(2); $buf[295]=enc9402(187);
open my $af,'>:raw',$arw or die $!; print $af pack('C*',@buf); close $af or die $!;
my $apsc_out="$dir/apsc-export.jpg";
copy("$fixtures/image.jpg",$apsc_out) or die $!;
ok(system('/usr/bin/perl',$helper,$arw,$apsc_out)==0,'APS-C ARW focus distance export succeeds');
require "$FindBin::Bin/../BirdBookBridge.lrplugin/BirdBookInfo.pm";
BirdBook::Info::register();
my $check=Image::ExifTool->new; $check->Options(PrintConv=>0);
my $apsc_info=$check->ImageInfo($apsc_out,'XMP-aux:ApproximateFocusDistance','XMP-bbinfo:FocusPosition2');
is($apsc_info->{FocusPosition2},'187','APS-C FocusPosition2 preserved');
ok(defined($apsc_info->{ApproximateFocusDistance}) && abs($apsc_info->{ApproximateFocusDistance} - 62.44236) < 0.05,
   'APS-C ApproximateFocusDistance uses 600mm physical focal length instead of 900mm 35mm equivalent');
done_testing();
