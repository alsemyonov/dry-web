require "yaml"

module Dry
  module Web
    class Settings
      SettingValueError = Class.new(StandardError)

      # @return [{Symbol => Dry::Types::Definition}]
      def self.schema
        @schema ||= {}
      end

      # @param [Symbol] name
      # @param [Dry::Types::Definition] type
      def self.setting(name, type = nil)
        settings(name => type)
      end

      # @param [{Symbol => Dry::Types::Definition}] new_schema
      # @return [self]
      def self.settings(new_schema)
        check_schema_duplication(new_schema)
        @schema = schema.merge(new_schema)

        self
      end

      # @param [{Symbol => Dry::Types::Definition}] new_schema
      # @raise [ArgumentError] if duplicate setting found in `new_schema`
      def self.check_schema_duplication(new_schema)
        shared_keys = new_schema.keys & schema.keys

        raise ArgumentError, "Setting :#{shared_keys.first} has already been defined" if shared_keys.any?
      end
      private_class_method :check_schema_duplication

      # @param [Pathname] root
      # @param [#to_s] env
      # @return [Dry::Configurable::Config]
      def self.load(root, env)
        yaml_path = root.join("config/settings.yml")
        yaml_data = File.exist?(yaml_path) ? YAML.load_file(yaml_path)[env.to_s] : {}
        schema = self.schema

        Class.new do
          extend Dry::Configurable

          schema.each do |key, type|
            value = ENV.fetch(key.to_s.upcase) { yaml_data[key.to_s.downcase] }

            begin
              value = type[value] if type
            rescue => e
              raise SettingValueError, "error typecasting +#{key}+: #{e}"
            end

            setting key, value
          end
        end.config
      end
    end
  end
end
