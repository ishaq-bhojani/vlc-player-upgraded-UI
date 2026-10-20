// Type-load probe for qml-smoke.sh. Tooling only: it is never part of the build
// of VLC; qml-smoke.sh compiles it inside the container and injects it into the
// redesign run of the build-tree vlc with LD_PRELOAD.
//
// What it does: once the Qt interface has registered its QML types (the singleton
// VLC.MainInterface/MainCtx exists), it creates a second QQmlEngine in the same
// process (so VLC.MainInterface, VLC.Style, VLC.Player, VLC.MediaLibrary, ... and
// the C++ types of VLC.Redesign resolve exactly as in the app) and loads every
// file of the VLC.Redesign module, listed in $QML_TYPELOAD_LIST, as a Component.
// Nothing is instantiated; Component.Ready is the pass criterion. Files that are
// loaded lazily in the app (the Settings modal, dialogs, ...) are therefore
// checked although the smoke run never opens them.
//
// A file named in $QML_TYPELOAD_ML_ONLY (one path per line) uses media library
// types, which the Linux image does not register. If it fails and every error is
// about a missing ML* type or the VLC.MediaLibrary module it is reported as
// "skipped-ml"; any other error (a syntax error, an unterminated comment, a
// missing non-ML type) still fails.
//
// Result lines, written to stderr (they end up in the vlc log):
//   TYPELOAD ready <path>
//   TYPELOAD skipped-ml <path>
//   TYPELOAD error <path>: <error> | <error> ...
//   TYPELOAD summary files=N ready=R skipped-ml=S errors=E ms=T
//   TYPELOAD notrun <reason>
//
// The probe only activates in a process whose executable is called "vlc"
// (vlc-qt-check and friends inherit LD_PRELOAD and must be left alone).

#include <QtCore/QCoreApplication>
#include <QtCore/QElapsedTimer>
#include <QtCore/QFile>
#include <QtCore/QRegularExpression>
#include <QtCore/QSet>
#include <QtCore/QStringList>
#include <QtCore/QTimer>
#include <QtCore/QUrl>
#include <QtQml/QQmlComponent>
#include <QtQml/QQmlEngine>
#include <QtQml/qqml.h>

#include <cstdio>
#include <unistd.h>

namespace {

constexpr int kPollMs = 200;
constexpr int kGiveUpMs = 12000;

QStringList readLines(const QByteArray &path)
{
    QStringList out;
    QFile f(QString::fromLocal8Bit(path));
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text))
        return out;
    while (!f.atEnd()) {
        const QString line = QString::fromUtf8(f.readLine()).trimmed();
        if (!line.isEmpty())
            out << line;
    }
    return out;
}

void out(const QString &line)
{
    fprintf(stderr, "%s\n", qPrintable(line));
    fflush(stderr);
}

void runProbe(const QStringList &files, const QSet<QString> &mlOnly)
{
    QElapsedTimer clock;
    clock.start();

    auto *engine = new QQmlEngine; // the app's own import path, see MainUI::setup
    engine->addImportPath(QStringLiteral(":/qt/qml"));

    // What a missing media library looks like: an ML* type (MLFolderModel, ...)
    // that is not registered, or the module itself.
    static const QRegularExpression missing(
        QStringLiteral("^(ML[A-Za-z0-9_]* is not a type|module \"VLC[.]MediaLibrary\" is not installed|Type .+ unavailable)$"));

    int ready = 0, skipped = 0, errors = 0;
    for (const QString &rel : files) {
        const QUrl url(QStringLiteral("qrc:/qt/qml/VLC/Redesign/") + rel);
        QQmlComponent comp(engine, url, QQmlComponent::PreferSynchronous);
        if (comp.status() == QQmlComponent::Ready) {
            ++ready;
            out(QStringLiteral("TYPELOAD ready ") + rel);
            continue;
        }

        QStringList msgs;
        bool allMissing = true;
        const auto errs = comp.errors();
        for (const QQmlError &e : errs) {
            QString u = e.url().toString();
            u.remove(QStringLiteral("qrc:/qt/qml/VLC/Redesign/"));
            msgs << QStringLiteral("%1:%2:%3: %4").arg(u).arg(e.line()).arg(e.column()).arg(e.description());
            if (!missing.match(e.description()).hasMatch())
                allMissing = false;
        }
        if (comp.status() == QQmlComponent::Loading)
            msgs << QStringLiteral("still loading after a synchronous load");
        if (mlOnly.contains(rel) && allMissing && !errs.isEmpty()) {
            ++skipped;
            out(QStringLiteral("TYPELOAD skipped-ml ") + rel);
        } else {
            ++errors;
            out(QStringLiteral("TYPELOAD error ") + rel + QStringLiteral(": ")
                + (msgs.isEmpty() ? QStringLiteral("status ") + QString::number(comp.status()) : msgs.join(QStringLiteral(" | "))));
        }
    }
    out(QStringLiteral("TYPELOAD summary files=%1 ready=%2 skipped-ml=%3 errors=%4 ms=%5")
            .arg(files.size()).arg(ready).arg(skipped).arg(errors).arg(clock.elapsed()));
    delete engine;
}

void start()
{
    char exe[4096];
    const ssize_t n = readlink("/proc/self/exe", exe, sizeof(exe) - 1);
    if (n <= 0)
        return;
    exe[n] = '\0';
    const QByteArray path(exe);
    if (path.mid(path.lastIndexOf('/') + 1) != "vlc")
        return;

    const QByteArray listPath = qgetenv("QML_TYPELOAD_LIST");
    if (listPath.isEmpty())
        return;

    QCoreApplication *app = QCoreApplication::instance();
    if (!app) {
        out(QStringLiteral("TYPELOAD notrun no application object"));
        return;
    }

    auto *timer = new QTimer(app);
    auto *elapsed = new QElapsedTimer;
    elapsed->start();
    QObject::connect(timer, &QTimer::timeout, timer, [timer, elapsed, listPath]() {
        // MainUI::registerQMLTypes registers VLC.MainInterface first and the
        // redesign and media library types in the same call: once MainCtx is
        // known, everything the app registers is there.
        if (qmlTypeId("VLC.MainInterface", 1, 0, "MainCtx") < 0) {
            if (elapsed->elapsed() > kGiveUpMs) {
                out(QStringLiteral("TYPELOAD notrun the interface did not register its QML types within %1 ms").arg(kGiveUpMs));
                timer->stop();
                delete elapsed;
            }
            return;
        }
        timer->stop();
        delete elapsed;
        const QStringList files = readLines(listPath);
        const QStringList ml = readLines(qgetenv("QML_TYPELOAD_ML_ONLY"));
        if (files.isEmpty()) {
            out(QStringLiteral("TYPELOAD notrun empty file list"));
            return;
        }
        runProbe(files, QSet<QString>(ml.begin(), ml.end()));
    });
    timer->start(kPollMs);
}

} // namespace

Q_COREAPP_STARTUP_FUNCTION(start)
