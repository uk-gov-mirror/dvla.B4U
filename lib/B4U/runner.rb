module B4U
  class LinterRunner
    def initialize(linters)
      @linters = linters
    end

    def run_all
      @linters.map do |linter|
        Thread.new do
          begin
            [linter.name, linter.run, nil]
          rescue LinterError => e
            [linter.name, :failed, e]
          end
        end
      end.map(&:join).map(&:value)
    end
  end
end
