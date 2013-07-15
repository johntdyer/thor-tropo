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

    namespace "tropo"

    class_option :called_path,
      :type    => :string,
      :aliases => "-d",
      :default => Dir.pwd,
      :desc    => "Directory of your Berksfile",
      :banner  => "Directory of your Berksfile"

    desc "package", "Package cookbooks and upload to S3"

    method_option :"version-override",
      :type    => :string,
      :aliases => "-V",
      :default => nil,
      :desc    => "Force override of version number",
      :banner  => "Force override of cookbook version"

    method_option :force,
      :type    => :boolean,
      :aliases => "-f",
      :default => false,
      :desc    => "Force override of any files on s3 without confirmation",
      :banner  => "Force overrides of existing files"

    method_option :noop,
      :type    => :boolean,
      :aliases => "-n",
      :default => false,
      :desc    => "NO-OP mode, dont actually upload anything"

    method_option :ignore_dirty,
      :type     => :boolean,
      :aliases  => "-i",
      :default  => false,
      :desc     => "Ignore any dirty files in directory and package anyways",
      :banner   => "Ignore dirty repository"

    method_option :clean_mode,
      :type     => :boolean,
      :aliases  => "-c",
      :default  => false,
      :desc     => "Delete lockfile before running `Berks install`",
      :banner   => "Delete lockfile before running `Berks install`"

    def package

      #$config = ThorTropo::Configuration.new(options[:called_path])
      $config = ThorTropo::Configuration.new(source_root)

      unless clean?
        unless options[:ignore_dirty]
          say "There are files that need to be committed first.", :red
          exit 1
        end
      end

      tag_version {
        bundle_cookbook
        upload_cookbook @packaged_cookbook, $config.project_name, {:force => options[:force],:noop => options[:noop]}
      }

    end

    no_tasks do

      def upload_cookbook(local_file,path,opts={})
        uploader = ThorTropo::Uploader.new({
                                             :access_key => $config.aws_key,
                                             :secret_key => $config.aws_secret,
                                             :bucket     => $config.bucket_name
        })

        uploader.upload :local_file => local_file, :path => path, :force => options[:force], :noop=>options[:noop]
      end

      def clean?
        #sh_with_excode("cd #{options[:called_path]}; git diff --exit-code")[1] == 0
        sh_with_excode("cd #{source_root}; git diff --exit-code")[1] == 0
      end

      def clean_lockfile
        #berksfile = "#{options[:called_path]}/Berksfile.lock"
        berksfile = "#{source_root}/Berksfile.lock"

        if File.exists? berksfile
          say "[ TROPO ] - Removing Berksfile.lock before running Berkshelf", :blue
          remove_file(berksfile) unless options[:noop]
        else
          say "[ TROPO ] - Unable to find berksfile to delete - [ #{berksfile} ]", :yellow
        end
      end

      def bundle_cookbook
        clean_lockfile if options[:clean_mode]

        say "[ TROPO ] - Packaging cookbooks from Berksfile", :blue
        @tmp_dir = Dir.mktmpdir
        opts = {
          #berksfile: File.join(options[:called_path],"/Berksfile"),
          berksfile: File.join(source_root,"/Berksfile"),
          path: "#{@tmp_dir}/cookbooks"
        }

        invoke("berkshelf:install", [], opts)
        #output   = File.expand_path(File.join(@tmp_dir, "#{options[:called_path].split("/")[-1]}-#{current_version}.tar.gz"))
        output   = File.expand_path(File.join(@tmp_dir, "#{cookbook_name}-#{current_version}.tar.gz"))

        Dir.chdir(@tmp_dir) do |dir|
          tgz = Zlib::GzipWriter.new(File.open(output, 'wb'))
          Archive::Tar::Minitar.pack('./cookbooks', tgz)
        end
        @packaged_cookbook = output

      end

      def cookbook_name
        source_root.split("/")[-1]
      end

      def current_version
        if options[:"version-override"]
          options[:"version-override"]
        else
          #metadata = Ridley::Chef::Cookbook::Metadata.from_file(File.join(options[:called_path],"metadata.rb"))
          metadata = Ridley::Chef::Cookbook::Metadata.from_file(File.join(source_root,"metadata.rb"))
          metadata.version
        end
      end

      def tag_version
        sh "git tag -a -m \"Version #{current_version}\" #{current_version}" unless options[:noop]
        say "[ TROPO ] - Tagged: #{current_version}", :blue
        yield if block_given?
        sh "git push --tags" unless options[:noop]
      rescue => e
        say "[ TROPO ] - Untagging: #{current_version} due to error", :red
        sh_with_excode "git tag -d #{current_version}"
        say "[ TROPO ] - #{e}", :red
        exit 1
      end

      ## Get the directory to Berksfile
      def source_root

        berks_path = File.expand_path(options[:called_path])
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
