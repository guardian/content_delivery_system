require 'json'

class FinishedNotification
  attr_accessor :exitcode
  attr_accessor :log
  attr_accessor :routename

  def initialize(routename, exitcode, log)
    @routename=routename
    @exitcode=exitcode
    @log=log
  end

  def to_json
    hash={}
    self.instance_variables.each do |var|
      hash[var]=self.instance_variable_get var
    end
    hash.to_json
  end

end