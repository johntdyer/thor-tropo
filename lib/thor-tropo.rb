module ThorTropo


  $:.unshift  File.expand_path('../thor-tropo', __FILE__)

  require 'thor'
  require 'thor/actions'
  require 'thor/scmversion'
  require 'thor/foodcritic'
  require 'tmpdir'
  require 'archive/tar/minitar'
  require 'zlib'
  require 'berkshelf/thor'
  require 'berkshelf/chef'
  require 'uploader'
  require 'configuration'
  require 'packaging'

  class Tasks < Thor
    include Thor::Actions
    include Packaging

    @packaged_cookbook = nil
    @working_directory = nil
    @invoke_directory = Dir.pwd

    namespace "tropo"

    class_option "help",
      :type    => :boolean,
      :default => false,
      :aliases => "-h"

    class_option "version",
      :type    => :boolean,
      :default => false,
      :aliases => "-v"

    desc "package", "Package cookbooks using Berkshelf and upload file to s3 bucket"

    method_option :berkspath,
      :type     => :string,
      :aliases  => "-b",
      :default  => nil,
      :desc     => "Berksfile path"

    method_option :"version-override",
      :type     => :string,
      :aliases  => "-V",
      :default  => nil,
      :desc     => "Provide a version for cookbook archive"

    method_option :force,
      :type     => :boolean,
      :aliases  => "-f",
      :default  => false,
      :desc     => "overwrite any files on s3 without confirmation"

    method_option :"iam-auth",
      :type     => :boolean,
      :default  => false,
      :aliases  => "-I",
      :desc     => "Use IAM roles for AWS authorization"

    method_option :"ignore-dirty",
      :type     => :boolean,
      :aliases  => "-i",
      :default  => false,
      :desc     => "Will ignore any dirty files in git repo and continue to package cookbooks"

    method_option :keeplock,
      :type     => :boolean,
      :aliases  => "-k",
      :default  => false,
      :desc     => "Respect Berksfile.lock"

    method_option :"clean-cache",
      :type     => :boolean,
      :aliases  => "-c",
      :default  => false,
      :desc     => "Delete local Berkshelf cookbook cache"

    method_option :"no-op",
      :type     => :boolean,
      :aliases  => "-n",
      :default  => false,
      :desc     => "NO-OP mode, Won't actually upload anything.  Useful to see what would have happened"

    def package

      print_help_or_version

      $config = ThorTropo::Configuration.new(source_root)

      clean?

      clean_berks_cache if options[:"clean-cache"]

      if path_priorities
        bundle_cookbook
        upload_cookbook @packaged_cookbook, $config.project_name, {:force => options[:force],:"no-op" => options[:"no-op"]}
      else
        if $config.cookbooks.is_a? Array
          say "[ TROPO ] - Found multiple cookbooks, packaging individual projects", :cyan
          home = Dir.pwd

          $config.cookbooks.each do |cookbook|
            break if options[:path]
            @working_directory = File.expand_path(File.join(home,cookbook))
            say "[ TROPO ] - Switcing to #{@working_directory}", :blue
            Dir.chdir(@working_directory)
            bundle_cookbook
            upload_cookbook @packaged_cookbook, $config.project_name, {:force => options[:force],:noop => options[:"no-op"]}
            #@working_directory = nil
          end
        end
      end

    end


    desc "tag", "Tag release"

    method_option :version,
      :type     => :string,
      :aliases  => "-v",
      :default  => nil,
      :required => true,
      :desc     => "Set a tag for the release and push to remote",
      :desc     => "Set a tag for the release and push to remote"
    def tag

      clean?
      print_help_or_version

      if File.exists?(".git")
        tag_version options[:version]
      else
        say "[ TROPO ] - Directory is not managed by Git, quiting..", :red
        exit 1
      end
    end

  end
end
