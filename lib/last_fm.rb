require 'rexml/document'
require 'net/http'

# ActsAsLastFm
module LastFm
  
  # GET RAILS ENVIRONMENT (TEST, DEVELOPMENT, PRODUCTION)
  env = ENV['RAILS_ENV'] || RAILS_ENV

  # GET CONFIGURATION FILE FOR LAST FM
  config = YAML.load_file(RAILS_ROOT + '/config/last_fm.yml')[env]

  # SET API KEY CONSTANT
  Key = config['api_key']

  # SET SECRET (CURRENTLY NOT USING THIS FOR ANYTHING)
  Secret = config['secret']

  # PREFIX FOR LAST FM QUERIES
  Prefix = "/2.0/?api_key=#{Key}&method="

  def self.included(base)
    base.extend ClassMethods
  end

  module ClassMethods
   
    def last_fm
      include LastFm::InstanceMethods
    end    
  end

    # HELPER METHOD FOR URLs
    def url(string)
      return  string.gsub(/\ +/, '%20')
    end  

    # PERFORM THE REST QUERY
    def fetch_last_fm(path)
      http = Net::HTTP.new("ws.audioscrobbler.com",80)
      path = url(path)
      resp, data = http.get(path)
       if resp.code == "200"
         return data
       else
         return false
       end	
    end

  module InstanceMethods

     # ALBUM INFO - CALLING 1.0 SINCE V2 HAS NO TRACK LISTING
     # TO ADD?
    def lastfm_album_info(artist,album)
      # 2.0  path = "album.getinfo&artist=#{(artist)}&album=#{(album)}"
      path = "/1.0/album/#{artist}/#{album}/info.xml"
      data = fetch_last_fm(path)
      if not data == false
        xml = REXML::Document.new(data)	
        album = {}
        album['releasedate'] = xml.elements['releasedate']
        album['url'] = xml.elements['url']
        coverart = xml.elements['//coverart']
        album['cover'] = coverart.elements['//large'].text
        tracks = []
        xml.elements.each('//track') do |el|
          tracks << { 
                  "title" => el.attributes["title"],
                  "url" =>   el.elements['url'].text 
                  }
        end # END EACH TRACK
        album['tracks'] = tracks
      end # END IF RESPONSE 200
      return album
    end # END ALBUM INFO METHOD

    def lastfm_artists_get_info(artist)
      path = "#{Prefix}artist.getinfo&artist=#{artist}"
      data = fetch_last_fm(path)
      if not data == false
        xml = REXML::Document.new(data)
        artist = {}
        artist['mbid'] = xml.elements['//mbid']
        artist['url'] = xml.elements['//url']
        bio = xml.elements['//bio']
        artist['bio_summary'] = bio.elements['summary'].text
        artist['bio_content'] = bio.elements['content'].text
        artist['small_image'] =  xml.elements['//artist'].elements[4].text 
        artist['medium_image'] =  xml.elements['//artist'].elements[5].text 
        artist['large_image'] =  xml.elements['//artist'].elements[6].text 
      end # END IF DATA NOT FALSE
      return artist
    end


    # ARTISTS CURRENT EVENTS -- NOT EVEN CLOSE TO COMPLETE
    # TO ADD: eventid, artists headliner, venue location->street, postal, geo:point->geo:lat,geo:long,and loc timezone,startTime,desc,images...
    def lastfm_artists_current_events(artist, limit = 10)
      path = "#{Prefix}artist.getevents&artist=#{artist}"
      data = fetch_last_fm(path)
      if not data == false
        xml = REXML::Document.new(data)
        events = []
        # REFACTOR MY CODE METHOD
        xml.elements.to_a('//event')[1..limit].each do |event| 
          bands = []
          artists = event.elements['artists']
          artists.elements.each('artist') do |band|
      	    bands << band.text   
          end # END EACH BAND
          venue = event.elements['venue']
          location = venue.elements['location']
          events << { 
                "title" => event.elements['title'].text, 
                "url" => event.elements['url'].text,  
                "date" => event.elements['startDate'].text, 
                "venue" => venue.elements['name'].text, 
                "city" => location.elements['city'].text, 
                "country" => location.elements['country'].text, 
                "venue_url" => venue.elements['url'].text,
                "bands" => bands 
                  }       
          end # END EACH EVENT
        end # END IF DATA NOT FALSE
        return events 
      end


    # ARTISTS SIMILAR ARTISTS -- COMPLETE
    def lastfm_similar_artists(artist,limit = 5)
      path = "#{Prefix}artist.similar&artist=#{artist}&limit=#{limit}"
      data = fetch_last_fm(path)
      if not data == false
        xml = REXML::Document.new(data)
        artists = []
        xml.elements.to_a('//artist')[1..limit].each do |artist|
            artists << {
                  "name" => artist.elements['name'].text,
                  "url" => artist.elements['url'].text,
                  "image" => artist.elements['image'].text,
                  "small_image" => artist.elements['image_small'].text,
                  "mbid" => artist.elements['mbid'].text,
                  "match" => artist.elements['match'].text
                  }              
        end
        return artists
      end
    end

    # WORKING - NEED TO MAP LARGE AND MEDIUM IMAGES BY ATTRIBUTE
    def lastfm_artists_top_albums(artist,limit = 5)          
      path = "#{Prefix}artist.topAlbums&artist=#{artist}"
      data = fetch_last_fm(path)
      if not data == false
        xml = REXML::Document.new(data)
        albums = []
        xml.elements.to_a('//album')[1..limit].each do |album| 
            albums <<  { 
                  "name"=>album.elements['name'].text, 
                  "url" => album.elements['url'].text, 
                  "small_image" => album.elements['image'].text 
                  }
        end
      end
      return albums
    end

    # ARTISTS TOP TRACKS
    # TO ADD: rank attr, image small, medium, large
    #  mbid?, playcount, listens
    def lastfm_artists_top_tracks(artist, limit = 5)          
      path = "#{Prefix}artist.topTracks&artist=#{artist}"
      data = fetch_last_fm(path)
      if not data == false
        xml = REXML::Document.new(data)
        tracks = []
        xml.elements.to_a('//track')[1..5].each do |track| 
            tracks << {
                  "name"=>track.elements['name'].text,
                  "url"=>track.elements['url'].text
                  }
        end
      end
      return tracks
    end

    # ARTISTS TOP TAGS -- complete
    def lastfm_artists_top_tags(artist, limit = 10)
      path = "#{Prefix}artist.topTags&artist=#{artist}"
      data = fetch_last_fm(path)
      if not data == false
        xml = REXML::Document.new(data)
        tags = []
        xml.elements.to_a('//tag')[1..limit].each do |tag|
            tags << { 'tag' => tag.elements['name'].text, 'url' => tag.elements['url'].text }              
        end
        return tags    
      end
    end

    # USERS WEEKLY ARTISTS
    # TO ADD:  from/to/user
    def lastfm_users_weekly_artists(user, limit = 10)
      path = "#{Prefix}user.getWeeklyArtistChart&user=#{user}"
      data = fetch_last_fm(path)
      if not data == false
        xml = REXML::Document.new(data)
        bands = []
        xml.elements.to_a('//artist')[1..10].each do |artist| 
          bands << { 
                  "name" => band.elements['name'].text, 
                  "url" => band.elements['url'].text,
                  "mbid" => band.elements['mbid'].text,
                  "playcount" => band.elements['playcount'].text,
                  "rank" => band.attributes['rank']
                  }
        end
        return bands
      end
    end

    # USERS WEEKLY ALBUMS
    # ELEMENTS TO ADD: 
    #weekly album chart: user, from, to, 
    # could allow params of from and to
    def lastfm_users_weekly_albums(user, limit = 10)
      path = "#{Prefix}user.getWeeklyAlbumChart&user=#{user}"
      data = fetch_last_fm(path)
      if not data == false
        xml = REXML::Document.new(data)
        albums = []
        xml.elements.to_a('//album')[1..10].each do |album| 
            albums << { 
                  "name" => album.elements['name'].text,
                  "band" => album.elements['artist'].text,
                  "url" => album.elements['url'].text,
                  "album_mbid" => album.elements['mbid'].text,
                  "playcount" => album.elements['playcount'].text,
                  "artist_mbid" => album.elements['artist'].attributes['mbid'],
                  "rank" => album.attributes['rank']
                    }
        end
        return albums
      end
    end
 
 end # MODULE INSTANCE METHODS
 
end # END MODULE ACTS AS LAST FM