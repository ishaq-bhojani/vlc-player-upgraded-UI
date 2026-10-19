/*****************************************************************************
 * Copyright (C) 2026 VLC Reborn contributors
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
#include "branding.hpp"

#include "qt.hpp" // qtr()

#include <QChar>
#include <QFile>
#include <QLabel>
#include <QTextEdit>

namespace redesign
{

void applyAboutBranding(QLabel* title, QLabel* description, QTextEdit* licensePage)
{
    /* built on VLC, link to the source, credit of the bundled font */
    description->setText("<html><head/><body>" +
        qtr( "<p>%1 is built on <a href=\"https://www.videolan.org/vlc/\"><span style=\" text-decoration: underline; color:#0057ae;\">VLC media player</span></a>, a free and open source media player made by the volunteers of the <a href=\"https://www.videolan.org/\"><span style=\" text-decoration: underline; color:#0057ae;\">VideoLAN</span></a> community.</p>"
             "<p>Source code: <a href=\"%2\"><span style=\" text-decoration: underline; color:#0057ae;\">%2</span></a></p>"
             "<p>The interface uses the Inter font (SIL Open Font License 1.1, see License).</p>" )
            .arg( productName(), productWebsite() ) +
        "</body> </html>");
    title->setText("<html><head/><body><p><span style=\" font-size:26pt; color:#353535;\"> " + productName()
        + " </span><span style=\" font-size:12pt; color:#353535;\">" + QChar( 0x2014 ) + " " + qtr( "built on VLC" )
        + "</span></p></body></html>");

    /* licence of the bundled Inter font, after the GPL text */
    QFile ofl( QStringLiteral( ":/redesign/fonts/OFL.txt" ) );
    if( ofl.open( QIODevice::ReadOnly ) )
        licensePage->setText( licensePage->toPlainText() + QStringLiteral( "\n\n----\nInter font\n\n" )
                              + QString::fromUtf8( ofl.readAll() ) );
}

} // namespace redesign
