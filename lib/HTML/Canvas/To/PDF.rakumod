unit class HTML::Canvas::To::PDF:ver<0.0.12>;

use HTML::Canvas :FillRule;
use HTML::Canvas::Gradient;
use HTML::Canvas::Graphic;
use HTML::Canvas::Pattern;
use HTML::Canvas::Path2D;
use HTML::Canvas::Image;
use HTML::Canvas::ImageData;
use PDF;
use PDF::COS::Dict;
use PDF::COS::Name;
use PDF::Content::Color :rgb, :gray;
use PDF::Content::FontObj;
use PDF::Content::Font::CoreFont;
use PDF::Content::Image::PNG;
use PDF::Content::Matrix;
use PDF::Content::Ops :TextMode, :LineCaps, :LineJoin;
use PDF::Content::XObject;
use PDF::Content;
use CSS::Font;

has HTML::Canvas $.canvas is rw .= new;
has PDF::Content $.gfx handles <content content-dump> is required;
has Numeric $.width;  # canvas width in points
has Numeric $.height; # canvas height in points

class Cache {
    use PDF::Font::Loader::FontObj;
    has %.image;
    has %.gradient{HTML::Canvas::Gradient};
    has %.pattern{HTML::Canvas::Pattern};
    has PDF::Font::Loader::FontObj %.font;
    has %.canvas{HTML::Canvas};
}
class Font is CSS::Font {
    use CSS::Font::Resources::Source;
    use PDF::Font::Loader::CSS;
    has PDF::Font::Loader::CSS $!font-loader handles<font-face>;
    has Cache $.cache is required;
    submethod TWEAK(:cache($), |c) {
        $!font-loader .= new: |c;
    }
    method font-obj(Font:D $font:) {
        my CSS::Font::Resources::Source $source = $!font-loader.source: :$font;
        my $key = do with $source { .Str } else { '' };
        $!cache.font{$key} //= $!font-loader.load-font: :$font, :$source;
    }
}
has Cache $.cache .= new;
has Font $!font .= new: :$!cache;

submethod TWEAK(PDF :$pdf, :@font-face)  {
    $!gfx //= .add-page.gfx
        with $pdf;
    with $!gfx.canvas {
        $!width  //= .width;
        $!height //= .height;
    }

    with $!canvas {
        .font-face.append: @font-face;
        .callback.push: self.callback;
    }
}

method !add-pdf-comment($op, *@args) {
    use JSON::Fast;
    my @jargs = flat @args.map: {
        when Str|Numeric|Bool|List { to-json($_).subst(/(<-[\0..\xFF]>)/, { '\u%04d'.sprintf($0.ord)}, :g).subst(/[' '|"\n"]+/, ' ', :g) }
        when HTML::Canvas::Pattern | HTML::Canvas::Gradient {
            .to-js('ctx');
        }
        default {
            .?js-ref // .raku;
        }
    };
    my \fmt = $op ~~ HTML::Canvas::LValue
        ?? 'ctx.%s = %s;'
        !! 'ctx.%s(%s);';
    my $js = fmt.sprintf( $op, @jargs.join(", ") );
    $!gfx.add-comment('--- ' ~ $js ~ ' ---')
}

method callback {
    sub (Str $op, |c) {
        if self.can: $op {
            self!add-pdf-comment($op, |c)
                unless $op.starts-with("_");
            self."{$op}"(|c);
        }
        else {
            warn "Canvas call not supported in PDF: $op"
        }
    }
}

sub pt(Numeric \l) { l }

method !coords(Numeric \x, Numeric \y) {
    (x, -y);
}

method !transform( |c ) {
    my Numeric @tm = PDF::Content::Matrix::transform( |c );
    $!gfx.ConcatMatrix( @tm );
}

method _start {
    $!font .= new: :$!cache;
    $!font.font-face = $!canvas.font-face;
    $!font.css = $!canvas.css;
    $!gfx.Save;
    # clip graphics to outside of canvas
    $!gfx.Rectangle(0, 0, pt($!width), pt($!height) );
    $!gfx.ClosePath;
    $!gfx.Clip;
    $!gfx.EndPath;
    # This translation lets us map HTML coordinates to PDF
    # by negating Y - see !coords method above
    $!gfx.transform: :translate[0, $!height];
    # initialize settings; just those where HTML and PDF defaults differ
    self.lineJoin($!canvas.lineJoin);
}
method _finish {
    $!gfx.Restore;
}
method save {
    $!gfx.Save
}
method restore {
    $!gfx.Restore;
    $!font.css = $!canvas.css;
}
method scale(Numeric \x, Numeric \y) { self!transform(|scale => [x, y]) }
method rotate(Numeric \r) { self!transform(|rotate => -r) }
method translate(Numeric \x, Numeric \y) { self!transform(|translate => [x, -y]) }
method transform(Numeric \a, Numeric \b, Numeric \c, Numeric \d, Numeric \e, Numeric \f) {
    self!transform( |matrix => [a, b, -c, d, e, -f]);
}
method setTransform(Numeric \a, Numeric \b, Numeric \c, Numeric \d, Numeric \e, Numeric \f) {
    $!gfx.CTM = PDF::Content::Matrix::multiply(
        [a, b, -c, d, e, -f],
        PDF::Content::Matrix::translate(0, $!height)
    );
}
method clearRect(Numeric \x, Numeric \y, Numeric \w, Numeric \h) {
    # stub - should etch a clipping path. not paint a white rectangle
    $!gfx.Save;
    $!gfx.FillColor = gray(1);
    $!gfx.FillAlpha = 1;
    $!gfx.Rectangle: |self!coords(x, y + h), pt(w), pt(h);
    $!gfx.Fill;
    $!gfx.Restore;
}
method fillRect(Numeric \x, Numeric \y, Numeric \w, Numeric \h ) {
    unless $!gfx.FillAlpha =~= 0 {
        $!gfx.Rectangle: |self!coords(x, y + h), pt(w), pt(h);
        $!gfx.Fill;
    }
}
method strokeRect(Numeric \x, Numeric \y, Numeric \w, Numeric \h ) {
    unless $!gfx.StrokeAlpha =~= 0 {
        $!gfx.Rectangle: |self!coords(x, y + h), pt(w), pt(h);
        $!gfx.CloseStroke;
    }
}
method beginPath() { }
multi method fill(HTML::Canvas::Path2D $path, FillRule $rule = 'nonzero') {
    self."{.key}"(|.value) for $path.calls();
    self.fill($rule);
}
multi method fill('evenodd') {
    $!gfx.EOFill;
}
multi method fill(Str $?) {
    $!gfx.Fill;
}
multi method stroke() {
    $!gfx.Stroke;
}
multi method stroke(HTML::Canvas::Path2D $path) {
    self."{.key}"(|.value) for $path.calls();
    self.stroke();
}
method clip() {
    $!gfx.Clip;
    $!gfx.EndPath;
}
method fillStyle(HTML::Canvas::ColorSpec $_) {
    when HTML::Canvas::Pattern {
        $!gfx.FillAlpha = 1.0;
        $!gfx.FillColor = self!make-pattern($_);
    }
    when HTML::Canvas::Gradient {
        $!gfx.FillAlpha = 1.0;
        $!gfx.FillColor = self!make-gradient($_);
    }
    default {
        with $!canvas.css.background-color {
            $!gfx.FillColor = rgb( |.rgb.map(*/255) );
            $!gfx.FillAlpha = .a / 255;
        }
    }
}
method !make-pattern(HTML::Canvas::Pattern $pattern --> Pair) {
    my @ctm = $!gfx.CTM.list;
    $!cache.pattern{$pattern}{@ctm.Str} //= do {
        my Bool \repeat-x = ? ($pattern.repetition ~~ 'repeat'|'repeat-x');
        my Bool \repeat-y = ? ($pattern.repetition ~~ 'repeat'|'repeat-y');

        my $image = $pattern.image;
        my PDF::Content::XObject $xobject = ($!cache.image{$image.html-id} //= PDF::Content::XObject.open: $image.data-uri);
        my Numeric $image-width = $xobject.width;
        my Numeric $image-height = $xobject.height;

        my constant BigPad = 1000;
        my $left-pad = repeat-x ?? 0 !! BigPad;
        my $bottom-pad = repeat-y ?? 0 !! BigPad;

        my @Matrix = @ctm;
        with @Matrix {
            enum « :Skew-Y(2) :Scale-Y(3) :E(4) :F(5) »;
            .[E] -= $image-height * .[Skew-Y];
            .[F] -= $image-height * .[Scale-Y];
        }
        my @BBox = [0, 0, $image-width + $left-pad, $image-height + $bottom-pad];
        my $Pattern = $!gfx.tiling-pattern(:@BBox, :@Matrix, :XStep($image-width + $left-pad), :YStep($image-height + $bottom-pad) );
        $Pattern.graphics: {
            .do($xobject, 0, 0);
        }
        $!gfx.use-pattern($Pattern);
    }
}
method !make-shading(HTML::Canvas::Gradient $gradient --> PDF::COS::Dict) {
    $!cache.gradient{$gradient}<shading> //= do {
        enum « :Axial(2) :Stitching(3), :Radial(3) »;
        my @color-stops;
        for $gradient.colorStops.sort(*.offset) {
            my @rgb = (.r, .g, .b).map: (*/255)
                with .color;
            @color-stops.push: %( :offset(.offset), :@rgb );
        };
        @color-stops.push({ :rgb[1, 1, 1] })
            unless @color-stops;
        @color-stops[0]<offset> = 0.0;
        my @Functions = [(1 ..^ +@color-stops).map: {
                my $C0 = @color-stops[$_ - 1]<rgb>;
                my $C1 = @color-stops[$_]<rgb>;
                %(
                    :FunctionType(Axial),
                    :Domain[0, 1],
                    :$C0,
                    :$C1,
                    :N(1)
                );
            }];
        my $Function;
        if +@Functions == 1 {
            $Function = @Functions[0];
        }
        else {
            # multiple functions - wrap then up in a stitching function
            my @Bounds = [ (1 .. (+@color-stops-2)).map: { @color-stops[$_]<offset>; } ];
            my @Encode = flat (0, 1) xx +@Functions;

            $Function = {
                :FunctionType(Stitching),
                :Domain[0, 1],
                :@Encode,
                :@Functions,
                :@Bounds
            }
        };

        my ($ShadingType, $Coords) = do given $gradient.type {
            when 'Linear' {
                (Axial,
                 [.x0, .y1, .x1, .y0] with $gradient);
            }
            when 'Radial' {
                (Radial,
                 [.x0, .y1 - 2 * .y0, .r0, .x1, -.y0, .r1] with $gradient);
            }
        }
        my PDF::COS::Name() $ColorSpace = 'DeviceRGB';

        PDF::COS::Dict.COERCE: {
            :$ShadingType,
            ($gradient.type eq 'Linear'
             ?? :Background(@color-stops.tail<rgb>)
             !! ()),
            :$ColorSpace,
            :Domain[0, 1],
            :$Coords,
            :$Function,
            :Extend[True, True],
        };
    }
}
method !make-gradient(HTML::Canvas::Gradient $gradient --> Pair) {
    my @ctm = $!gfx.CTM.list;
    @ctm.push: +$gradient.colorStops;
    $!cache.gradient{$gradient}{@ctm.Str} //= do {
        my $Shading = self!make-shading($gradient);
        my Numeric $gradient-height = $gradient.y1 - $gradient.y0;

        my (\scale-x, \skew-x, \skew-y, \scale-y, \trans-x, \trans-y) = @ctm;
        my @Matrix = [scale-x, skew-x, skew-y, scale-y,
                      trans-x - $gradient-height*skew-y,
                      trans-y - $gradient-height*scale-y,
                     ];
        # construct a type 2 (shading) pattern
        my PDF::COS::Name() $Type = 'Pattern';
        my %dict = :$Type, :PatternType(2), :@Matrix, :$Shading;
        my $Pattern = $!gfx.resource-key(PDF::COS::Dict.COERCE: %dict);
        :$Pattern;
    }
}
method strokeStyle(HTML::Canvas::ColorSpec $_) {
    when HTML::Canvas::Pattern {
        $!gfx.StrokeAlpha = 1.0;
        $!gfx.StrokeColor = self!make-pattern($_);
    }
    when HTML::Canvas::Gradient {
        $!gfx.StrokeAlpha = 1.0;
        $!gfx.StrokeColor = self!make-gradient($_);
    }
    default {
        with $!canvas.css.color {
            $!gfx.StrokeColor = rgb( |.rgb.map(*/255) );
            $!gfx.StrokeAlpha = .a / 255;
        }
    }
}
method lineWidth(Numeric $width) {
    $!gfx.LineWidth = $width;
}
method globalAlpha(Numeric) { }
method lineCap(HTML::Canvas::LineCap $cap-name) {
    my LineCaps $lc = %( :butt(ButtCaps), :round(RoundCaps),  :square(SquareCaps)){$cap-name};
    $!gfx.LineCap = $lc;
}
method lineJoin(HTML::Canvas::LineJoin $join-name) {
    my LineJoin $lj = %( :miter(MiterJoin), :round(RoundJoin),  :bevel(BevelJoin)){$join-name};
    $!gfx.LineJoin = $lj;
}
method !text-box(Str $text) {
    my $align = $!canvas.textAlign;
    my HTML::Canvas::Baseline $baseline = $!canvas.textBaseline;
    my $direction = $!canvas.direction;
    $!gfx.text-box: :$text, :$align, :$baseline, :shape, :$direction;
}
method !text(Str $text, Numeric $x, Numeric $y, Numeric :$maxWidth) {
    my Numeric $scale = 100;
    my $text-box = self!text-box($text);
    if $maxWidth {
        my \width = $!canvas.measureText(Str, :$text-box).width;
        $scale = 100 * $maxWidth / width
            if width > $maxWidth;
    }

    $!gfx.BeginText;
    $!gfx.HorizScaling = $scale;
    $!gfx.text-position = self!coords($x, $y);
    $!gfx.print: $text-box;
    $!gfx.EndText;
}
method font(Str $font-style) {
    $!font.css = $!canvas.css;
    my \pdf-font = $!gfx.use-font($!font.font-obj);
    $!gfx.font = [ pdf-font, $!canvas.adjusted-font-size($!font.em) ];
}
method textBaseline(Str $_) {}
method textAlign(Str $_) {}
method direction(Str $_) {}
method fillText(Str $text, Numeric $x, Numeric $y, Numeric $maxWidth?) {
    $!gfx.Save;
    self!text($text, $x, $y, :$maxWidth);
    $!gfx.Restore
}
method strokeText(Str $text, Numeric $x, Numeric $y, Numeric $maxWidth?) {
    $!gfx.Save;
    $!gfx.TextRender = TextMode::OutlineText;
    self!text($text, $x, $y, :$maxWidth);
    $!gfx.Restore
}
method measureText(Str $text, :$text-box = self!text-box($text) --> Numeric) {
    $!canvas.adjusted-font-size: $text-box.width;
}
method !canvas-to-xobject(HTML::Canvas $image, Numeric :$width!, Numeric :$height! ) {
    $!cache.canvas{$image}{"$width,$height"} //= do {
        my $form = $!gfx.xobject-form( :BBox[0, 0, $width, $height] );
        my $renderer = self.new: :gfx($form.gfx), :$width, :$height, :$!cache;
        $image.render($renderer);
        $form
    };
}
method !to-xobject(HTML::Canvas::Graphic $_, :$width! is rw, :$height! is rw --> PDF::Content::XObject) {
    my $k := .html-id;
    when HTML::Canvas {
        $width = $_ with .html-width;
        $height = $_ with .html-height;
        $!cache.image{$k} //= self!canvas-to-xobject($_, :$width, :$height);
    }
    when HTML::Canvas::ImageData {
        need PDF::IO;
        given $!cache.image{$k} //= do {
            my $source = PDF::IO.COERCE: .image.Blob.decode: "latin-1";
            PDF::Content::XObject.open( :$source, :image-type<PNG> );
          } {
            $width = .width;
            $height = .height;
            $_;
        }
    }
    when .image-type ~~ 'PNG'|'JPEG'|'GIF' {
        given $!cache.image{$k} //= PDF::Content::XObject.open: .data-uri {
            $width = .width;
            $height = .height;
            $_;
        }
    }
    default {
        # something we can't handle - draw a placeholder
        my $form = $!gfx.xobject-form( :BBox[0, 0, $width, $height] );
        $form.graphics: {
            .FillColor = rgb(.8, .9, .9);
            .FillAlpha = .45;
            .Rectangle(0, 0, $width, $height);
            .Fill;
        }
        $form;
    }
}
multi method drawImage( HTML::Canvas::Graphic $image,
                        Numeric \sx, Numeric \sy,
                        Numeric \sw, Numeric \sh,
                        Numeric \dx, Numeric \dy,
                        Numeric \dw, Numeric \dh) {
    unless sw =~= 0 || sh =~= 0 {
        $!gfx.Save;
        my $ga = $!canvas.globalAlpha;
        unless $ga =~= 1 {
            $!gfx.StrokeAlpha *= $ga;
            $!gfx.FillAlpha *= $ga;
        }
        # position at top right of visible area
        $!gfx.transform: :translate(self!coords(dx, dy));
        # clip to visible area
        $!gfx.Rectangle: pt(0), pt(-dh), pt(dw), pt(dh);
        $!gfx.ClosePath;
        $!gfx.Clip;
        $!gfx.EndPath;

        my \x-scale = dw / sw;
        my \y-scale = dh / sh;
        $!gfx.transform: :translate[ -sx * x-scale, sy * y-scale ]
            if sx || sy;

        my Numeric $width = dw;
        my Numeric $height = dh;
        my PDF::Content::XObject $xobject = self!to-xobject($image, :$width, :$height);

        $width  *= x-scale;
        $height *= y-scale;

        $!gfx.do: $xobject, :valign<top>, :$width, :$height;

        $!gfx.Restore;
    }
}
multi method drawImage(HTML::Canvas::Graphic $image, Numeric $dx, Numeric $dy, Numeric $dw?, Numeric $dh?) {
    my $width = $dw;
    my $height = $dh;
    my PDF::Content::XObject $xobject = self!to-xobject($image, :$width, :$height);

    my %opt = :valign<top>;
    %opt<width>  = $_ with $dw;
    %opt<height> = $_ with $dh;

    my $ga = $!canvas.globalAlpha;
    unless $ga =~= 1 {
        $!gfx.Save;
        $!gfx.StrokeAlpha *= $ga;
        $!gfx.FillAlpha *= $ga;
    }

    $!gfx.do: $xobject, |self!coords($dx, $dy), |%opt;

    $!gfx.Restore
        unless $ga =~= 1;
}
method putImageData(HTML::Canvas::ImageData $image-data, Numeric $dx, Numeric $dy) { self.drawImage( $image-data, $dx, $dy) }
method getLineDash() {}
method setLineDash(*@pattern) {
    $!gfx.SetDashPattern(@pattern, $!canvas.lineDashOffset)
}
method closePath() { $!gfx.ClosePath }
method moveTo(Numeric \x, Numeric \y) {
    $!gfx.MoveTo: |self!coords(x, y);
}
method lineTo(Numeric \x, Numeric \y) {
    $!gfx.LineTo: |self!coords(x, y);
}
method quadraticCurveTo(Numeric \cp1x, Numeric \cp1y, Numeric \x, Numeric \y) {
    my \cp2x = cp1x + 2/3 * (x - cp1x);
    my \cp2y = cp1y + 2/3 * (y - cp1y);
    $!gfx.CurveTo: |self!coords(cp1x, cp1y), |self!coords(cp2x, cp2y), |self!coords(x, y);
 }
 method bezierCurveTo(Numeric \cp1x, Numeric \cp1y, Numeric \cp2x, Numeric \cp2y, Numeric \x, Numeric \y) {
    $!gfx.CurveTo: |self!coords(cp1x, cp1y), |self!coords(cp2x, cp2y), |self!coords(x, y);
}
method rect(\x, \y, \w, \h) {
    $!gfx.Rectangle: |self!coords(x, y + h), pt(w), pt(h);
    $!gfx.ClosePath;
}

#| Compute all four points for an arc that subtends the same total angle
#| but is centered on the X-axis
sub createSmallArc(Numeric \r, Numeric \a1, Numeric \a2) {
    # PDF doesn't have a semicircle operator. Need to approximate via Bezier curves. Adapted from
    # http://hansmuller-flex.blogspot.co.nz/2011/04/approximating-circular-arc-with-cubic.html
    # courtesy of Hans Muller
    my Numeric \a = (a2 - a1) / 2.0;

    my Numeric \x4 = r * cos(a);
    my Numeric \y4 = r * sin(a);
    my Numeric \x1 = x4;
    my Numeric \y1 = -y4;

    my Numeric \k = 0.5522847498;
    my Numeric \f = k * tan(a);

    my Numeric \x2 = x1 + f * y4;
    my Numeric \y2 = y1 + f * x4;
    my Numeric \x3 = x2;
    my Numeric \y3 = -y2;

    # Find the arc points actual locations by computing x1,y1 and x4,y4
    # and rotating the control points by a + a1

    my Numeric \ar = a + a1;
    my Numeric \cos_ar = cos(ar);
    my Numeric \sin_ar = sin(ar);

    return {
        :x1(r * cos(a1)),
        :y1(r * sin(a1)),
        :x2(x2 * cos_ar - y2 * sin_ar),
        :y2(x2 * sin_ar + y2 * cos_ar),
        :x3(x3 * cos_ar - y3 * sin_ar),
        :y3(x3 * sin_ar + y3 * cos_ar),
        :x4(r * cos(a2)),
        :y4(r * sin(a2)),
    };
}

constant @Quadrant = [ 0, pi/2, pi, 3 * pi/2, 2 * pi ];
sub find-quadrant($a) {
    my \a = $a % (2*pi);
    (0..3).first: { @Quadrant[$_] - $*TOLERANCE <= a <= @Quadrant[$_+1] + $*TOLERANCE };
}
sub swap($a is rw, $b is rw) {
    my $t = $a;
    $a = $b;
    $b = $t;
}
method arc(Numeric \x, Numeric \y, Numeric \r,
           Numeric $startAngle is copy, Numeric $endAngle is copy, Bool $anti-clockwise?) {

    # limit to one full rotation
    if $anti-clockwise {
        $endAngle = $startAngle
            if $startAngle - $endAngle > 2 * pi;
    }
    else {
        $endAngle = $startAngle + 2 * pi
            if $endAngle - $startAngle > 2 * pi;
    }

    # break circle down into semicircle quadrants, which
    # are then drawn with individual PDF CurveTo operations
    my $start-q = find-quadrant($startAngle);
    my $end-q   = find-quadrant($endAngle);

    my $n = $end-q >= $start-q
        ?? $end-q - $start-q
        !! (4 - $start-q) + $end-q;

    $n ||= do {
        # further analyse start/end in the same quadrant
        # ~ full circle, or short arc?
        my \theta = $endAngle - $startAngle;
        theta < pi ?? 0 !! 4;
    }

    if $anti-clockwise {
        # draw the complimentry arc
        swap($startAngle, $endAngle);
        swap($start-q, $end-q);
        $n = 4 - $n;
    }

    my @arcs = (0..$n).map: {
        my \starting = $_ == 0;
        my \ending = $_ == $n;
        my \i = ($start-q + $_) % 4;
        my \a1 = starting ?? $startAngle !! @Quadrant[i];
        my \a2 = ending  ?? $endAngle    !! @Quadrant[i+1];
        a1 =~= a2
            ?? Empty
            !! createSmallArc(r, a1, a2)
    }

    $!gfx.MoveTo: |self!coords(x + .<x1>, y + .<y1>)
        with @arcs[0];

    for @arcs {
        $!gfx.CurveTo: |self!coords(x + .<x2>, y + .<y2>),
                       |self!coords(x + .<x3>, y + .<y3>),
                       |self!coords(x + .<x4>, y + .<y4>);
    }
}
