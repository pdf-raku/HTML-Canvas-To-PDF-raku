use Test;
plan 1;

use PDF::Lite;
use HTML::Canvas;
use HTML::Canvas::To::PDF;
use PDF::Content;

constant $LRM = 0x200E.chr;
constant $LRO = 0x202D.chr;
constant $RLO = 0x202E.chr;
constant $PDF = 0x202C.chr;

my HTML::Canvas $canvas .= new;
my PDF::Lite $pdf .= new;
my PDF::Content $gfx = $pdf.add-page.gfx;
my HTML::Canvas::To::PDF $feed .= new: :$gfx, :$canvas;

$canvas.context: {
    # example adapted from from https://stackoverflow.com/questions/8961636/html5-canvas-filltext-with-right-to-left-string/15979861#15979861
    .textAlign = 'right';
    .direction = 'rtl';
    .font = "22px Unifont";
    # Simple Sentence with punctuation.
    my \str1 = "این یک آزمایش است.";
    # Few sentences with punctuation and numerals. 
    my \str2 = "۱ آزمایش. 2 آزمایش، سه آزمایش & Foo آزمایش!";
    # Needs implicit bidi marks to display correctly.
    my \str3 = "آزمایش برای Foo Ltd. و Bar Inc. باشد که آزموده شود.";
    # Implicit bidi marks added; "Foo Ltd.&lrm; و Bar Inc.&lrm;"
    my \str4 = "آزمایش برای Foo Ltd.{$LRM} و Bar Inc.{$LRM} باشد که آزموده شود.";

    .fillText(str1, 580, 60);
    .fillText(str2, 580, 100);
    .fillText(str3, 580, 140);
    .fillText(str4, 580, 180);
    .fillText("rtl (with) parens", 580, 220);
    # left to right as dominant direction
    .direction = 'ltr';
    .fillText("Left {$RLO}Right{$PDF} left", 580, 260);

    # add a guide line
    .strokeStyle = "rgba(255, 50, 50, 0.6)";
    .lineWidth = 4.0;
    .moveTo(580, 50);
    .lineTo(580,260);
    .stroke;
}

# ensure consistant document ID generation
$pdf.id = $*PROGRAM-NAME.fmt('%-16.16s');
lives-ok {$pdf.save-as("t/direction.pdf");}, "pdf.save-as";

# also save comparative HTML

my $width = $feed.width;
my $height = $feed.height;
my $html = "<html><body>{ $canvas.to-html( :$width, :$height ) }</body></html>";
"t/direction.html".IO.spurt: $html;

done-testing();
