'use strict'

const chai = require('chai')
const supertest = require('supertest')
const expect = require('chai').expect

// The client listening to the eXist REST API
var client = supertest.agent('http://localhost:8088')

describe('xqSuite unit testing', function() {

  describe('rest api returns', function() {
    it('404 from random page', function(done) {
      this.timeout(10000)
      client
        .get('/random')
        .expect(404)
        .end(function(err, res) {
          expect(res.status).to.equal(404)
          if (err) return done(err)
          done()
        })
    })

    it('200 from default rest endpoint', function(done) {
      client
        .get('/exist/rest/db/')
        .expect(200)
        .end(function(err, res) {
          expect(res.status).to.equal(200)
          if (err) return done(err)
          done()
        })
    })

    it('200 from startpage (index.html)', function(done) {
      client
        .get('/exist/rest/db/apps/tls-app/index.html')
        .expect(200)
        .end(function(err, res) {
          expect(res.status).to.equal(200)
          if (err) return done(err)
          done()
        })
    })
  })

  // TODO: add authentication
  describe('running tests', function() {
    this.timeout(10000)
    this.slow(3000)
    let runner = '/exist/rest/db/apps/tls-app/modules/test-runner.xq'

    it('returns 0 errors or failures', function(done) {
      client
        .get(runner)
        .auth('admin', 'eX1st')
        .set('Accept', 'application/json')
        .expect('content-type', 'application/json;charset=utf-8')
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

    it('GET api/get_toc returns 200', function(done) {
      get('/api/get_toc?textid=' + textid).expect(200).end(done)
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
