# frozen_string_literal: true

require_relative 'B4U/runner'
require_relative 'B4U/string_methods'
require_relative 'B4U/condition'
require_relative 'B4U/linter'
require_relative 'B4U/version'
require_relative 'B4U/error'


module B4U
  def self.lint(config:, quiet: false, action: nil)
    conditions = Condition.from_config(config['conditions'])
    met = Condition.check(conditions, config['linters'])

    skipped, to_run = config['linters'].partition { |l| l['run_if'] && !met[l['run_if']] }

    linters = to_run.map do |l|
      Linter.new(name: l['name'], command: l['command'], ignore: l.fetch('ignore', false))
    end

    puts "Running #{linters.size} lint tasks (B4U #{action})".cyan

    raw_results = LinterRunner.new(linters).run_all
    results = raw_results.to_h { |name, status, _| [name, status] }
    errors = raw_results.filter_map { |_, _, e| e }

    unless met.empty?
      puts 'Running pre-condition checks...'.cyan
      skipped_conditions = met.reject { |_, result| result }
      skipped_conditions.each do |id, _|
        label = conditions[id].label
        skipped_names = skipped.select { |l| l['run_if'] == id }.map { |l| l['name'] }
        puts "Skipping #{skipped_names.join(' & ')} because '#{label}' was not met".yellow
      end
      puts
    end

    groups = config['linters'].group_by { |l| l['run_if'] }
    groups.each do |condition_id, group_linters|
      if condition_id && met[condition_id]
        puts "#{conditions[condition_id].label}:".cyan
        group_linters.each do |l|
          next if skipped.include?(l)
          case results[l['name']]
          when :passed  then puts "  #{l['name']}: passed".green
          when :ignored then puts "  #{l['name']}: failed but ignored".yellow
          when :failed  then puts "  #{l['name']}: failed".red
          end
        end
      elsif condition_id.nil?
        group_linters.each do |l|
          case results[l['name']]
          when :passed  then puts "#{l['name']}: passed".green
          when :ignored then puts "#{l['name']}: failed but ignored".yellow
          when :failed  then puts "#{l['name']}: failed".red
          end
        end
      end
    end

    unless errors.empty?
      unless quiet
        puts
        puts '─' * 60
        errors.each do |error|
          puts " #{error.linter} output:".bold
          puts '─' * 60
          puts error.console_output.red
          puts '─' * 60
        end
      end
      puts "#{action} prevented because the following linters failed: #{errors.map(&:linter).join(', ')}".red
      exit 1
    end
  end

  # class ProjectChecker
  #   def self.ensure_project_root!(required_files)
  #     puts 'Checking project structure...'.cyan
  #     missing_files = required_files.reject { |file| File.exist?(file) }
  #     raise StructureError.new(files: missing_files, msg: "Missing project files: #{missing_files.join(', ')}") unless missing_files.empty?
  #   end
  # end
end
