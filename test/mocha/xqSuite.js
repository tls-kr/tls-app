'use strict'

const chai = require('chai')
const supertest = require('supertest')
const expect = require('chai').expect

// The client listening to the mock rest server
var client = supertest.agent('http://localhost:8080')

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
    this.timeout(1500)
    this.slow(500)
    let runner = '/exist/rest/db/apps/tls-app/modules/test-runner.xq'

    it('returns 0 errors or failures', function(done) {
      client
        .get(runner)
        .set('Accept', 'application/json')
        .expect('content-type', 'application/json;charset=utf-8')
        .end(function(err, res) {
          if (err) return done(err)
          expect(res.body.testsuite.failures).to.equal('0')
          // errors appeare in eXist >= 4.3.0
          if (typeof res.body.testsuite.errors !== 'undefined') {
              expect(res.body.testsuite.errors).to.equal('0')
          }
          done()
        })
    })
  })
})
