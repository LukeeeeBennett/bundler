# frozen_string_literal: true

module Bundler
  # General purpose class for retrying code that may fail
  class Retry
    attr_accessor :name, :total_runs, :current_run

    class << self
      def default_attempts
        default_retries + 1
      end
      alias_method :attempts, :default_attempts

      def default_retries
        Bundler.settings[:retry]
      end

      def default_backoff
        Bundler.settings[:backoff]
      end
    end

    def initialize(name, exceptions = nil, retries = self.class.default_retries, backoff = self.class.default_backoff)
      @name = name
      @retries = retries
      @backoff = backoff
      @exceptions = Array(exceptions) || []
      @total_runs = @retries + 1 # will run once, then upto attempts.times
    end

    def attempt(&block)
      @current_run = 0
      @failed      = false
      @error       = nil
      run(&block) while keep_trying?
      @result
    end
    alias_method :attempts, :attempt

  private

    def run(&block)
      @failed = false
      @current_run += 1
      @result = block.call
    rescue StandardError => e
      fail_attempt(e)
    end

    def fail_attempt(e)
      @failed = true
      if last_attempt? || @exceptions.any? {|k| e.is_a?(k) }
        Bundler.ui.info "" unless Bundler.ui.debug?
        raise e
      end
      return true unless name
      Bundler.ui.info "" unless Bundler.ui.debug? # Add new line incase dots preceded this
      Bundler.ui.warn "Retrying #{name} in #{backoff_duration} seconds due to error (#{current_run.next}/#{total_runs}): #{e.class} #{e.message}", Bundler.ui.debug?
      sleep backoff_duration
    end

    def keep_trying?
      return true  if current_run.zero?
      return false if last_attempt?
      return true  if @failed
    end

    def last_attempt?
      current_run >= total_runs
    end

    def backoff_duration
      2 ** (@backoff + @current_run - 1)
    end
  end
end
