require 'sitediff/uriwrapper'
require 'typhoeus'

class SiteDiff
  class Fetch
    # Cache is a cache object, see sitediff/cache
    # Paths is a list of sub-paths
    # Tags is a hash of tag names => base URLs.
    def initialize(cache, paths, tags)
      @cache = cache
      @paths = paths
      @tags = tags
    end

    # Fetch all the paths, once per tag.
    # When a path has been fetched for every tag, block will be called with the
    # path, and a hash of tag => UriWrapper::ReadResult objects.
    def run(&block)
      @callback = block
      @hydra = Typhoeus::Hydra.new(max_concurrency: 3)
      @paths.each { |path| queue_path(path) }
      @hydra.run
    end

    private

    # Queue a path for fetching
    def queue_path(path)
      results = {}

      @tags.each do |tag, base|
        if (res = @cache.get(tag, path))
          results[tag] = res
          process_results(path, results)
        elsif !base
          # We only have the cache, but this item isn't cached!
          results[tag] = UriWrapper::ReadResult.error('Not cached')
          process_results(path, results)
        else
          uri = UriWrapper.new(base + path)
          uri.queue(@hydra) do |resl|
            @cache.set(tag, path, resl)
            results[tag] = resl
            process_results(path, results)
          end
        end
      end
    end

    # Process fetch results
    def process_results(path, results)
      return unless results.size == @tags.size
      @callback[path, results]
    end
  end
end
