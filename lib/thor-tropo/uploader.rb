module ThorTropo
  class Uploader < Thor

    include Thor::Actions

    require 'digest/md5'
    require 'fog'
    require 'mime/types'

    require 'pry'

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

        if file_exists? remote_file

          if force

            file = send_file remote_file, local_file

          else

            response = ask "[ TROPO ] - file already exists on S3, do you want me to overwrite it ? (yes|no) ? ", :yellow

            if response.downcase.match /yes|ok|y/
              begin

                file = send_file remote_file, local_file

              rescue Exception => e
                say "[ TROPO ] Error: #{e}", :red
                say "[ TROPO ] Backtrace:\n\t#{e.backtrace.join("\n\t")}" if @debug_mode
              end

            else
              say "[ TROPO ] - Quiting..", :red
            end
          end
        else

          file = send_file remote_file, local_file

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

      def send_file(remote_file,local_file)
        say "[ TROPO ] - Uploading file.", :blue
        file = @bucket_name.files.create(
          :key    => remote_file,
          :body   => File.open(local_file),
          :public => true,
          :content_type => get_mime_type(local_file),
          :metadata => {
            "x-amz-meta-sha256-hash" =>get_sha256_sum(local_file)
          }
        )
        say "[ TROPO ] - Public URL: #{file.public_url}", :blue
        return file
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
