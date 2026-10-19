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

#include <atomic>
#include <chrono>
#include <memory>
#include <thread>

#include <QCryptographicHash>
#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSettings>
#include <QSignalSpy>
#include <QTemporaryDir>
#include <QTest>

#include <private/qzipwriter_p.h>

#include "../redesign/cpp/toolmanager.hpp"

namespace
{

QByteArray sha256Hex(const QByteArray& data)
{
    return QCryptographicHash::hash(data, QCryptographicHash::Sha256).toHex();
}

//! shared state of a FakeFetcher: the test keeps it after the manager took the fetcher
struct FakeState
{
    QByteArray payload;
    bool fail = false;
    std::atomic_int fetches{0};
    std::atomic_bool hold{false}; //!< a fetch blocks while this is set (or until it is cancelled)
    std::atomic_bool aborted{false};
    QString lastUrl;
};

class FakeFetcher final : public ToolFetcher
{
public:
    explicit FakeFetcher(std::shared_ptr<FakeState> state) : m_state(std::move(state)) {}

    bool fetch(const QString& url, QIODevice* out, std::function<void(qint64, qint64)> progress,
               std::atomic_bool& cancel, QString* error) override
    {
        m_state->lastUrl = url;
        ++m_state->fetches;
        while (m_state->hold && !cancel)
            std::this_thread::sleep_for(std::chrono::milliseconds(5));
        if (cancel) {
            *error = QStringLiteral("cancelled");
            return false;
        }
        if (m_state->fail) {
            *error = QStringLiteral("server unreachable");
            return false;
        }
        const qint64 half = m_state->payload.size() / 2;
        out->write(m_state->payload.constData(), half);
        progress(half, m_state->payload.size());
        out->write(m_state->payload.constData() + half, m_state->payload.size() - half);
        progress(m_state->payload.size(), m_state->payload.size());
        return true;
    }

    void abortAll() override { m_state->aborted = true; }

private:
    std::shared_ptr<FakeState> m_state;
};

QStringList filesBelow(const QString& dir)
{
    QStringList files;
    QDirIterator it(dir, QDir::Files | QDir::Hidden, QDirIterator::Subdirectories);
    while (it.hasNext())
        files << it.next();
    return files;
}

QByteArray makeZip(const QString& file, const QList<QPair<QString, QByteArray>>& entries)
{
    {
        QZipWriter zip(file);
        for (const auto& entry : entries)
            zip.addFile(entry.first, entry.second);
        zip.close();
    }
    QFile f(file);
    if (!f.open(QIODevice::ReadOnly))
        return {};
    return f.readAll();
}

} // anonymous namespace

class TestToolManager : public QObject
{
    Q_OBJECT

private:
    ToolEntry entryFor(const QByteArray& payload, const QString& archive = QString()) const
    {
        ToolEntry e;
        e.name = QStringLiteral("tool");
        e.version = QStringLiteral("1.0");
        e.url = QStringLiteral("https://example.test/releases/download/1.0/tool.exe");
        e.sha256 = QString::fromLatin1(sha256Hex(payload));
        e.exe = QStringLiteral("tool.exe");
        e.archive = archive;
        e.size = payload.size();
        return e;
    }

    //! a manager in the temporary directory; the tools directory is <user>/vlc-reborn/tools
    std::unique_ptr<ToolManager> makeManager(const QList<ToolEntry>& tools, const std::shared_ptr<FakeState>& state,
                                             bool consent = true)
    {
        auto manager = std::make_unique<ToolManager>(toolsRoot(), tools, std::make_unique<FakeFetcher>(state),
                                                     m_settings.get());
        manager->setConsentGiven(consent);
        return manager;
    }

    QString userDir() const { return m_dir->path() + QStringLiteral("/user"); }
    QString toolsRoot() const { return userDir() + QStringLiteral("/vlc-reborn/tools"); }
    QString settingsFile() const { return m_dir->filePath(QStringLiteral("settings.ini")); }

private slots:
    void init()
    {
        m_dir = std::make_unique<QTemporaryDir>();
        QVERIFY(m_dir->isValid());
        m_settings = std::make_unique<QSettings>(settingsFile(), QSettings::IniFormat);
    }

    void cleanup()
    {
        m_settings.reset();
        m_dir.reset();
    }

    // ---- manifest

    void parseManifest_accepts_valid()
    {
        const QByteArray json = "{\"version\":1,\"tools\":["
            "            {\"name\":\"yt-dlp\",\"version\":\"2026.08.19\",\"url\":\"https://github.com/yt-dlp/yt-dlp/releases/download/2026.08.19/yt-dlp.exe\","
            "             \"sha256\":\"66674953fe251b89f4d08c5f0e35e0728679bd67ab3d7d05c0562af101dd3e7a\",\"size\":17840399,\"exe\":\"yt-dlp.exe\"},"
            "            {\"name\":\"ffmpeg\",\"version\":\"b1\",\"url\":\"https://example.test/dl/b1/ffmpeg.zip\","
            "             \"sha256\":\"19852763398AD0A56F9C763C96E0CB7706BEC68994B33C77786451B9CC5CEE98\",\"archive\":\"zip\",\"exe\":\"ffmpeg.exe\"}]}";
        QString error;
        const auto tools = ToolManager::parseManifest(json, &error);
        QVERIFY2(tools.has_value(), qPrintable(error));
        QCOMPARE(tools->size(), 2);
        QCOMPARE(tools->at(0).name, QStringLiteral("yt-dlp"));
        QCOMPARE(tools->at(0).size, qint64(17840399));
        QCOMPARE(tools->at(1).archive, QStringLiteral("zip"));
        // digests are normalised to lower case
        QCOMPARE(tools->at(1).sha256, QStringLiteral("19852763398ad0a56f9c763c96e0cb7706bec68994b33c77786451b9cc5cee98"));
    }

    void parseManifest_rejects_data()
    {
        QTest::addColumn<QString>("url");
        QTest::addColumn<QString>("digest");
        QTest::addColumn<QString>("name");
        QTest::addColumn<QString>("exe");

        const QString good = QStringLiteral("https://example.test/dl/1.0/tool.exe");
        const QString digest = QString::fromLatin1(sha256Hex("abc"));

        QTest::newRow("latest") << QStringLiteral("https://github.com/o/r/releases/latest/download/tool.exe")
                                << digest << QStringLiteral("tool") << QStringLiteral("tool.exe");
        QTest::newRow("63 hex digits") << good << digest.left(63) << QStringLiteral("tool") << QStringLiteral("tool.exe");
        QTest::newRow("65 hex digits") << good << (digest + QLatin1Char('0')) << QStringLiteral("tool") << QStringLiteral("tool.exe");
        QTest::newRow("non hex digest") << good << (QStringLiteral("g") + digest.mid(1)) << QStringLiteral("tool") << QStringLiteral("tool.exe");
        QTest::newRow("http") << QStringLiteral("http://example.test/dl/1.0/tool.exe") << digest
                              << QStringLiteral("tool") << QStringLiteral("tool.exe");
        QTest::newRow("file") << QStringLiteral("file:///C:/tool.exe") << digest << QStringLiteral("tool") << QStringLiteral("tool.exe");
        QTest::newRow("no host") << QStringLiteral("https:///tool.exe") << digest << QStringLiteral("tool") << QStringLiteral("tool.exe");
        QTest::newRow("name with path") << good << digest << QStringLiteral("../evil") << QStringLiteral("tool.exe");
        QTest::newRow("exe with path") << good << digest << QStringLiteral("tool") << QStringLiteral("bin/tool.exe");
    }

    void parseManifest_rejects()
    {
        QFETCH(QString, url);
        QFETCH(QString, digest);
        QFETCH(QString, name);
        QFETCH(QString, exe);

        QJsonObject tool;
        tool[QStringLiteral("name")] = name;
        tool[QStringLiteral("version")] = QStringLiteral("1.0");
        tool[QStringLiteral("url")] = url;
        tool[QStringLiteral("sha256")] = digest;
        tool[QStringLiteral("exe")] = exe;
        QJsonObject root;
        root[QStringLiteral("version")] = 1;
        root[QStringLiteral("tools")] = QJsonArray{tool};

        QString error;
        const auto tools = ToolManager::parseManifest(QJsonDocument(root).toJson(), &error);
        QVERIFY(!tools.has_value());
        QVERIFY(!error.isEmpty());
    }

    void parseManifest_rejects_structure()
    {
        QString error;
        QVERIFY(!ToolManager::parseManifest("not json", &error).has_value());
        QVERIFY(!ToolManager::parseManifest("{\"version\":2,\"tools\":[]}", &error).has_value());
        QVERIFY(!ToolManager::parseManifest("{\"version\":1,\"tools\":[]}", &error).has_value());
        QVERIFY(!ToolManager::parseManifest("{\"version\":1}", &error).has_value());
        // an unknown archive type
        QVERIFY(!ToolManager::parseManifest("{\"version\":1,\"tools\":[{\"name\":\"t\",\"version\":\"1\",\"url\":\"https://e.test/t.7z\","
            "            \"sha256\":\"ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad\",\"archive\":\"7z\",\"exe\":\"t.exe\"}]}",
            &error).has_value());
    }

    //! the manifest compiled into the build passes the same validation
    void bundledManifest_is_valid()
    {
        const QList<ToolEntry> tools = ToolManager::bundledManifest();
        QCOMPARE(tools.size(), 2);
        QCOMPARE(tools.at(0).name, QStringLiteral("yt-dlp"));
        QCOMPARE(tools.at(1).name, QStringLiteral("ffmpeg"));
        QCOMPARE(tools.at(1).archive, QStringLiteral("zip"));
        for (const auto& tool : tools) {
            QVERIFY(tool.size > 0);
            QVERIFY(tool.url.startsWith(QLatin1String("https://github.com/")));
        }
    }

    // ---- verifySha256

    void verifySha256_data()
    {
        QTest::addColumn<QByteArray>("content");
        QTest::addColumn<QByteArray>("digest");
        QTest::addColumn<bool>("expected");

        const QByteArray abc = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad";
        QTest::newRow("abc") << QByteArray("abc") << abc << true;
        QTest::newRow("abc, upper case digest") << QByteArray("abc") << abc.toUpper() << true;
        QTest::newRow("one byte changed") << QByteArray("abd") << abc << false;
        QTest::newRow("empty file") << QByteArray() << abc << false;
        QTest::newRow("short digest") << QByteArray("abc") << abc.left(63) << false;
    }

    void verifySha256()
    {
        QFETCH(QByteArray, content);
        QFETCH(QByteArray, digest);
        QFETCH(bool, expected);

        const QString file = m_dir->filePath(QStringLiteral("f.bin"));
        QFile f(file);
        QVERIFY(f.open(QIODevice::WriteOnly));
        f.write(content);
        f.close();
        QCOMPARE(ToolManager::verifySha256(file, digest), expected);
    }

    void verifySha256_missing_file()
    {
        QVERIFY(!ToolManager::verifySha256(m_dir->filePath(QStringLiteral("nope")),
                                           "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"));
    }

    // ---- ensure

    void ensure_without_consent_does_nothing()
    {
        auto state = std::make_shared<FakeState>();
        state->payload = "payload";
        auto manager = makeManager({entryFor(state->payload)}, state, false);
        QSignalSpy ready(manager.get(), &ToolManager::ready);
        QSignalSpy failed(manager.get(), &ToolManager::failed);
        QSignalSpy needed(manager.get(), &ToolManager::consentRequired);

        manager->ensure(QStringLiteral("tool"));
        QTest::qWait(100);

        QCOMPARE(state->fetches.load(), 0);
        QCOMPARE(ready.count(), 0);
        QCOMPARE(failed.count(), 0);
        QCOMPARE(needed.count(), 1);
        QVERIFY(!manager->busy(QStringLiteral("tool")));
        QVERIFY(manager->path(QStringLiteral("tool")).isEmpty());
        QVERIFY(!QFileInfo::exists(userDir()));
    }

    void ensure_checksum_mismatch_fails_and_leaves_nothing()
    {
        auto state = std::make_shared<FakeState>();
        state->payload = "tampered payload";
        ToolEntry entry = entryFor("the expected payload");
        entry.size = 0; // the size check has its own test
        auto manager = makeManager({entry}, state);
        QSignalSpy ready(manager.get(), &ToolManager::ready);
        QSignalSpy failed(manager.get(), &ToolManager::failed);

        manager->ensure(QStringLiteral("tool"));
        QTRY_VERIFY_WITH_TIMEOUT(ready.count() + failed.count() > 0, 10000);

        QCOMPARE(ready.count(), 0);
        QCOMPARE(failed.count(), 1);
        QCOMPARE(failed.first().at(0).toString(), QStringLiteral("tool"));
        QVERIFY(!failed.first().at(1).toString().isEmpty());
        QCOMPARE(state->fetches.load(), 1);
        QVERIFY(manager->path(QStringLiteral("tool")).isEmpty());
        QVERIFY(!manager->busy(QStringLiteral("tool")));
        // not a file in the tools directory, nor a leftover temporary download beside it
        QVERIFY2(filesBelow(userDir()).isEmpty(), qPrintable(filesBelow(userDir()).join(QLatin1Char(','))));
        QVERIFY(!QDir(toolsRoot()).exists() || QDir(toolsRoot()).isEmpty());
    }

    void ensure_matching_payload_installs()
    {
        auto state = std::make_shared<FakeState>();
        state->payload = "#!executable bytes " + QByteArray(100000, 'x');
        auto manager = makeManager({entryFor(state->payload)}, state);
        QSignalSpy ready(manager.get(), &ToolManager::ready);
        QSignalSpy failed(manager.get(), &ToolManager::failed);
        QSignalSpy progress(manager.get(), &ToolManager::progress);

        QVERIFY(manager->path(QStringLiteral("tool")).isEmpty());
        manager->ensure(QStringLiteral("tool"));
        QTRY_VERIFY_WITH_TIMEOUT(ready.count() + failed.count() > 0, 10000);

        QCOMPARE(failed.count(), 0);
        QCOMPARE(ready.count(), 1);
        QCOMPARE(ready.first().at(0).toString(), QStringLiteral("tool"));
        QCOMPARE(state->lastUrl, QStringLiteral("https://example.test/releases/download/1.0/tool.exe"));

        const QString path = manager->path(QStringLiteral("tool"));
        QVERIFY(!path.isEmpty());
        QVERIFY(QFileInfo(path).isAbsolute());
        QVERIFY(path.startsWith(toolsRoot() + QLatin1String("/tool-1.0/")));
        QCOMPARE(QFileInfo(path).fileName(), QStringLiteral("tool.exe"));
        QFile f(path);
        QVERIFY(f.open(QIODevice::ReadOnly));
        QCOMPARE(f.readAll(), state->payload);
        f.close();

        // the last progress event reports the whole download
        QVERIFY(progress.count() >= 1);
        QCOMPARE(progress.last().at(0).toString(), QStringLiteral("tool"));
        QCOMPARE(progress.last().at(1).toLongLong(), qint64(state->payload.size()));
        QCOMPARE(progress.last().at(2).toLongLong(), qint64(state->payload.size()));

        // only the executable and its record below the user directory, no temporary download left
        QCOMPARE(filesBelow(userDir()).size(), 2);
        QVERIFY(QDir(userDir() + QStringLiteral("/vlc-reborn")).entryList(QStringList{QStringLiteral("tools-tmp-*")}).isEmpty());

        // installed: ready at once, no second download
        manager->ensure(QStringLiteral("tool"));
        QCOMPARE(ready.count(), 2);
        QCOMPARE(state->fetches.load(), 1);
    }

    //! a file that was replaced or truncated after the installation is not reported
    void path_detects_tampering()
    {
        auto state = std::make_shared<FakeState>();
        state->payload = "good executable";
        auto manager = makeManager({entryFor(state->payload)}, state);
        QSignalSpy ready(manager.get(), &ToolManager::ready);
        QSignalSpy failed(manager.get(), &ToolManager::failed);
        manager->ensure(QStringLiteral("tool"));
        QTRY_VERIFY_WITH_TIMEOUT(ready.count() + failed.count() > 0, 10000);

        const QString path = manager->path(QStringLiteral("tool"));
        QVERIFY(!path.isEmpty());
        QFile f(path);
        QVERIFY(f.open(QIODevice::Append));
        f.write("extra");
        f.close();
        QVERIFY(manager->path(QStringLiteral("tool")).isEmpty());

        // and the next ensure() installs it again
        manager->ensure(QStringLiteral("tool"));
        QTRY_COMPARE_WITH_TIMEOUT(ready.count(), 2, 10000);
        QCOMPARE(state->fetches.load(), 2);
        QVERIFY(!manager->path(QStringLiteral("tool")).isEmpty());
    }

    void ensure_coalesces_concurrent_calls()
    {
        auto state = std::make_shared<FakeState>();
        state->payload = "slow executable";
        state->hold = true;
        auto manager = makeManager({entryFor(state->payload)}, state);
        QSignalSpy ready(manager.get(), &ToolManager::ready);
        QSignalSpy failed(manager.get(), &ToolManager::failed);

        manager->ensure(QStringLiteral("tool"));
        QVERIFY(manager->busy(QStringLiteral("tool")));
        manager->ensure(QStringLiteral("tool"));
        manager->ensure(QStringLiteral("tool"));
        QTest::qWait(50);
        state->hold = false;
        QTRY_VERIFY_WITH_TIMEOUT(ready.count() + failed.count() > 0, 10000);
        QTest::qWait(50);

        QCOMPARE(state->fetches.load(), 1);
        QCOMPARE(ready.count(), 1);
        QCOMPARE(failed.count(), 0);
        QVERIFY(!manager->busy(QStringLiteral("tool")));
    }

    void ensure_fetch_failure_is_reported()
    {
        auto state = std::make_shared<FakeState>();
        state->payload = "x";
        state->fail = true;
        auto manager = makeManager({entryFor(state->payload)}, state);
        QSignalSpy ready(manager.get(), &ToolManager::ready);
        QSignalSpy failed(manager.get(), &ToolManager::failed);

        manager->ensure(QStringLiteral("tool"));
        QTRY_VERIFY_WITH_TIMEOUT(ready.count() + failed.count() > 0, 10000);

        QCOMPARE(failed.count(), 1);
        QCOMPARE(failed.first().at(1).toString(), QStringLiteral("server unreachable"));
        QVERIFY(filesBelow(userDir()).isEmpty());
    }

    void ensure_rejects_oversized_download()
    {
        auto state = std::make_shared<FakeState>();
        state->payload = QByteArray(5000, 'x');
        ToolEntry entry = entryFor(state->payload);
        entry.size = 1000; // the manifest pins a smaller size
        auto manager = makeManager({entry}, state);
        QSignalSpy ready(manager.get(), &ToolManager::ready);
        QSignalSpy failed(manager.get(), &ToolManager::failed);

        manager->ensure(QStringLiteral("tool"));
        QTRY_VERIFY_WITH_TIMEOUT(ready.count() + failed.count() > 0, 10000);

        QCOMPARE(ready.count(), 0);
        QCOMPARE(failed.count(), 1);
        QVERIFY(manager->path(QStringLiteral("tool")).isEmpty());
        QVERIFY(filesBelow(userDir()).isEmpty());
    }

    void cancel_stops_the_download()
    {
        auto state = std::make_shared<FakeState>();
        state->payload = "slow";
        state->hold = true;
        auto manager = makeManager({entryFor(state->payload)}, state);
        QSignalSpy ready(manager.get(), &ToolManager::ready);
        QSignalSpy failed(manager.get(), &ToolManager::failed);

        manager->ensure(QStringLiteral("tool"));
        QTRY_VERIFY_WITH_TIMEOUT(state->fetches.load() == 1, 5000);
        manager->cancel(QStringLiteral("tool"));
        QTRY_VERIFY_WITH_TIMEOUT(ready.count() + failed.count() > 0, 10000);

        QCOMPARE(ready.count(), 0);
        QCOMPARE(failed.count(), 1);
        QVERIFY(state->aborted);
        QVERIFY(filesBelow(userDir()).isEmpty());
    }

    void destroying_the_manager_cancels_a_running_download()
    {
        auto state = std::make_shared<FakeState>();
        state->payload = "slow";
        state->hold = true;
        auto manager = makeManager({entryFor(state->payload)}, state);
        manager->ensure(QStringLiteral("tool"));
        QTRY_VERIFY_WITH_TIMEOUT(state->fetches.load() == 1, 5000);
        manager.reset(); // must not hang nor crash
        QVERIFY(filesBelow(userDir()).isEmpty());
    }

    void ensure_unknown_tool_fails()
    {
        auto state = std::make_shared<FakeState>();
        auto manager = makeManager({entryFor("x")}, state);
        QSignalSpy failed(manager.get(), &ToolManager::failed);
        manager->ensure(QStringLiteral("nope"));
        QCOMPARE(failed.count(), 1);
        QCOMPARE(state->fetches.load(), 0);
        QVERIFY(manager->path(QStringLiteral("nope")).isEmpty());
    }

    //! the manager refuses a non-https url by itself, whatever the manifest says
    void ensure_refuses_http()
    {
        auto state = std::make_shared<FakeState>();
        state->payload = "x";
        ToolEntry entry = entryFor(state->payload);
        entry.url = QStringLiteral("http://example.test/tool.exe");
        auto manager = makeManager({entry}, state);
        QSignalSpy failed(manager.get(), &ToolManager::failed);
        manager->ensure(QStringLiteral("tool"));
        QCOMPARE(failed.count(), 1);
        QCOMPARE(state->fetches.load(), 0);
    }

    // ---- zip archive (ffmpeg)

    void ensure_extracts_the_exe_of_a_zip()
    {
        const QByteArray exe = "MZ fake ffmpeg " + QByteArray(300000, 'f');
        const QByteArray zip = makeZip(m_dir->filePath(QStringLiteral("fixture.zip")), {
            {QStringLiteral("tool-build/LICENSE.txt"), "licence"},
            {QStringLiteral("tool-build/bin/tool.exe"), exe},
            {QStringLiteral("tool-build/bin/toolprobe.exe"), "other"},
            {QStringLiteral("tool-build/doc/tool.exe.txt"), "doc"},
        });
        QVERIFY(!zip.isEmpty());

        auto state = std::make_shared<FakeState>();
        state->payload = zip;
        ToolEntry entry = entryFor(zip, QStringLiteral("zip"));
        entry.exeSha256 = QString::fromLatin1(sha256Hex(exe));
        auto manager = makeManager({entry}, state);
        QSignalSpy ready(manager.get(), &ToolManager::ready);
        QSignalSpy failed(manager.get(), &ToolManager::failed);

        manager->ensure(QStringLiteral("tool"));
        QTRY_VERIFY_WITH_TIMEOUT(ready.count() + failed.count() > 0, 10000);

        QCOMPARE(failed.count(), 0);
        QCOMPARE(ready.count(), 1);
        const QString path = manager->path(QStringLiteral("tool"));
        QVERIFY(!path.isEmpty());
        QFile f(path);
        QVERIFY(f.open(QIODevice::ReadOnly));
        QCOMPARE(f.readAll(), exe);
        // the archive and the other members are gone: the exe and its record
        QCOMPARE(filesBelow(userDir()).size(), 2);
    }

    void ensure_zip_without_the_exe_fails()
    {
        const QByteArray zip = makeZip(m_dir->filePath(QStringLiteral("fixture.zip")), {
            {QStringLiteral("tool-build/bin/other.exe"), "other"},
        });
        auto state = std::make_shared<FakeState>();
        state->payload = zip;
        auto manager = makeManager({entryFor(zip, QStringLiteral("zip"))}, state);
        QSignalSpy ready(manager.get(), &ToolManager::ready);
        QSignalSpy failed(manager.get(), &ToolManager::failed);

        manager->ensure(QStringLiteral("tool"));
        QTRY_VERIFY_WITH_TIMEOUT(ready.count() + failed.count() > 0, 10000);

        QCOMPARE(failed.count(), 1);
        QVERIFY(manager->path(QStringLiteral("tool")).isEmpty());
        // the fixture zip itself is in the temporary directory: look below the user directory only
        QVERIFY(filesBelow(userDir()).isEmpty());
    }

    void ensure_zip_with_wrong_exe_digest_fails()
    {
        const QByteArray zip = makeZip(m_dir->filePath(QStringLiteral("fixture.zip")), {
            {QStringLiteral("tool-build/bin/tool.exe"), "actual exe"},
        });
        auto state = std::make_shared<FakeState>();
        state->payload = zip;
        ToolEntry entry = entryFor(zip, QStringLiteral("zip"));
        entry.exeSha256 = QString::fromLatin1(sha256Hex("another exe"));
        auto manager = makeManager({entry}, state);
        QSignalSpy ready(manager.get(), &ToolManager::ready);
        QSignalSpy failed(manager.get(), &ToolManager::failed);

        manager->ensure(QStringLiteral("tool"));
        QTRY_VERIFY_WITH_TIMEOUT(ready.count() + failed.count() > 0, 10000);

        QCOMPARE(failed.count(), 1);
        QVERIFY(filesBelow(userDir()).isEmpty());
    }

    void ensure_not_a_zip_fails()
    {
        auto state = std::make_shared<FakeState>();
        state->payload = "this is not a zip file";
        auto manager = makeManager({entryFor(state->payload, QStringLiteral("zip"))}, state);
        QSignalSpy ready(manager.get(), &ToolManager::ready);
        QSignalSpy failed(manager.get(), &ToolManager::failed);

        manager->ensure(QStringLiteral("tool"));
        QTRY_VERIFY_WITH_TIMEOUT(ready.count() + failed.count() > 0, 10000);

        QCOMPARE(failed.count(), 1);
        QVERIFY(filesBelow(userDir()).isEmpty());
    }

    // ---- consent

    void consent_is_persisted_in_the_redesign_group()
    {
        auto state = std::make_shared<FakeState>();
        auto manager = makeManager({entryFor("x")}, state, false);
        QVERIFY(!manager->consentGiven());
        QSignalSpy changed(manager.get(), &ToolManager::consentGivenChanged);

        manager->setConsentGiven(true);
        manager->setConsentGiven(true);
        QCOMPARE(changed.count(), 1);
        QVERIFY(manager->consentGiven());

        QSettings reread(settingsFile(), QSettings::IniFormat);
        QVERIFY(reread.value(QStringLiteral("redesign/toolsConsent")).toBool());

        // a new manager on the same settings sees it
        auto second = makeManager({entryFor("x")}, state, true);
        QVERIFY(second->consentGiven());

        manager->setConsentGiven(false);
        QCOMPARE(changed.count(), 2);
        QSettings last(settingsFile(), QSettings::IniFormat);
        QVERIFY(!last.value(QStringLiteral("redesign/toolsConsent")).toBool());
    }

private:
    std::unique_ptr<QTemporaryDir> m_dir;
    std::unique_ptr<QSettings> m_settings;
};

QTEST_GUILESS_MAIN(TestToolManager)
#include "test_tool_manager.moc"
