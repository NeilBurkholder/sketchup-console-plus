=begin
Utility to observe files for changes.

@class   FileObserver
@version 1.0.1
@date    2015-08-14
@author  Andreas Eisenbarth
@license MIT License (MIT)
=end

# Requires UI


module AE


  class Console


    class FileObserver


      # Create a new file observer.
      # @param  [Numeric] interval  The interval in seconds to check all observed file paths.
      def initialize(interval=2)
        @supported_events = [:created, :changed, :deleted]
        @observers        = {}
        @timer            = nil
        @interval         = (interval.is_a?(Numeric) && interval > 0) ? interval : 2 # in seconds
      end


      # Register a handler to do something on an event on a specific file.
      # @param  [String] path      The path of a file.
      # @param  [Symbol] event     The event to listen for, one of [:created, :changed, :deleted]
      # @yield                     The action to do when the event occurs.
      # @yieldparam [String] path  The file path
      def register(path, event, &callback)
        raise ArgumentError unless path.is_a?(String) && @supported_events.include?(event) && block_given?
        # If this is the first registered event, we need to start the timer.
        if @observers.empty?
          @timer = UI.start_timer(@interval, true) { check_files }
          check_files
        end
        # Register the event
        @observers[path]        ||= {}
        @observers[path][event]   = callback
        exists                    = File.exists?(path)
        @observers[path][:exists] = exists
        if exists
          @observers[path][:ctime] = File.stat(path).ctime.to_i
        end
      end


      # Unregister a handler.
      # @param  [String] path   The path of the file which should not be observed anymore.
      # @param  [Symbol] event  The event to unregister. If not given, all events for that file are unregistered.
      def unregister(path, event=nil)
        if event
          @observers[path].delete(event)
        else # all events for that path
          @observers.delete(path)
        end
        # If no events are left, we don't need to check them.
        if @timer && @observers.empty?
          UI.stop_timer(@timer)
          @timer = nil
        end
      end


      # Unregister all handlers for all files.
      def unregister_all
        @observers.clear
        if @timer
          UI.stop_timer(@timer)
          @timer = nil
        end
      end


      private


      def check_files
        @observers.each { |path, hash|
          begin
            exists = File.exists?(path)
            if exists # whether it exists now
              ctime = File.stat(path).ctime.to_i
              if hash[:exists] # whether it existed before
                # File exists but did not exist before → created
                hash[:created].call(path) if hash[:created]
              else
                # File exists but did not exist before → created
                hash[:changed].call(path) if hash[:changed] && hash[:ctime] < ctime
              end
            else
              # File does not exist but existed before → deleted
              hash[:deleted].call(path) if hash[:exists] && hash[:deleted]
            end
          rescue Exception => e
            AE::Console.error(e)
          ensure
            hash[:exists] = exists
            hash[:ctime]  = ctime
          end
        }
      end


    end # class FileObserver


  end


end
