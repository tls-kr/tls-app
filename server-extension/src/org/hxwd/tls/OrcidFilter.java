package org.hxwd.tls;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.exist.security.AbstractAccount;
import org.exist.security.Account;
import org.exist.security.Group;
import org.exist.security.SecurityManager;
import org.exist.security.Subject;
import org.exist.security.internal.SubjectAccreditedImpl;
import org.exist.security.internal.aider.UserAider;
import org.exist.storage.BrokerPool;
import org.exist.storage.DBBroker;
import org.exist.xquery.CompiledXQuery;
import org.exist.xquery.XQueryContext;
import org.exist.xquery.XPathException;
import org.exist.xquery.value.Item;

import javax.servlet.Filter;
import javax.servlet.FilterChain;
import javax.servlet.FilterConfig;
import javax.servlet.ServletException;
import javax.servlet.ServletRequest;
import javax.servlet.ServletResponse;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import javax.servlet.http.HttpSession;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.io.PrintWriter;
import java.net.HttpURLConnection;
import java.net.URL;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardCopyOption;
import java.security.SecureRandom;
import java.security.MessageDigest;
import java.util.Base64;
import java.util.Optional;
import java.util.Properties;

/** ORCID authorization-code callback and eXist-db session bridge. */
public final class OrcidFilter implements Filter {
    private static final String SUBJECT = "_eXist_xmldb_user";
    private static final String STATE = "tls.orcid.state";
    private static final String STARTED = "tls.orcid.started";
    private static final String LINK = "tls.orcid.link-user";
    private static final String PENDING_LINK = "tls.orcid.pending-link";
    private static final String ORCID = "tls.orcid.id";
    private static final String UNLINK_TOKEN = "tls.orcid.unlink-token";
    private static final String ORCID_PATTERN = "[0-9]{4}-[0-9]{4}-[0-9]{4}-[0-9]{3}[0-9X]";
    private static final String SETUP_QUERY = "xquery version \"3.1\"; "
            + "import module namespace orcid=\"http://hxwd.org/orcid\" "
            + "at \"xmldb:exist:///db/apps/tls-app/modules/orcid-link.xql\"; "
            + "declare variable $username external; declare variable $name external; "
            + "orcid:ensure-user($username, $name)";
    private static final String RECORD_QUERY = "xquery version \"3.1\"; "
            + "import module namespace orcid=\"http://hxwd.org/orcid\" "
            + "at \"xmldb:exist:///db/apps/tls-app/modules/orcid-link.xql\"; "
            + "declare variable $username external; declare variable $orcid external; "
            + "orcid:record-link($username, $orcid)";
    private static final String CLEAR_QUERY = "xquery version \"3.1\"; "
            + "import module namespace orcid=\"http://hxwd.org/orcid\" "
            + "at \"xmldb:exist:///db/apps/tls-app/modules/orcid-link.xql\"; "
            + "declare variable $username external; orcid:clear-link($username)";
    private final SecureRandom random = new SecureRandom();
    private final ObjectMapper json = new ObjectMapper();
    private final Object lock = new Object();
    private String clientId;
    private String clientSecret;
    private String redirectUri;
    private String callbackHost;
    private String base;
    private Path linksPath;
    private String configurationError;

    @Override public void init(FilterConfig config) throws ServletException {
        try {
            clientId = required("TLS_ORCID_CLIENT_ID");
            clientSecret = required("TLS_ORCID_CLIENT_SECRET");
            redirectUri = required("TLS_ORCID_REDIRECT_URI");
            try { callbackHost = new URL(redirectUri).getHost(); }
            catch (IOException ex) { throw new ServletException("TLS_ORCID_REDIRECT_URI is invalid"); }
            linksPath = Paths.get(required("TLS_ORCID_LINKS_PATH"));
            Path linksParent = linksPath.toAbsolutePath().getParent();
            if (linksParent == null || !Files.isDirectory(linksParent) || !Files.isWritable(linksParent))
                throw new ServletException("TLS_ORCID_LINKS_PATH parent directory must be writable by eXist-db");
            if (Files.exists(linksPath) && !Files.isWritable(linksPath))
                throw new ServletException("TLS_ORCID_LINKS_PATH file must be writable by eXist-db");
            base = "sandbox".equals(System.getenv("TLS_ORCID_ENV"))
                    ? "https://sandbox.orcid.org" : "https://orcid.org";
            if (!redirectUri.endsWith("/orcid/callback"))
                throw new ServletException("TLS_ORCID_REDIRECT_URI must end in /orcid/callback");
        } catch (ServletException ex) {
            configurationError = ex.getMessage();
            config.getServletContext().log("TLS ORCID disabled: " + configurationError);
        }
    }

    private static String required(String name) throws ServletException {
        String value = System.getenv(name);
        if (value == null || value.trim().isEmpty()) throw new ServletException(name + " is required");
        return value;
    }

    @Override public void doFilter(ServletRequest request, ServletResponse response, FilterChain chain)
            throws IOException, ServletException {
        HttpServletRequest req = (HttpServletRequest) request;
        HttpServletResponse res = (HttpServletResponse) response;
        res.setHeader("Cache-Control", "no-store");
        if (configurationError != null) {
            res.sendError(503, "ORCID configuration incomplete: " + configurationError);
            return;
        }
        String path = req.getRequestURI().substring(req.getContextPath().length());
        try {
            if (path.endsWith("/orcid/start") && "GET".equals(req.getMethod())) start(req, res);
            else if (path.endsWith("/orcid/callback") && "GET".equals(req.getMethod())) callback(req, res);
            else if (path.endsWith("/orcid/unlink") && "POST".equals(req.getMethod())) unlink(req, res);
            else res.sendError(404);
        } catch (Exception ex) {
            configLog(req, ex);
            if (!res.isCommitted()) res.sendError(400, "ORCID sign-in could not be completed");
        }
    }

    private void configLog(HttpServletRequest req, Exception ex) {
        req.getServletContext().log("TLS ORCID request failed", ex);
    }

    private void start(HttpServletRequest req, HttpServletResponse res) throws Exception {
        if (!callbackHost.equalsIgnoreCase(req.getServerName())) {
            res.sendError(400, "Open TLS at the same hostname as the ORCID callback: "
                    + callbackHost + ". Then start ORCID sign-in again.");
            return;
        }
        HttpSession session = req.getSession(true);
        String linkedUser = null;
        if ("link".equals(req.getParameter("mode"))) {
            linkedUser = sessionString(session.getAttribute(LINK));
            session.removeAttribute(LINK);
            Subject subject = authenticatedSubject(session);
            if (subject == null || linkedUser == null || !linkedUser.equals(subject.getName())) {
                res.sendError(403, "Sign in to TLS before connecting ORCID");
                return;
            }
        }
        byte[] nonce = new byte[32];
        random.nextBytes(nonce);
        String state = Base64.getUrlEncoder().withoutPadding().encodeToString(nonce);
        session.setAttribute(STATE, state);
        session.setAttribute(STARTED, System.currentTimeMillis());
        if (linkedUser != null) session.setAttribute(PENDING_LINK, linkedUser);
        else session.removeAttribute(PENDING_LINK);
        String url = base + "/oauth/authorize?client_id=" + enc(clientId)
                + "&response_type=code&scope=" + enc("/authenticate")
                + "&redirect_uri=" + enc(redirectUri) + "&state=" + enc(state);
        res.sendRedirect(url);
    }

    private void callback(HttpServletRequest req, HttpServletResponse res) throws Exception {
        HttpSession session = req.getSession(false);
        if (session == null) {
            res.sendError(400, "TLS sign-in session missing. Open TLS at " + callbackHost
                    + " and start ORCID sign-in again.");
            return;
        }
        String expected = (String) session.getAttribute(STATE);
        Long started = (Long) session.getAttribute(STARTED);
        String linkedUser = (String) session.getAttribute(PENDING_LINK);
        session.removeAttribute(STATE);
        session.removeAttribute(STARTED);
        session.removeAttribute(PENDING_LINK);
        if (expected == null || !expected.equals(req.getParameter("state")) || started == null
                || System.currentTimeMillis() - started > 600000L || req.getParameter("error") != null) {
            res.sendError(400, "Invalid or expired ORCID request"); return;
        }
        String code = req.getParameter("code");
        if (code == null || code.isEmpty()) { res.sendError(400); return; }
        JsonNode token = exchange(code);
        String orcid = token.path("orcid").asText();
        if (!orcid.matches(ORCID_PATTERN) || token.path("access_token").asText().isEmpty()
                || !token.path("scope").asText().contains("/authenticate")) {
            res.sendError(400, "ORCID did not verify an iD"); return;
        }
        SecurityManager sm = BrokerPool.getInstance().getSecurityManager();
        Account account;
        boolean generatedAccount;
        synchronized (lock) {
            Properties links = readLinks();
            String username = links.getProperty(orcid);
            if (linkedUser != null) {
                if (username != null && !username.equals(linkedUser)) {
                    linkConflict(req, res, "This ORCID iD is already connected to TLS account " + username + ".",
                            "Sign in to that account to use this ORCID iD. To move the connection, "
                            + "disconnect it in that account's Settings first, then connect it here.");
                    return;
                }
                for (String id : links.stringPropertyNames()) {
                    if (linkedUser.equals(links.getProperty(id)) && !id.equals(orcid)) {
                        linkConflict(req, res, "This TLS account is already connected to a different ORCID iD.",
                                "Open Settings and disconnect the existing ORCID iD before connecting another one.");
                        return;
                    }
                }
                username = linkedUser;
            } else if (username == null) {
                username = "orcid-" + orcid.replace("-", "");
                if (sm.hasAccount(username)) {
                    res.sendError(409, "TLS account name already exists"); return;
                }
                createAccount(sm, username);
            }
            account = sm.getAccount(username);
            if (!(account instanceof AbstractAccount) || !account.isEnabled()) {
                res.sendError(403, "TLS account unavailable"); return;
            }
            if (!username.equals(links.getProperty(orcid))) {
                links.setProperty(orcid, username);
                writeLinks(links);
            }
            generatedAccount = linkedUser == null && username.equals("orcid-" + orcid.replace("-", ""));
        }
        try {
            if (generatedAccount) {
                String name = token.path("name").asText("").trim();
                if (name.isEmpty()) name = "ORCID " + orcid;
                setupAccount(account.getName(), name);
            }
            recordLink(account.getName(), orcid);
        } catch (Exception ex) {
            configLog(req, ex);
            res.sendError(500, "ORCID account setup failed. Sign in again to retry.");
            return;
        }
        session.setAttribute(SUBJECT, new SubjectAccreditedImpl((AbstractAccount) account, this));
        session.setAttribute("org.hxwd.tls.user", account.getName());
        session.setAttribute(ORCID, orcid);
        res.sendRedirect(req.getContextPath() + "/apps/tls-app/index.html");
    }

    private void linkConflict(HttpServletRequest req, HttpServletResponse res, String heading, String guidance)
            throws IOException {
        res.setStatus(HttpServletResponse.SC_CONFLICT);
        res.setCharacterEncoding(StandardCharsets.UTF_8.name());
        res.setContentType("text/html");
        String app = req.getContextPath() + "/apps/tls-app/";
        try (PrintWriter out = res.getWriter()) {
            out.print("<!doctype html><html lang=\"en\"><head><meta charset=\"utf-8\">"
                    + "<title>ORCID connection already exists</title>"
                    + "<style>body{font:1rem/1.5 sans-serif;max-width:42rem;margin:3rem auto;padding:0 1rem}"
                    + "a{margin-right:1.5rem}</style></head><body><main>"
                    + "<h1>ORCID connection already exists</h1><p>" + escapeHtml(heading)
                    + "</p><p>" + escapeHtml(guidance) + "</p>"
                    + "<p>Your existing account connections were not changed.</p>"
                    + "<p><a href=\"" + app + "settings.html\">TLS Settings</a>"
                    + "<a href=\"" + app + "index.html\">TLS home</a></p></main></body></html>");
        }
    }

    private static String escapeHtml(String value) {
        return value.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
                .replace("\"", "&quot;").replace("'", "&#39;");
    }

    private void createAccount(SecurityManager sm, String username) throws Exception {
        Group group = sm.getGroup("tls-user");
        if (group == null) throw new IllegalStateException("tls-user group missing");
        byte[] bytes = new byte[48]; random.nextBytes(bytes);
        UserAider user = new UserAider(username, group);
        user.setPassword(Base64.getEncoder().encodeToString(bytes));
        user.setUserMask(0002);
        try (DBBroker broker = BrokerPool.getInstance().get(Optional.of(sm.getSystemSubject()))) {
            sm.addAccount(broker, user);
        }
    }

    private void setupAccount(String username, String name) throws Exception {
        runAccountQuery(SETUP_QUERY, username, "name", name);
    }

    private void recordLink(String username, String orcid) throws Exception {
        runAccountQuery(RECORD_QUERY, username, "orcid", orcid);
    }

    private void clearLink(String username) throws Exception {
        runAccountQuery(CLEAR_QUERY, username, null, null);
    }

    private void runAccountQuery(String source, String username, String valueName, String value) throws Exception {
        BrokerPool pool = BrokerPool.getInstance();
        try (DBBroker broker = pool.get(Optional.of(pool.getSecurityManager().getSystemSubject()))) {
            XQueryContext context = new XQueryContext(pool);
            context.declareVariable("username", username);
            if (valueName != null) context.declareVariable(valueName, value);
            CompiledXQuery query = pool.getXQueryService().compile(broker, context, source);
            pool.getXQueryService().execute(broker, query, null);
        }
    }

    private JsonNode exchange(String code) throws IOException {
        HttpURLConnection connection = (HttpURLConnection) new URL(base + "/oauth/token").openConnection();
        connection.setRequestMethod("POST");
        connection.setConnectTimeout(10000);
        connection.setReadTimeout(10000);
        connection.setRequestProperty("Accept", "application/json");
        connection.setRequestProperty("Content-Type", "application/x-www-form-urlencoded");
        connection.setDoOutput(true);
        byte[] body = ("client_id=" + enc(clientId) + "&client_secret=" + enc(clientSecret)
                + "&grant_type=authorization_code&code=" + enc(code)
                + "&redirect_uri=" + enc(redirectUri)).getBytes(StandardCharsets.UTF_8);
        try (OutputStream out = connection.getOutputStream()) { out.write(body); }
        if (connection.getResponseCode() != 200) throw new IOException("ORCID token exchange failed");
        try (InputStream in = connection.getInputStream()) { return json.readTree(in); }
        finally { connection.disconnect(); }
    }

    private void unlink(HttpServletRequest req, HttpServletResponse res) throws Exception {
        HttpSession session = req.getSession(false);
        if (session == null) {
            res.sendError(403, "ORCID unlink session missing. Reload Settings and try again."); return;
        }
        Subject subject = authenticatedSubject(session);
        if (subject == null) {
            res.sendError(403, "Sign in to TLS before disconnecting ORCID."); return;
        }
        String token = sessionString(session.getAttribute(UNLINK_TOKEN));
        String submitted = req.getParameter("csrf");
        if (token == null || submitted == null) {
            res.sendError(403, "ORCID unlink token missing. Reload Settings and try again."); return;
        }
        if (!MessageDigest.isEqual(token.getBytes(StandardCharsets.UTF_8),
                submitted.getBytes(StandardCharsets.UTF_8))) {
            res.sendError(403, "ORCID unlink token changed. Reload Settings and try again."); return;
        }
        session.removeAttribute(UNLINK_TOKEN);
        String username = subject.getName();
        synchronized (lock) {
            Properties links = readLinks();
            for (String id : links.stringPropertyNames()) {
                if (username.equals(links.getProperty(id))) {
                    links.remove(id);
                    writeLinks(links);
                    break;
                }
            }
        }
        clearLink(username);
        session.removeAttribute(ORCID);
        res.sendRedirect(req.getContextPath() + "/apps/tls-app/settings.html");
    }

    private Properties readLinks() throws IOException {
        Properties links = new Properties();
        if (Files.exists(linksPath)) try (InputStream in = Files.newInputStream(linksPath)) { links.load(in); }
        return links;
    }

    private void writeLinks(Properties links) throws IOException {
        Path parent = linksPath.toAbsolutePath().getParent();
        Files.createDirectories(parent);
        Path temporary = Files.createTempFile(parent, "orcid-links-", ".tmp");
        try {
            try (OutputStream out = Files.newOutputStream(temporary)) { links.store(out, "TLS ORCID account links"); }
            Files.move(temporary, linksPath, StandardCopyOption.ATOMIC_MOVE, StandardCopyOption.REPLACE_EXISTING);
        } finally { Files.deleteIfExists(temporary); }
    }

    private static String sessionString(Object value) throws XPathException {
        if (value instanceof String) return (String) value;
        if (value instanceof Item) return ((Item) value).getStringValue();
        return null;
    }

    private static Subject authenticatedSubject(HttpSession session) {
        Object value = session == null ? null : session.getAttribute(SUBJECT);
        if (!(value instanceof Subject)) return null;
        Subject subject = (Subject) value;
        return subject.isAuthenticated() && !"guest".equals(subject.getName()) ? subject : null;
    }

    private static String enc(String value) throws IOException {
        return URLEncoder.encode(value, "UTF-8");
    }

    @Override public void destroy() { }
}
