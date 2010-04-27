require "rubygems"
require "sinatra/base"
require "sinatra/cache"
require "builder"
require "haml"
require "sass"
require 'compass'

require "lib/configuration"
require "lib/models"

module Jrom
  class Application < Sinatra::Base
    configure do
      register(Sinatra::Cache)
      set :root, File.dirname(__FILE__)
      set :cache_enabled, Jrom::Configuration.cache
      set :cache_output_dir, Proc.new { File.join(root, 'public', 'cache') }

      Compass.configuration do |config|
        config.project_path = File.dirname(__FILE__)
        config.sass_dir = 'views/css'
      end
      set :sass, Compass.sass_engine_options
    end

    helpers do
      def set_from_config(*variables)
        variables.each do |var|
          instance_variable_set("@#{var}", Jrom::Configuration.send(var))
        end
      end

      def set_from_page(*variables)
        variables.each { |var| instance_variable_set("@#{var}", @page.send(var)) }
      end

      def set_title(page)
        if page.respond_to?(:parent) && page.parent
          @title = "#{page.heading} - #{page.parent.heading}"
        else
          @title = "#{page.heading} - #{Jrom::Configuration.title}"
        end
      end

      def no_widow(text)
        text.split[0...-1].join(" ") + "&nbsp;#{text.split[-1]}"
      end

      def set_common_variables
        @menu_items = Page.menu_items
        @site_title = Jrom::Configuration.title
        set_from_config(:title, :google_analytics_code)
      end

      def url_for(page)
        File.join(base_url, page.path)
      end

      def base_url
        url = "http://#{request.host}"
        request.port == 80 ? url : url + ":#{request.port}"
      end

      def absolute_urls(text)
        text.gsub!(/(<a href=['"])\//, '\1' + base_url + '/')
        text
      end

      def atom_id_for_page(page)
        published = page.date.strftime('%Y-%m-%d')
        "tag:#{request.host},#{published}:#{page.abspath}"
      end

      def atom_id(page = nil)
        if page
          page.atom_id || atom_id_for_page(page)
        else
          "tag:#{request.host},2009:/"
        end
      end

      def format_date(date)
        date.strftime("%d %B %Y") if date
      end
    end

    not_found do
      set_common_variables
      haml(:not_found)
    end

    error do
      set_common_variables
      haml(:error)
    end unless Sinatra::Application.environment == :development

    def render_options(engine, template)
      local_views = File.join("local", "views")
      if File.exist?(File.join(local_views, "#{template}.#{engine}"))
        { :views => local_views }
      else
        {}
      end
    end

    get "/css/:sheet.css" do
      content_type "text/css", :charset => "utf-8"
      sass("css/#{params[:sheet]}".to_sym)
    end

    get "/" do
      set_common_variables
      set_from_config(:title, :description, :keywords)
      @heading = @title
      @title = "#{@title}"
      @articles = Page.find_articles[0..7]
      @body_class = "index"
      haml(:index)
    end

    get %r{/files/([\w/.-]+)} do
      file = File.join(Jrom::Configuration.attachment_path, params[:captures].first)
      send_file(file, :disposition => nil)
    end

    get "/articles.xml" do
      content_type :xml, :charset => "utf-8"
      set_from_config(:title, :author)
      @articles = Page.find_articles.select { |a| a.date }[0..9]
      builder(:atom)
    end

    get "/sitemap.xml" do
      content_type :xml, :charset => "utf-8"
      @pages = Page.find_all
      @last = @pages.map { |page| page.last_modified }.inject do |latest, page|
        (page > latest) ? page : latest
      end
      builder(:sitemap)
    end

    get "*" do
      set_common_variables
      @page = Page.find_by_path(File.join(params[:splat]))
      raise Sinatra::NotFound if @page.nil?
      set_title(@page)
      set_from_page(:description, :keywords)
      haml(:page)
    end
  end # module Application
end # module Jrom
