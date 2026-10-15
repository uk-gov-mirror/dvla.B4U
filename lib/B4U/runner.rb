module B4U
  class LinterRunner
    def initialize(config:, action:, quiet: false)
      @config = config
      @action = action
      @quiet = quiet
    end

    def run
      check_config
      check_conditions
      build_linters
      results = execute
      report(results)
    end

  private

    def check_config
      raise ConfigError, 'Linters have conditional dependencies but no conditions have been declared' if @config['conditions'] && @config['linters'].none? { |l| l['run_if'] }
      raise ConfigError, 'Linters are missing config' unless @config['linters']
      raise ConfigError, 'All linters must have a name and command' if @config['linters'].any? { |l| l['name'].nil? || l['command'].nil? }
    end

    def check_conditions
      @conditions = Condition.from_config(@config['conditions'])
      @met = Condition.check(@conditions, @config['linters'])
      return if @conditions.empty?

      puts 'Running pre-condition checks...'.cyan
      @conditions.each do |id, condition|
        case @met[id]
        when :met   then puts "  #{condition.label}: met".green
        when :unmet then puts "  #{condition.label}: unmet".yellow
        when nil    then puts "  #{condition.label}: skipped (no linters depend on this)".yellow
        else             raise "Unexpected condition state: #{@met[id]}"
        end
      end
      puts
    end

    def build_linters
      @linters = @config['linters'].map do |l|
        skip_reason = @conditions[l['run_if']]&.label if l['run_if'] && @met[l['run_if']] != :met
        Linter.new(name: l['name'], command: l['command'], ignore: l.fetch('ignore', false), skip_reason:)
      end
    end

    def execute
      skipped_count = @linters.count(&:skip_reason)
      puts "Running #{@linters.size - skipped_count} lint tasks (B4U #{@action})".cyan

      skipped = @linters.select(&:skip_reason).map { |l| [l.name, :skipped, nil] }
      threads = @linters.reject(&:skip_reason).map do |linter|
        Thread.new do
          [linter.name, linter.run, nil]
        rescue LinterError => e
          [linter.name, :failed, e]
        end
      end
      skipped + threads.map { |t| t.join.value }
    end

    def report(results)
      errors = results.filter_map { |_, _, e| e }
      skipped_count = results.count { |_, status, _| status == :skipped }

      results.each do |name, status, _|
        next if status == :skipped

        case status
        when :passed  then puts "✅ - #{name}".green
        when :ignored then puts "⚠️  - #{name} (failed but ignored)".yellow
        when :failed  then puts "❌ - #{name}".red
        else               raise "Unexpected status: #{status}"
        end
      end

      unless errors.empty?
        unless @quiet
          puts
          puts '─' * 60
          errors.each do |error|
            puts " #{error.linter} output:".bold
            puts '─' * 60
            puts error.console_output.red
            puts '─' * 60
          end
        end
        puts "#{@action} prevented because the following linters failed: #{errors.map(&:linter).join(', ')}".red
        exit 1
      end

      summary = 'All linters passed!'
      summary += " (#{skipped_count} skipped)" unless skipped_count.zero?
      puts summary.green
    end
  end
end
