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

  class Tasks < Thor
    include Thor::Actions


    @packaged_cookbook = nil

    @working_directory = nil
    @invoke_directory = Dir.pwd

    namespace "tropo"

    class_option "help",
      :type => :boolean,
      :default => false,
      :aliases => "-h"

    class_option "version",
      :type => :boolean,
      :default => false,
      :aliases => "-v"

    desc "package", "Package cookbooks using Berkshelf and upload file to s3 bucket"

    method_option :berkspath,
      :type    => :string,
      :aliases => "-b",
      :default => nil,
      :desc    => "Berksfile path"

    #:banner  => "Path to find your cookbook Berksfile"

    method_option :"version-override",
      :type    => :string,
      :aliases => "-V",
      :default => nil,
      :desc    => "Provide a version for cookbook archive"

    #:banner  => "Provider a cookbook version rather then using metadata.rb"

    method_option :force,
      :type    => :boolean,
      :aliases => "-f",
      :default => false,
      :desc    => "overwrite any files on s3 without confirmation"

    #:banner  => "Ignore existing files and overwrite without confirmation"

    method_option :"iam-auth",
      :type     => :boolean,
      :default  => false,
      :aliases  => "-I",
      :desc     => "Use IAM roles for AWS authorization"

    #:banner   => "Will expect an IAM role is present for S3 Auth.  Useful for CI"

    method_option :"ignore-dirty",
      :type     => :boolean,
      :aliases  => "-i",
      :default  => false,
      :desc     => "Will ignore any dirty files in git repo and continue to package cookbooks"

    #:banner   => "Ignore dirty git repository"

    method_option :keeplock,
      :type     => :boolean,
      :aliases  => "-k",
      :default  => false,
      :desc     => "Respect Berksfile.lock"

    #:banner   => "Don't delete lockfile before running `Berks install`"

    method_option :"clean-cache",
      :type     => :boolean,
      :aliases  => "-c",
      :default  => false,

      #:banner     => "Delete Berkshelf cookbook cache",
      :desc     => "Delete local Berkshelf cookbook cache"

    method_option :"no-op",
      :type    => :boolean,
      :aliases => "-n",
      :default => false,
      :desc    => "NO-OP mode, Won't actually upload anything.  Useful to see what would have happened"
    #:banner    => "NO-OP mode",


    def package

      print_help_or_version

      $config = ThorTropo::Configuration.new(source_root)

      unless clean?
        say "[ TROPO ] - There are files that need to be committed first.", :red
        exit 1 unless options[:"ignore-dirty"]
      end

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
      print_help_or_version

      if File.exists?(".git")
        tag_version options[:version]
      else
        say "[ TROPO ] - Directory is not managed by Git, quiting..", :red
        exit 1
      end
    end

    no_tasks do


      def print_help_or_version
        if options[:help]
          help "package"
          exit 0
        elsif options[:version]
          say "[ TROPO ] Version - #{ThorTropo::VERSION}", :blue
          exit 0
        end
      end
      def path_priorities
        if options[:berkspath]
          say "[ TROPO ] - Detected Berkspath was provided, so we will use this", :blue
          ### User specified berkspath, this is highest priority
          @working_directory = File.expand_path(options[:berkspath])
        elsif Dir.glob("*").include?("Berksfile")
          say "[ TROPO ] - Detected Berksfile in current directory and no --berkspath was provided.  We'll use local Berksfile.", :blue
          ### Found berksfile in working directory
          @working_directory = File.expand_path(".")
        end

      end

      def upload_cookbook(local_file,path,opts={})
        uploader = ThorTropo::Uploader.new({
                                             :access_key => $config.aws_key,
                                             :secret_key => $config.aws_secret,
                                             :bucket     => $config.bucket_name,
                                             :use_iam    => options[:"iam-auth"]
        })

        uploader.upload :local_file => local_file, :path => path, :force => options[:force], :noop => options[:"no-op"]
      end

      def clean_berks_cache
        say "[ TROPO ] - Clearing local Berkshelf cookbook cache", :green

        unless options[:"no-op"]
          remove_dir (File.expand_path(File.join(Dir.home,".berkshelf","cookbooks")))
        end
      end

      def clean?
        sh_with_excode("cd #{source_root}; git diff --exit-code")[1] == 0
      end

      def clean_lockfile
        berksfile = "#{source_root}/Berksfile.lock"

        if File.exists? berksfile
          say "[ TROPO ] - Removing Berksfile.lock before running Berkshelf", :blue
          remove_file(berksfile) unless options[:"no-op"]
        else
          say "[ TROPO ] - Unable to find berksfile to delete - [ #{berksfile} ]", :yellow
        end
      end

      def bundle_cookbook
        clean_lockfile unless options[:keeplock]
        berksfile = File.join(source_root,"/Berksfile")
        say "[ TROPO ] - Packaging cookbooks using #{berksfile}", :blue
        @tmp_dir = Dir.mktmpdir
        opts = {
          berksfile: berksfile,
          path: "#{@tmp_dir}/cookbooks"
        }

        Dir.chdir File.dirname(berksfile)
        invoke("berkshelf:install", [], opts)

        @_invocations.except!(Berkshelf::Cli) ### Clear Berkshelf from invocations array, because apperently you can't invoke the same task twice...

        output   = File.expand_path(File.join(@tmp_dir, "#{get_cookbook_name}-#{current_version}.tar.gz"))

        Dir.chdir(@tmp_dir) do |dir|
          tgz = Zlib::GzipWriter.new(File.open(output, 'wb'))
          Archive::Tar::Minitar.pack('./cookbooks', tgz)
        end
        @packaged_cookbook = output

      end

      def get_cookbook_name
        source_root.split("/")[-1]
      end

      def current_version
        if options[:"version-override"]
          options[:"version-override"]
        else

          metadata = Ridley::Chef::Cookbook::Metadata.from_file(File.join(source_root,"metadata.rb"))
          metadata.version
        end
      end

      def tag_version(version=nil)
        git_tag = version || current_version
        sh "git tag -a -m \"Version #{git_tag}\" #{git_tag}" unless options[:"no-op"]
        say "[ TROPO ] - Tagged: #{git_tag}", :blue
        yield if block_given?
        sh "git push --tags" unless options[:"no-op"]
      rescue => e
        say "[ TROPO ] - Untagging: #{git_tag} due to error", :red
        sh_with_excode "git tag -d #{git_tag}"
        say "[ TROPO ] - #{e}", :red
        exit 1
      end

      ## Get the directory to Berksfile
      def source_root
        berks_path = unless options[:berkspath]
          Dir.pwd
        else
          @working_directory || File.expand_path(options[:berkspath])
        end

        if File.exists? berks_path
          berks_path
        else
          raise Errno::ENOENT, "#{berks_path} does not contain a Berksfile"
        end
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

    end

  end
end
