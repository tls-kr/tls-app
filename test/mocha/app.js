'use strict'

const chai = require('chai')
const chaiXml = require('chai-xml')
const expect = require('chai').expect
const fs = require('fs-extra')
const glob = require('glob')
const xmldoc = require('xmldoc')

const ignore = ['node_modules/**', 'test/**', 'documentation/**']

describe('consistency checks', function () {
  describe('existing markup files are well-formed', function () {
    chai.use(chaiXml)

    it('*.html is xhtml', function () {
      glob.sync('**/*.html', {ignore}).forEach(function (html) {
        const xhtml = fs.readFileSync(html, 'utf8')
        const hParsed = new xmldoc.XmlDocument(xhtml).toString()
        expect(hParsed).xml.to.be.valid()
      })
    })

    it('*.xml', function () {
      glob.sync('**/*.xml', {ignore}).forEach(function (xmls) {
        const xml = fs.readFileSync(xmls, 'utf8')
        const xParsed = new xmldoc.XmlDocument(xml).toString()
        expect(xParsed).xml.to.be.valid()
      })
    })

    it('*.xconf', function () {
      glob.sync('**/*.xconf', {ignore}).forEach(function (xconfs) {
        const xconf = fs.readFileSync(xconfs, 'utf8')
        const cParsed = new xmldoc.XmlDocument(xconf).toString()
        expect(cParsed).xml.to.be.valid()
      })
    })

    it('*.odd', function () {
      this.slow(1000)
      glob.sync('**/*.odd', {ignore}).forEach(function (odds) {
        const odd = fs.readFileSync(odds, 'utf8')
        const xParsed = new xmldoc.XmlDocument(odd).toString()
        expect(xParsed).xml.to.be.valid()
      })
    })
  })

  describe('meta-data consistency', function () {
    // Load expath-pkg.xml as source of truth (version and human-readable title)
    let exPkgVer, exPkgTitle
    if (fs.existsSync('expath-pkg.xml')) {
      const exPkg = new xmldoc.XmlDocument(fs.readFileSync('expath-pkg.xml', 'utf8'))
      exPkgVer = exPkg.attr.version
      exPkgTitle = exPkg.childNamed('title') ? exPkg.childNamed('title').val : undefined
    }

    it('version string is consistent', function () {
      if (!exPkgVer) { this.skip(); return }
      const pkgVer = JSON.parse(fs.readFileSync('package.json', 'utf8')).version
      expect(pkgVer, 'package.json version').to.equal(exPkgVer)
    })

    it('description matches expath-pkg title', function () {
      if (!exPkgTitle) { this.skip(); return }
      const pkgDesc = JSON.parse(fs.readFileSync('package.json', 'utf8')).description
      expect(pkgDesc, 'package.json description').to.equal(exPkgTitle)
    })

    it('Readme is consistent with meta-data', function () {
      if (!fs.existsSync('README.md')) { this.skip(); return }
      const readme = fs.readFileSync('README.md', 'utf8')
      if (exPkgTitle) {
        expect(readme, 'README contains project title').to.include(exPkgTitle)
      }
    })
  })
})
