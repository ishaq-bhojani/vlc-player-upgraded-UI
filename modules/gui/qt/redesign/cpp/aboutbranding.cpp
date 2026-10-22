/*****************************************************************************
 * Copyright (C) 2026 Vireo contributors
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
 *****************************************************************************/
#ifdef HAVE_CONFIG_H
# include <config.h>
#endif

#include "aboutbranding.hpp"
#include "brandicon.hpp"
#include "branding.hpp"

#include "qt.hpp" // qtr()

#include <QChar>
#include <QFile>
#include <QLabel>
#include <QPixmap>
#include <QTextEdit>

namespace redesign
{

void applyAboutBranding(QLabel* title, QLabel* description, QLabel* version, QLabel* logo, QTextEdit* licensePage)
{
    /* built on VLC, link to the source, not affiliated with VideoLAN, credit of the bundled font */
    description->setText("<html><head/><body>" +
        qtr( "<p>%1 is built on <a href=\"https://www.videolan.org/vlc/\"><span style=\" text-decoration: underline; color:#0057ae;\">VLC media player</span></a>, a free and open source media player made by the volunteers of the <a href=\"https://www.videolan.org/\"><span style=\" text-decoration: underline; color:#0057ae;\">VideoLAN</span></a> community. %1 is an independent project and is not affiliated with or endorsed by VideoLAN.</p>"
             "<p>Source code: <a href=\"%2\"><span style=\" text-decoration: underline; color:#0057ae;\">%2</span></a></p>"
             "<p>The interface uses the Inter font (SIL Open Font License 1.1, see License).</p>" )
            .arg( productName(), productWebsite() ) +
        "</body> </html>");

    /* "Vireo 0.1.0" (+ build number), then "Built on VLC media player <VLC version>" */
    const QString name = productName();
    const QString suffix = versionSuffix( releaseVersion(), REDESIGN_BUILD_NUMBER );
    title->setText("<html><head/><body><p><span style=\" font-size:26pt; color:#353535;\"> " + name.toHtmlEscaped()
        + " </span><span style=\" font-size:14pt; color:#353535;\">" + suffix.toHtmlEscaped()
        + "</span></p><p><span style=\" font-size:10pt; color:#353535;\"> "
        + builtOnLine( qtr( "Built on VLC media player %1" ), QString::fromUtf8( VERSION_MESSAGE ) ).toHtmlEscaped()
        + "</span></p></body></html>");
    version->hide();

    logo->setPixmap( appIcon().pixmap( 256, 256 ) );

    /* licence of the bundled Inter font, after the GPL text */
    QFile ofl( QStringLiteral( ":/redesign/fonts/OFL.txt" ) );
    if( ofl.open( QIODevice::ReadOnly ) )
        licensePage->setText( licensePage->toPlainText() + QStringLiteral( "\n\n----\nInter font\n\n" )
                              + QString::fromUtf8( ofl.readAll() ) );
}

} // namespace redesign
