# typed: true

# DO NOT EDIT MANUALLY
# This is an autogenerated file for types exported from the `autoprefixer-rails` gem.
# Please instead update this file by running `bin/tapioca gem autoprefixer-rails`.

# source://autoprefixer-rails//lib/autoprefixer-rails/railtie.rb#10
module AutoprefixedRails; end

# source://autoprefixer-rails//lib/autoprefixer-rails/railtie.rb#11
class AutoprefixedRails::Railtie < ::Rails::Railtie
  # source://autoprefixer-rails//lib/autoprefixer-rails/railtie.rb#28
  def config; end

  # source://autoprefixer-rails//lib/autoprefixer-rails/railtie.rb#49
  def roots; end
end

# Ruby integration with Autoprefixer JS library, which parse CSS and adds
# only actual prefixed
#
# source://autoprefixer-rails//lib/autoprefixer-rails.rb#5
module AutoprefixerRails
  class << self
    # Add Autoprefixer for Sprockets environment in `assets`.
    # You can specify `browsers` actual in your project.
    #
    # source://autoprefixer-rails//lib/autoprefixer-rails.rb#21
    def install(assets, params = T.unsafe(nil)); end

    # Add prefixes to `css`. See `Processor#process` for options.
    #
    # source://autoprefixer-rails//lib/autoprefixer-rails.rb#9
    def process(css, opts = T.unsafe(nil)); end

    # Cache processor instances
    #
    # source://autoprefixer-rails//lib/autoprefixer-rails.rb#32
    def processor(params = T.unsafe(nil)); end

    # Disable installed Autoprefixer
    #
    # source://autoprefixer-rails//lib/autoprefixer-rails.rb#27
    def uninstall(assets); end
  end
end

# Ruby to JS wrapper for Autoprefixer processor instance
#
# source://autoprefixer-rails//lib/autoprefixer-rails/processor.rb#11
class AutoprefixerRails::Processor
  # @return [Processor] a new instance of Processor
  #
  # source://autoprefixer-rails//lib/autoprefixer-rails/processor.rb#14
  def initialize(params = T.unsafe(nil)); end

  # Return, which browsers and prefixes will be used
  #
  # source://autoprefixer-rails//lib/autoprefixer-rails/processor.rb#52
  def info; end

  # Parse Browserslist config
  #
  # source://autoprefixer-rails//lib/autoprefixer-rails/processor.rb#57
  def parse_config(config); end

  # Process `css` and return result.
  #
  # Options can be:
  # * `from` with input CSS file name. Will be used in error messages.
  # * `to` with output CSS file name.
  # * `map` with true to generate new source map or with previous map.
  #
  # source://autoprefixer-rails//lib/autoprefixer-rails/processor.rb#24
  def process(css, opts = T.unsafe(nil)); end

  private

  # source://autoprefixer-rails//lib/autoprefixer-rails/processor.rb#159
  def build_js; end

  # Convert ruby_options to jsOptions
  #
  # source://autoprefixer-rails//lib/autoprefixer-rails/processor.rb#99
  def convert_options(opts); end

  # Try to find Browserslist config
  #
  # source://autoprefixer-rails//lib/autoprefixer-rails/processor.rb#114
  def find_config(file); end

  # source://autoprefixer-rails//lib/autoprefixer-rails/processor.rb#77
  def params_with_browsers(from = T.unsafe(nil)); end

  # Lazy load for JS library
  #
  # source://autoprefixer-rails//lib/autoprefixer-rails/processor.rb#131
  def runtime; end
end

# source://autoprefixer-rails//lib/autoprefixer-rails/processor.rb#12
AutoprefixerRails::Processor::SUPPORTED_RUNTIMES = T.let(T.unsafe(nil), Array)

# Container of prefixed CSS and source map with changes
#
# source://autoprefixer-rails//lib/autoprefixer-rails/result.rb#5
class AutoprefixerRails::Result
  # @return [Result] a new instance of Result
  #
  # source://autoprefixer-rails//lib/autoprefixer-rails/result.rb#15
  def initialize(css, map, warnings); end

  # Prefixed CSS after Autoprefixer
  #
  # source://autoprefixer-rails//lib/autoprefixer-rails/result.rb#7
  def css; end

  # Source map of changes
  #
  # source://autoprefixer-rails//lib/autoprefixer-rails/result.rb#10
  def map; end

  # Stringify prefixed CSS
  #
  # source://autoprefixer-rails//lib/autoprefixer-rails/result.rb#22
  def to_s; end

  # Warnings from Autoprefixer
  #
  # source://autoprefixer-rails//lib/autoprefixer-rails/result.rb#13
  def warnings; end
end

# Register autoprefixer postprocessor in Sprockets and fix common issues
#
# source://autoprefixer-rails//lib/autoprefixer-rails/sprockets.rb#7
class AutoprefixerRails::Sprockets
  # Sprockets 2 API new and render
  #
  # @return [Sprockets] a new instance of Sprockets
  #
  # source://autoprefixer-rails//lib/autoprefixer-rails/sprockets.rb#54
  def initialize(filename); end

  # Sprockets 2 API new and render
  #
  # source://autoprefixer-rails//lib/autoprefixer-rails/sprockets.rb#60
  def render(*_arg0); end

  class << self
    # Sprockets 3 and 4 API
    #
    # source://autoprefixer-rails//lib/autoprefixer-rails/sprockets.rb#13
    def call(input); end

    # Register postprocessor in Sprockets depend on issues with other gems
    #
    # source://autoprefixer-rails//lib/autoprefixer-rails/sprockets.rb#32
    def install(env); end

    # source://autoprefixer-rails//lib/autoprefixer-rails/sprockets.rb#8
    def register_processor(processor); end

    # Add prefixes to `css`
    #
    # source://autoprefixer-rails//lib/autoprefixer-rails/sprockets.rb#20
    def run(filename, css); end

    # Register postprocessor in Sprockets depend on issues with other gems
    #
    # source://autoprefixer-rails//lib/autoprefixer-rails/sprockets.rb#43
    def uninstall(env); end
  end
end

# source://autoprefixer-rails//lib/autoprefixer-rails/version.rb#4
AutoprefixerRails::VERSION = T.let(T.unsafe(nil), String)

# source://autoprefixer-rails//lib/autoprefixer-rails/processor.rb#7
IS_SECTION = T.let(T.unsafe(nil), Regexp)
