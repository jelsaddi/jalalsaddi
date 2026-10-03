<?xml version="1.0" encoding="UTF-8"?>
<!-- Presentation only: makes sitemap.xml readable in a browser. Crawlers ignore this file. -->
<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:sm="http://www.sitemaps.org/schemas/sitemap/0.9"
  xmlns:xhtml="http://www.w3.org/1999/xhtml">
  <xsl:output method="html" encoding="UTF-8" indent="yes"/>

  <xsl:template match="/">
    <html lang="en">
      <head>
        <meta charset="UTF-8"/>
        <meta name="viewport" content="width=device-width, initial-scale=1"/>
        <title>Sitemap — jalalsaddi.de</title>
        <style>
          body { font-family: system-ui, sans-serif; background: #EDEFF1; color: #1A2138; margin: 0; padding: 2rem 1rem; }
          main { max-width: 1100px; margin: 0 auto; }
          h1 { font-family: Georgia, serif; font-size: 1.6rem; margin: 0 0 .25rem; }
          p { color: #4a5270; margin: 0 0 1.5rem; font-size: .95rem; }
          table { width: 100%; border-collapse: collapse; background: #fff; border: 1px solid #c9ced6; font-size: .9rem; }
          th, td { text-align: left; padding: .6rem .8rem; border-bottom: 1px solid #e1e4e9; vertical-align: top; }
          th { background: #1A2138; color: #C79552; font-size: .75rem; letter-spacing: .06em; text-transform: uppercase; }
          a { color: #8f6420; text-decoration: none; word-break: break-all; }
          a:hover { text-decoration: underline; }
          .lang { display: inline-block; font-family: monospace; font-size: .75rem; border: 1px solid #c9ced6; border-radius: 3px; padding: 0 .35rem; margin: 0 .25rem .25rem 0; }
          .date { font-family: monospace; white-space: nowrap; }
        </style>
      </head>
      <body>
        <main>
          <h1>Sitemap</h1>
          <p><xsl:value-of select="count(sm:urlset/sm:url)"/> URLs, each with its language alternates (hreflang).</p>
          <table>
            <thead>
              <tr><th>URL</th><th>Language versions</th><th>Last modified</th></tr>
            </thead>
            <tbody>
              <xsl:for-each select="sm:urlset/sm:url">
                <tr>
                  <td><a href="{sm:loc}"><xsl:value-of select="sm:loc"/></a></td>
                  <td>
                    <xsl:for-each select="xhtml:link[@rel='alternate']">
                      <span class="lang" title="{@href}"><xsl:value-of select="@hreflang"/></span><xsl:text> </xsl:text>
                    </xsl:for-each>
                  </td>
                  <td class="date"><xsl:value-of select="sm:lastmod"/></td>
                </tr>
              </xsl:for-each>
            </tbody>
          </table>
        </main>
      </body>
    </html>
  </xsl:template>
</xsl:stylesheet>
