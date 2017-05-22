#!/usr/bin/env ruby

$: << "./lib"
require 'CDSElasticTranscode.rb'
require 'filename_utils.rb'
require 'trollop'
require 'awesome_print'

#START MAIN
opts = Trollop.options do
  opt :input, "Input path", :type=>:string
  opt :pipeline, "Pipeline name", :type=>:string
  opt :preset, "Preset name", :type=>:string
  opt :output, "Output path and basename", :type=>:string
end

t = CDSElasticTranscode.new
outputs = t.presets_to_outputs(opts.preset.split(/,/), opts.output)
args = t.generate_args(t.lookup_pipeline(opts.pipeline), FilenameUtils.new(opts.input), outputs)

ap args

result = t.do_transcode(args,outputs,should_raise: true)

ap result

print result.job.output.status_detail