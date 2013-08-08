module ThorTropo
  class Configuration < Thor

  no_commands {

    require 'pathname'
    require 'yaml'

    attr_reader :bucket_name, :aws_secret, :aws_key, :project_name, :cookbooks, :model_name, :base_dir

    def initialize(path)
      file_name=".deployer"

      Pathname.new(path).ascend do |dir|
        config_file = dir + file_name
        if dir.children.include?(config_file)
          merge_config(YAML::load_file(config_file))
        end
      end

    end

    private

    def merge_config(config)

      if config['bucket_name']
        @bucket_name = config['bucket_name'] unless @bucket_name
      end

      if config['base_dir']
        @base_dir = config['base_dir'] unless @base_dir
      end

      if config['model_name']
        @model_name = config['model_name'] unless @model_name
      end

      if config['aws_secret']
        @aws_secret = config['aws_secret'] unless @aws_secret
      end

      if config['aws_key']
        @aws_key = config['aws_key'] unless @aws_key
      end

      if config['project_name']
        @project_name = config['project_name'] unless @project_name
      end

      if config['cookbooks']
        @cookbooks = config['cookbooks'] unless @cookbooks
      end

    end
  }

  end
end


