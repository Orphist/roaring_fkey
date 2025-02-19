# frozen_string_literal: true

desc "Create data for benchmarking"
task populate: :environment, [:scale_factor] => :environment do |t, args|
  args.with_defaults(
    scale_factor: 100_000
  )

  Benchmarker.connect!

  Benchmarker.cleanup
  Benchmarker.populate(args[:scale_factor])

  Benchmarker.db_data_report
end

task clean: :environment do
  Benchmarker.cleanup
end

task reset: ["populate:clean", "populate"]