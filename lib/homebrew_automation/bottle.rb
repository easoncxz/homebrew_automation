
require 'json'

require_relative './brew.rb'

module HomebrewAutomation

  # Metadata for building a Bottle for a Homebrew package
  class Bottle

    class Error < StandardError

      attr_reader :original

      def initialize(msg, original:)
        @original = original
        super(msg)
      end

    end

    # @param tap_name [String] For use with +brew tap+
    # @param tap_url [String] Something suitable for +git clone+, e.g. +git@github.com:easoncxz/homebrew-tap.git+ or +/some/path/to/my-git-repo+
    # @param formula_name [String] As known by Homebrew
    # @param os_name [String] As known by Homebrew, e.g. +el_capitan+
    # @param keep_tmp [Boolean] pass +--keep-tmp+ to +brew+
    # @param brew [Brew] Homebrew effects
    # @param bottle_finder [Bottle] Bottle-related filesystem effects
    def initialize(
        tap_name,
        tap_url,
        formula_name,
        os_name,
        keep_tmp: false,
        brew: Brew,
        bottle_finder: Bottle)
      @tap_name = tap_name
      @tap_url = tap_url
      @formula_name = formula_name
      @os_name = os_name
      @keep_tmp = keep_tmp
      @brew = brew
      @bottle_finder = bottle_finder
    end

    # Build the bottle and get a binary tarball suitable for upload to Bintray
    #
    # Unless you've already run +brew install --build-bottle+ on that Formula
    # on your system before, the returned effect would take ages to run (looking
    # at about 30-60 minutes).
    #
    # @yieldparam filename [String] A filename to tell Bintray which Homebrew can
    #   recognise
    # @yieldparam contents [String] The data of the binary Bottle tarball, as if
    #   read via {File#read}
    # @return [NilClass]
    def build!(&block)
      raise StandardError, "Bottle#build! expects a block" unless block
      call_brew! do
        json_str = @bottle_finder.read_json!
        (minus_minus, filename) = parse_for_tarball_path(json_str)
        contents = @bottle_finder.read_tarball! minus_minus
        block.call(filename, contents)
      end
    end

    def self.read_json!
      json_filename = Dir['*.bottle.json'].first
      File.read(json_filename)
    end

    def self.read_tarball!(minus_minus)
      File.read(minus_minus)
    end

    private

    # tap, install, and bottle
    def call_brew!(&block)
      tapped = false
      begin
        @brew.tap!(@tap_name, @tap_url)
        tapped = true
        # TODO: @brew.list! may print a worrying "Error" message if Formula wasn't installed:
        if @brew.list!([], fully_qualified_formula_name)
          # TODO: This doesn't seem to work. Carefully test.
          # passing `--force` to uninstall all versions
          @brew.uninstall!(['--force'], fully_qualified_formula_name)
        end
        @brew.install!(
          %w[--verbose --build-bottle --force] + if @keep_tmp then %w[--keep-tmp] else [] end,
          fully_qualified_formula_name)
        @brew.bottle!(
          %w[--verbose --json --no-rebuild],
          fully_qualified_formula_name)
        block.call
      ensure
        @brew.untap! @tap_name if tapped
      end
    end

    # pure-ish; raises exception
    #
    # @return [Tuple<String, String>] +[minus_minus, filename]+
    def parse_for_tarball_path(json_str)
      begin
        json = JSON.parse(json_str)
        focus = json
        [fully_qualified_formula_name, 'bottle', 'tags', @os_name].each do |key|
          focus = focus[key]
          if focus.nil?
            raise Error.new(
              "unexpected JSON structure, couldn't find key: #{key}",
              original: json)
          end
        end
        # https://github.com/Homebrew/brew/pull/4612
        minus_minus, filename = focus['local_filename'], focus['filename']
        if minus_minus.nil? || filename.nil?
          raise Error.new(
            "unexpected JSON structure, couldn't find both `local_filename` and `filename` keys: #{minus_minus.inspect}, #{filename.inspect}",
            original: json)
        end
        [minus_minus, filename]
      rescue JSON::ParserError => e
        raise Error.new(
          "error parsing JSON: #{e}",
          original: json_str)
      end
    end

    def fully_qualified_formula_name
      @tap_name + '/' + @formula_name
    end

  end

end
