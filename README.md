# TLS - 漢學文典
[![Build Status](https://travis-ci.com/tls-kr/tls-app.svg?branch=master)](https://travis-ci.com/tls-kr/tls-app)
<img src="icon.png" align="left" width="30%"/>

This is the [eXist-db](https://www.exist-db.org) application for presenting the *Thesaurus Linguae Sinicae (TLS)* -an Historical and Comparative Encyclopaedia of Chinese Conceptual Schemes on the Web.

Editors:
-   General: Christoph Harbsmeier 何莫邪
-   Associate: Jiang Shaoyu 蔣紹愚

## Requirements
*   [exist-db](http://exist-db.org/exist/apps/homepage/index.html) version: `3.6.1` or greater
*   [tls-data] version: `0.8.0`
*   [tls-texts] version: `0.7.0`
*   [ant](http://ant.apache.org) version: `1.10.5` \(for building from source\)

Note:  The data repositories are currently private.  We plan to make them public in due time.

## Building and Installation
1.  Download, fork or clone this GitHub repository, e.g:
    ```bash
    git clone https://github.com/tls-kr/tls-data.git
    ```
2.  Navigate to the repository you just cloned, and call `ant`:   
    ```bash
    cd tls-app
    ant
    ```

    You should see `BUILD SUCCESSFUL`, and two `.xar` files inside the `build/` folder.

    1.  There are two default build targets in `build.xml`:
        *   `dev` includes *all* files, and unoptmized frontend dependencies. For development work.
        *   `prod` is the official release. It only contains optimized files for the production server.
4.  Open the [dashboard](http://localhost:8080/exist/apps/dashboard/index.html) of your exist-db instance and click on `package manager`.
    1.  Click on the `add package` symbol in the upper left corner and select **one of the two** `.xar` files you just created.  



## Data Packages
As noted under requirements above. The full *TLS* app depends on two further data packages:
-   tls-data:  The lexical part of the database, including attributions and translations,
-   tls-texts: The source texts.

The app in in this repository will attempt to download and install these apps when following the installation procedure. If for any reasons the data-apps are unavailable, the installation process will be aborted. You can find out more about the contents of the data packages by following the links above.

## Upgrading eXist-db on the TLS server

The current server runs eXist-db 6.4.0 on Java 8 from `/data/tls-exist`.
Its systemd unit is `/etc/systemd/system/exist-db.service`, with service
settings in `/data/etc/exist-db.env`. The ORCID filter is a separate JAR in
`etc/webapp/WEB-INF/lib/`; it is not part of the TLS `.xar` package.

For a routine production upgrade, first evaluate a stable 6.x release. As of
November 2026, 6.4.1 is the latest stable release listed by eXist-db. The 7.0
releases are beta and require Java 21 and Jetty 12, with other breaking changes;
test those separately before considering a production move. See the
[release list](https://github.com/eXist-db/exist/releases) and the
[7.0 beta notes](https://github.com/eXist-db/exist/releases/tag/eXist-7.0.0-beta5).
Changing the Java executable alone does not upgrade eXist-db.

1. Read the target release notes for Java requirements, database binary
   compatibility, and package changes. Take a **full server-side `/db` backup**
   on the current version and inspect its report. Also copy the current
   `etc/conf.xml`, Jetty and webapp configuration, the systemd unit and
   environment file, the ORCID link file named by `TLS_ORCID_LINKS_PATH`, and
   any TLS deployment scripts. Keep the backup and old installation intact.
2. Install the target eXist-db version in a **new directory**, using the Java
   version required by that release. Set up a separate data directory and
   different HTTP ports for a parallel test. Restore the full backup into this
   test instance. Only reuse raw database files if the target release notes
   explicitly say the versions are binary compatible; otherwise perform a full
   backup/restore migration. See eXist-db's
   [upgrade guide](https://exist-db.org/exist/apps/doc/upgrading) and
   [backup guide](https://exist-db.org/exist/apps/doc/backup).
3. Reapply local configuration to the new installation deliberately; do not
   copy the entire old `etc/` directory over it. Reinstall or verify the TLS
   app, `tls-data`, `tls-texts`, and other required packages. Rebuild the
   [ORCID extension](server-extension/README.md) against the **new** eXist-db
   libraries, install its JAR and filter mapping, and supply its environment
   variables and preserved link file. Its use of eXist-db internal session APIs
   requires a functional check on every eXist-db upgrade.
4. On the test instance, check startup logs, package availability, guest and
   password login, reading and editing as a `tls-user`, ORCID first login and
   existing-account linking, logout, API routes, and scheduled jobs. Check
   that the ORCID redirect URI registered with ORCID matches the test URL.
5. For cutover, take a fresh full backup after writes have stopped, restore it
   to the validated new instance, then change the systemd service and reverse
   proxy to the new installation. Restart and repeat the smoke checks. Keep the
   old instance and its data untouched until the new one is confirmed; rollback
   means routing back to that old instance. Changes written after cutover would
   need a separate export before rolling back.

## Memo
A xquery script 'stat.xql' in modules can be used to create a report of the content of the database. It can be executed with a cron job, to automate this action. For this to work, the following has to be added to the exist conf.xml file:
        ```<job type="user"
             xquery="/db/apps/tls-app/modules/stat.xql"
             cron-trigger="0 5 0/12 * * ?">
        </job>```

This will execute the module five minutes past noon and midnight. It will be
executed with the "guest" user identity, so the permission bits here have to be
set to "setuid" and "execute".
