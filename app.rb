require "sinatra"
require "haml"
require "securerandom"
require "tmpdir"
require "mini_magick"

get "/" do
  @params ||= {}
  haml :index
end

post "/" do
  begin
    generate_image
    @download_url = download_filepath
  rescue => e
    puts "Error: #{e.message}"
    puts e.backtrace
    @error = true
    haml :index
  end

  #@params = params
  haml :index
end

helpers do
  def output_filename
    return @output_filename if @output_filename
    @output_filename = "deck#{Time.now.strftime("%Y%m%d%H%M")}-#{SecureRandom.hex(4)}.png"
    @output_filename
  end

  def base_dir
    "public/images"
  end

  def output_filepath
    return @output_filepath if @output_filepath
    FileUtils.mkdir_p(base_dir)
    @output_filepath = File.join(base_dir, output_filename)
    @output_filepath
  end

  def download_filepath
    return @download_filepath if @download_filepath
    @download_filepath = "#{base_url}/#{base_dir.gsub(/\Apublic\//, "")}/#{output_filename}"
    @download_filepath
  end

  def generate_image
    Dir.mktmpdir do |dir|
      a_path = params["ss1"]["tempfile"].path
      b_path = params["ss2"]["tempfile"].path
      #raise "b is not png." if /\.png\z/ =~ b_path
      a = MiniMagick::Image.open(a_path)
      raise "a.type is invalid: <#{a.type}>" if /\A(png|jpe?g)\z/i !~ a.type

      ratio = a.width * 1.0 / 1080
      header_top = 74 * ratio
      header_bottom = 249 * ratio
      header_height = header_bottom - header_top
      main_a_top = 372 * ratio
      main_a_bottom = 1500 * ratio
      main_a_height = main_a_bottom - main_a_top
      main_b_top = 354 * ratio
      main_b_bottom = 635 * ratio
      main_b_height = main_b_bottom - main_b_top
      extra_top = 945 * ratio
      extra_bottom = 1230 * ratio
      extra_height = extra_bottom - extra_top

      main_b = params["n_cards"] == "30"

      MiniMagick::Tool::Convert.new do |convert|
        convert << a_path
        convert.crop("#{a.width}x#{header_height}+0+#{header_top}")
        convert << "#{dir}/header.png"
      end
      MiniMagick::Tool::Convert.new do |convert|
        convert << a_path
        convert.crop("#{a.width}x#{main_a_height}+0+#{main_a_top}")
        convert << "#{dir}/main_a.png"
      end
      if main_b
        MiniMagick::Tool::Convert.new do |convert|
          convert << b_path
          convert.crop("#{a.width}x#{main_b_height}+0+#{main_b_top}")
          convert << "#{dir}/main_b.png"
        end
      end
      MiniMagick::Tool::Convert.new do |convert|
        convert << b_path
        convert.crop("#{a.width}x#{extra_height}+0+#{extra_top}")
        convert << "#{dir}/extra.png"
      end

      MiniMagick::Tool::Convert.new do |convert|
        convert.append
        convert << "#{dir}/header.png"
        convert << "#{dir}/main_a.png"
        if main_b
          convert << "#{dir}/main_b.png"
        end
        convert << "#{dir}/extra.png"
        convert << "#{dir}/output.png"
      end

      if params["copyright"] == "1"
        if ratio != 1.0
          width = 630 * ratio
          height = 72 * ratio
          MiniMagick::Tool::Convert.new do |convert|
            convert << "assets/images/copyright.png"
            convert << "-resize" << "#{width}x#{height}"
            convert << "#{dir}/copyright.png"
          end
        else
          FileUtils.cp("assets/images/copyright.png", "#{dir}/")
        end

        MiniMagick::Tool::Convert.new do |convert|
          convert << "#{dir}/output.png"
          convert << "#{dir}/copyright.png"
          convert << "-gravity" << "southeast"
          convert << "-compose" << "over"
          convert << "-composite" << "#{dir}/output.png"
        end
      end

      FileUtils.mv("#{dir}/output.png", output_filepath)
    end
  end

  def base_url
    parts_of_url = {
      :scheme => request.scheme,
      :host   => request.host,
      :port   => request.port,
      :path   => request.script_name,
    }
    URI::Generic.build(parts_of_url).to_s.gsub(/(#{request.scheme}:\/\/#{request.host}):80/, '\1')
  end
end
