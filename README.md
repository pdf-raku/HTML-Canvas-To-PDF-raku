# HTML-Canvas-To-PDF-raku

[![Actions Status](https://github.com/pdf-raku/HTML-Canvas-To-PDF-raku/workflows/test/badge.svg)](https://github.com/pdf-raku/HTML-Canvas-To-PDF-raku/actions)

This is a PDF rendering back-end for the HTML::Canvas module.

- A canvas may be rendered to either a page, or an XObject form, using
a PDF::Content graphics object
- This back-end is compatible with PDF::Lite, PDF::Class and PDF::API6.
- Supported canvas image formats are PNG, GIF, JPEG and PDF

This back-end is **experimental**.

It may be useful, if you wish to manipulate existing PDF files
use the HTML Canvas API.

```
use v6;
# Finish an existing PDF. Add a background color and page numbers

use PDF::Lite;
use PDF::Content;
use PDF::Content::Page;
use HTML::Canvas::To::PDF;

# render to a PDF page
my PDF::Lite $pdf .= open: "examples/render-pdf-test-sheets.pdf";

# use a cache for shared resources such as fonts and images.
# for faster production and smaller multi-page PDF files
my HTML::Canvas::To::PDF::Cache $cache .= new;
my UInt $pages = $pdf.page-count;

for 1 .. $pages -> $page-num {
    my PDF::Content::Page $page = $pdf.page($page-num);
    my PDF::Content $gfx = $page.pre-gfx;
    $gfx.canvas: :$cache, -> \ctx {
        ctx.fillStyle = "rgba(0, 0, 200, 0.2)";
        ctx.fillRect(10, 25, $page.width - 20, $page.height - 45);
        ctx.font = "12px Arial";
        ctx.fillStyle = "rgba(50, 50, 200, 0.8)";
        ctx.fillText("Page $page-num/$pages", 550, 15);
    }
}

$pdf.save-as: "examples/demo.pdf";
```
