# perl6-HTML-Canvas-To-PDF

This is a PDF rendering backend for HTML::Canvas. A canvas may be rendered to either a page, or an XObject form.

This backend is **experimental**. At this stage, it is intended primarily for benchmarking and regression testing, etc for the Perl 6 PDF and CSS tool-chains.

```
use v6;
# Create a simple Canvas. Save as PDF

use PDF::Lite;
use HTML::Canvas;
use HTML::Canvas::To::PDF;

# render to a PDF page
my PDF::Lite $pdf .= new;

# a cache for shared resources such as fonts and images.
my $cache = HTML::Canvas::To::PDF::Cache.new;

for 1..2 -> $page {
    my HTML::Canvas $canvas .= new;
    my $gfx = $pdf.add-page.gfx;
    my $feed = HTML::Canvas::To::PDF.new: :$gfx, :$canvas, :$cache;

    $canvas.context: -> \ctx {
        ctx.save; {
            ctx.fillStyle = "orange";
            ctx.fillRect(10, 10, 50, 50);

            ctx.fillStyle = "rgba(0, 0, 200, 0.3)";
            ctx.fillRect(35, 35, 50, 50);
        }; ctx.restore;

        ctx.font = "18px Arial";
        ctx.fillText("Page $page/2", 40, 75);
    }
}

$pdf.save-as: "t/canvas-demo.pdf";
```
