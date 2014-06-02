require 'spec_helper'

describe FeedClient do
  before :each do
    @original_feed_title = 'Some feed title'
    @original_feed_url = 'http://some.feed.com/'
    @feed = FactoryGirl.create :feed, title: @original_feed_title, url: @original_feed_url

    @feed_title = 'xkcd.com'
    @feed_url = 'http://xkcd.com/'

    @entry1 = FactoryGirl.build :entry
    @entry1.title = 'Silence'
    @entry1.url = 'http://xkcd.com/1199/'
    @entry1.summary = %{&lt;p&gt;All music is just performances of 4'33" in studios where another band happened to be playing at the time.&lt;/p&gt;}
    @entry1.published = 'Mon, 15 Apr 2013 04:00:00 -0000'
    @entry1.guid = 'http://xkcd.com/1199/'

    @entry2 = FactoryGirl.build :entry
    @entry2.title = 'Geologist'
    @entry2.url = 'http://xkcd.com/1198/'
    @entry2.summary = %{&lt;p&gt;'It seems like it's still alive, Professor.' 'Yeah, a big one like this can keep running around for a few billion years after you remove the head.';&lt;/p&gt;}
    @entry2.published = 'Fri, 12 Apr 2013 04:00:00 -0000'
    @entry2.guid = 'http://xkcd.com/1198/'
  end

  context 'Atom feed fetching' do

    before :each do
      @feed_xml = <<FEED_XML
<?xml version="1.0" encoding="utf-8"?>
<feed xmlns="http://www.w3.org/2005/Atom" xml:lang="en">
  <title>#{@feed_title}</title>
  <link href="#{@feed_url}" rel="alternate" />
  <id>http://xkcd.com/</id>
  <updated>2013-04-15T00:00:00Z</updated>
  <entry>
    <title>#{@entry2.title}</title>
    <link href="#{@entry2.url}" rel="alternate" />
    <updated>#{@entry2.published}</updated>
    <id>#{@entry2.guid}</id>
    <summary type="html">#{@entry2.summary}</summary>
  </entry>
  <entry>
    <title>#{@entry1.title}</title>
    <link href="#{@entry1.url}" rel="alternate" />
    <updated>#{@entry1.published}</updated>
    <id>#{@entry1.guid}</id>
    <summary type="html">#{@entry1.summary}</summary>
  </entry>
</feed>
FEED_XML

      @feed_xml.stub(:headers).and_return {}
      RestClient.stub get: @feed_xml
    end

    it 'returns feed if successful' do
      feed = FeedClient.fetch @feed
      feed.should eq @feed
    end

    it 'fetches the right entries and saves them in the database' do
      FeedClient.fetch @feed
      @feed.reload
      @feed.entries.count.should eq 2

      entry1 = @feed.entries[0]
      entry1.title.should eq @entry1.title
      entry1.url.should eq @entry1.url
      entry1.author.should eq @entry1.author
      entry1.summary.should eq CGI.unescapeHTML(@entry1.summary)
      entry1.published.should eq @entry1.published
      entry1.guid.should eq @entry1.guid

      entry2 = @feed.entries[1]
      entry2.title.should eq @entry2.title
      entry2.url.should eq @entry2.url
      entry2.author.should eq @entry2.author
      entry2.summary.should eq CGI.unescapeHTML(@entry2.summary)
      entry2.published.should eq @entry2.published
      entry2.guid.should eq @entry2.guid
    end

    it 'ignores entry if it is received again' do
      # Create an entry for feed @feed with the same guid as @entry1 (which is not saved in the DB) but all other
      # fields with different values
      entry_before = FactoryGirl.create :entry, feed_id: @feed.id, title: 'Original title',
                                        url: 'http://original.url.com', author: 'Original author',
                                        content: 'Original content', summary: 'Original summary',
                                        published: Time.zone.parse('2013-01-01T00:00:00'), guid: @entry1.guid

      # XML that will be fetched contains an entry with the same guid. It will be ignored.
      FeedClient.fetch @feed

      # After fetching, relevant fields should be updated with the values received in the XML
      entry_after = Entry.where(guid: entry_before.guid, feed_id: entry_before.feed_id).first
      entry_after.feed_id.should eq entry_before.feed_id
      entry_after.title.should eq entry_before.title
      entry_after.url.should eq entry_before.url
      entry_after.author.should eq entry_before.author
      entry_after.summary.should eq CGI.unescapeHTML(entry_before.summary)
      entry_after.guid.should eq entry_before.guid
      entry_after.published.should eq entry_before.published
    end

    it 'saves entry if another one with the same guid but from a different feed is already in the database' do
      feed2 = FactoryGirl.create :feed
      # Create an entry for feed @feed with the same guid as @entry1 (which is not saved in the DB) but all other
      # fields with different values
      entry = FactoryGirl.create :entry, feed_id: feed2.id, title: 'Original title',
                                 url: 'http://origina.url.com', author: 'Original author',
                                 content: 'Original content', summary: '<p>Original summary</p>',
                                 published: Time.zone.parse('2013-01-01T00:00:00'),
                                 guid: @entry1.guid

      # XML that will be fetched contains an entry with the same guid from a different feed. Both entries
      # should be treated as separate entities.
      FeedClient.fetch @feed

      # After fetching, entry should be left untouched
      entry.reload
      entry.feed_id.should eq feed2.id
      entry.title.should eq 'Original title'
      entry.url.should eq 'http://origina.url.com'
      entry.author.should eq 'Original author'
      entry.summary.should eq '<p>Original summary</p>'
      entry.published.should eq Time.zone.parse('2013-01-01T00:00:00')
      entry.guid.should eq @entry1.guid

      # Fetched entry should also be saved in the database
      fetched_entry = Entry.where(guid: @entry1.guid, feed_id: @feed.id).first
      fetched_entry.feed_id.should eq @feed.id
      fetched_entry.title.should eq @entry1.title
      fetched_entry.url.should eq @entry1.url
      fetched_entry.author.should eq @entry1.author
      fetched_entry.summary.should eq CGI.unescapeHTML(@entry1.summary)
      fetched_entry.published.should eq @entry1.published
      fetched_entry.guid.should eq @entry1.guid
    end

    it 'retrieves the feed title and saves it in the database' do
      FeedClient.fetch @feed
      @feed.reload
      @feed.title.should eq @feed_title
    end

    it 'does not update the feed title if it is not present in the feed' do
      @feed_xml = <<FEED_XML
<?xml version="1.0" encoding="utf-8"?>
<feed xmlns="http://www.w3.org/2005/Atom" xml:lang="en">
  <link href="#{@feed_url}" rel="alternate" />
  <id>http://xkcd.com/</id>
  <updated>2013-04-15T00:00:00Z</updated>
  <entry>
    <title>#{@entry2.title}</title>
    <link href="#{@entry2.url}" rel="alternate" />
    <updated>#{@entry2.published}</updated>
    <id>#{@entry2.guid}</id>
    <summary type="html">#{@entry2.summary}</summary>
  </entry>
  <entry>
    <title>#{@entry1.title}</title>
    <link href="#{@entry1.url}" rel="alternate" />
    <updated>#{@entry1.published}</updated>
    <id>#{@entry1.guid}</id>
    <summary type="html">#{@entry1.summary}</summary>
  </entry>
</feed>
FEED_XML
      @feed_xml.stub(:headers).and_return {}
      RestClient.stub get: @feed_xml

      FeedClient.fetch @feed
      @feed.reload
      @feed.title.should eq @original_feed_title
    end

    it 'retrieves the feed URL and saves it in the database' do
      FeedClient.fetch @feed
      @feed.reload
      @feed.url.should eq @feed_url
    end

    it 'does not update the feed URL if it is not present in the feed' do
      @feed_xml = <<FEED_XML
<?xml version="1.0" encoding="utf-8"?>
<feed xmlns="http://www.w3.org/2005/Atom" xml:lang="en">
  <title>#{@feed_title}</title>
  <id>http://xkcd.com/</id>
  <updated>2013-04-15T00:00:00Z</updated>
  <entry>
    <title>#{@entry2.title}</title>
    <link href="#{@entry2.url}" rel="alternate" />
    <updated>#{@entry2.published}</updated>
    <id>#{@entry2.guid}</id>
    <summary type="html">#{@entry2.summary}</summary>
  </entry>
  <entry>
    <title>#{@entry1.title}</title>
    <link href="#{@entry1.url}" rel="alternate" />
    <updated>#{@entry1.published}</updated>
    <id>#{@entry1.guid}</id>
    <summary type="html">#{@entry1.summary}</summary>
  </entry>
</feed>
FEED_XML

      @feed_xml.stub(:headers).and_return {}
      RestClient.stub get: @feed_xml

      FeedClient.fetch @feed
      @feed.reload
      @feed.url.should eq @original_feed_url
    end
  end

  context 'xhtml content in atom feeds' do

    before :each do
      @feed_title = 'ongoing by Tim Bray'
      @feed_url = 'https://www.tbray.org/ongoing/'
      @feed_fetch_url = 'https://www.tbray.org/ongoing/ongoing.atom'
      @feed = FactoryGirl.create :feed, title: @feed_title, url: @feed_url, fetch_url: @feed_fetch_url

      @entry = FactoryGirl.build :entry
      @entry.title = 'Stross&#x2019; (unfinished) Merchant Princes'
      @entry.url = 'https://www.tbray.org/ongoing/When/201x/2014/03/25/Merchant-Princes'
      @entry.summary = "<p>I just finished reading the three volumes of The Merchant Princes Omnibus by Charlie Stross:</p>"
      @entry.content = %{<p>I just finished reading the three volumes of <a href="http://www.amazon.com/s/?_encoding=UTF8&amp;camp=1789&amp;creative=390957&amp;field-keywords=merchant%20princes%20omnibus&amp;linkCode=ur2&amp;rh=i%3Aaps%2Ck%3Amerchant%20princes%20omnibus&amp;sprefix=merchant%20princes%20omni%2Caps%2C206&amp;tag=ongoing-20&amp;url=search-alias%3Daps" target="_blank">The Merchant Princes Omnibus</a> by <a href="http://www.antipope.org/charlie/" target="_blank">Charlie Stross</a>:</p>}
      @entry.published = '2014-03-25T12:00:00-07:00'
      @entry.guid = 'https://www.tbray.org/ongoing/When/201x/2014/03/25/Merchant-Princes'

      @feed_xml = <<FEED_XML
<?xml version='1.0' encoding='UTF-8'?>
<feed xmlns='http://www.w3.org/2005/Atom'
    xmlns:thr='http://purl.org/syndication/thread/1.0'
    xml:lang='en-us'>
  <title>#{@feed_title}</title>
  <link rel='hub' href='http://pubsubhubbub.appspot.com/' />
  <id>https://www.tbray.org/ongoing/</id>
  <link href='#{@feed_url}' />
  <link rel='self' href='#{@feed_fetch_url}' />
  <link rel='replies'       thr:count='101'       href='https://www.tbray.org/ongoing/comments.atom' />
  <logo>rsslogo.jpg</logo>
  <icon>/favicon.ico</icon>
  <updated>2014-03-26T10:33:02-07:00</updated>
  <author><name>Tim Bray</name></author>
  <subtitle>ongoing fragmented essay by Tim Bray</subtitle>
  <rights>All content written by Tim Bray and photos by Tim Bray Copyright Tim Bray, some rights reserved, see /ongoing/misc/Copyright</rights>
  <generator uri='/misc/Colophon'>Generated from XML source code using Perl, Expat, Emacs, Mysql, Ruby, Java, and ImageMagick.  Industrial-strength technology, baby.</generator>

  <entry>
    <title>#{@entry.title}</title>
    <link href='#{@entry.url}' />
    <link rel='replies'        thr:count='5'        type='application/xhtml+xml'        href='/ongoing/When/201x/2014/03/25/Merchant-Princes#comments' />
    <id>#{@entry.guid}</id>
    <published>#{@entry.published}</published>
    <updated>2014-03-26T08:17:43-07:00</updated>
    <category scheme='https://www.tbray.org/ongoing/What/' term='Arts/Books' />
    <category scheme='https://www.tbray.org/ongoing/What/' term='Arts' />
    <category scheme='https://www.tbray.org/ongoing/What/' term='Books' />
    <summary type='xhtml'>
      <div xmlns='http://www.w3.org/1999/xhtml'>
        #{@entry.summary}
      </div>
    </summary>
    <content type='xhtml'>
      <div xmlns='http://www.w3.org/1999/xhtml'>#{@entry.content}</div>
    </content>
  </entry>
</feed>
FEED_XML

      @feed_xml.stub(:headers).and_return {}
      RestClient.stub get: @feed_xml
    end

    it 'fetches and saves entries' do
      FeedClient.fetch @feed
      @feed.reload
      @feed.entries.count.should eq 1

      entry = @feed.entries[0]
      entry.title.should eq CGI.unescapeHTML(@entry.title)
      entry.url.should eq @entry.url
      entry.author.should eq @entry.author
      entry.summary.should eq @entry.summary
      entry.published.should eq @entry.published
      entry.guid.should eq @entry.guid
    end

    it 'preserves markup in xhtml content' do
      FeedClient.fetch @feed
      @feed.reload

      entry = @feed.entries[0]
      entry.content.should eq "#{@entry.content}"
    end
  end

  context 'xhtml content in atom feedburner feeds' do

    before :each do
      @feed_title = 'Not Invented Here'
      @feed_url = 'http://notinventedhe.re/'
      @feed_fetch_url = 'http://feeds.feedburner.com/NotInventedHere'
      @feed = FactoryGirl.create :feed, title: @feed_title, url: @feed_url, fetch_url: @feed_fetch_url

      @entry = FactoryGirl.build :entry
      @entry.title = 'This strip was Not Invented Here on Thursday, May 29, 2014'
      @entry.url = 'http://notinventedhe.re/on/2014-5-29/comic'
      @entry.summary = nil
      @entry.content = <<ENTRY_CONTENT
<p><em>Not Invented Here</em> <a href="http://notinventedhe.re/book" target="_blank">collections</a> now available in ebook and good-old-fashioned paper versions!</p>
<a href="/on/2014-5-29" target="_blank"><img alt="Not Invented Here strip for 5/29/2014" src="/images/Ajax-loader.gif" data-src="/images/Ajax-loader.gif"></a><a href="/on/2014-5-29/comic#disqus_thread" target="_blank">comments</a>|<a href="mailto:nihcomic@gmail.com" target="_blank">email</a>|<a href="http://www.twitter.com/nihcomic" target="_blank">twitter</a><img src="/images/Ajax-loader.gif" data-src=\"/images/Ajax-loader.gif\">
ENTRY_CONTENT

      @entry.published = '2014-05-29T07:00:00.0000000Z'
      @entry.guid = 'http://notinventedhe.re/on/2014-5-29/comic/'

      @feed_xml = <<FEED_XML
<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/xsl" media="screen" href="/~d/styles/atom10full.xsl"?><?xml-stylesheet type="text/css" media="screen" href="http://feeds.feedburner.com/~d/styles/itemcontent.css"?><feed xmlns="http://www.w3.org/2005/Atom" xml:base="http://notinventedhe.re" xml:lang="en-us">
  <id>http://notinventedhe.re/</id>
  <link type="text/html" rel="alternate" href="#{@feed_url}" />
  <title type="text">#{@feed_title}</title>
  <icon>http://thiswas.notinventedhe.re/with/favicon.ico</icon>
  <subtitle type="text">A comic about software and the people who make it</subtitle>
  <updated>2014-05-29T07:00:00.0000000Z</updated>
  <author>
    <name>Bill Barnes</name>
    <email>bill@overduemedia.com</email>
  </author>
  <author>
    <name>Paul Southworth</name>
    <email>pskl13@yahoo.com</email>
  </author>
  <rights>(c) Bill Barnes and Paul Southworth</rights>
  <atom10:link xmlns:atom10="http://www.w3.org/2005/Atom" rel="self" type="application/atom+xml" href="#{@feed_fetch_url}" /><feedburner:info xmlns:feedburner="http://rssnamespace.org/feedburner/ext/1.0" uri="notinventedhere" /><atom10:link xmlns:atom10="http://www.w3.org/2005/Atom" rel="hub" href="http://pubsubhubbub.appspot.com/" />
  <entry>
    <id>#{@entry.guid}</id>
    <title>
      This strip was Not Invented Here on Thursday, May 29, 2014
    </title>
    <published>#{@entry.published}</published>
    <updated>2014-05-29T07:00:00.0000000Z</updated>
    <link type="text/html" rel="alternate" href="#{@entry.url}" />
    <content type="xhtml">
      <div xmlns="http://www.w3.org/1999/xhtml">#{@entry.content}</div>
    </content>
  </entry>
</feed>

FEED_XML

      @feed_xml.stub(:headers).and_return {}
      RestClient.stub get: @feed_xml
    end

    it 'fetches and saves entries' do
      FeedClient.fetch @feed
      @feed.reload
      @feed.entries.count.should eq 1

      entry = @feed.entries[0]
      entry.title.should eq CGI.unescapeHTML(@entry.title)
      entry.url.should eq @entry.url
      entry.author.should eq @entry.author
      entry.summary.should eq @entry.summary
      entry.published.should eq @entry.published
      entry.guid.should eq @entry.guid
    end

    it 'preserves markup in xhtml content' do
      FeedClient.fetch @feed
      @feed.reload

      entry = @feed.entries[0]
      entry.content.strip.should eq "#{@entry.content.strip}"
    end
  end

  context 'Atom feed autodiscovery' do

    it 'updates fetch_url of the feed with autodiscovery full URL' do
      feed_url = 'http://webpage.com/feed'
      webpage_html = <<WEBPAGE_HTML
<!DOCTYPE html>
<html>
<head>
  <link rel="alternate" type="application/atom+xml" href="#{feed_url}">
</head>
<body>
  webpage body
</body>
</html>
WEBPAGE_HTML
      webpage_html.stub headers: {}

      # First fetch the webpage; then, when fetching the actual feed URL, simulate receiving a 304-Not Modified
      RestClient.stub :get do |url|
        if url==feed_url
          raise RestClient::NotModified.new
        else
          webpage_html
        end
      end

      @feed.fetch_url.should_not eq feed_url
      FeedClient.fetch @feed, true
      @feed.reload
      @feed.fetch_url.should eq feed_url
    end

    it 'updates fetch_url of the feed with autodiscovery relative URL' do
      feed_fetch_url = 'http://webpage.com/feed'
      feed_path = '/feed'
      feed_url = 'http://webpage.com'
      feed = FactoryGirl.create :feed, title: feed_url, fetch_url: feed_url

      webpage_html = <<WEBPAGE_HTML
<!DOCTYPE html>
<html>
<head>
  <link rel="alternate" type="application/atom+xml" href="#{feed_path}">
</head>
<body>
  webpage body
</body>
</html>
WEBPAGE_HTML
      webpage_html.stub headers: {}

      # First fetch the webpage; then, when fetching the actual feed URL, simulate receiving a 304-Not Modified
      RestClient.stub :get do |url|
        if url==feed_fetch_url
          raise RestClient::NotModified.new
        else
          webpage_html
        end
      end

      feed.fetch_url.should_not eq feed_fetch_url
      FeedClient.fetch feed, true
      feed.reload
      feed.fetch_url.should eq feed_fetch_url
    end

    it 'fetches feed' do
      feed_url = 'http://webpage.com/feed'
      webpage_html = <<WEBPAGE_HTML
<!DOCTYPE html>
<html>
<head>
  <link rel="alternate" type="application/atom+xml" href="#{feed_url}">
</head>
<body>
  webpage body
</body>
</html>
WEBPAGE_HTML
      webpage_html.stub headers: {}

      feed_xml = <<FEED_XML
<?xml version="1.0" encoding="utf-8"?>
<feed xmlns="http://www.w3.org/2005/Atom" xml:lang="en">
  <title>#{@feed_title}</title>
  <link href="#{@feed_url}" rel="alternate" />
  <id>http://xkcd.com/</id>
  <updated>2013-04-15T00:00:00Z</updated>
  <entry>
    <title>#{@entry1.title}</title>
    <link href="#{@entry1.url}" rel="alternate" />
    <updated>#{@entry1.published}</updated>
    <id>#{@entry1.guid}</id>
    <summary type="html">#{@entry1.summary}</summary>
  </entry>
</feed>
FEED_XML
      feed_xml.stub headers: {}

      # First fetch the webpage; then, when fetching the actual feed URL, return an Atom XML with one entry
      RestClient.stub :get do |url|
        if url==feed_url
          feed_xml
        else
          webpage_html
        end
      end

      @feed.entries.should be_blank
      FeedClient.fetch @feed, true
      @feed.entries.count.should eq 1
      @feed.entries.where(guid: @entry1.guid).should be_present
    end

    it 'detects that autodiscovered feed is already in the database' do
      feed_url = 'http://webpage.com/feed'
      webpage_html = <<WEBPAGE_HTML
<!DOCTYPE html>
<html>
<head>
  <link rel="alternate" type="application/atom+xml" href="#{feed_url}">
</head>
<body>
  webpage body
</body>
</html>
WEBPAGE_HTML
      webpage_html.stub headers: {}

      feed_xml = <<FEED_XML
<?xml version="1.0" encoding="utf-8"?>
<feed xmlns="http://www.w3.org/2005/Atom" xml:lang="en">
  <title>#{@feed_title}</title>
  <link href="#{@feed_url}" rel="alternate" />
  <id>http://xkcd.com/</id>
  <updated>2013-04-15T00:00:00Z</updated>
  <entry>
    <title>#{@entry1.title}</title>
    <link href="#{@entry1.url}" rel="alternate" />
    <updated>#{@entry1.published}</updated>
    <id>#{@entry1.guid}</id>
    <summary type="html">#{@entry1.summary}</summary>
  </entry>
</feed>
FEED_XML
      feed_xml.stub headers: {}

      old_feed = FactoryGirl.create :feed, fetch_url: feed_url
      new_feed = FactoryGirl.create :feed

      # First fetch the webpage; then, when fetching the actual feed URL, return an Atom XML with one entry
      RestClient.stub :get do |url|
        if url==feed_url
          feed_xml
        elsif url==new_feed.fetch_url
          webpage_html
        end
      end

      old_feed.entries.should be_blank

      FeedClient.fetch new_feed, true

      # When performing autodiscovery, FeedClient should realise that there is another feed in the database with
      # the autodiscovered fetch_url; it should delete the "new" feed and instead fetch and return the "old" one
      old_feed.entries.count.should eq 1
      old_feed.entries.where(guid: @entry1.guid).should be_present
      Feed.exists?(id: new_feed).should be_false
    end

    it 'uses first feed available for autodiscovery' do
      rss_url = 'http://webpage.com/rss'
      atom_url = 'http://webpage.com/atom'
      feed_url = 'http://webpage.com/feed'
      webpage_html = <<WEBPAGE_HTML
<!DOCTYPE html>
<html>
<head>
  <link rel="alternate" type="application/atom+xml" href="#{atom_url}">
  <link rel="alternate" type="application/rss+xml" href="#{rss_url}">
  <link rel="feed" href="#{feed_url}">
</head>
<body>
  webpage body
</body>
</html>
WEBPAGE_HTML
      webpage_html.stub headers: {}

      webpage_url = @feed.fetch_url
      # First fetch the webpage; then, when fetching the actual feed URL, simulate receiving a 304-Not Modified
      RestClient.stub :get do |url|
        if url==webpage_url
          webpage_html
        else
          raise RestClient::NotModified.new

        end
      end

      @feed.fetch_url.should_not eq atom_url
      FeedClient.fetch @feed, true
      @feed.reload
      @feed.fetch_url.should eq atom_url
    end

  end

end