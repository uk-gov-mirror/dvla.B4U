# frozen_string_literal: true

require_relative 'B4U/runner'
require_relative 'B4U/string_methods'
require_relative 'B4U/condition'
require_relative 'B4U/linter'
require_relative 'B4U/version'
require_relative 'B4U/error'


module B4U
  def self.lint(config:, quiet: false, action: nil)
    LinterRunner.new(config:, action:, quiet:).run
  end

  # class ProjectChecker
  #   def self.ensure_project_root!(required_files)
  #     puts 'Checking project structure...'.cyan
  #     missing_files = required_files.reject { |file| File.exist?(file) }
  #     raise StructureError.new(files: missing_files, msg: "Missing project files: #{missing_files.join(', ')}") unless missing_files.empty?
  #   end
  # end
end
