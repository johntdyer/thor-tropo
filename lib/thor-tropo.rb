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
      :type => :string,
      :default => Dir.pwd

    class_option :verbose,
      :type => :boolean,
      :aliases => "-v",
      :default => false

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

    # def version
    #   OLDVERSION=`sed -n -e "s/version.*\"\(.*\)\"/\1/p" metadata.rb`
    #   sed -ie "s/\(version *\)\".*\"/\1\"$OLDVERSION\"/" metadata.rb
    #   git add metadata.rb
    # end


    def package

      $config = ThorTropo::Configuration.new(options[:called_path])

      unless clean?
        unless options[:ignore_dirty]
          say "There are files that need to be committed first.", :red
          exit 1
        end
      end

      bundle_cookbook

      upload_cookbook @packaged_cookbook, $config.project_name, {:force => options[:force],:noop => options[:noop]}
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

      def upload_cookbook(local_file,path,opts={})
        uploader = ThorTropo::Uploader.new({
                                             :access_key => $config.aws_key,
                                             :secret_key => $config.aws_secret,
                                             :bucket     => $config.bucket_name
        })

        uploader.upload :local_file => local_file, :path => path, :force => options[:force], :noop=>options[:noop]
      end

      def clean?
        sh_with_excode("cd #{options[:called_path]}; git diff --exit-code")[1] == 0
      end

      def clean_lockfile
        berksfile = "#{options[:called_path]}/Berksfile.lock"

        if File.exists? berksfile
          say "[ TROPO ] - Removing Berksfile.lock before running Berkshelf", :blue
          remove_file berksfile
        else
          say "[ TROPO ] - Unable to find berksfile to delete - [ #{berksfile} ]", :yellow
        end
      end

      def bundle_cookbook
        clean_lockfile if options[:clean_mode]

        say "[ TROPO ] - Packaging cookbooks from Berksfile", :blue
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
        if options[:"version-override"]
          options[:"version-override"]
        else
          metadata = Ridley::Chef::Cookbook::Metadata.from_file(File.join(options[:called_path],"metadata.rb"))
          metadata.version
        end
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
