module ThorTropo


$:.unshift  File.expand_path('../thor-tropo', __FILE__)

require 'thor'
require 'thor/actions'
require 'thor/scmversion'
require 'tmpdir'
require 'archive/tar/minitar'
require 'zlib'

require 'berkshelf/thor'
require 'berkshelf/chef'
require 'digest/md5'
require 'aws/s3'

require File.expand_path('../thor-tropo/uploader.rb', __FILE__)



  class Tasks < Thor
    include Thor::Actions

    @packaged_cookbook = nil
    class_option :called_path,
      :type => :string,
      :default => Dir.pwd

    class_option :verbose,
      :type => :boolean,
      :aliases => "-v",
      :default => false


    namespace "tropo"

    desc "bump", "Bump version"
    def bump
      puts "This should bump the version in the metatdata.rb file... eventually"
    end


    desc "package", "Package cookbook"
    def package
      unless clean?
        say "There are files that need to be committed first.", :red
        exit 1
      end

      bundle_cookbook
     # upload_cookbook @packaged_cookbook, "test"
      #  tag_version {
      #    publish_cookbook(options)
      #  }
    end


    # desc "build", "Package cookbook"

    # def build
    #   cleanup
    #   run "git archive --format=tar -o #{pkg_path}/tarfile HEAD"
    #   run "tar rf #{pkg_path}/tarfile VERSION" # Stick VERSION in the tar
    #   run "gzip -9 #{pkg_path}/tarfile"
    #   FileUtils.mv "#{pkg_path}/tarfile.gz", artifact_path
    #   say "Built #{artifact_path}"
    # end

    no_tasks do

      def upload_cookbook(local_file,path)
        @uploader = ThorTropo::Uploader.new
        @uploader.upload :local_file => local_file, :path => path
      end

      def clean?
        sh_with_excode("git diff --exit-codeBerkshelf")[1] == 0
      end

      def bundle_cookbook
        @tmp_dir = Dir.mktmpdir
        opts = {
          berksfile: File.join(options[:called_path],"/Berksfile"),
          path: "#{@tmp_dir}/cookbooks"
        }

        invoke("berkshelf:install", [], opts)
        output   = File.expand_path(File.join(@tmp_dir, "#{options[:called_path].split("/")[-1]}-#{current_version}.tar.gz"))


        Dir.chdir(@tmp_dir) do |dir|
          tgz = Zlib::GzipWriter.new(File.open(output, 'wb'))
          Archive::Tar::Minitar.pack('./cookbooks', tgz)
        end
        @packaged_cookbook = output

      end

      def current_version
        metadata = Ridley::Chef::Cookbook::Metadata.from_file(File.join(options[:called_path],"metadata.rb"))
        metadata.version
      end

      def tag_version
        sh "git tag -a -m \"Version #{current_version}\" #{current_version}"
        say "Tagged: #{current_version}", :green
        yield if block_given?
        sh "git push --tags"
      rescue => e
        say "Untagging: #{current_version} due to error", :red
        sh_with_excode "git tag -d #{current_version}"
        say e, :red
        exit 1
      end

      def source_root
        options[:called_path]
      end

      def sh(cmd, dir = source_root, &block)
        out, code = sh_with_excode(cmd, dir, &block)
        code == 0 ? out : raise(out.empty? ? "Running `#{cmd}` failed. Run this command directly for more detailed output." : out)
      end

      def sh_with_excode(cmd, dir = source_root, &block)
        cmd << " 2>&1"
        outbuf = ''

        Dir.chdir(dir) {
          outbuf = `#{cmd}`
          if $? == 0
            block.call(outbuf) if block
          end
        }

        [ outbuf, $? ]
      end

      def cleanup
        FileUtils.rm_r(pkg_path, :force => true)
        FileUtils.mkdir_p pkg_path
      end

    end

  end
end
