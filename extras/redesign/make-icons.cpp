// Renders the Vireo brand artwork (modules/gui/qt/redesign/assets/brand/*.svg) into
// every raster file the product ships: the Windows .ico, the PNGs of the Qt window
// and tray icon, the NSIS and MSI installer bitmaps and the preview sheet.
//
// Built and run inside the Linux container by extras/redesign/make-icons.sh (Qt6
// Svg + Gui are the only dependencies); do not run it by hand. The result is
// deterministic for a given Qt version, so re-running it on unchanged artwork
// leaves `git status` clean.
//
// usage: make-icons REPO_ROOT PREVIEW_DIR

#include <QtCore/QBuffer>
#include <QtCore/QByteArray>
#include <QtCore/QDir>
#include <QtCore/QFile>
#include <QtCore/QFileInfo>
#include <QtCore/QSaveFile>
#include <QtCore/QString>
#include <QtGui/QFontDatabase>
#include <QtGui/QGuiApplication>
#include <QtGui/QImage>
#include <QtGui/QPainter>
#include <QtSvg/QSvgRenderer>

#include <cstdio>
#include <vector>

namespace
{

// Sizes of the Windows icon (taskbar, title bar, Explorer views at 100%..200% DPI).
const int icoSizes[] = { 16, 20, 24, 32, 40, 48, 64, 96, 128, 256 };
// Sizes of the PNG files the Qt interface bundles (window icon, tray, About).
const int pngSizes[] = { 16, 24, 32, 48, 64, 128, 256 };
// Up to this size the hand-tuned small artwork (thicker mark) is used.
const int smallMaxSize = 24;

const QColor tileColor( 0x1B, 0x1B, 0x1B );

QString root;

bool fail( const QString &msg )
{
    std::fprintf( stderr, "make-icons: %s\n", qPrintable( msg ) );
    return false;
}

QSvgRenderer *load( const QString &rel )
{
    auto *r = new QSvgRenderer( root + "/" + rel );
    if( !r->isValid() )
    {
        fail( "cannot load " + rel );
        delete r;
        return nullptr;
    }
    return r;
}

QImage render( QSvgRenderer &svg, int size )
{
    QImage img( size, size, QImage::Format_ARGB32_Premultiplied );
    img.fill( Qt::transparent );
    QPainter p( &img );
    p.setRenderHints( QPainter::Antialiasing | QPainter::SmoothPixmapTransform );
    svg.render( &p, QRectF( 0, 0, size, size ) );
    return img;
}

QByteArray pngBytes( const QImage &img )
{
    QByteArray ba;
    QBuffer buf( &ba );
    buf.open( QIODevice::WriteOnly );
    img.save( &buf, "PNG" );
    return ba;
}

void put16( QByteArray &b, quint16 v ) { b.append( char( v & 0xff ) ); b.append( char( v >> 8 ) ); }
void put32( QByteArray &b, quint32 v ) { put16( b, v & 0xffff ); put16( b, v >> 16 ); }

// ICO entry for sizes below 64: a 32-bit DIB with an (all opaque) AND mask, the most
// compatible form. Larger sizes use an embedded PNG (supported since Vista).
QByteArray dibBytes( const QImage &argb )
{
    const int n = argb.width();
    const QImage img = argb.convertToFormat( QImage::Format_ARGB32 );
    QByteArray b;
    put32( b, 40 );          // BITMAPINFOHEADER
    put32( b, n );
    put32( b, n * 2 );       // XOR bitmap + AND mask
    put16( b, 1 );
    put16( b, 32 );
    put32( b, 0 );           // BI_RGB
    put32( b, n * n * 4 + ( ( n + 31 ) / 32 ) * 4 * n );
    put32( b, 0 ); put32( b, 0 ); put32( b, 0 ); put32( b, 0 );
    for( int y = n - 1; y >= 0; --y )   // bottom-up
        for( int x = 0; x < n; ++x )
        {
            const QRgb c = img.pixel( x, y );
            b.append( char( qBlue( c ) ) );
            b.append( char( qGreen( c ) ) );
            b.append( char( qRed( c ) ) );
            b.append( char( qAlpha( c ) ) );
        }
    b.append( QByteArray( ( ( n + 31 ) / 32 ) * 4 * n, 0 ) );   // AND mask: 0 = opaque (alpha rules)
    return b;
}

// What a PNG file or payload must satisfy: signature, decodable, exact size.
bool checkPng( const QByteArray &data, int w, int h, const QString &what, QImage *out = nullptr )
{
    static const char sig[8] = { char( 0x89 ), 'P', 'N', 'G', '\r', '\n', 0x1a, '\n' };
    if( data.size() < 8 || memcmp( data.constData(), sig, 8 ) != 0 )
        return fail( what + ": not a PNG (bad signature)" );
    QImage img;
    if( !img.loadFromData( data, "PNG" ) || img.isNull() )
        return fail( what + ": PNG does not decode" );
    if( img.width() != w || img.height() != h )
        return fail( what + ": PNG is " + QString::number( img.width() ) + "x" + QString::number( img.height() ) );
    if( out )
        *out = img;
    return true;
}

quint32 get32( const QByteArray &b, int off )
{
    return quint32( quint8( b[off] ) ) | quint32( quint8( b[off + 1] ) ) << 8
         | quint32( quint8( b[off + 2] ) ) << 16 | quint32( quint8( b[off + 3] ) ) << 24;
}
quint16 get16( const QByteArray &b, int off ) { return quint16( quint8( b[off] ) | quint8( b[off + 1] ) << 8 ); }

// Writes through a temporary file that is renamed on success (an interrupted run cannot
// leave a half-written file), then reads the file back and runs `verify` on it.
template<class Verify>
bool writeFile( const QString &rel, const QByteArray &data, Verify verify )
{
    const QString path = root + "/" + rel;
    QDir().mkpath( QFileInfo( path ).absolutePath() );
    QSaveFile f( path );
    if( !f.open( QIODevice::WriteOnly ) || f.write( data ) != data.size() || !f.commit() )
        return fail( "cannot write " + path );
    QFile in( path );
    if( !in.open( QIODevice::ReadOnly ) )
        return fail( "cannot read back " + path );
    const QByteArray back = in.readAll();
    if( back != data )
        return fail( rel + ": the file on disk differs from what was written" );
    if( !verify( back ) )
        return fail( rel + ": validation failed" );
    std::printf( "wrote %s (%lld bytes, validated)\n", qPrintable( rel ), qint64( data.size() ) );
    return true;
}

bool writePng( const QString &rel, const QImage &img )
{
    return writeFile( rel, pngBytes( img ), [&]( const QByteArray &d ) { return checkPng( d, img.width(), img.height(), rel ); } );
}

// The directory of the icon must list every size, each payload must be a valid PNG or DIB of
// that size, and decode to exactly the image that was meant for that size.
bool checkIco( const QByteArray &d, const std::vector<QImage> &images )
{
    if( d.size() < 6 || get16( d, 0 ) != 0 || get16( d, 2 ) != 1 || get16( d, 4 ) != images.size() )
        return fail( "ico: bad header or wrong image count" );
    for( size_t i = 0; i < images.size(); ++i )
    {
        const int n = images[i].width();
        const QString what = "ico entry " + QString::number( n );
        const int dir = 6 + 16 * int( i );
        const int dw = quint8( d[dir] ) ? quint8( d[dir] ) : 256;
        const quint32 size = get32( d, dir + 8 ), off = get32( d, dir + 12 );
        if( dw != n || quint8( d[dir + 1] ) != quint8( d[dir] ) )
            return fail( what + ": directory size is " + QString::number( dw ) );
        if( off + size > quint32( d.size() ) || size < 40 )
            return fail( what + ": payload outside the file" );
        const QByteArray payload = d.mid( int( off ), int( size ) );
        QImage got;
        if( n >= 64 )
        {
            if( !checkPng( payload, n, n, what, &got ) )
                return false;
        }
        else
        {
            if( get32( payload, 0 ) != 40 || int( get32( payload, 4 ) ) != n || int( get32( payload, 8 ) ) != 2 * n
                || get16( payload, 14 ) != 32 )
                return fail( what + ": bad DIB header" );
            got = QImage( n, n, QImage::Format_ARGB32 );
            const int px = 40;
            if( payload.size() < px + n * n * 4 )
                return fail( what + ": DIB too short" );
            for( int y = 0; y < n; ++y )
                for( int x = 0; x < n; ++x )
                {
                    const int o = px + ( ( n - 1 - y ) * n + x ) * 4;
                    got.setPixel( x, y, qRgba( quint8( payload[o + 2] ), quint8( payload[o + 1] ),
                                               quint8( payload[o] ), quint8( payload[o + 3] ) ) );
                }
        }
        if( got.convertToFormat( QImage::Format_ARGB32 ) != images[i].convertToFormat( QImage::Format_ARGB32 ) )
            return fail( what + ": decoded pixels differ from the rendered image" );
    }
    return true;
}

bool writeIco( const QString &rel, const std::vector<QImage> &images )
{
    QByteArray head, body;
    put16( head, 0 ); put16( head, 1 ); put16( head, quint16( images.size() ) );
    quint32 offset = 6 + 16 * quint32( images.size() );
    for( const QImage &img : images )
    {
        const int n = img.width();
        const QByteArray data = n >= 64 ? pngBytes( img ) : dibBytes( img );
        head.append( char( n >= 256 ? 0 : n ) );
        head.append( char( n >= 256 ? 0 : n ) );
        head.append( char( 0 ) ); head.append( char( 0 ) );   // colours, reserved
        put16( head, 1 ); put16( head, 32 );                  // planes, bpp
        put32( head, quint32( data.size() ) );
        put32( head, offset );
        offset += quint32( data.size() );
        body.append( data );
    }
    return writeFile( rel, head + body, [&]( const QByteArray &d ) { return checkIco( d, images ); } );
}

// 24-bit bottom-up BMP, the form NSIS and WiX expect.
QByteArray bmpBytes( const QImage &src )
{
    const QImage img = src.convertToFormat( QImage::Format_RGB888 );
    const int w = img.width(), h = img.height();
    const int stride = ( w * 3 + 3 ) & ~3;
    const quint32 dataSize = quint32( stride * h );
    QByteArray b;
    b.append( "BM" );
    put32( b, 54 + dataSize ); put32( b, 0 ); put32( b, 54 );
    put32( b, 40 ); put32( b, w ); put32( b, h );
    put16( b, 1 ); put16( b, 24 ); put32( b, 0 ); put32( b, dataSize );
    put32( b, 2835 ); put32( b, 2835 ); put32( b, 0 ); put32( b, 0 );
    for( int y = h - 1; y >= 0; --y )
    {
        const uchar *line = img.constScanLine( y );
        b.append( reinterpret_cast<const char *>( line ), w * 3 );
        b.append( QByteArray( stride - w * 3, 0 ) );
    }
    return b;
}

bool writeBmp( const QString &rel, const QImage &img )
{
    return writeFile( rel, bmpBytes( img ), [&]( const QByteArray &d ) {
        const int stride = ( img.width() * 3 + 3 ) & ~3;
        return d.startsWith( "BM" ) && get16( d, 28 ) == 24 && int( get32( d, 18 ) ) == img.width()
            && int( get32( d, 22 ) ) == img.height() && d.size() == 54 + stride * img.height();
    } );
}

QString interFamily()
{
    const int id = QFontDatabase::addApplicationFont(
        root + "/modules/gui/qt/redesign/assets/fonts/Inter-SemiBold.ttf" );
    const QStringList fams = QFontDatabase::applicationFontFamilies( id );
    return fams.isEmpty() ? QString() : fams.first();
}

// Left panel of the NSIS welcome and finish pages (164 x 314).
QImage nsisPanel( QSvgRenderer &icon, const QString &family )
{
    QImage img( 164, 314, QImage::Format_RGB32 );
    img.fill( tileColor );
    QPainter p( &img );
    p.setRenderHints( QPainter::Antialiasing | QPainter::SmoothPixmapTransform | QPainter::TextAntialiasing );
    icon.render( &p, QRectF( 34, 54, 96, 96 ) );
    QFont f( family.isEmpty() ? QStringLiteral( "sans-serif" ) : family );
    f.setPixelSize( 30 );
    p.setFont( f );
    p.setPen( QColor( 0xF2, 0xF2, 0xF2 ) );
    p.drawText( QRectF( 0, 160, 164, 40 ), Qt::AlignCenter, QStringLiteral( "Vireo" ) );
    QFont g = f;
    g.setPixelSize( 11 );
    p.setFont( g );
    p.setPen( QColor( 0x9A, 0x9A, 0x9A ) );
    p.drawText( QRectF( 0, 198, 164, 18 ), Qt::AlignCenter, QStringLiteral( "built on VLC media player" ) );
    return img;
}

// Banner of the MSI dialogs (WixUIBannerBmp, 494 x 58): the title text is drawn on the
// left by WiX, so the artwork sits on the right.
QImage msiBanner( QSvgRenderer &icon )
{
    QImage img( 494, 58, QImage::Format_RGB32 );
    img.fill( Qt::white );
    QPainter p( &img );
    p.setRenderHints( QPainter::Antialiasing | QPainter::SmoothPixmapTransform );
    icon.render( &p, QRectF( 494 - 54, 3, 52, 52 ) );
    return img;
}

} // namespace

int main( int argc, char **argv )
{
    qputenv( "QT_QPA_PLATFORM", "offscreen" );
    QGuiApplication app( argc, argv );
    if( argc != 3 )
    {
        std::fprintf( stderr, "usage: make-icons REPO_ROOT PREVIEW_DIR\n" );
        return 2;
    }
    root = QString::fromLocal8Bit( argv[1] );
    const QString preview = QString::fromLocal8Bit( argv[2] );

    const QString brand = "modules/gui/qt/redesign/assets/brand";
    QSvgRenderer *icon = load( brand + "/vireo-icon.svg" );
    QSvgRenderer *small = load( brand + "/vireo-icon-small.svg" );
    if( !icon || !small )
        return 1;
    auto pick = [&]( int size ) -> QSvgRenderer & { return size <= smallMaxSize ? *small : *icon; };

    bool ok = true;

    std::vector<QImage> ico;
    for( int s : icoSizes )
        ico.push_back( render( pick( s ), s ) );
    // Up to smallMaxSize the entries must come from the thick small artwork, not the master.
    for( size_t i = 0; i < ico.size(); ++i )
    {
        const int s = icoSizes[i];
        const bool isSmall = ico[i] == render( *small, s );
        const bool isMaster = ico[i] == render( *icon, s );
        if( s <= smallMaxSize ? ( !isSmall || isMaster ) : ( !isMaster || isSmall ) )
            ok &= fail( "ico entry " + QString::number( s ) + " uses the wrong artwork" );
        else
            std::printf( "ico entry %d: %s artwork\n", s, s <= smallMaxSize ? "small (vireo-icon-small.svg)" : "master (vireo-icon.svg)" );
    }
    ok &= writeIco( "share/icons/vireo.ico", ico );

    for( int s : pngSizes )
        ok &= writePng( brand + "/png/vireo-" + QString::number( s ) + ".png", render( pick( s ), s ) );

    const QString family = interFamily();
    if( family.isEmpty() )
        ok &= fail( "Inter-SemiBold.ttf not found" );
    ok &= writeBmp( "extras/package/win32/NSIS/vireo_branding.bmp", nsisPanel( *icon, family ) );
    ok &= writeBmp( "extras/package/win32/msi/vireo_bannrbmp.bmp", msiBanner( *icon ) );

    // Previews for the owner to check (not committed): the sizes that matter, and a sheet
    // that shows each of them enlarged on a light and a dark background.
    QDir().mkpath( preview );
    const int previewSizes[] = { 16, 20, 24, 32, 48, 256 };
    QImage sheet( 6 * 270, 2 * 270 + 20, QImage::Format_RGB32 );
    sheet.fill( Qt::white );
    QPainter sp( &sheet );
    int col = 0;
    for( int s : previewSizes )
    {
        const QImage img = render( pick( s ), s );
        img.save( preview + "/vireo-" + QString::number( s ) + ".png" );
        const int zoom = s >= 256 ? 1 : 256 / s;
        const int z = s * zoom;
        for( int row = 0; row < 2; ++row )
        {
            const QRect cell( col * 270 + 5, row * 270 + 10, 260, 260 );
            sp.fillRect( cell, row == 0 ? QColor( 0xF0, 0xF0, 0xF0 ) : QColor( 0x20, 0x20, 0x20 ) );
            sp.drawImage( QRect( cell.x() + ( 260 - z ) / 2, cell.y() + ( 260 - z ) / 2, z, z ),
                          img.scaled( z, z, Qt::IgnoreAspectRatio, Qt::FastTransformation ) );
            // and the real size next to the corner, as the shell shows it
            sp.drawImage( cell.x() + 4, cell.y() + 4, img.width() > 64 ? img.scaled( 48, 48, Qt::KeepAspectRatio, Qt::SmoothTransformation ) : img );
        }
        ++col;
    }
    sp.end();
    sheet.save( preview + "/vireo-sheet.png" );
    nsisPanel( *icon, family ).save( preview + "/nsis-panel.png" );
    msiBanner( *icon ).save( preview + "/msi-banner.png" );

    delete icon;
    delete small;
    return ok ? 0 : 1;
}
