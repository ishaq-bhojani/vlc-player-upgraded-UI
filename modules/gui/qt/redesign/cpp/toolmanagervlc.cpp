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

#include "toolmanagervlc.hpp"

#include <algorithm>
#include <cstdlib>
#include <mutex>
#include <vector>

#include <QIODevice>
#include <QUrl>

#include <vlc_common.h>
#include <vlc_configuration.h>
#include <vlc_interrupt.h>
#include <vlc_stream.h>

namespace redesign
{

namespace
{

class VlcToolFetcher final : public ToolFetcher
{
public:
    explicit VlcToolFetcher(vlc_object_t* obj) : m_obj(obj) {}

    bool fetch(const QString& url, QIODevice* out, std::function<void(qint64, qint64)> progress,
               std::atomic_bool& cancel, QString* error) override
    {
        // checked here as well: the manager checks it, but this class is the one that opens sockets
        const QUrl parsed(url, QUrl::StrictMode);
        if (!parsed.isValid() || parsed.scheme() != QLatin1String("https")) {
            *error = QObject::tr("Only https downloads are allowed.");
            return false;
        }

        // makes the blocking network calls of this thread interruptible by abortAll()
        vlc_interrupt_t* ctx = vlc_interrupt_create();
        if (!ctx) {
            *error = QObject::tr("Out of memory.");
            return false;
        }
        vlc_interrupt_t* previous = vlc_interrupt_set(ctx);
        {
            std::lock_guard<std::mutex> lock(m_mutex);
            m_active.push_back(ctx);
        }

        bool ok = false;
        // cancelled between the flag check of the caller and the registration above
        if (cancel) {
            *error = QObject::tr("The download was cancelled.");
        } else {
            ok = read(parsed, out, progress, cancel, error);
        }

        {
            std::lock_guard<std::mutex> lock(m_mutex);
            m_active.erase(std::remove(m_active.begin(), m_active.end(), ctx), m_active.end());
        }
        vlc_interrupt_set(previous);
        vlc_interrupt_destroy(ctx);
        return ok;
    }

    void abortAll() override
    {
        std::lock_guard<std::mutex> lock(m_mutex);
        for (vlc_interrupt_t* ctx : m_active)
            vlc_interrupt_raise(ctx);
    }

private:
    bool read(const QUrl& url, QIODevice* out, const std::function<void(qint64, qint64)>& progress,
              std::atomic_bool& cancel, QString* error)
    {
        const QByteArray encoded = url.toEncoded();
        stream_t* stream = vlc_stream_NewURL(m_obj, encoded.constData());
        if (!stream) {
            *error = cancel ? QObject::tr("The download was cancelled.")
                            : QObject::tr("The server cannot be reached.");
            return false;
        }

        uint64_t size = 0;
        const qint64 total = vlc_stream_GetSize(stream, &size) == VLC_SUCCESS ? qint64(size) : -1;

        char buffer[64 * 1024];
        qint64 done = 0;
        bool ok = true;
        for (;;) {
            if (cancel) {
                *error = QObject::tr("The download was cancelled.");
                ok = false;
                break;
            }
            const ssize_t got = vlc_stream_Read(stream, buffer, sizeof(buffer));
            if (got < 0) {
                *error = cancel ? QObject::tr("The download was cancelled.")
                                : QObject::tr("The connection was interrupted.");
                ok = false;
                break;
            }
            if (got == 0)
                break;
            if (out->write(buffer, got) != got) {
                *error = QObject::tr("The download could not be written.");
                ok = false;
                break;
            }
            done += got;
            progress(done, total);
        }
        if (ok && total >= 0 && done != total) {
            *error = QObject::tr("The download is incomplete.");
            ok = false;
        }
        if (ok)
            progress(done, done);

        vlc_stream_Delete(stream);
        return ok;
    }

    vlc_object_t* m_obj;
    std::mutex m_mutex;
    std::vector<vlc_interrupt_t*> m_active;
};

} // anonymous namespace

std::unique_ptr<ToolFetcher> makeVlcToolFetcher(vlc_object_t* obj)
{
    return std::make_unique<VlcToolFetcher>(obj);
}

ToolManager* createToolManager(vlc_object_t* obj)
{
    char* userDir = config_GetUserDir(VLC_USERDATA_DIR);
    if (!userDir)
        return nullptr;
    const QString root = QString::fromUtf8(userDir) + QStringLiteral("/vlc-reborn/tools");
    free(userDir);

    return new ToolManager(root, ToolManager::bundledManifest(), makeVlcToolFetcher(obj));
}

} // namespace redesign
