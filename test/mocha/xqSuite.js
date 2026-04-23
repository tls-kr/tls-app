'use strict'

const chai = require('chai')
const supertest = require('supertest')
const expect = require('chai').expect
const fs = require('fs')
const path = require('path')

// Optional test-account file (gitignored). Tests that need a real,
// session-issuing login skip themselves if this file is missing or
// has no usable user entry — CI without secrets still runs green.
function loadTestAccount(noteMatch) {
  try {
    const p = path.join(__dirname, '.test-accounts.local.json')
    const raw = JSON.parse(fs.readFileSync(p, 'utf8'))
    const u = (raw.users || []).find(
      (u) => u.name && u.password &&
             (noteMatch ? (u.note || '').includes(noteMatch) : true)
    )
    return u || null
  } catch (e) { return null }
}

// Public host used by the app routes — tests there match what users see
// (dev: direct Jetty on :8088; prod: Apache → eXist, same as Cloudflare).
var client = supertest.agent(process.env.TEST_HOST || 'http://localhost:8088')

// Dev serves the raw eXist REST API on the same host/port. Prod hides
// /exist/rest/* behind Apache, so the XQSuite test runner has to reach
// eXist directly on its Jetty port (8443 over TLS on hxwd.org).
var restClient = supertest.agent(
  process.env.TEST_REST_HOST ||
  process.env.TEST_HOST ||
  'http://localhost:8088'
)

describe('xqSuite unit testing', function() {

  describe('running tests', function() {
    this.timeout(30000)
    this.slow(5000)
    let runner = '/exist/rest/db/apps/tls-app/modules/test-runner.xq'

    it('returns 0 errors or failures', function(done) {
      restClient
        .get(runner)
        .auth('admin', 'eX1st')
        .set('Accept', 'application/json')
        .expect(200)
        .expect('content-type', /^application\/json/)
        .end(function(err, res) {
          if (err) return done(err)
          expect(res.body.testsuite.failures).to.equal('0')
          if (typeof res.body.testsuite.errors !== 'undefined') {
            expect(res.body.testsuite.errors).to.equal('0')
          }
          done()
        })
    })
  })

  // Covers the flat-URL OpenAPI routes introduced in Waves A + B
  // (see info/log.md 2026-04-20 "API migration: Waves 1, A, B complete").
  //
  // Uses a fresh, non-agent client so it doesn't inherit the admin session
  // cookie from the XQSuite runner test above. Every request sets a
  // User-Agent header because controller.xql's local:isBlocked() declares
  // $ua as exactly-one xs:string and raises XPTY0004 if the header is missing.
  describe('migrated OpenAPI endpoints', function() {
    // Cold-cache get_toc scans the whole text collection and routinely
    // takes 15-25s after an eXist restart. 30s accommodates that; warm
    // cache brings it back under 10s.
    this.timeout(30000)
    const base = 'http://localhost:8088/exist/apps/tls-app'
    const seg = 'CH1a0907_CHANT_016-35a.4'
    const textid = 'CH1a0907'
    const get = (path) =>
      supertest(base).get(path).set('User-Agent', 'mocha-test')

    it('GET api/get_toc returns 200 with dropdown entries', function(done) {
      get('/api/get_toc?textid=' + textid)
        .expect(200)
        .end(function(err, res) {
          if (err) return done(err)
          // Response is HTML fragment of <a class="dropdown-item"> links.
          // CH1a0907 has a multi-div body so at least one entry must render.
          expect(res.text).to.match(/class="dropdown-item"/)
          done()
        })
    })

    it('GET api/autocomplete returns JSONP payload', function(done) {
      get('/api/autocomplete?type=concept&term=ren')
        .expect(200)
        .expect('content-type', /javascript/)
        .end(function(err, res) {
          if (err) return done(err)
          expect(res.text).to.match(/\w+\(\[.*\]\)/)
          done()
        })
    })

    it('GET api/get_guangyun returns 200', function(done) {
      get('/api/get_guangyun?char=' + encodeURIComponent('仁'))
        .expect(200).end(done)
    })

    it('GET api/show_swl_for_lines returns JSON array', function(done) {
      get('/api/show_swl_for_lines?lines=' + seg)
        .expect(200)
        .end(function(err, res) {
          if (err) return done(err)
          expect(res.body).to.be.an('array')
          done()
        })
    })

    // Regression test for the /db/apps/tls-data root-read permission
    // issue (see info/log.md 2026-04-22 "Anonymous users see empty SWL
    // fields"). Uses a seg known to carry real annotations so
    // lrh:format-swl runs its concept/sense lookup. Asserts the
    // rendered html contains CJK characters — if the root collection
    // is not world-readable, the sense lookup returns 0 hits and the
    // zi/pinyin columns render as empty strings.
    it('GET api/show_swl_for_lines exposes full SWL content to anonymous users', function(done) {
      const annotatedSeg = 'KR1e0001_tls_009-572a.13'
      get('/api/show_swl_for_lines?lines=' + annotatedSeg)
        .expect(200)
        .end(function(err, res) {
          if (err) return done(err)
          expect(res.body).to.be.an('array').with.length.greaterThan(0)
          const html = res.body[0].html
          expect(html, 'row html').to.be.a('string').and.not.empty
          // Any CJK Unified Ideograph proves the sense lookup returned
          // at least one entry — i.e. collection(tls-data)//tei:sense[...]
          // was enumerable from the anonymous session.
          expect(html, 'zi column populated').to.match(/[\u4e00-\u9fff]/)
          done()
        })
    })

    it('GET api/record_visit returns 200', function(done) {
      get('/api/record_visit?location=' + seg).expect(200).end(done)
    })

    it('GET api/get_text_preview returns 200', function(done) {
      get('/api/get_text_preview?loc=' + seg).expect(200).end(done)
    })

    it('old .xql stub URL is gone (404)', function(done) {
      get('/api/autocomplete.xql?type=concept&term=ren')
        .expect(404).end(done)
    })
  })

  // Regression guard for the translation-slot stickiness bug fixed
  // on 2026-04-23 (see info/log.md). Commit 9bad418 had introduced
  // session-scoped caching of lus:get-settings() which made slot
  // changes invisible on the next page load within the same session.
  // The fix moved the cache to request scope. This test exercises the
  // actual cross-request flow: save via /api/ltr_reload_selector, then
  // read via /api/get_slot_config from a second request using the
  // same authenticated session.
  describe('translation slot stickiness', function() {
    this.timeout(45000)
    const base = process.env.TEST_HOST || 'http://localhost:8088'
    // The regression reproduces only for a regular tls-user (not dba,
    // not tls-test — those take different code paths in ltr:reload-
    // selector). We load credentials from a gitignored local file; if
    // absent, skip so CI without secrets still passes.
    const account = loadTestAccount('tls-user')
    const user = account ? account.name : null
    const pass = account ? account.password : null
    // Sentinel textid that no real text uses — writes here are inert.
    const textid = 'MOCHA-STICKY-TEST'
    const slot = 'slot1'

    before(function() {
      if (!account) this.skip()
    })

    // supertest.agent preserves JSESSIONID across requests. Basic auth
    // alone would not — only /login (persistent-login) issues the cookie
    // that activates eXist's session scope. Without a real session, the
    // buggy session-scoped cache never engaged and the test passed even
    // against the broken code.
    const agent = () => supertest.agent(base + '/exist/apps/tls-app')

    const login = (a) =>
      a.get(`/login?user=${user}&password=${pass}`)
        .set('User-Agent', 'mocha-test')

    const readSlot = (a) =>
      a.get(`/api/get_slot_config?textid=${textid}&slot=${slot}`)
        .set('User-Agent', 'mocha-test')

    const writeSlot = (a, contentId) =>
      a.get(`/api/save_slot_config?textid=${textid}&slot=${slot}&content-id=${contentId}`)
        .set('User-Agent', 'mocha-test')

    it('picks up slot changes on a subsequent request in the same session', function(done) {
      const a = agent()
      const v1 = 'sentinel-A-' + Date.now()
      const v2 = 'sentinel-B-' + Date.now()
      login(a).expect(200).end(function(err, res) {
        if (err) return done(err)
        // Guard: if login didn't establish a session we wouldn't exercise
        // the session-cache code path and the test would silently pass.
        expect(res.headers['set-cookie'], 'login must issue JSESSIONID')
          .to.exist
        writeSlot(a, v1).expect(200).end(function(err) {
          if (err) return done(err)
          // First read populates any per-session cache with v1.
          readSlot(a).expect(200).end(function(err, res) {
            if (err) return done(err)
            expect(res.body['content-id'], 'initial read').to.equal(v1)
            // Second write in a fresh request — under the old session
            // cache this write would not be visible to the next read.
            writeSlot(a, v2).expect(200).end(function(err) {
              if (err) return done(err)
              readSlot(a).expect(200).end(function(err, res) {
                if (err) return done(err)
                expect(res.body['content-id'], 'slot change sticky across requests').to.equal(v2)
                done()
              })
            })
          })
        })
      })
    })
  })

  // Wave C: responder.xql retired in favour of flat per-function routes
  // (see info/log.md 2026-04-20 "API migration: Wave C complete").
  describe('Wave C — former responder.xql targets', function() {
    this.timeout(10000)
    const base = 'http://localhost:8088/exist/apps/tls-app'
    const get = (path) =>
      supertest(base).get(path).set('User-Agent', 'mocha-test')

    it('GET api/bib_new_entry_dialog returns 200', function(done) {
      get('/api/bib_new_entry_dialog').expect(200).end(done)
    })

    it('GET api/dialogs_new_concept_dialog returns 200', function(done) {
      get('/api/dialogs_new_concept_dialog').expect(200).end(done)
    })

    it('GET api/bib_quick_search returns 200', function(done) {
      get('/api/bib_quick_search?q=test').expect(200).end(done)
    })

    it('old responder.xql dispatcher is gone (404)', function(done) {
      get('/api/responder.xql?func=autocomplete&type=concept&term=ren')
        .expect(404).end(done)
    })
  })
})
