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
#ifndef VLC_QT_REDESIGN_CURRENTMEDIAFAVORITE_HPP
#define VLC_QT_REDESIGN_CURRENTMEDIAFAVORITE_HPP

#include <functional>
#include <memory>
#include <optional>

#include <QObject>
#include <QString>

/**
 * Where the favorite flag of a media lives (the media library in the app, an
 * in-memory table in the tests).
 *
 * Both calls are asynchronous: `done` is called on the Qt thread (the thread
 * of the CurrentMediaFavorite that owns the backend), possibly before the call
 * returns. A backend must not call `done` anymore once it is destroyed.
 */
class FavoriteBackend
{
public:
    virtual ~FavoriteBackend() = default;

    /** `done(nullopt)`: the media is not in the library; otherwise its favorite flag. */
    virtual void lookup(const QString& mrl, std::function<void(std::optional<bool>)> done) = 0;
    virtual void set(const QString& mrl, bool favorite, std::function<void(bool ok)> done) = 0;
};

/**
 * Favorite state of one media (the current one of the player), for the
 * Favorite control-bar item.
 */
class CurrentMediaFavorite : public QObject
{
    Q_OBJECT

    Q_PROPERTY(QString mrl READ mrl WRITE setMrl NOTIFY mrlChanged FINAL)
    //! false when the media is not in the library, there is no library, or the mrl is empty
    Q_PROPERTY(bool available READ available NOTIFY stateChanged FINAL)
    Q_PROPERTY(bool favorite READ favorite NOTIFY stateChanged FINAL)

public:
    using BackendFactory = std::function<std::unique_ptr<FavoriteBackend>()>;

    /**
     * Backend given to every CurrentMediaFavorite created afterwards (the
     * media library one, installed by MainUI when the interface has a
     * library). An empty factory means no backend: nothing is available.
     */
    static void setDefaultBackendFactory(BackendFactory factory);

    explicit CurrentMediaFavorite(QObject* parent = nullptr);

    void setBackend(std::unique_ptr<FavoriteBackend> backend);

    QString mrl() const { return m_mrl; }
    void setMrl(const QString& mrl);

    bool available() const { return m_available; }
    bool favorite() const { return m_favorite; }

    /** Flips the flag at once and reverts it when the backend reports a failure. No-op when !available. */
    Q_INVOKABLE void toggle();

signals:
    void mrlChanged();
    void stateChanged();

private:
    void refresh();
    void setState(bool available, bool favorite);

    std::unique_ptr<FavoriteBackend> m_backend;
    QString m_mrl;
    bool m_available = false;
    bool m_favorite = false;
    bool m_setPending = false;
    // bumped whenever answers still in flight become stale (mrl or backend changed)
    quint64 m_generation = 0;
};

#endif
