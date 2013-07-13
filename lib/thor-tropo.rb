require 'thor'
require 'thor/actions'

module ThorTropo
  class Tasks < Thor
    include Thor::Actions

    namespace "tropo"

    desc "package", "Package cookbook"
    def build
      cleanup
      run "git archive --format=tar -o #{pkg_path}/tarfile HEAD"
      run "tar rf #{pkg_path}/tarfile VERSION" # Stick VERSION in the tar
      run "gzip -9 #{pkg_path}/tarfile"
      FileUtils.mv "#{pkg_path}/tarfile.gz", artifact_path
      say "Built #{artifact_path}"
    end


    no_tasks do
      def cleanup
        FileUtils.rm_r(pkg_path, :force => true)
        FileUtils.mkdir_p pkg_path
      end

      def source_root
        if defined?(::SOURCE_ROOT)
          ::SOURCE_ROOT
        else
          warn "::SOURCE_ROOT must be set to provide the path to the root of the source being packaged."
        end
      end

      def pkg_path
        File.join(source_root, 'pkg')
      end

      def artifact_path
        File.join(pkg_path, artifact_filename)
      end

      def artifact_filename
        "#{application_name}-#{current_version}.tar.gz"
      end

      def current_version
        require "thor/scmversion"
        invoke "version:current"
        File.read(File.join(source_root, "VERSION")).chomp
      rescue
        warn "This project is not versioned via thor-scmversion"
        "UNVERSIONED"
      end

      def application_name
        if defined?(::APPLICATION_NAME)
          ::APPLICATION_NAME
        else
          warn "::APPLICATION_NAME should be set to the name of your application. Using 'application_name' for now."
          "application_name"
        end
      end
    end
  end
end
