use strict;
use warnings;
no warnings 'once';
use Test::More;
use File::Copy qw(copy);
use File::Basename ();
use File::Temp qw(tempdir);
use FindBin;
use Image::ExifTool;
require "$FindBin::Bin/../BirdBookBridge.lrplugin/FocusFrame.pm";
require "$FindBin::Bin/../BirdBookBridge.lrplugin/RegisterFocus.pm";
require "$FindBin::Bin/../BirdBookBridge.lrplugin/BirdBookInfo.pm";
BirdBook::Info::register();

my %source = (Model=>'ILCE-1M2', FocusMode=>2, FocusLocation=>'1000 1000 500 500',
              FocusFrameSize=>'100 100 257', Orientation=>1);
my %export = (HasCrop=>0, ImageWidth=>500, ImageHeight=>500, Orientation=>1);
my ($state,$frame) = BirdBook::FocusFrame::for_export(\%source,\%export);
is($state,'available','valid camera AF frame');
my @v=split ' ',$frame;
is_deeply([@v[0..2]],[1,500,500],'frame version and final dimensions');
is_deeply([map{0+$_}@v[3..6]],[0.45,0.45,0.1,0.1],'normalised AF coordinates');
my %crop=(%export,HasCrop=>1,CropLeft=>0.25,CropTop=>0.25,CropRight=>0.75,CropBottom=>0.75);
($state,$frame)=BirdBook::FocusFrame::for_export(\%source,\%crop);
is($state,'available','simple crop is mapped');
@v=split ' ',$frame;
is_deeply([map{0+$_}@v[3..6]],[0.4,0.4,0.2,0.2],'crop coordinates');
my %outside=(%crop,CropRight=>0.4);
is((BirdBook::FocusFrame::for_export(\%source,\%outside))[0],'outside-crop','cropped-out frame omitted');
for my $edit (qw(CropAngle LensProfileEnable LensManualDistortionAmount PerspectiveVertical)) {
    my %edited=(%export,$edit=>1);
    is((BirdBook::FocusFrame::for_export(\%source,\%edited))[0],'unsupported-edits',"$edit guarded");
}
for my $mode (0,1,5) {
    my %manual=(%source,FocusMode=>$mode);
    is((BirdBook::FocusFrame::for_export(\%manual,\%export))[0],'missing',"unvalidated focus mode $mode rejected");
}
my %other=(%source,Model=>'OTHER');
is((BirdBook::FocusFrame::for_export(\%other,\%export))[0],'missing','other camera rejected');
my %camera_jpeg=(%source,FileType=>'JPEG');
is((BirdBook::FocusFrame::for_export(\%camera_jpeg,\%export))[0],'unsupported-edits','camera JPEG geometry is not assumed');
ok(!defined(BirdBook::RegisterFocus::for_export('unused','unused',\%camera_jpeg,\%export,'unused')),
   'camera JPEG is not registered against an unvalidated preview');
my %bad=(%source,FocusLocation=>'bad data');
is((BirdBook::FocusFrame::for_export(\%bad,\%export))[0],'missing','invalid coordinates rejected');
my %portrait=(%source,Orientation=>6);
is((BirdBook::FocusFrame::for_export(\%portrait,\%export))[0],'available','uncropped orientation supported');
is((BirdBook::FocusFrame::for_export(\%portrait,\%crop))[0],'available','portrait rectangular crop supported');
my @expected=(
    [0.48,11/30,0.16,2/15], [0.36,11/30,0.16,2/15],
    [0.36,0.5,0.16,2/15], [0.48,0.5,0.16,2/15],
    [11/30,0.48,2/15,0.16], [0.5,0.48,2/15,0.16],
    [0.5,0.36,2/15,0.16], [11/30,0.36,2/15,0.16]);
for my $o (1..8) {
    my %s=(%source,Orientation=>$o,FocusLocation=>'1200 800 720 360',FocusFrameSize=>'120 80 257');
    my %d=(%crop,CropLeft=>0.25,CropTop=>0.125,CropRight=>0.875,CropBottom=>0.875,
        ImageWidth=>($o>=5?600:750),ImageHeight=>($o>=5?750:600));
    my($status,$value)=BirdBook::FocusFrame::for_export(\%s,\%d);
    is($status,'available',"asymmetric crop orientation $o accepted");
    my @actual=split ' ',($value//'');
    ok(@actual==7 && !(grep { abs($actual[$_+3]-$expected[$o-1][$_])>0.00000001 } 0..3),
        "asymmetric crop orientation $o preserves recorded frame coordinates");
}
# Independent 3-4-5 triangle fixture: a 400 x 300 crop rotated in a 1500 x 1000 source.
for my $sign (-1,1) { for my $o (1..8) {
    my $a=$sign*atan2(3,4)*180/atan2(0,-1);
    my ($dx,$dy)=(0.8*400-$sign*0.6*300,$sign*0.6*400+0.8*300);
    my %s=(%source,Orientation=>$o,FocusLocation=>'1500 1000 780 520',FocusFrameSize=>'50 30 257');
    my %d=(%export,HasCrop=>1,CropAngle=>$a,CropLeft=>(750-$dx/2)/1500,CropRight=>(750+$dx/2)/1500,
        CropTop=>(500-$dy/2)/1000,CropBottom=>(500+$dy/2)/1000,
        ImageWidth=>($o>=5?300:400),ImageHeight=>($o>=5?400:300));
    my ($status,$value)=BirdBook::FocusFrame::for_export(\%s,\%d,1);
    is($status,'available',"rotation $sign orientation $o geometry accepted");
    my ($x,$y,$w,$h)=($sign==1?0.5175:0.4575,$sign==1?121/300:157/300,58/400,54/300);
    my @want=([$x,$y,$w,$h],[1-$x-$w,$y,$w,$h],[1-$x-$w,1-$y-$h,$w,$h],[$x,1-$y-$h,$w,$h],
        [$y,$x,$h,$w],[1-$y-$h,$x,$h,$w],[1-$y-$h,1-$x-$w,$h,$w],[$y,1-$x-$w,$h,$w]);
    my @v=split ' ',($value//'');
    ok(@v==7 && !(grep {abs($v[$_+3]-$want[$o-1][$_])>1e-8} 0..3),"rotation $sign orientation $o independently calculated corners");
} }
my %edge=(%export,HasCrop=>1,CropLeft=>0.49,CropTop=>0.25,CropRight=>0.99,CropBottom=>0.75);
($state,$frame)=BirdBook::FocusFrame::for_export(\%source,\%edge);
is($state,'available','partially cropped frame with visible centre retained');
@v=split ' ',$frame;
ok(abs($v[3])<1e-9 && abs($v[5]-0.12)<1e-9,'partial frame clipped at image boundary');
for my $angle ('NaN','Inf',46,-46) {
    my %d=(%crop,CropAngle=>$angle);
    is((BirdBook::FocusFrame::for_export(\%source,\%d,1))[0],'unsupported-edits',"invalid angle $angle rejected");
}
ok(!defined(BirdBook::RegisterFocus::for_export('unused','unused',\%source,\%export,'/nonexistent/bbb-helper')),
   'missing registration helper fails closed');
is(BirdBook::Info::clean('  AF-C  '),'AF-C','text trimmed');
for my $bad (undef,'Unknown (0)','n/a','(none)',"line\nbreak",'x'x257,[]) {
    ok(!defined(BirdBook::Info::clean($bad)),'invalid capture value omitted');
}

my $fixture=shift @ARGV or die 'Pass a generated JPEG fixture';
my $dir=tempdir(CLEANUP=>1);
my $out="$dir/completed.jpg";
ok(copy($fixture,$out),'isolated synthetic fixture');
my $w=Image::ExifTool->new;
$w->SetNewValue('EXIF:ISO',800);
$w->SetNewValue('EXIF:DateTimeOriginal','2020:01:02 03:04:05');
ok($w->WriteInfo($out),'prepare known existing EXIF');
sub scan_bytes {
    my($path)=@_;open my $f,'<:raw',$path or die $!;local $/;my $b=<$f>;
    my $i=2;
    while ($i+4<=length($b)) {
        die 'invalid JPEG' unless ord(substr($b,$i,1))==255;
        return substr($b,$i) if ord(substr($b,$i+1,1))==218;
        my $size=unpack('n',substr($b,$i+2,2));$i+=2+$size;
    }
    die 'missing JPEG scan';
}
my $pixels=scan_bytes($out);
my $read=Image::ExifTool->new;$read->Options(PrintConv=>0);
my $existing=$read->ImageInfo($out);
my %src=(%source,ISO=>100,Make=>'SONY',ExposureCompensation=>0);
my $write=Image::ExifTool->new;$write->Options(PrintConv=>0);
BirdBook::Info::supplement($write,$fixture,\%src,$existing);
ok($write->WriteInfo($out),'supplement metadata');
my $info=$read->ImageInfo($out);
is($info->{ISO},800,'existing ISO retained');
is($info->{ExposureCompensation},0,'missing exposure value supplemented');
is($info->{DateTimeOriginal},'2020:01:02 03:04:05','existing date retained');
is($info->{SourceModel},'ILCE-1M2','source model stored in XMP');
is($info->{OriginalFocusLocation},'1000 1000 500 500','source AF position stored');
is(scan_bytes($out),$pixels,'compressed JPEG scan unchanged');
ok(!grep(/GPS|Serial|Face|Date|Orientation|ImageWidth|ColorSpace/,@BirdBook::Info::standard),
   'supplement list excludes location, identity, dates and geometry');
is(BirdBook::Info::clean_setting('SourceCameraSoftware','ILCE-1M2 v4.00'),'ILCE-1M2 v4.00','camera firmware record accepted');
ok(!defined(BirdBook::Info::clean_setting('SourceCameraSoftware','Adobe Photoshop Lightroom Classic 15.5.1')),'editing software is not camera firmware');
is($info->{OriginalFileSizeBytes},-s $fixture,'original source byte count retained');
is($info->{OriginalFileType},'JPEG','source file type retained');
is($info->{OriginalFileName},(File::Basename::basename($fixture)),'filename fallback retained');
is(BirdBook::Info::clean_setting('BatteryLevel','53%'),'53%','valid battery level retained');
ok(!defined(BirdBook::Info::clean_setting('WhiteBalance','Auto',{WhiteBalance=>0})),'native auto white balance is not duplicated');
ok(!defined(BirdBook::Info::clean_setting('WhiteBalance','Manual',{WhiteBalance=>1})),'native manual white balance is not duplicated');
ok(!defined(BirdBook::Info::clean_setting('WhiteBalance','Auto',{WhiteBalance=>'Auto'})),'text-form auto white balance is not numerically coerced');
ok(!defined(BirdBook::Info::clean_setting('WhiteBalance','Manual',{WhiteBalance=>'Manual'})),'text-form manual white balance is not numerically coerced');
is(BirdBook::Info::clean_setting('WhiteBalance','Daylight',{WhiteBalance=>1}),'Daylight','more specific capture preset retained');
ok(!defined(BirdBook::Info::clean_setting('BatteryLevel','101%')),'out-of-range battery omitted');
is(BirdBook::Info::clean_setting('AmbientTemperature','-5 C'),'-5 C','negative capture temperature retained');
ok(!defined(BirdBook::Info::clean_setting('AmbientTemperature','nan C')),'non-finite temperature omitted');
ok(!defined(BirdBook::Info::clean_setting('AmbientTemperature','255 C')),'out-of-range temperature omitted');
is(scalar @BirdBook::Info::settings,51,'51 capture-setting names');
my $all=Image::ExifTool->new;
for my $tag (@BirdBook::Info::settings) {
    $all->SetNewValue("XMP-bbinfo:$tag","test-$tag") or die $tag;
}
ok($all->WriteInfo($out),'all 51 registered capture fields writable');
$info=$read->ImageInfo($out);
is_deeply([map{$info->{$_}}@BirdBook::Info::settings],
          [map{"test-$_"}@BirdBook::Info::settings],'51 XMP fields read back');
my $retired=Image::ExifTool->new;
$retired->SetNewValue("XMP-bbinfo:$_",'14') for @BirdBook::Info::retired;
ok($retired->WriteInfo($out),'seed retired custom fields');
my $again=Image::ExifTool->new;$again->Options(PrintConv=>0);
BirdBook::Info::supplement($again,$fixture,\%src,$info);
ok($again->WriteInfo($out),'repeat supplementation');
$info=$read->ImageInfo($out);
is($info->{ISO},800,'repeat preserves existing ISO');
ok(!exists($info->{FocusMode}),'absent source setting clears stale custom value');
ok(!(grep { exists $info->{$_} } @BirdBook::Info::retired), 'retired custom fields removed on repeat');
is(scan_bytes($out),$pixels,'repeat preserves JPEG scan');
done_testing();
