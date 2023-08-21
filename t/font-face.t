use v6;
use Test;
plan 6;

use HTML::Canvas;
use HTML::Canvas::To::PDF;
use CSS::Font::Descriptor;
use PDF::Lite;
use PDF::Content;

my CSS::Font::Descriptor $arial .= new: :font-family<arial>, :src<url(t/fonts/FreeMono.ttf)>;
my HTML::Canvas $canvas .= new: :font-face[$arial];
my PDF::Lite $pdf .= new;
my PDF::Content $gfx = $pdf.add-page.gfx;
my HTML::Canvas::To::PDF $feed .= new: :$gfx, :$canvas;

$canvas.context: {
    .font = "30px Arial";
    .fillText("Hello Mono World",10,50);
}

# ensure consistant document ID generation
$pdf.id = $*PROGRAM-NAME.fmt('%-16.16s');
lives-ok {$pdf.save-as("t/font-face.pdf");}, "pdf.save-as";

$pdf .= open: "t/font-face.pdf";

my %fonts = $pdf.page(1).resources('Font');

my $mono = %fonts<F1>;
ok $mono.defined, 'font sanity';
is $mono<Type>, 'Font', '/Type';
is $mono<Subtype>, 'Type0', '/Subtype';
is $mono<Encoding>, 'Identity-H', '/Encoding';

my %dfont =  %fonts<F1><DescendantFonts>[0];
is %dfont<BaseFont>, 'FreeMono';

done-testing;
