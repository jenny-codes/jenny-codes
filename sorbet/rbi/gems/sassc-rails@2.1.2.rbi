# typed: true

# DO NOT EDIT MANUALLY
# This is an autogenerated file for types exported from the `sassc-rails` gem.
# Please instead update this file by running `bin/tapioca gem sassc-rails`.

# source://sassc-rails//lib/sassc/rails/version.rb#3
module SassC
  class << self
    # source://sassc/2.4.0/lib/sassc.rb#21
    def load_paths; end
  end
end

# source://sassc-rails//lib/sassc/rails/version.rb#4
module SassC::Rails; end

# source://sassc-rails//lib/sassc/rails/importer.rb#7
class SassC::Rails::Importer < ::SassC::Importer
  # source://sassc-rails//lib/sassc/rails/importer.rb#89
  def imports(path, parent_path); end

  private

  # source://sassc-rails//lib/sassc/rails/importer.rb#139
  def context; end

  # source://sassc-rails//lib/sassc/rails/importer.rb#129
  def extension_for_file(file); end

  # source://sassc-rails//lib/sassc/rails/importer.rb#147
  def glob_imports(base, glob, current_file); end

  # @raise [ArgumentError]
  #
  # source://sassc-rails//lib/sassc/rails/importer.rb#158
  def globbed_files(base, glob); end

  # source://sassc-rails//lib/sassc/rails/importer.rb#143
  def load_paths; end

  # source://sassc-rails//lib/sassc/rails/importer.rb#135
  def record_import_as_dependency(path); end
end

# source://sassc-rails//lib/sassc/rails/importer.rb#20
class SassC::Rails::Importer::CSSExtension
  # source://sassc-rails//lib/sassc/rails/importer.rb#25
  def import_for(full_path, parent_dir, options); end

  # source://sassc-rails//lib/sassc/rails/importer.rb#21
  def postfix; end
end

# source://sassc-rails//lib/sassc/rails/importer.rb#42
class SassC::Rails::Importer::CssSassExtension < ::SassC::Rails::Importer::Extension
  # source://sassc-rails//lib/sassc/rails/importer.rb#47
  def import_for(full_path, parent_dir, options); end

  # source://sassc-rails//lib/sassc/rails/importer.rb#43
  def postfix; end
end

# source://sassc-rails//lib/sassc/rails/importer.rb#31
class SassC::Rails::Importer::CssScssExtension < ::SassC::Rails::Importer::Extension
  # source://sassc-rails//lib/sassc/rails/importer.rb#36
  def import_for(full_path, parent_dir, options); end

  # source://sassc-rails//lib/sassc/rails/importer.rb#32
  def postfix; end
end

# source://sassc-rails//lib/sassc/rails/importer.rb#67
class SassC::Rails::Importer::ERBExtension < ::SassC::Rails::Importer::Extension
  # source://sassc-rails//lib/sassc/rails/importer.rb#68
  def import_for(full_path, parent_dir, options); end
end

# source://sassc-rails//lib/sassc/rails/importer.rb#75
SassC::Rails::Importer::EXTENSIONS = T.let(T.unsafe(nil), Array)

# source://sassc-rails//lib/sassc/rails/importer.rb#8
class SassC::Rails::Importer::Extension
  # @return [Extension] a new instance of Extension
  #
  # source://sassc-rails//lib/sassc/rails/importer.rb#11
  def initialize(postfix = T.unsafe(nil)); end

  # source://sassc-rails//lib/sassc/rails/importer.rb#15
  def import_for(full_path, parent_dir, options); end

  # Returns the value of attribute postfix.
  #
  # source://sassc-rails//lib/sassc/rails/importer.rb#9
  def postfix; end
end

# source://sassc-rails//lib/sassc/rails/importer.rb#87
SassC::Rails::Importer::GLOB = T.let(T.unsafe(nil), Regexp)

# source://sassc-rails//lib/sassc/rails/importer.rb#86
SassC::Rails::Importer::PREFIXS = T.let(T.unsafe(nil), Array)

# source://sassc-rails//lib/sassc/rails/importer.rb#54
class SassC::Rails::Importer::SassERBExtension < ::SassC::Rails::Importer::Extension
  # source://sassc-rails//lib/sassc/rails/importer.rb#59
  def import_for(full_path, parent_dir, options); end

  # source://sassc-rails//lib/sassc/rails/importer.rb#55
  def postfix; end
end

# source://sassc-rails//lib/sassc/rails/railtie.rb#7
class SassC::Rails::Railtie < ::Rails::Railtie; end

# source://sassc-rails//lib/sassc/rails/template.rb#8
class SassC::Rails::SassTemplate < ::Sprockets::SassProcessor
  # @return [SassTemplate] a new instance of SassTemplate
  #
  # source://sassc-rails//lib/sassc/rails/template.rb#9
  def initialize(options = T.unsafe(nil), &block); end

  # source://sassc-rails//lib/sassc/rails/template.rb#21
  def call(input); end

  # source://sassc-rails//lib/sassc/rails/template.rb#46
  def config_options; end

  # @return [Boolean]
  #
  # source://sassc-rails//lib/sassc/rails/template.rb#69
  def line_comments?; end

  # source://sassc-rails//lib/sassc/rails/template.rb#65
  def load_paths; end

  # source://sassc-rails//lib/sassc/rails/template.rb#73
  def safe_merge(_key, left, right); end

  # source://sassc-rails//lib/sassc/rails/template.rb#61
  def sass_style; end
end

# The methods in the Functions module were copied here from sprockets in order to
# override the Value class names (e.g. ::SassC::Script::Value::String)
#
# source://sassc-rails//lib/sassc/rails/template.rb#85
module SassC::Rails::SassTemplate::Functions
  # source://sassc-rails//lib/sassc/rails/template.rb#101
  def asset_data_url(path); end

  # source://sassc-rails//lib/sassc/rails/template.rb#86
  def asset_path(path, options = T.unsafe(nil)); end

  # source://sassc-rails//lib/sassc/rails/template.rb#97
  def asset_url(path, options = T.unsafe(nil)); end
end

# source://sassc-rails//lib/sassc/rails/template.rb#108
class SassC::Rails::ScssTemplate < ::SassC::Rails::SassTemplate
  class << self
    # source://sassc-rails//lib/sassc/rails/template.rb#109
    def syntax; end
  end
end

# source://sassc-rails//lib/sassc/rails/version.rb#5
SassC::Rails::VERSION = T.let(T.unsafe(nil), String)

# source://sassc/2.4.0/lib/sassc/version.rb#4
SassC::VERSION = T.let(T.unsafe(nil), String)

# source://sassc-rails//lib/sassc/rails/functions.rb#5
module Sprockets
  extend ::Sprockets::Utils
  extend ::Sprockets::URIUtils
  extend ::Sprockets::PathUtils
  extend ::Sprockets::DigestUtils
  extend ::Sprockets::PathDigestUtils
  extend ::Sprockets::Dependencies
  extend ::Sprockets::Compressing
  extend ::Sprockets::Processing
  extend ::Sprockets::HTTPUtils
  extend ::Sprockets::Transformers
  extend ::Sprockets::Engines
  extend ::Sprockets::Mime
  extend ::Sprockets::Paths
end

# source://sprockets/3.7.2/lib/sprockets/legacy.rb#18
Sprockets::Index = Sprockets::CachedEnvironment

# source://sassc-rails//lib/sassc/rails/compressor.rb#6
class Sprockets::SassCompressor
  # @return [SassCompressor] a new instance of SassCompressor
  #
  # source://sassc-rails//lib/sassc/rails/compressor.rb#7
  def initialize(options = T.unsafe(nil)); end

  # source://sprockets/3.7.2/lib/sprockets/sass_compressor.rb#35
  def cache_key; end

  # source://sassc-rails//lib/sassc/rails/compressor.rb#17
  def call(*args); end

  # sprockets 2.x
  #
  # source://sassc-rails//lib/sassc/rails/compressor.rb#17
  def evaluate(*args); end

  class << self
    # source://sprockets/3.7.2/lib/sprockets/sass_compressor.rb#31
    def cache_key; end

    # source://sprockets/3.7.2/lib/sprockets/sass_compressor.rb#27
    def call(input); end

    # source://sprockets/3.7.2/lib/sprockets/sass_compressor.rb#23
    def instance; end
  end
end

# source://sprockets/3.7.2/lib/sprockets/sass_compressor.rb#18
Sprockets::SassCompressor::VERSION = T.let(T.unsafe(nil), String)

# source://sprockets/3.7.2/lib/sprockets/sass_processor.rb#291
Sprockets::SassFunctions = Sprockets::SassProcessor::Functions

# source://sprockets/3.7.2/lib/sprockets/version.rb#2
Sprockets::VERSION = T.let(T.unsafe(nil), String)
