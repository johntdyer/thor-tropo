module ThorTropo
  class Uploader

    require 'digest/md5'
    require 'aws/s3'

    def initialize#(key,secret)
      @c = AWS::S3::Base.establish_connection!(
        :access_key_id     => ENV['AWS_ACCESS_KEY'],
        :secret_access_key => ENV['AWS_SECRET_KEY']
      )
      @bucket = opts[:bucket] || 'artifacts.voxeolabs.net'
    end

    def upload(opts={})
      local_file  = opts[:local_file]
      remote_file = opts[:path] + "/" + opts[:local_file]
      force       = opts[:force].nil? ? false : opts[:force]

      puts  test_file :local_file => local_file, :remote_file => :remote_file

    end


    private

    def test_file(opts={})
      #get the S3 file (object)
      object = AWS::S3::S3Object.find(opts[:remote_file], @bucket)
      #separate the etag object, and remove the extra quotations
      etag = object.about['etag'].gsub('"', '')
      digest = Digest::MD5.hexdigest(File.read(opts[:local_file]))
      #a string comparison to finish it off
      return digest.eql? etag

    end
  end

end
