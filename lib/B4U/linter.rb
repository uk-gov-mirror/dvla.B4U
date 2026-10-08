class Linter
  attr_reader :name, :command, :ignore

  def initialize(name:, command:, ignore: false)
    @name = name
    @command = command
    @ignore = ignore
  end

  def run
    console_output, status = Open3.capture2e(command)
    if status.success?
      :passed
    elsif ignore
      :ignored
    else
      raise LinterError.new(linter: name, console_output:)

    end
  end
end
