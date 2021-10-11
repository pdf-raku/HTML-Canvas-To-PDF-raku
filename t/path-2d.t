use v6;
use Test;
plan 1;

use Cairo;
use HTML::Canvas;
use HTML::Canvas::To::PDF;
use HTML::Canvas::Path2D;
use PDF::Lite;
my PDF::Lite $pdf .= new;
my $gfx = $pdf.add-page.gfx;

my HTML::Canvas $canvas .= new: :width(300), :height(200);
my HTML::Canvas::To::PDF $feed .= new: :$gfx :$canvas;

# adapted from https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/fill

$canvas.context: -> \ctx {
    # Create path
    my HTML::Canvas::Path2D \region .= new;
    region.moveTo(30, 90);
    region.lineTo(110, 20);
    region.lineTo(240, 130);
    region.lineTo(60, 130);
    region.lineTo(190, 20);
    region.lineTo(270, 90);
    region.closePath();

    ctx.fillStyle = 'green';
    ctx.fill(region, 'evenodd');

    ctx.translate(100, 100);
    ctx.fillStyle = 'blue';
    ctx.fill(region);
}

# save canvas as as PDF
$pdf.id = $*PROGRAM-NAME.fmt('%-16.16s');
lives-ok { $pdf.save-as: "t/path-2d.pdf" };
my $html = "<html><body>{ $canvas.to-html( :width(612), :height(792) ) }</body></html>";
"t/path-2d.html".IO.spurt: $html;

done-testing();
