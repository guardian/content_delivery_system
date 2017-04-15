require 'rspec'
require './lib/filename_utils'

describe 'FilenameUtils' do

  it 'should break down a file path' do
    fn = FilenameUtils.new("/path/to/somefile.ext")

    expect(fn.extension).to eq("ext")
    expect(fn.prefix).to eq("/path/to")
    expect(fn.filebase).to eq("somefile")
    expect(fn.filename).to eq("somefile.ext")
  end

  it 'should reconstitute a file path' do
    fn = FilenameUtils.new("/path/to/somefile.ext")

    expect(fn.filepath).to eq("/path/to/somefile.ext")
  end

  it 'should insert numbers into a file path' do
    fn = FilenameUtils.new("/path/to/somefile.ext")

    fn.increment!
    expect(fn.filepath).to eq("/path/to/somefile-1.ext")
    fn.increment!
    expect(fn.filepath).to eq("/path/to/somefile-2.ext")
    fn.increment!
    expect(fn.filepath).to eq("/path/to/somefile-3.ext")
  end

  it 'should handle unicode characters' do
    fn = FilenameUtils.new("/some/path/ت‎ثـﺏ")

    expect(fn.prefix).to eq("/some/path")
    expect(fn.filebase).to eq("ت‎ثـﺏ")
    fn.increment!
    expect(fn.filepath).to eq("/some/path/ت‎ثـﺏ-1")
  end

  it 'should handle spaces' do
    fn = FilenameUtils.new("/a kinda long/path_to/a file with spaces and € symbols.dat")

    expect(fn.prefix).to eq("/a kinda long/path_to")
    expect(fn.filebase).to eq("a file with spaces and € symbols")
    expect(fn.extension).to eq("dat")

    expect(fn.filepath).to eq("/a kinda long/path_to/a file with spaces and € symbols.dat")
    fn.increment!
    expect(fn.filepath).to eq("/a kinda long/path_to/a file with spaces and € symbols-1.dat")
  end

  it 'should handle a file with no extension' do
    fn = FilenameUtils.new("/path/to/extensionless_file")

    expect(fn.filepath).to eq("/path/to/extensionless_file")
    fn.increment!
    expect(fn.filepath).to eq("/path/to/extensionless_file-1")
  end

  it 'should drop in bitrate and codec annotations' do
    fn = FilenameUtils.new("/a kinda long/path_to/a file with spaces and € symbols.dat")
    fn.add_transcode_parts!(4096,"vp8")
    expect(fn.filepath).to eq("/a kinda long/path_to/a file with spaces and € symbols_4M_vp8.dat")

    fn = FilenameUtils.new("/a kinda long/path_to/a file with spaces and € symbols.dat")
    fn.add_transcode_parts!(360,"vp8")
    expect(fn.filepath).to eq("/a kinda long/path_to/a file with spaces and € symbols_360k_vp8.dat")
  end

  it 'should increment and return a new object' do
    fn = FilenameUtils.new("/a kinda long/path_to/a file with spaces and € symbols.dat")
    new = fn.increment

    expect(new).not_to equal(fn)
    expect(fn.filepath).to eq("/a kinda long/path_to/a file with spaces and € symbols.dat")
    expect(new.filepath).to eq("/a kinda long/path_to/a file with spaces and € symbols-1.dat")
  end
end