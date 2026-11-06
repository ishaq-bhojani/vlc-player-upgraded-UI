# Vireo privacy policy

*Last updated: 6 November 2026*

Vireo is a media player that runs on your computer. It has no accounts, no advertising, no
analytics and no telemetry. The Vireo project does not run any server, so it never receives
information about you or about what you watch or listen to.

## What stays on your computer

Your settings, your media library (the folders you add, titles, thumbnails, play history and
playback positions), recently played items and lyrics files are stored only on your computer:
in `%APPDATA%\vireo`, or in the `portable` folder of the portable version. Uninstalling Vireo
with "Delete preferences and cache" selected removes them.

Vireo does not send crash reports.

## When Vireo connects to the internet

Vireo connects to other computers only in the cases below. Each one sends your IP address and
the usual technical details of a network request (such as the program name and version) to the
service it contacts. That service's own privacy policy applies.

| Feature | What is contacted | When | How to turn it off |
|---|---|---|---|
| **Update check** | GitHub (`github.com` and its download servers), to read the latest version number of Vireo | Every 3 days, when the update notification is on (it is on unless you turn it off in the introduction) | Settings › General › *Activate the updates availability notification* |
| **Downloading an update** | GitHub, to download the installer | Only when you accept an update | Do not accept the update |
| **Cover art and track information** | MusicBrainz, Last.fm, Google Images and similar services, with the title or artist of the item | Only if you allow metadata network access (off by default) | Settings › Privacy |
| **Media you open from the network** | The website, stream or server whose address you open | When you play it | Do not open network media |
| **Website links** (YouTube and similar) | GitHub, once, to download the open-source tools yt-dlp and ffmpeg; then the website you open | Only after you agree in a dialog | Answer "Not now", or turn it off in Settings › Network |
| **Local network discovery** | Devices and media servers on your local network (UPnP, mDNS and SAP), and Chromecast devices when you look for one to cast to | While Vireo is running, so that they appear on the Network page. These messages stay on your local network | Not yet configurable in Settings |
| **Optional extensions and services** | For example OpenSubtitles (subtitle search extension) or Jamendo (free music service) | Only when you start that extension or service | Do not use it |
| **Add-ons catalogue** | VideoLAN's add-ons server (`api-addons.videolan.org`), to list add-ons | Only if you open the add-ons manager | Do not open it |

Vireo does not include any third-party tracking or advertising code.

## Children

Vireo does not collect personal information from anyone, including children.

## Changes

If Vireo's behaviour changes, this page is updated and the date at the top changes. The history
of this file is public in the repository.

## Contact

Questions about privacy: open an issue at
<https://github.com/ishaq-bhojani/vlc-player-upgraded-UI/issues>.
