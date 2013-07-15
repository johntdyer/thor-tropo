module ThorTropo
  class Uploader < Thor
    include Thor::Actions
    no_commands {


      require 'digest/md5'
      require 'aws-sdk'
      require 'mime/types'

      def initialize(opts={})
        @s3 = setup_connection(u,p)

        @bucket_name = ensure_bucket_exists( opts[:bucket] || 'artifacts.voxeolabs.net' )
      end

      def upload(opts={})
        local_file  = opts[:local_file]
        remote_file = opts[:path] + "/" + opts[:local_file].split("/")[-1]
        force       = opts[:force].nil? ? false : opts[:force]

        if file_exists? :local_file => local_file, :remote_file => remote_file
          upload_file local_file
        end
      end


      private

        def setup_connection(u,p)
           AWS::S3.new(
            :access_key_id => u
            :secret_access_key p
          }
        end

        def upload_cookbooks(local_file)
          get_folder_name = "test"
          ## Only upload files, we're not interested in directories
          if File.file?(local_file)
            base_name = File.basename(local_file)
            remote_file = "#{get_folder_name}/#{base_name}"
            mime_type = MIME::Types.type_for(local_file).to_s
            begin

              AWS::S3::S3Object.store(
                base_name,
                File.open(local_file),
                @bucket,
                :content_type =>  mime_type
              )

            rescue => e
              #say "Shit, something bad happened -> #{e}", :red

            end

            #   say  "== Uploading http://#{@.bucket_name}/#{get_folder_name}/#{file.split("/")[-1]}", :blue
            #   obj = bucket.objects.build(remote_file)
            #   obj.content = open(file)
            #   obj.content_type = MIME::Types.type_for(file).to_s
            #   obj.save

          end
          # puts ui.highline.color  "== Done syncing #{file.split('/')[-1]}",:green
        end

        def ensure_bucket_exists(bucket_name)
          bucket = @s3.buckets[bucket_name]

          # If the bucket doesn't exist, create it
          unless bucket.exists?
            say "Bucket not found, creating it ", :yellow
            @s3.buckets.create(bucket)
          end
          return bucket
        end

        def test_file(opts={})
          #get the S3 file (object)
          begin
            bucket = ensure_bucket_exists(@bucket_name)
            bucket.objects[opts[:remote_file]].metadata['etag'].gsub('"', '')

            #object = AWS::S3::S3Object.find(opts[:remote_file], @bucket_name)
            #separate the etag object, and remove the extra quotations
            etag = object.about['etag'].gsub('"', '')
            digest = Digest::MD5.hexdigest(File.read(opts[:local_file]))
            #a string comparison to finish it off
            return digest.eql? etag
          rescue AWS::S3::NoSuchKey
            say "Key not found, uploading local file.", :green
            false
          end


        end
        alias :file_exists? :test_file
    }
  end

end
