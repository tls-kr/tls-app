# TLS - 漢學文典
[![Build Status](https://travis-ci.com/tls-kr/tls-app.svg?branch=master)](https://travis-ci.com/tls-kr/tls-app)
<img src="icon.png" align="left" width="30%"/>

This is the [eXist-db](https://www.exist-db.org) application for presenting the *Thesaurus Linguae Sinicae (TLS)* -an Historical and Comparative Encyclopaedia of Chinese Conceptual Schemes on the Web.

Editors:
-   General: Christoph Harbsmeier 何莫邪
-   Associate: Jiang Shaoyu 蔣紹愚

## Requirements
*   [exist-db](http://exist-db.org/exist/apps/homepage/index.html) version: `3.6.1` or greater
*   [tls-data](https://github.com/tls-kr/tls-data) version: `0.8.0`
*   [tls-texts](https://github.com/tls-kr/tls-texts) version: `0.7.0`
*   [ant](http://ant.apache.org) version: `1.10.5` \(for building from source\)

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

## Memo
A xquery script 'stat.xql' in modules can be used to create a report of the content of the database. It can be executed with a cron job, to automate this action. For this to work, the following has to be added to the exist conf.xml file:
        <job type="user"
             xquery="/db/apps/tls-app/modules/stat.xql"
             cron-trigger="0 5 0/12 * * ?">
        </job>

This will execute the module five minutes past noon and midnight. It will be
executed with the "guest" user identity, so the permission bits here have to be
set to "setuid" and "execute".
