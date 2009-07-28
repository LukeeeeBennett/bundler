module Bundler
  class InvalidRepository < StandardError ; end

  class Repository

    attr_reader :path

    def initialize(path)
      @path = Pathname.new(path)
      unless valid?
        raise InvalidRepository, "'#{path}' is not a valid gem repository"
      end
    end

    # Returns the source index for all gems installed in the
    # repository
    def source_index
      Gem::SourceIndex.from_gems_in(@path.join("specifications"))
    end

    def valid?
      (Dir[@path.join("*")] - Dir[@path.join("{cache,doc,gems,environments,specifications}")]).empty?
    end

    # Checks whether a gem is installed
    def install_cached_gems(options = {})
      cached_gems.each do |name, version|
        unless installed?(name, version)
          install_cached_gem(name, version, options)
        end
      end
    end

    def install_cached_gem(name, version, options = {})
      cached_gem = cache_path.join("#{name}-#{version}.gem")
      if cached_gem.file?
        Bundler.logger.info "Installing #{name}-#{version}.gem"
        installer = Gem::Installer.new(cached_gem.to_s, options.merge(
          :install_dir         => @path,
          :ignore_dependencies => true,
          :env_shebang         => true,
          :wrappers            => true
        ))
        installer.install
      end
    end

  private

    def cache_path
      @path.join("cache")
    end

    def cache_files
      Dir[cache_path.join("*.gem")]
    end

    def cached_gems
      cache_files.map do |f|
        full_name = File.basename(f).gsub(/\.gem$/, '')
        full_name.split(/-(?=[\d.]+$)/)
      end
    end

    def spec_path
      @path.join("specifications")
    end

    def spec_files
      Dir[spec_path.join("*.gemspec")]
    end

    def gem_path
      @path.join("gems")
    end

    def gems
      Dir[gem_path.join("*")]
    end

    def installed?(name, version)
      spec_files.any? { |g| File.basename(g) == "#{name}-#{version}.gemspec" } &&
        gems.any? { |g| File.basename(g) == "#{name}-#{version}" }
    end

  end
end