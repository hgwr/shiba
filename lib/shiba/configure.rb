require 'pathname'
require 'pp'
require 'optionparser'

module Shiba
  module Configure

    # avoiding Rails dependency on the cli tools for now.
    # yanked from https://github.com/rails/rails/blob/v5.0.5/railties/lib/rails/application/configuration.rb
    def self.activerecord_configuration(config_path = "config/database.yml")
      yaml = Pathname.new(config_path)

      config = if yaml && yaml.exist?
                 require "yaml"
                 require "erb"
                 YAML.load(ERB.new(yaml.read).result) || {}
               end

      env     = ENV["RAILS_ENV"] || "test"
      config  = config[env]
      adapter = config.delete("adapter")

      if adapter == "mysql2"
        config["server"] = "mysql"
      else
        config["server"] = adapter
      end

      config
    rescue Psych::SyntaxError => e
      raise "YAML syntax error occurred while parsing #{yaml.to_s}. " \
        "Please note that YAML must be consistently indented using spaces. Tabs are not allowed. " \
        "Error: #{e.message}"
    rescue => e
      raise e, "Cannot load `#{path}`:\n#{e.message}", e.backtrace
    end

    def self.ci?
      ENV['CI'] || ENV['CONTINUOUS_INTEGRATION']
    end

    # loosely based on https://dev.mysql.com/doc/refman/8.0/en/option-files.html
    def self.mysql_config_path
      paths = [ File.join(Dir.home, '.mylogin.cnf'), File.join(Dir.home, '.my.cnf')  ]

      paths.detect { |p| File.exist?(p) }
    end

    def self.read_config_file(option_file, default)
      file_to_read = nil
      if option_file
        if !File.exist?(option_file)
          $stderr.puts "no such file: #{option_file}"
          exit 1
        end
        file_to_read = option_file
      elsif File.exist?(default)
        file_to_read = default
      end

      if file_to_read
        YAML.load_file(file_to_read)
      else
        {}
      end
    end

    def self.make_options_parser(options, only_basics = false)
      OptionParser.new do |opts|
        # note that the key to the hash needs to stay the same as the
        # option name since we re-pass them
        opts.on("-s","--server SERVER_TYPE", "mysql|postgres") do |s|
          options["server"] = s
        end

        opts.on("-h","--host HOST", "sql host") do |h|
          options["host"] = h
        end

        opts.on("-d","--database DATABASE", "sql database") do |d|
          options["database"] = d
        end

        opts.on("-u","--username USER", "sql user") do |u|
          options["username"] = u
        end

        opts.on("-p","--password PASSWORD", "sql password") do |p|
          options["password"] = p
        end

        opts.on("-P","--port PORT", "server port") do |p|
          options["port"] = p
        end

        opts.on("-c","--config FILE", "location of shiba.yml") do |f|
          options["config"] = f
        end

        opts.on("-i","--index INDEX", "location of shiba_index.yml") do |i|
          options["index"] = i.to_i
        end

        opts.on("--default-extras-file", "The option file to read mysql configuration from") do |f|
          options["default_file"] = f
        end

        next if only_basics

        opts.on("--sql SQL", "analyze this sql") do |s|
          options["sql"] = s
        end

        opts.on("-f", "--file FILE", "location of file containing queries") do |f|
          options["file"] = f
        end

        opts.on("-j", "--json [FILE]", "write JSON report here. default: to stdout") do |f|
          if f
            options["json"] = File.open(f, 'w')
          else
            options["json"] = $stdout
          end
        end

        opts.on("--example_data_json FILE", "(dev only) generate example data for vue development testing") do |f|
          options['example_data_json'] = f
        end

        opts.on("-h", "--html FILE", "write html report here.") do |h|
          options["html"] = h
        end

        opts.on("-v", "--verbose", "print internal runtime information") do
           options["verbose"] = true
        end

        # This naming seems to be mysql convention, maybe we should just do our own thing though.
        opts.on("--login-path", "The option group from the mysql config file to read from") do |f|
          options["default_group"] = f
        end

      end
    end
  end
end
