require 'rspec'
require 'FinishedNotification'

describe 'FinishedNotification' do

  it 'should render instance variables as json' do
    f = FinishedNotification.new("routename",1,"route log here")
    expect(f.to_json).to eq '{"@routename":"routename","@exitcode":1,"@log":"route log here"}'
  end

end