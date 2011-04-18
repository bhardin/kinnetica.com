# Sitemap Generator is a Jekyll plugin that generated a sitemap.xml file
#
# How To Use: 
#   1.) Copy File Into _plugins/ folder within your Jekyll project
#   2.) Change MY_URL to reflect your domain name
#   2.) Run Jekyll: jekyll --server --auto
#   3.) sitemap.xml should be included in _site/ folder
#
# Customizations:
#   1.) If there are any files you don't want included in the sitemap, add them
#       to the EXCLUDED_FILES list. The name should match the name of the source 
#       file.
#   2.) If you want to include the optional changefreq and priority attributes,
#       simply include custom variables in the YAML Front Matter of that file.
#       The names of these variables are defined below in the
#       CHANGE_FREQUENCY_CUSTOM_VARIABLE_NAME and PRIORITY_CUSTOM_VARIABLE_NAME
#       constants.
# 
# Notes:
#   1.) The last modified date is determined by the latest from the following:
#       system modified date of the page or post, system modified date of
#       included layout, system modified date of included layout within that
#       layout, ... 
#
# Author: Michael Levin
# Site: http://www.kinnetica.com
# Distributed Under A Creative Commons License
#   - http://creativecommons.org/licenses/by/3.0/

require 'rexml/document'

module Jekyll

  class Post
    attr_accessor :name

    def full_path_to_source
      return File.join(@base, @name)
    end
  end

  class Page
    attr_accessor :name

    def full_path_to_source
      return File.join(@base, @dir, @name)
    end
  end

  class Layout
    def full_path_to_source
      return File.join(@base, @name)
    end
  end

  # Recover from strange exception when starting server without --auto
  class SitemapFile < StaticFile
    def write(dest)
      begin
        super(dest)
      rescue
      end
      
      return true
    end
  end

  class SitemapGenerator < Generator
    safe true
    
    # Change MY_URL to reflect the site you are using
    MY_URL = "http://www.kinnetica.com"

    # Any files to exclude from being included in the sitemap.xml
    EXCLUDED_FILES = ["atom.xml"]

    # Custom variable names for changefreq and priority elements
    #
    # These names are used within the YAML Front Matter of pages or posts
    # for which you want to include these properties
    CHANGE_FREQUENCY_CUSTOM_VARIABLE_NAME = "change_frequency"
    PRIORITY_CUSTOM_VARIABLE_NAME = "priority"

    # Goes through pages and posts and generates sitemap.xml file
    #
    # Returns nothing
    def generate(site)
      sitemap = REXML::Document.new << REXML::XMLDecl.new("1.0", "UTF-8")

      urlset = REXML::Element.new "urlset"
      urlset.add_attribute("xmlns", 
        "http://www.sitemaps.org/schemas/sitemap/0.9")

      site.pages.each do |page|
        if !excluded?(page.name)
          url = fill_url(site, page)
          urlset.add_element(url)
        end
      end

      site.posts.each do |post|
        if !excluded?(post.name)
          url = fill_url(site, post)
          urlset.add_element(url)
        end
      end
      
      sitemap.add_element(urlset)

      # File I/O: create sitemap.xml file and write out pretty-printed XML
      file = File.new(File.join(site.dest, "sitemap.xml"), "w")
      formatter = REXML::Formatters::Pretty.new(4)
      formatter.compact = true
      formatter.write(sitemap, file)
      file.close

      # Keep the sitemap.xml file from being cleaned by Jekyll
      site.static_files << Jekyll::SitemapFile.new(site, site.dest, '/', 'sitemap.xml')
    end

    # Fill data of each URL element: location, last modified, 
    # change frequency (optional), and priority.
    #
    # Returns url REXML::Element
    def fill_url(site, page_or_post)
      url = REXML::Element.new "url"

      loc = fill_location(page_or_post.url)
      url.add_element(loc)

      lastmod = fill_last_modified(site, page_or_post)
      url.add_element(lastmod)

      if (page_or_post.data[CHANGE_FREQUENCY_CUSTOM_VARIABLE_NAME])
        changefreq = REXML::Element.new "changefreq"
        changefreq.text = page_or_post.data[CHANGE_FREQUENCY_CUSTOM_VARIABLE_NAME]
        url.add_element(changefreq)
      end

      if (page_or_post.data[PRIORITY_CUSTOM_VARIABLE_NAME])
        priority = REXML::Element.new "priority"
        priority.text = page_or_post.data[PRIORITY_CUSTOM_VARIABLE_NAME]
        url.add_element(priority)
      end

      return url
    end

    # Get URL location of page or post 
    #
    # Returns the location of the page or post
    def fill_location(path)
      loc = REXML::Element.new "loc"

      # Avoid displaying trailing /index.html in the path
      if (path != "/index.html")
        loc.text = "#{MY_URL}#{path}"
      else
        loc.text = MY_URL
      end
      return loc
    end

    # Fill lastmod XML element with the last modified date for the page or post.
    #
    # Returns lastmod REXML::Element
    def fill_last_modified(site, page_or_post)
      lastmod = REXML::Element.new "lastmod"
      path = page_or_post.full_path_to_source
      date = File.mtime(path)
      lastmod.text = find_latest_date(date, site, page_or_post)
      return lastmod
    end

    # Go through the page/post and any implemented layouts and get the latest
    # modified date
    #
    # Returns formatted output of latest date of page/post and any used layouts
    def find_latest_date(latest_date, site, page_or_post)
      layouts = site.layouts
      layout = layouts[page_or_post.data["layout"]]
      while layout
        path = layout.full_path_to_source
        date = File.mtime(path)

        latest_date = date if (date > latest_date)

        layout = layouts[layout.data["layout"]]
      end

      return latest_date.strftime("%Y-%m-%dT%H:%M:%S%Z")
    end

    # Is the page or post listed as something we want to exclude?
    #
    # Returns boolean
    def excluded?(name)
      return EXCLUDED_FILES.include? name
    end

  end
end