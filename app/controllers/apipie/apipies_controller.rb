module Apipie
  class ApipiesController < ActionController::Base
    # caches_page :index

    include ActionView::Context
    include ApipieHelper

    layout Apipie.configuration.layout

    around_action :set_script_name
    before_action :authenticate

    def authenticate
      if Apipie.configuration.authenticate
        instance_eval(&Apipie.configuration.authenticate)
      end
    end

    def guides
      @section = params[:section] || :specification

      title = @section.to_s.humanize
      desc = "Guides for #{title}"
      set_meta_tags({
        title: title,
        description: desc,
        keywords: [title, '42', 'API', 'guides'].join(', '),
        author: "https://plus.google.com/u/0/115378296196014576465",
        publisher: "https://plus.google.com/u/0/115378296196014576465",
        og: {
          title: title,
          description: desc
        },
        twitter: {
          card: "summary",
          site: "@42born2code",
          title: title,
          description: desc
        }
      })

      render "apipie/static/#{@section}", layout: "apipie/guides"
    end

    def index
      params[:version] ||= Apipie.configuration.default_version

      get_format

      if params[:type].to_s == 'swagger' && params[:format].to_s == 'json'
        head :forbidden and return if Apipie.configuration.authorize
        should_render_swagger = true
      end

      respond_to do |format|

        if Apipie.configuration.use_cache?
          render_from_cache
          return
        end

        @language = get_language

        Apipie.load_documentation if Apipie.configuration.reload_controllers? || !Rails.application.config.eager_load

        I18n.locale = @language

        if should_render_swagger
          prev_warning_value = Apipie.configuration.generator.swagger.suppress_warnings
          begin
            Apipie.configuration.generator.swagger.suppress_warnings = true
            @doc = Apipie.to_swagger_json(params[:version], params[:resource], params[:method], @language)
          ensure
            Apipie.configuration.generator.swagger.suppress_warnings = prev_warning_value
          end
        else
          @doc = Apipie.to_json(params[:version], params[:resource], params[:method], @language)
          @doc = authorized_doc
        end

        format.json do
          if @doc
            render :json => @doc
          else
            head :not_found
          end
        end

        format.html do
          unless @doc
            render 'apipie_404', :status => 404
            return
          end

          @versions = Apipie.available_versions
          @doc = @doc[:docs]
          @doc[:link_extension] = (@language ? ".#{@language}" : '')+Apipie.configuration.link_extension
          if @doc[:resources].blank?
            render "getting_started" and return
          end
          @resource = @doc[:resources].first if params[:resource].present?
          @method = @resource[:methods].first if params[:method].present?
          @languages = Apipie.configuration.languages


          title = ""
          title = @resource[:name] if @resource
          title = "#{@method[:name].gsub(/^_/, "")} of #{title} (#{@method[:apis].count} endpoints)" if @method

          description = ""
          description = @resource[:description] if @resource
          description = @method[:desription] if @method

          tags = []
          tags << @resource[:name] if @resource
          tags << @method[:name] if @method
          tags << ["42", "api"]

          path = Apipie.configuration.doc_base_url.dup
          path << "/" << params[:version] if params[:version].present?
          path << "/" << params[:resource] if params[:resource].present?
          path << "/" << params[:method] if params[:method].present?
          
          author = {
            "@type": "Person",
            first_name: 'André',
            last_name: 'Aubin',
            username: 'andral',
            gender: 'male',
            "name": "André Aubin",
            "url": "https://plus.google.com/u/0/115378296196014576465",
            fb: {
              profile_id: 'andre.awbin'
            }
          }

          article = {
            published_time: Date.parse("2016-02-10"),
            modified_time: Date::today,
            author: author,
            "datePublished": Date.parse("2016-02-10"),
            "dateModified": Date::today,
            "description": description,
            "keywords": tags.join(', '),
            tag: tags
          }

          additional = {}
          if @resource && @method
            additional = {
              label1: "Method",
              data1: @method[:apis].try(:first).try(:fetch, :http_method, :GET).to_s,
              label2: "Endpoint",
              data2: "#{@resource[:name]}##{@method[:name].gsub(/^_/, "")}",
            }
          end

          set_meta_tags({
            title: title,
            description: description,
            keywords: tags.join(', '),
            author: "https://plus.google.com/u/0/115378296196014576465",
            publisher: "https://plus.google.com/u/0/115378296196014576465",
            og: {
              title: title,
              type: 'article',
              description: description,
              author: author,
              url: "#{path}.html",
              article: article
            },
            twitter: {
              card: "summary",
              site: "@42born2code",
              title: title,
              url: "#{path}.html",
              description: description
            }.merge(additional)
          })

          if @resource && @method
            render 'method'
          elsif @resource
            render 'resource'
          elsif params[:resource].present? || params[:method].present?
            render 'apipie_404', :status => 404
          else
            render 'index'
          end
        end
      end
    end

    def apipie_checksum
    end

    private
    helper_method :heading

    def get_language
      return nil unless Apipie.configuration.translate
      lang = Apipie.configuration.default_locale
      [:resource, :method, :version].each do |par|
        next unless params[par]
        splitted = params[par].split('.')
        if splitted.length > 1 && (Apipie.configuration.languages.include?(splitted.last) || Apipie.configuration.default_locale == splitted.last)
          lang = splitted.last
          params[par].sub!(".#{lang}", '')
        end
      end
      lang
    end

    def authorized_doc
      return if @doc.nil?
      return @doc unless Apipie.configuration.authorize

      new_doc = { :docs => @doc[:docs].clone }

      new_doc[:docs][:resources] = if @doc[:docs][:resources].kind_of?(Array)
        @doc[:docs][:resources].select do |resource|
          authorize_resource(resource)
        end
      else
        @doc[:docs][:resources].select do |_resource_id, resource|
          authorize_resource(resource)
        end
      end

      new_doc
    end

    def authorize_resource resource
      if instance_exec(resource[:id], nil, resource, &Apipie.configuration.authorize)
        resource[:methods] = resource[:methods].select do |m|
          instance_exec(resource[:id], m[:name], m, &Apipie.configuration.authorize)
        end
        true
      else
        false
      end
    end

    def get_format
      [:resource, :method, :version].each do |par|
        next unless params[par]
        [:html, :json].each do |format|
          extension = ".#{format}"
          if params[par].include?(extension)
            params[par] = params[par].sub(extension, '')
            params[:format] = format
          end
        end
      end
      request.format = params[:format] if params[:format]
    end

    def render_from_cache
      path = Apipie.configuration.doc_base_url.dup
      path << "/" << params[:version] if params[:version].present?
      path << "/" << params[:resource] if params[:resource].present?
      path << "/" << params[:method] if params[:method].present?
      # Sanitize path against directory traversal attacks (e.g. ../../foo)
      # by turning path into an absolute path before appending it to the cache dir
      path = File.expand_path("#{path}.#{request.format.symbol}", '/')

      cache_file = File.join(Apipie.configuration.cache_dir, path)
      if File.exist?(cache_file)
        content_type = case params[:format]
                       when "json" then "application/json"
                       else "text/html"
                       end
        send_file cache_file, :type => content_type, :disposition => "inline"
      else
        Rails.logger.error("API doc cache not found for '#{path}'. Perhaps you have forgot to run `rake apipie:cache`")
        head :not_found
      end
    end

    def set_script_name
      Apipie.request_script_name = request.env["SCRIPT_NAME"]
      yield
    ensure
      Apipie.request_script_name = nil
    end
  end
end
