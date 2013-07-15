module ThorTropo
  class Uploader < Thor

    include Thor::Actions

    require 'digest/md5'
    require 'fog'
    require 'mime/types'

    no_commands {

      def initialize(opts={})
        @debug_mode   = opts[:debug_mode]
        @connection   = setup_connection(opts[:access_key],opts[:secret_key])
        @bucket_name  = get_bucket( opts[:bucket] || 'artifacts.voxeolabs.net' )
      end

      def upload(opts={})

        local_file  = opts[:local_file]
        remote_file = opts[:path] + "/" + opts[:local_file].split("/")[-1]
        force       = opts[:force].nil? ? false : opts[:force]
        noop        = opts[:noop].nil? ? false : opts[:noop]

        if file_exists? remote_file

          if force

            send_file :remote_file => remote_file, :local_file => local_file, :noop => noop

          else

            response = ask "[ TROPO ] - file already exists on S3, do you want me to overwrite it ? (yes|no) ? ", :yellow

            if response.downcase.match /yes|ok|y/
              begin

                send_file :remote_file => remote_file, :local_file => local_file, :noop => noop

              rescue Exception => e
                say "[ TROPO ] Error: #{e}", :red
                say "[ TROPO ] Backtrace:\n\t#{e.backtrace.join("\n\t")}" if @debug_mode
              end

            else
              say "[ TROPO ] - Quiting..", :red
            end
          end
        else

          send_file :remote_file => remote_file, :local_file => local_file, :noop => noop

        end
      end

      private

      def setup_connection(u,p)
        Fog::Storage.new({
            :provider                 => 'AWS',
            :aws_access_key_id        => u,
            :aws_secret_access_key    => p
        })
      end

      def get_bucket(bucket_name)
        directory = @connection.directories.create(
          :key    => bucket_name,
          :public => true
        )
      end

      def file_exists?(key)
        !@bucket_name.files.head(key).nil?
      end

      def send_file(opts={})
        local_file  = opts[:local_file]
        remote_file = opts[:remote_file]

        say "[ TROPO ] - Uploading file. [ #{File.basename(opts[:local_file])} ]", :blue
        unless opts[:noop]
          file = @bucket_name.files.create(
            :key    => remote_file,
            :body   => File.open(local_file),
            :public => true,
            :content_type => get_mime_type(local_file),
            :metadata => {
              "x-amz-meta-sha256-hash" =>get_sha256_sum(local_file)
            }
          )
          public_url = file.public_url

        else
          public_url = " *** NOOP ** /#{remote_file}"

        end
          say "[ TROPO ] - Public URL: #{public_url}", :blue

      end

      def get_sha256_sum(file)
        Digest::SHA256.file(file).hexdigest
      end

      def get_mime_type(file)
        MIME::Types.type_for(file)[0].to_s
      end

    }
  end

end
