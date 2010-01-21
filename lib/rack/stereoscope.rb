require 'markaby'
require 'json'
require 'nokogiri'
require 'rack/accept_media_types'
require 'addressable/template'

# Rack::Stereoscope - bringing a new dimension to your RESTful API
#
# Stereoscope is inspired by the idea that software should be explorable. Put
# stereoscope in front of your RESTful API, and you get an interactive,
# explorable HTML interface to your API for free. Use it to manually test your
# API from a browser. Use it to make your API self-documenting. Use it to
# quickly prototype new API features and get a visual feel for the data
# structures.
#
# Stereoscope is designed to be unobtrusive. It will not interpose itself unless
# the request asks for HTML (i.e. it comes from a browser). If the request
# requests no explicit content type; or if it requests a content-type other than
# HTML, Stereoscope stays out of the way.
#
# This middleware is especially well-suited to presenting APIs that are heavily
# hyperlinked (and if your API doesn't have hyperlinks, why
# not?[1]). Stereoscope does it's best to recognize URLs and make them
# clickable. What's more, Stereoscope supports URI Templates[2]. If your data
# includes URL templates such as the following:
# 
#     http://example.org/{foo}?bar={bar}
#
# Stereoscope will render a form which enables the user to experiment with
# different expansions of the URI template.
#
# Limitations:
#   * Currently only supports JSON data
#   * Only link-ifies fully-qualified URLs; relative URLs are not supported
#   * Read-only exploration; no support for POSTs, PUTs, or DELETEs.
#
# [1] http://www.theamazingrando.com/blog/?p=107
# [2] http://bitworking.org/projects/URI-Templates/
module Rack
  class Stereoscope
    def initialize(app)
      @app = app
    end

    def call(env)
      request = Rack::Request.new(env)
      if Rack::AcceptMediaTypes.new(env['HTTP_ACCEPT']).include?('text/html')
        status, headers, body = @app.call(env)
        if request.path == '/__stereoscope_expand_template__'
          expand_template(request)
        else
          present_data(request, status, headers, body)
        end
      else
        @app.call(env)
      end
    end

    def present_data(request, status, headers, body)
      response = Rack::Response.new("", status, headers)
      response.write(build_page(body, request, response))
      response['Content-Type'] = 'text/html'
      response.finish
    end

    def expand_template(request)
      template = Addressable::Template.new(request['__template__'])
      url      = template.expand(request.params)
      response = Rack::Response.new
      response.redirect(url.to_s)
      response.finish
    end

    def build_page(content, request, response)
      this = self
      mab = Markaby::Builder.new
      mab.html do 
        head do 
          title request.path
        end
        body do
          
          h1 "#{response.status} #{request.url}"
          h2 "Headers"
          div do
            this.data_to_html(response.headers, mab)
          end
          if !content.to_s.empty?
            h2 "Response:"
            case response.content_type
            when 'application/json' then
              div do
                this.data_to_html(JSON.parse(content.join), mab)
              end
            when 'text/plain' then
              p content.join
            else
              text Nokogiri::HTML(content.join).css('body').inner_html
            end
          else
            p "(No content)"
          end
          h2 "Raw:"
          tt do
            raw_content = case response.content_type
                          when 'application/json'
                            JSON.pretty_generate(JSON.parse(content.join))
                          else
                            content.join
                          end
            pre raw_content
          end
        end
      end
      mab.to_s
    end

    def data_to_html(data, builder)
      this = self
      case data
      when Hash
        builder.dl do
          data.each_pair do |key, value|
            dt do 
              this.data_to_html(key, builder)
            end
            dd do
              this.data_to_html(value, builder)
            end
          end
        end
      when Array
        if tabular?(data)
          table_to_html(data, builder)
        else
          list_to_html(data, builder)
        end
      when String
        if url?(data)
          if url_template?(data)
            template_to_html(data, builder)
          else
            url_to_html(data, builder)
          end
        else
          builder.div do
            data.split("\n").each do |line|
              builder.span line
              builder.br
            end
          end
        end
      else
        builder.span do data end
      end
    end

    def url?(text)
      Addressable::URI.parse(text.to_s).ip_based?
    end

    def url_template?(text)
      !Addressable::Template.new(text.to_s).variables.empty?
    end

    def tabular?(data)
      data.kind_of?(Array) &&
        data.all?{|e| e.kind_of?(Hash)} &&
        data[1..-1].all?{|e| e.keys == data.first.keys}
    end

    def url_to_html(url, builder)
      builder.a(url.to_s, :href => url.to_s)      
    end

    def template_to_html(text, builder)
      template = Addressable::Template.new(text)
      builder.div(:class => 'url-template-form') do
        p text
        form(:method => 'GET', :action => '/__stereoscope_expand_template__') do
          input(:type => 'hidden', :name => '__template__', :value => text)
          template.variables.each do |variable|
            div(:class => 'url-template-variable') do
              label do
                text "#{variable}: "
                input(
                  :type => 'text', 
                  :name => variable, 
                  :value => template.variable_defaults[variable])
              end
            end
          end
          input(:type => 'submit')
        end
      end
    end

    def list_to_html(data, builder)
      this = self
      builder.ol do
        data.each do |value|
          li do
            this.data_to_html(value, builder)
          end
        end
      end
    end

    def table_to_html(data, builder)
      this = self
      builder.table do
        headers = data.first.keys
        thead do 
          headers.each do |header| 
            th do
              this.data_to_html(header, builder) 
            end
          end
        end
        tbody do
          data.each do |row|
            tr do
              row.each do |key, value|
                td do
                  this.data_to_html(value, builder)
                end
              end
            end
          end
        end
      end
    end
  end
end
