module Miro
  class DominantColors
    attr_accessor :src_image_path

    def initialize(src_image_path, image_type = nil)
      @src_image_path = src_image_path	
      @image_type = image_type
    end

    def to_hex
      return histogram.map{ |item| item[1].html } if Miro.histogram?
      sorted_pixels.collect { |pixel| ChunkyPNG::Color.to_hex(pixel, false) }
    end

    def to_rgb
      return histogram.map { |item| item[1].to_rgb.to_a } if Miro.histogram?
      sorted_pixels.collect { |pixel| ChunkyPNG::Color.to_truecolor_bytes(pixel) }
    end

    def to_rgba
      return histogram.map { |item| item[1].css_rgba } if Miro.histogram?
      sorted_pixels.collect { |pixel| ChunkyPNG::Color.to_truecolor_alpha_bytes(pixel) }
    end

   def to_hsl
      histogram.map { |item| item[1].to_hsl.to_a } if Miro.histogram?
    end

    def to_cmyk
      histogram.map { |item| item[1].to_cmyk.to_a } if Miro.histogram?
    end

    def to_yiq
      histogram.map { |item| item[1].to_yiq.to_a } if Miro.histogram?
    end

    def by_percentage
      return nil if Miro.histogram?
      sorted_pixels
      pixel_count = @pixels.size
      sorted_pixels.collect { |pixel| @grouped_pixels[pixel].size / pixel_count.to_f }
    end

    def sorted_pixels
      @sorted_pixels ||= extract_colors_from_image
    end

    def histogram
      @histogram || downsample_and_histogram.sort_by { |item| item[0]  }.reverse
    end
  private

    def downsample_and_histogram
      @source_image = open_source_image
      hstring = Cocaine::CommandLine.new(Miro.options[:image_magick_path], image_magick_params).
        run(:in => File.expand_path(@source_image.path),
            :resolution => Miro.options[:resolution],
            :colors => Miro.options[:color_count].to_s,
            :quantize => Miro.options[:quantize])
      cleanup_temporary_files!
      parse_result(hstring)
    end

    def parse_result(hstring)
      hstring.scan(/(\d*):.*(#[0-9A-Fa-f]*)/).collect do |match|
        [match[0].to_i, Object.const_get("Color::#{Miro.options[:quantize].upcase}").from_html(match[1])]
      end
    end

    def extract_colors_from_image
      downsample_colors_and_convert_to_png!
      colors = sort_by_dominant_color
      cleanup_temporary_files!
      colors
    end

    def downsample_colors_and_convert_to_png!
      @source_image = open_source_image
      @downsampled_image = open_downsampled_image
	  @in = @source_image
	  @out = @downsampled_image	 
	  
      Cocaine::CommandLine.new(Miro.options[:image_magick_path], image_magick_params).
        run(in: @in,
            resolution: Miro.options[:resolution],
            colors: Miro.options[:color_count].to_s,
            quantize: Miro.options[:quantize],
            out: @out)
			
    end

    def open_source_image
      return File.open(@src_image_path) unless remote_source_image?
      original_extension = @image_type || URI.parse(@src_image_path).path.split('.').last
	  hash = Digest::SHA1.hexdigest @src_image_path
	  temp_dir = Dir.tmpdir() 
	  path = "#{temp_dir}/#{hash}.#{original_extension}"
	  FileUtils.touch(path)	      
	  open(path, 'wb') do |file|
	    file << open(@src_image_path).read
	  end
      path
    end

    def open_downsampled_image
		temp_dir = Dir.tmpdir() 
		hash = Digest::SHA1.hexdigest "#{@src_image_path}"
		path = "#{temp_dir}/#{hash}-downsampled.png"
		FileUtils.touch(path)
		tempfile = File.open(path)
		tempfile.binmode
		tempfile.close
		path
    end

    def image_magick_params
      if Miro.histogram?
        ":in -resize :resolution -colors :colors -colorspace :quantize -quantize :quantize -alpha remove -format %c histogram:info:"
      else
        ":in -resize :resolution -colors :colors -colorspace :quantize -quantize :quantize :out"
      end
    end

    def group_pixels_by_color
      @pixels ||= ChunkyPNG::Image.from_file(File.expand_path(@downsampled_image)).pixels
      @grouped_pixels ||= @pixels.group_by { |pixel| pixel }
    end

    def sort_by_dominant_color
      group_pixels_by_color.sort_by { |k,v| v.size }.reverse.flatten.uniq
    end

    def cleanup_temporary_files!     
	  FileUtils.rm_rf(@source_image)
	  FileUtils.rm_rf(@downsampled_image)
    end

    def remote_source_image?
      @src_image_path =~ /^https?:\/\//
    end
  end
end
