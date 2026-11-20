# ORCID server extension

This filter is needed because eXist-db's bundled persistent-login module can
authenticate local accounts only with a password. The filter exchanges ORCID's
authorization code and creates an authenticated eXist-db HTTP session without
storing or changing an existing user's password. It is built against eXist-db
6.4.0 and uses eXist-db's `SubjectAccreditedImpl` and HTTP session subject slot;
review those APIs before an eXist-db upgrade.

## Build and install

1. Run `bash server-extension/build.sh` with `EXIST_HOME` pointing to the
   eXist-db installation if it is not `/data/tls-exist`. The build targets
   Java 8, matching this server. Verify with
   `javap -verbose -classpath server-extension/build/tls-orcid-filter.jar org.hxwd.tls.OrcidFilter | grep 'major version'`; it must say `52`.
2. Copy `server-extension/build/tls-orcid-filter.jar` to
   `$EXIST_HOME/etc/webapp/WEB-INF/lib/` (create `lib/` if needed). Jetty loads
   webapp filters from this directory. This installation's `startup.xml` has
   an explicit classpath, so placing the JAR in `$EXIST_HOME/lib/` alone causes
   the entire `/exist` webapp to return 503 after the filter is registered.
3. Add this filter to `$EXIST_HOME/etc/webapp/WEB-INF/web.xml` (the webapp
   serving `/exist`) and restart eXist-db:

   ```xml
   <filter>
     <filter-name>tls-orcid</filter-name>
     <filter-class>org.hxwd.tls.OrcidFilter</filter-class>
   </filter>
   <filter-mapping>
     <filter-name>tls-orcid</filter-name>
     <url-pattern>/apps/tls-app/orcid/*</url-pattern>
   </filter-mapping>
   ```

   Put both elements directly under `<web-app>`, before its closing tag. The
   installed JAR alone does not register the filter. If `/orcid/start` returns
   `No route matches pattern: /orcid/start` from Roaster, this mapping is absent
   from the live `web.xml` or eXist-db has not been restarted since adding it.
   Check with `grep -n 'tls-orcid' "$EXIST_HOME/etc/webapp/WEB-INF/web.xml"`.
   A configured filter redirects `/orcid/start` to `sandbox.orcid.org` (or
   `orcid.org` in production), rather than returning a TLS API response.
   A 503 for every `/exist` page after adding the filter indicates that Jetty
   cannot load its class. Move the JAR into `etc/webapp/WEB-INF/lib/` and
   restart. With the current filter build, missing credentials give a 503 only
   on `/orcid/*`, with the missing setting named in the response.

4. Set these environment variables for the eXist-db service before restart:

   - `TLS_ORCID_CLIENT_ID`: ORCID Public API client ID.
   - `TLS_ORCID_CLIENT_SECRET`: matching client secret.
   - `TLS_ORCID_REDIRECT_URI`: exact registered callback URI, such as
     `http://localhost:8088/exist/apps/tls-app/orcid/callback` for sandbox.
   - `TLS_ORCID_ENV=sandbox` for sandbox; omit for production.
   - `TLS_ORCID_LINKS_PATH`: writable private path outside the app package,
     such as `/data/tls-exist/orcid-links.properties`. Back up this file.
     The **parent directory must be writable by the `existdb` service user**:
     the filter creates a temporary file there before atomically replacing
     the links file. Do not point it at `/data/etc/` if that directory is
     root-owned and not writable by `existdb`.

For sandbox testing, create a **separate test ORCID record** at
<https://sandbox.orcid.org/register> and use that record's email and password
on the sandbox sign-in page. Production ORCID records are not present in the
sandbox, and the API client ID/secret are for the server's OAuth exchange, not
for signing in as a researcher. ORCID's sandbox only sends verification and
password-reset email to `@mailinator.com` addresses. See the
[ORCID sandbox guide](https://info.orcid.org/documentation/integration-guide/sandbox-testing-server/).
If the sandbox page itself says "Invalid sign in details" and there is no
`/orcid/callback` request in the eXist-db access log, the TLS callback has not
yet run; first verify that the test record can sign in directly at
<https://sandbox.orcid.org/signin>.
If ORCID instead reports `invalid_request: Invalid parameter: client_id`,
compare the `client_id` in the browser's `/oauth/authorize` URL with the **API
client ID** shown in <https://sandbox.orcid.org/developer-tools>. The sandbox
and production registries issue separate API clients. Set both
`TLS_ORCID_CLIENT_ID` and `TLS_ORCID_CLIENT_SECRET` to the matching sandbox
client pair in the eXist-db service environment, then restart the service.
Also register the exact `TLS_ORCID_REDIRECT_URI` for that sandbox client.
The hostname used to open TLS must match the callback hostname exactly. For
example, when `TLS_ORCID_REDIRECT_URI` starts with `http://127.0.0.1:8088/`,
open TLS at `http://127.0.0.1:8088/exist/apps/tls-app/index.html`, not at
`http://localhost:8088/...`. Browsers do not send a `localhost` session cookie
to `127.0.0.1`, so the callback otherwise fails with HTTP 400 before token
exchange. The filter rejects a mismatched starting hostname with a clear error.

Use an HTTPS callback in production. Never put the client secret in this
repository. The filter creates the link file with private file permissions on
Unix systems; keep its parent directory accessible only to the eXist-db service.

Deploy the TLS app package containing the new login and Settings controls at
the same time as the filter. Register the callback URI in ORCID Developer Tools.
The generated account name is `orcid-` followed by the 16 ORCID digits and is
assigned the existing `tls-user` group. On each ORCID sign-in, the callback
ensures that generated accounts have a `/db/users/<username>` collection owned
by the account, in the `tls-user` group, with mode `rwxrwxr--`. It sets a
missing full name from ORCID's token response, falling back to `ORCID <iD>`.
An existing full name is preserved. If setup fails, the callback returns HTTP
500 before signing in; the next ORCID sign-in retries setup. Existing accounts
can connect their ORCID iD from Settings after signing in with their password.
Disconnecting is available in Settings.

The callback also keeps a read-only ORCID iD record in `/db/orcid-links` for
each linked TLS account. This lets XQuery show the connection after a password
login without reading the private link file. After deploying this change, run
`orcid:sync-links()` once as a DBA to populate records for existing links.
Regular users can call `orcid:current-id()` from `modules/orcid-link.xql`; it
returns their linked iD as a string or the empty sequence. The private link
file remains the login authority.

To delete a generated ORCID test account, run this XQuery as a DBA after
deploying `modules/orcid-link.xql`:

```xquery
import module namespace orcid="http://hxwd.org/orcid"
    at "xmldb:exist:///db/apps/tls-app/modules/orcid-link.xql";
orcid:remove-user("orcid-0000000000000000")
```

The function removes that account's entry from `TLS_ORCID_LINKS_PATH`, its
`/db/users/<username>` collection and contents, and the account itself. It
accepts only generated ORCID usernames and does not delete unrelated account
data elsewhere in the database.

If a first sign-in created an eXist account but failed with an
`AccessDeniedException` while saving the link file, correct
`TLS_ORCID_LINKS_PATH` and restart. Then restore the missing mapping only after
checking the account creation and ORCID iD in the eXist log. The properties
file entry has the form `0000-0000-0000-0000=orcid-0000000000000000`.
Create the file as `existdb` with mode `0600`; preserve any existing entries.
Without this mapping a retry sees the generated username already in use and
returns HTTP 409. Do not delete the account to retry, as it may already own
TLS data.
