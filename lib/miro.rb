require "miro/version"
require "oily_png"
require "cocaine"
require "color"
require "tempfile"
require "open-uri"
require 'fileutils'
require 'net/https'
require 'tmpdir'
require 'digest/sha1'
require "miro/dominant_colors"

module Miro
  class << self
    def options
      convert = '' #`which convert`.strip
      @options ||= {
        :image_magick_path  => convert.length > 0 ? convert : '/usr/bin/convert',
        :resolution         => "150x150",
        :color_count        => 8,
        :quantize           => 'RGB',
        :method             => 'pixel_group'
      }
    end
    def pixel_group?
      options[:method] == 'pixel_group'
    end

    def histogram?
      options[:method] == 'histogram'
    end
  end
end

module Kernel
  if !self.methods.include?(:silence_warnings)
    def silence_warnings
      old_verbose, $VERBOSE = $VERBOSE, nil
      yield
    ensure
      $VERBOSE = old_verbose
    end
  end
end

silence_warnings do
	OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE
end
