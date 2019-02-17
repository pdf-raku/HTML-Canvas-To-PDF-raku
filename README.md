# HTML-Canvas-To-PDF-p6

This is a PDF rendering back-end for HTML::Canvas.

- A canvas may be rendered to either a page, or an XObject form, using
a PDF::Content graphics object
- This back-end is compatible with PDF::Lite, PDF::Class and PDF::API6.
- Supported canvas image formats are PNG, GIF, JPEG and PDF

This back-end is **experimental**. At this stage, it is intended primarily for bench-marking and regression testing, etc for the Perl 6 PDF and CSS tool-chains.

```
use v6;
# Create a simple Canvas. Save as PDF

use PDF::Lite;
use PDF::Content;
use HTML::Canvas;
use HTML::Canvas::To::PDF;

# render to a PDF page
my PDF::Lite $pdf .= new;

# use a cache for shared resources such as fonts and images.
# for faster production and smaller multi-page PDF files
my HTML::Canvas::To::PDF::Cache $cache .= new;

for 1..2 -> $page {
    my HTML::Canvas $canvas .= new;
    my PDF::Content $gfx = $pdf.add-page.gfx;
    my HTML::Canvas::To::PDF $feed .= new: :$gfx, :$canvas, :$cache;

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

## Images